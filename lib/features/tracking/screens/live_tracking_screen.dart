import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/location/location_service.dart';
import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../bookings/models/booking_model.dart';
import '../../bookings/screens/booking_alternatives_screen.dart';
import '../../reviews/screens/rate_delivery_screen.dart';
import '../models/order_tracking_model.dart';
import '../services/order_tracking_service.dart';

export '../models/order_tracking_model.dart' show UserRole, OrderTrackingModel;

/// Backward-compatible wrapper that renders the shared [OrderTrackingScreen].
class LiveTrackingScreen extends StatelessWidget {
  final BookingModel booking;
  final UserRole userRole;

  const LiveTrackingScreen({
    super.key,
    required this.booking,
    this.userRole = UserRole.customer,
  });

  @override
  Widget build(BuildContext context) {
    return OrderTrackingScreen(
      orderId: booking.id,
      userRole: userRole,
      initialBooking: booking,
    );
  }
}

/// Shared real-time interactive map tracking screen used by both Customers and Suppliers
/// for the same order ID and shared backend tracking record.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  final UserRole userRole;
  final BookingModel? initialBooking;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.userRole,
    this.initialBooking,
  });

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final OsrmRoutingService _routingService = OsrmRoutingService();

  OrderTrackingModel? _tracking;
  BookingModel? _booking;
  bool _isInitialLoading = true;
  bool _isUpdatingStatus = false;
  String? _connectionError;

  List<LatLng> _routePoints = const [];
  double? _routeDistanceKm;
  int? _routeDurationMin;
  LatLng? _lastRoutedSupplierPos;
  LatLng? _lastRoutedCustomerPos;

  bool _mapReady = false;
  bool _hasFramedBothLocations = false;

  OrderTrackingRealtimeSubscription? _realtimeSub;
  Timer? _clockTicker;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _booking = widget.initialBooking;
    if (_booking != null) {
      _tracking = OrderTrackingModel.fromBooking(_booking!);
      _isInitialLoading = false;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Refresh "Updated Xs ago" / stale indicator every second
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _tracking != null && _tracking!.updatedAt != null) {
        setState(() {});
      }
    });

    Future.microtask(_initializeTrackingSession);
  }

  @override
  void didUpdateWidget(covariant OrderTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      _realtimeSub?.dispose();
      if (widget.initialBooking != null) {
        _booking = widget.initialBooking;
        _tracking = OrderTrackingModel.fromBooking(_booking!);
      }
      Future.microtask(_initializeTrackingSession);
    } else if (oldWidget.userRole != widget.userRole &&
        widget.userRole == UserRole.supplier) {
      final status = _tracking?.orderStatus ?? _booking?.status ?? '';
      if (['accepted', 'dispatched', 'arriving'].contains(status)) {
        Future.microtask(() {
          if (!mounted) return;
          ref
              .read(waterFixControllerProvider)
              .locationBroadcaster
              .startBroadcastingForOrder(widget.orderId);
        });
      }
    }
  }

  Future<void> _initializeTrackingSession() async {
    final controller = ref.read(waterFixControllerProvider);

    // If opened by the assigned supplier while order is active post-acceptance,
    // immediately start or attach live GPS broadcasting.
    if (widget.userRole == UserRole.supplier && mounted) {
      final status = _tracking?.orderStatus ?? _booking?.status ?? '';
      if (['accepted', 'dispatched', 'arriving'].contains(status)) {
        await controller.locationBroadcaster.startBroadcastingForOrder(
          widget.orderId,
        );
      }
    }

    if (!mounted) return;

    // Subscribe to real-time updates for this orderId
    _realtimeSub = OrderTrackingRealtimeSubscription(
      orderId: widget.orderId,
      apiClient: controller.apiClient,
      onUpdate: _handleRealtimeTrackingUpdate,
      onError: (msg) {
        if (!mounted) return;
        setState(() {
          _connectionError = msg;
          _isInitialLoading = false;
        });
      },
    );
    await _realtimeSub!.start();
  }

  void _handleRealtimeTrackingUpdate(OrderTrackingModel updated) {
    if (!mounted) return;
    final previousSupplierPos = _tracking?.supplierLatLng;
    final hadBothBefore =
        (_tracking?.hasCustomerCoordinates ?? false) &&
        (_tracking?.hasSupplierCoordinates ?? false);

    setState(() {
      _tracking = updated;
      if (updated.booking != null) {
        _booking = updated.booking;
      }
      _connectionError = null;
      _isInitialLoading = false;
    });

    final nowHasBoth =
        updated.hasCustomerCoordinates && updated.hasSupplierCoordinates;

    // Frame camera when both locations first become available or when supplier moves
    if (_mapReady) {
      if (nowHasBoth && !hadBothBefore && !_hasFramedBothLocations) {
        _hasFramedBothLocations = true;
        _recenterMap();
      } else if (previousSupplierPos == null &&
          updated.supplierLatLng != null &&
          !updated.hasCustomerCoordinates) {
        _recenterMap();
      }
    }

    // Stop supplier GPS broadcaster if order transitioned to completed or cancelled
    if (widget.userRole == UserRole.supplier &&
        (updated.isCompleted || updated.isCancelledOrRejected)) {
      ref
          .read(waterFixControllerProvider)
          .locationBroadcaster
          .stopBroadcastingForOrder(widget.orderId, notifyBackend: false);
    }

    // Fetch real road route geometry if both coordinates exist
    _maybeRefreshRoadRoute(updated);
  }

  Future<void> _maybeRefreshRoadRoute(OrderTrackingModel model) async {
    if (!model.hasCustomerCoordinates || !model.hasSupplierCoordinates) {
      if (_routePoints.isNotEmpty && mounted) {
        setState(() {
          _routePoints = const [];
          _routeDistanceKm = null;
          _routeDurationMin = null;
        });
      }
      return;
    }

    final supPos = model.supplierLatLng!;
    final custPos = model.customerLatLng!;

    if (_lastRoutedSupplierPos != null && _lastRoutedCustomerPos != null) {
      final movedMeters = LocationService.calculateDistanceMeters(
        _lastRoutedSupplierPos!.latitude,
        _lastRoutedSupplierPos!.longitude,
        supPos.latitude,
        supPos.longitude,
      );
      final destChanged =
          LocationService.calculateDistanceMeters(
            _lastRoutedCustomerPos!.latitude,
            _lastRoutedCustomerPos!.longitude,
            custPos.latitude,
            custPos.longitude,
          ) >
          5.0;
      if (movedMeters < 40.0 && !destChanged && _routePoints.isNotEmpty) {
        return;
      }
    }

    _lastRoutedSupplierPos = supPos;
    _lastRoutedCustomerPos = custPos;

    final route = await _routingService.fetchDrivingRoute(
      origin: supPos,
      destination: custPos,
    );
    if (!mounted) return;
    setState(() {
      if (route != null && route.points.length >= 2) {
        _routePoints = route.points;
        _routeDistanceKm = route.distanceKm;
        _routeDurationMin = route.durationMinutes;
      } else {
        // Do not draw a fake route line if routing service is unavailable
        _routePoints = const [];
        _routeDistanceKm = null;
        _routeDurationMin = null;
      }
    });
  }

  void _recenterMap() {
    if (!_mapReady) return;
    final custLatLng = _tracking?.customerLatLng;
    final supLatLng = _tracking?.supplierLatLng;

    try {
      if (custLatLng != null && supLatLng != null) {
        final distMeters = LocationService.calculateDistanceMeters(
          custLatLng.latitude,
          custLatLng.longitude,
          supLatLng.latitude,
          supLatLng.longitude,
        );
        if (distMeters < 30) {
          _mapController.move(supLatLng, 16.0);
        } else {
          _mapController.fitCamera(
            CameraFit.coordinates(
              coordinates: [custLatLng, supLatLng],
              padding: const EdgeInsets.fromLTRB(56, 90, 56, 56),
              maxZoom: 16.5,
            ),
          );
        }
      } else if (supLatLng != null) {
        _mapController.move(supLatLng, 15.2);
      } else if (custLatLng != null) {
        _mapController.move(custLatLng, 15.2);
      }
    } catch (_) {}
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    try {
      final cam = _mapController.camera;
      final nextZoom = (cam.zoom + delta).clamp(3.0, 18.5);
      _mapController.move(cam.center, nextZoom);
    } catch (_) {}
  }

  Future<void> _openExternalGoogleMapsNavigation() async {
    final cust = _tracking?.customerLatLng;
    if (cust == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer delivery coordinates are not available.'),
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${cust.latitude},${cust.longitude}&travelmode=driving',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Destination: ${cust.latitude.toStringAsFixed(5)}, ${cust.longitude.toStringAsFixed(5)}',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Destination: ${cust.latitude.toStringAsFixed(5)}, ${cust.longitude.toStringAsFixed(5)}',
          ),
        ),
      );
    }
  }

  Future<void> _updateOrderStatus(
    String nextStatus, {
    String? reason,
    String? deliveryCode,
  }) async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);
    final controller = ref.read(waterFixControllerProvider);
    try {
      final updatedBooking = await controller.updateBookingStatus(
        bookingId: widget.orderId,
        status: nextStatus,
        reason: reason,
        deliveryCode: deliveryCode,
      );
      if (!mounted) return;
      setState(() {
        _booking = updatedBooking;
      });
      await _realtimeSub?.fetchLatestSnapshot();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: WaterFixColors.coralAlertText,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  void _showSupplierCompleteDialog() {
    final codeCtrl = TextEditingController();
    final customerName = _booking?.customerName ?? 'the customer';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 4-digit delivery verification code from $customerName (or leave blank for authorized supplier completion):',
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                hintText: '4-digit code (e.g. 4821)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _updateOrderStatus(
                'delivered',
                deliveryCode: codeCtrl.text.trim(),
              );
            },
            child: const Text('Confirm Delivered'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _realtimeSub?.dispose();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String get _currentStatus =>
      _tracking?.orderStatus ?? _booking?.status ?? 'requested';

  int get _activeStep {
    switch (_currentStatus) {
      case 'accepted':
        return 1;
      case 'dispatched':
        return 2;
      case 'arriving':
        return 3;
      case 'delivered':
        return 4;
      default:
        return 0;
    }
  }

  String get _statusBadgeLabel {
    switch (_currentStatus) {
      case 'requested':
        return 'Awaiting Supplier';
      case 'accepted':
        return 'Accepted';
      case 'dispatched':
        return 'Dispatched';
      case 'arriving':
        return 'Arriving';
      case 'delivered':
        return 'Completed';
      case 'cancelled':
      case 'rejected':
        return 'Cancelled';
      default:
        return _currentStatus;
    }
  }

  String get _headlineTitleLabel {
    switch (_currentStatus) {
      case 'requested':
        return 'ORDER STATUS';
      case 'accepted':
      case 'dispatched':
      case 'arriving':
        return 'ESTIMATED ARRIVAL';
      case 'delivered':
        return 'DELIVERY STATUS';
      default:
        return 'ORDER STATUS';
    }
  }

  String get _headlinePrimaryValue {
    switch (_currentStatus) {
      case 'requested':
        return 'Pending';
      case 'delivered':
        return 'Completed';
      case 'cancelled':
      case 'rejected':
        return 'Cancelled';
      case 'accepted':
      case 'dispatched':
      case 'arriving':
        if (_routeDurationMin != null) {
          return '$_routeDurationMin min';
        }
        final minEta = _booking?.estimatedArrivalMinutesMin;
        if (minEta != null) {
          return '$minEta min';
        }
        return 'Active';
      default:
        return _currentStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);
    final broadcastState = controller.locationBroadcaster.state;
    final tracking = _tracking;
    final booking = _booking;

    final custLatLng = tracking?.customerLatLng;
    final supLatLng = tracking?.supplierLatLng;
    final isPreAcceptance = _currentStatus == 'requested';
    final isStale = tracking?.isLocationStale() == true;

    // Initial center uses real customer delivery location or real supplier GPS location
    final LatLng? initialCenter = supLatLng ?? custLatLng;

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Interactive Real Map Section
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildMapArea(
                      initialCenter: initialCenter,
                      custLatLng: custLatLng,
                      supLatLng: supLatLng,
                      isPreAcceptance: isPreAcceptance,
                    ),
                  ),

                  // Top Back Button + Role Pill + Map Controls
                  Positioned(
                    top: 14,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SquareIconButton(
                              icon: Icons.chevron_left_rounded,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: WaterFixColors.primaryBlack.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.userRole == UserRole.supplier
                                        ? Icons.local_shipping_outlined
                                        : Icons.person_pin_circle_outlined,
                                    size: 15,
                                    color: WaterFixColors.skyBlue,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.userRole == UserRole.supplier
                                        ? 'Supplier Live View'
                                        : 'Customer Live View',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SquareIconButton(
                              key: const Key('recenter_map_button'),
                              icon: Icons.my_location_rounded,
                              onTap: _recenterMap,
                            ),
                            const SizedBox(height: 8),
                            SquareIconButton(
                              key: const Key('zoom_in_map_button'),
                              icon: Icons.add_rounded,
                              onTap: () => _zoomBy(1.0),
                            ),
                            const SizedBox(height: 8),
                            SquareIconButton(
                              key: const Key('zoom_out_map_button'),
                              icon: Icons.remove_rounded,
                              onTap: () => _zoomBy(-1.0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Pre-acceptance banner or Waiting-for-GPS / Permission / Stale banner on Map
                  Positioned(
                    bottom: 34,
                    left: 16,
                    right: 16,
                    child: _buildMapStatusOverlay(
                      isPreAcceptance: isPreAcceptance,
                      hasCustomerCoords: custLatLng != null,
                      hasSupplierCoords: supLatLng != null,
                      isStale: isStale,
                      broadcastState: broadcastState,
                      controller: controller,
                    ),
                  ),

                  // Required OpenStreetMap Attribution
                  Positioned(
                    bottom: 6,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: WaterFixColors.primaryBlack,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Order & Live Tracking Information Panel
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  color: WaterFixColors.cardBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Connection Error Banner if any
                      if (_connectionError != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: WaterFixColors.coralAlertBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                size: 18,
                                color: WaterFixColors.coralAlertText,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _connectionError!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: WaterFixColors.coralAlertText,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _realtimeSub?.fetchLatestSnapshot(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Top Status & ETA Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _headlineTitleLabel,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                          if (booking != null)
                            Text(
                              '${booking.bookingCode} · ${booking.capacityLiters} L · Rs ${booking.totalPrice}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: WaterFixColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _headlinePrimaryValue,
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: WaterFixColors.primaryBlack,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            key: const Key('order_status_badge'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _currentStatus == 'cancelled' ||
                                      _currentStatus == 'rejected'
                                  ? WaterFixColors.coralAlertBg
                                  : _currentStatus == 'requested'
                                  ? const Color(0xFFEBEBE6)
                                  : WaterFixColors.skyBlue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusBadgeLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color:
                                    _currentStatus == 'cancelled' ||
                                        _currentStatus == 'rejected'
                                    ? WaterFixColors.coralAlertText
                                    : WaterFixColors.primaryBlack,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Live Last-Updated & Distance Indicator Row
                      const SizedBox(height: 8),
                      _buildLastUpdatedAndDistanceRow(
                        tracking: tracking,
                        isStale: isStale,
                      ),

                      const SizedBox(height: 16),

                      // 4-Step Progress Bar: Accepted | Dispatched | Arriving | Completed
                      Row(
                        children: List.generate(4, (index) {
                          final stepNum = index + 1;
                          Color barColor = WaterFixColors.cardBorder;
                          if (stepNum < _activeStep) {
                            barColor = WaterFixColors.primaryBlack;
                          } else if (stepNum == _activeStep) {
                            barColor = WaterFixColors.skyBlue;
                          }
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 6,
                              margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 7),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Accepted',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Dispatched',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Arriving',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Delivery Destination Address Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: WaterFixColors.scaffoldBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: WaterFixColors.primaryBlack,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: WaterFixColors.skyBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'DELIVERY DESTINATION',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: WaterFixColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tracking?.deliveryAddressLine.isNotEmpty ==
                                            true
                                        ? tracking!.deliveryAddressLine
                                        : (booking?.addressLine ??
                                              'Delivery address'),
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: WaterFixColors.primaryBlack,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.userRole == UserRole.supplier &&
                                custLatLng != null)
                              IconButton(
                                key: const Key('external_navigation_button'),
                                tooltip: 'Navigate in Google Maps',
                                onPressed: _openExternalGoogleMapsNavigation,
                                icon: const Icon(
                                  Icons.directions_rounded,
                                  color: WaterFixColors.tankerBlue,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Role-Specific Counterparty & Controls Section
                      if (widget.userRole == UserRole.supplier)
                        _buildSupplierBottomControls(
                          booking: booking,
                          broadcastState: broadcastState,
                          controller: controller,
                          hasCustomerCoords: custLatLng != null,
                        )
                      else
                        _buildCustomerBottomControls(booking: booking),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapArea({
    required LatLng? initialCenter,
    required LatLng? custLatLng,
    required LatLng? supLatLng,
    required bool isPreAcceptance,
  }) {
    if (_isInitialLoading && initialCenter == null) {
      return Container(
        color: const Color(0xFFEAF2F8),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: WaterFixColors.primaryBlack),
              SizedBox(height: 12),
              Text(
                'Loading order location...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: WaterFixColors.primaryBlack,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (initialCenter == null) {
      return Container(
        color: const Color(0xFFEAF2F8),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 42,
                color: WaterFixColors.primaryBlack,
              ),
              const SizedBox(height: 12),
              Text(
                isPreAcceptance
                    ? 'Exact delivery GPS coordinates were not saved for this order. Waiting for supplier acceptance.'
                    : 'Waiting for valid GPS coordinates for this order...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: WaterFixColors.primaryBlack,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final markers = <Marker>[];

    // 1. Customer Delivery Destination Marker (real saved delivery coordinates)
    if (custLatLng != null) {
      markers.add(
        Marker(
          key: const Key('customer_destination_marker'),
          point: custLatLng,
          width: 120,
          height: 88,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: WaterFixColors.primaryBlack,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Delivery',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: WaterFixColors.primaryBlack,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. Supplier Live GPS Marker (ONLY shown after acceptance when real GPS coordinates exist)
    if (!isPreAcceptance && supLatLng != null) {
      markers.add(
        Marker(
          key: const Key('supplier_live_marker'),
          point: supLatLng,
          width: 130,
          height: 92,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale = 1.0 + (_pulseController.value * 0.08);
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: WaterFixColors.skyBlue,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: WaterFixColors.primaryBlack,
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        'Water Tanker',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: WaterFixColors.primaryBlack,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: WaterFixColors.skyBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: WaterFixColors.primaryBlack,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: WaterFixColors.skyBlue.withValues(
                                alpha: 0.45,
                              ),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: WaterFixColors.primaryBlack,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return FlutterMap(
      key: const Key('interactive_order_map'),
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 14.5,
        minZoom: 3.0,
        maxZoom: 18.5,
        onMapReady: () {
          _mapReady = true;
          _recenterMap();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.mapTileUrl,
          userAgentPackageName: AppConfig.applicationId,
          maxZoom: 19,
        ),
        if (!isPreAcceptance && _routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 4.5,
                color: WaterFixColors.primaryBlack,
              ),
            ],
          ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildMapStatusOverlay({
    required bool isPreAcceptance,
    required bool hasCustomerCoords,
    required bool hasSupplierCoords,
    required bool isStale,
    required SupplierBroadcastState broadcastState,
    required WaterFixController controller,
  }) {
    // 1. Before supplier acceptance: clearly state that supplier hasn't accepted yet
    if (isPreAcceptance) {
      return Container(
        key: const Key('pre_acceptance_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: WaterFixColors.primaryBlack.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              color: WaterFixColors.skyBlue,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.userRole == UserRole.supplier
                    ? 'Order not accepted yet. Accept this order below to activate live GPS tracking.'
                    : 'Waiting for supplier to accept your order. Live tanker GPS tracking begins after acceptance.',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Supplier GPS permission / service disabled error banner on Supplier screen
    if (widget.userRole == UserRole.supplier &&
        (_currentStatus == 'accepted' ||
            _currentStatus == 'dispatched' ||
            _currentStatus == 'arriving')) {
      if (broadcastState.status == SupplierBroadcastStatus.serviceDisabled ||
          broadcastState.status == SupplierBroadcastStatus.permissionDenied ||
          broadcastState.status ==
              SupplierBroadcastStatus.permissionDeniedForever) {
        return Container(
          key: const Key('supplier_gps_permission_error_banner'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: WaterFixColors.coralAlertBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WaterFixColors.coralAlertText),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.gps_off_rounded,
                color: WaterFixColors.coralAlertText,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  broadcastState.errorMessage ??
                      'GPS permission is required to share live tanker location.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: WaterFixColors.coralAlertText,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (broadcastState.status ==
                      SupplierBroadcastStatus.serviceDisabled) {
                    await LocationService.openDeviceLocationSettings();
                  } else if (broadcastState.status ==
                      SupplierBroadcastStatus.permissionDeniedForever) {
                    await LocationService.openAppPermissionSettings();
                  }
                  await controller.locationBroadcaster
                      .startBroadcastingForOrder(widget.orderId);
                },
                child: const Text(
                  'Enable GPS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: WaterFixColors.primaryBlack,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    // 3. Post-acceptance waiting for first supplier GPS fix
    if (!hasSupplierCoords &&
        ['accepted', 'dispatched', 'arriving'].contains(_currentStatus)) {
      return Container(
        key: const Key('waiting_for_supplier_gps_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: WaterFixColors.primaryBlack.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: WaterFixColors.skyBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.userRole == UserRole.supplier
                    ? 'Acquiring your live GPS coordinates to share with customer...'
                    : 'Order accepted · Waiting for supplier\'s initial live GPS position...',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            if (widget.userRole == UserRole.supplier)
              TextButton(
                onPressed: () {
                  controller.locationBroadcaster.startBroadcastingForOrder(
                    widget.orderId,
                  );
                },
                child: const Text(
                  'Retry GPS',
                  style: TextStyle(
                    color: WaterFixColors.skyBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 4. Stale GPS signal warning
    if (isStale) {
      return Container(
        key: const Key('stale_gps_warning_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD97706)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB45309),
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Supplier GPS signal may be delayed (${_tracking?.formatLastUpdated() ?? "stale"}).',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLastUpdatedAndDistanceRow({
    required OrderTrackingModel? tracking,
    required bool isStale,
  }) {
    final isPre = _currentStatus == 'requested';
    final isDone = _currentStatus == 'delivered';
    final isCancelled =
        _currentStatus == 'cancelled' || _currentStatus == 'rejected';

    String statusText;
    Color dotColor;

    if (isPre) {
      statusText = 'Waiting for supplier acceptance';
      dotColor = WaterFixColors.textSecondary;
    } else if (isDone) {
      statusText = 'Delivery completed · Live GPS tracking stopped';
      dotColor = WaterFixColors.successGreen;
    } else if (isCancelled) {
      statusText = 'Order cancelled · Live GPS tracking inactive';
      dotColor = WaterFixColors.coralAlertText;
    } else if (isStale) {
      statusText = 'Stale signal · ${tracking?.formatLastUpdated() ?? ""}';
      dotColor = const Color(0xFFD97706);
    } else if (tracking?.hasSupplierCoordinates == true) {
      statusText = 'Live GPS · ${tracking!.formatLastUpdated()}';
      dotColor = WaterFixColors.successGreen;
    } else {
      statusText = 'Waiting for supplier GPS fix...';
      dotColor = WaterFixColors.tankerBlue;
    }

    double? displayDistKm = _routeDistanceKm;
    if (displayDistKm == null &&
        tracking?.hasSupplierCoordinates == true &&
        tracking?.hasCustomerCoordinates == true) {
      displayDistKm = LocationService.calculateDistanceKm(
        tracking!.latitude!,
        tracking.longitude!,
        tracking.deliveryLat!,
        tracking.deliveryLng!,
      );
    }

    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            statusText,
            key: const Key('tracking_last_updated_text'),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isStale
                  ? const Color(0xFFB45309)
                  : WaterFixColors.textSecondary,
            ),
          ),
        ),
        if (!isPre && displayDistKm != null)
          Text(
            '$displayDistKm km away',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerBottomControls({required BookingModel? booking}) {
    if (booking == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Driver / Supplier Contact Card
        AnimatedSectionEntrance(
          delay: const Duration(milliseconds: 50),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WaterFixColors.scaffoldBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: WaterFixColors.skyBlue,
                  child: Text(
                    booking.driverInitials,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: WaterFixColors.primaryBlack,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.driverName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: WaterFixColors.primaryBlack,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking.supplierBusinessName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: WaterFixColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                PressableScale(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Supplier contact: ${booking.supplierPhone.isNotEmpty ? booking.supplierPhone : "Available in booking details"}',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: WaterFixColors.primaryBlack,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Delivery Code Card
        AnimatedSectionEntrance(
          delay: const Duration(milliseconds: 90),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WaterFixColors.skyBlueLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DELIVERY CODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: WaterFixColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.formattedDeliveryCode,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: WaterFixColors.primaryBlack,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Share it with the driver when they arrive.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: WaterFixColors.primaryBlack,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (booking.isCancelledBySupplier)
          SkyBlueButton(
            label: 'Find another supplier',
            leadingIcon: Icons.auto_awesome,
            onPressed: () {
              Navigator.of(context).pushReplacement(
                WaterFixPageRoute(
                  page: BookingAlternativesScreen(cancelledBooking: booking),
                ),
              );
            },
          )
        else if (_currentStatus == 'delivered' && !booking.isReviewed)
          PrimaryArrowButton(
            label: 'Rate your delivery',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                WaterFixPageRoute(page: RateDeliveryScreen(booking: booking)),
              );
            },
          )
        else if (booking.canCustomerCancel)
          Center(
            child: TextButton(
              onPressed: _isUpdatingStatus
                  ? null
                  : () => _updateOrderStatus(
                      'cancelled',
                      reason: 'Cancelled by customer',
                    ),
              child: const Text(
                'Cancel booking',
                style: TextStyle(
                  color: WaterFixColors.coralAlertText,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSupplierBottomControls({
    required BookingModel? booking,
    required SupplierBroadcastState broadcastState,
    required WaterFixController controller,
    required bool hasCustomerCoords,
  }) {
    final isTrackingThisOrder = broadcastState.isTrackingOrder(widget.orderId);
    final isActiveDelivery = [
      'accepted',
      'dispatched',
      'arriving',
    ].contains(_currentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Contact Card for Supplier
        if (booking != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WaterFixColors.scaffoldBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: WaterFixColors.skyBlue,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: WaterFixColors.primaryBlack,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.customerName,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: WaterFixColors.primaryBlack,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Customer · ${booking.customerPhone}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: WaterFixColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasCustomerCoords)
                  OutlinedButton.icon(
                    onPressed: _openExternalGoogleMapsNavigation,
                    icon: const Icon(Icons.navigation_outlined, size: 16),
                    label: const Text('Navigate'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // Supplier GPS Broadcasting Status Pill
        if (isActiveDelivery)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: WaterFixColors.skyBlueLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  isTrackingThisOrder
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_not_fixed_rounded,
                  size: 18,
                  color: WaterFixColors.primaryBlack,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tracking?.hasSupplierCoordinates == true
                        ? 'Broadcasting your GPS (${_tracking!.latitude!.toStringAsFixed(4)}, ${_tracking!.longitude!.toStringAsFixed(4)})'
                        : 'Live GPS broadcasting active for this delivery',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: WaterFixColors.primaryBlack,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),

        // Supplier Order Workflow Buttons (Accept / Dispatch / Complete)
        if (_currentStatus == 'requested')
          Row(
            children: [
              Expanded(
                child: SkyBlueButton(
                  label: 'Accept order',
                  isLoading: _isUpdatingStatus,
                  onPressed: () => _updateOrderStatus('accepted'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _isUpdatingStatus
                    ? null
                    : () => _updateOrderStatus(
                        'rejected',
                        reason: 'Tanker unavailable for immediate dispatch.',
                      ),
                child: const Text('Reject'),
              ),
            ],
          )
        else if (_currentStatus == 'accepted')
          Column(
            children: [
              SkyBlueButton(
                label: 'Dispatch tanker & broadcast GPS',
                leadingIcon: Icons.local_shipping_outlined,
                isLoading: _isUpdatingStatus,
                onPressed: () => _updateOrderStatus('dispatched'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isUpdatingStatus
                      ? null
                      : _showSupplierCompleteDialog,
                  child: const Text('Complete delivery'),
                ),
              ),
            ],
          )
        else if (_currentStatus == 'dispatched' || _currentStatus == 'arriving')
          PrimaryArrowButton(
            label: 'Complete delivery',
            isLoading: _isUpdatingStatus,
            onPressed: _showSupplierCompleteDialog,
          ),
      ],
    );
  }
}
