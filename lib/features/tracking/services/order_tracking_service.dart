import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../models/order_tracking_model.dart';

enum SupplierBroadcastStatus {
  idle,
  checkingPermissions,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  acquiringGpsFix,
  broadcasting,
  gpsSignalLost,
  networkError,
  stopped,
}

class SupplierBroadcastState {
  final SupplierBroadcastStatus status;
  final Set<String> activeOrderIds;
  final double? lastLatitude;
  final double? lastLongitude;
  final double? lastAccuracy;
  final DateTime? lastPublishedAt;
  final String? errorMessage;

  const SupplierBroadcastState({
    this.status = SupplierBroadcastStatus.idle,
    this.activeOrderIds = const {},
    this.lastLatitude,
    this.lastLongitude,
    this.lastAccuracy,
    this.lastPublishedAt,
    this.errorMessage,
  });

  bool get isBroadcasting =>
      status == SupplierBroadcastStatus.broadcasting ||
      status == SupplierBroadcastStatus.acquiringGpsFix;

  bool isTrackingOrder(String orderId) => activeOrderIds.contains(orderId);

  SupplierBroadcastState copyWith({
    SupplierBroadcastStatus? status,
    Set<String>? activeOrderIds,
    double? lastLatitude,
    double? lastLongitude,
    double? lastAccuracy,
    DateTime? lastPublishedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupplierBroadcastState(
      status: status ?? this.status,
      activeOrderIds: activeOrderIds ?? this.activeOrderIds,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastAccuracy: lastAccuracy ?? this.lastAccuracy,
      lastPublishedAt: lastPublishedAt ?? this.lastPublishedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Manages real-time GPS coordinate acquisition and throttled publishing
/// for the supplier's active accepted/dispatched tanker deliveries.
class SupplierLocationBroadcaster extends ChangeNotifier {
  final ApiClient apiClient;
  final Future<GpsPermissionCheckResult> Function()? permissionChecker;
  final Future<Position> Function()? currentPositionGetter;
  final Stream<Position> Function()? positionStreamFactory;

  SupplierBroadcastState _state = const SupplierBroadcastState();
  SupplierBroadcastState get state => _state;

  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  Position? _latestPosition;

  // Throttling thresholds to minimize bandwidth and stationary writes
  static const double minDistanceMeters = 5.0;
  static const int minPublishIntervalSeconds = 3;
  static const int stationaryHeartbeatSeconds = 15;

  final Map<String, (double, double, DateTime)> _lastPublishedPerOrder = {};

  SupplierLocationBroadcaster({
    required this.apiClient,
    this.permissionChecker,
    this.currentPositionGetter,
    this.positionStreamFactory,
  });

  void _updateState(SupplierBroadcastState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Starts or attaches live GPS broadcasting for a specific accepted/dispatched order.
  Future<bool> startBroadcastingForOrder(String orderId) async {
    if (orderId.isEmpty) return false;

    final updatedOrders = Set<String>.from(_state.activeOrderIds)..add(orderId);
    _updateState(
      _state.copyWith(
        status: SupplierBroadcastStatus.checkingPermissions,
        activeOrderIds: updatedOrders,
        clearError: true,
      ),
    );

    final checkFn =
        permissionChecker ?? LocationService.checkAndRequestGpsPermission;
    final permResult = await checkFn();

    if (!permResult.isGranted) {
      SupplierBroadcastStatus mappedStatus =
          SupplierBroadcastStatus.permissionDenied;
      if (permResult.status == GpsAccessStatus.serviceDisabled) {
        mappedStatus = SupplierBroadcastStatus.serviceDisabled;
      } else if (permResult.status == GpsAccessStatus.deniedForever) {
        mappedStatus = SupplierBroadcastStatus.permissionDeniedForever;
      }
      _updateState(
        _state.copyWith(
          status: mappedStatus,
          errorMessage: permResult.message,
        ),
      );
      return false;
    }

    _updateState(
      _state.copyWith(
        status: SupplierBroadcastStatus.acquiringGpsFix,
        clearError: true,
      ),
    );

    // 1. Acquire initial real GPS fix immediately
    try {
      final posFn =
          currentPositionGetter ?? LocationService.acquireRealGpsPosition;
      final initialPos = await posFn();
      _latestPosition = initialPos;
      await _publishPositionToOrder(orderId, initialPos, force: true);
    } catch (e) {
      // Continue starting stream even if initial one-shot fix timed out
      _updateState(
        _state.copyWith(
          status: SupplierBroadcastStatus.acquiringGpsFix,
          errorMessage: 'Waiting for clear outdoor GPS satellite fix...',
        ),
      );
    }

    // 2. Ensure continuous position stream is active
    _ensurePositionStreamStarted();
    return true;
  }

  void _ensurePositionStreamStarted() {
    if (_positionSub != null) return;

    final streamFn =
        positionStreamFactory ??
        () => Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
            );

    _positionSub = streamFn().listen(
      (Position position) {
        _latestPosition = position;
        _onNewPosition(position);
      },
      onError: (Object error) {
        _updateState(
          _state.copyWith(
            status: SupplierBroadcastStatus.gpsSignalLost,
            errorMessage:
                'GPS signal interrupted. Tracking will resume automatically when signal returns.',
          ),
        );
      },
    );

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: stationaryHeartbeatSeconds),
      (_) {
        final pos = _latestPosition;
        if (pos != null && _state.activeOrderIds.isNotEmpty) {
          for (final orderId in List<String>.from(_state.activeOrderIds)) {
            _publishPositionToOrder(orderId, pos, force: false);
          }
        }
      },
    );
  }

  Future<void> _onNewPosition(Position position) async {
    if (_state.activeOrderIds.isEmpty) {
      await _cancelStreamSubscriptions();
      return;
    }
    for (final orderId in List<String>.from(_state.activeOrderIds)) {
      await _publishPositionToOrder(orderId, position, force: false);
    }
  }

  bool _shouldPublish(String orderId, Position pos, {required bool force}) {
    if (force) return true;
    final prev = _lastPublishedPerOrder[orderId];
    if (prev == null) return true;

    final now = DateTime.now();
    final elapsedSec = now.difference(prev.$3).inSeconds;
    if (elapsedSec < minPublishIntervalSeconds) {
      return false;
    }

    final movedMeters = LocationService.calculateDistanceMeters(
      prev.$1,
      prev.$2,
      pos.latitude,
      pos.longitude,
    );

    if (movedMeters >= minDistanceMeters) {
      return true;
    }

    // Heartbeat update if stationary for >= stationaryHeartbeatSeconds
    return elapsedSec >= stationaryHeartbeatSeconds;
  }

  Future<void> _publishPositionToOrder(
    String orderId,
    Position pos, {
    required bool force,
  }) async {
    if (!_state.activeOrderIds.contains(orderId)) return;
    if (!_shouldPublish(orderId, pos, force: force)) return;

    final now = DateTime.now();
    try {
      await apiClient.put(
        '/bookings/$orderId/tracking',
        data: {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'heading': pos.heading,
          'speed': pos.speed,
          'accuracy': pos.accuracy,
        },
      );
      _lastPublishedPerOrder[orderId] = (pos.latitude, pos.longitude, now);
      _updateState(
        _state.copyWith(
          status: SupplierBroadcastStatus.broadcasting,
          lastLatitude: pos.latitude,
          lastLongitude: pos.longitude,
          lastAccuracy: pos.accuracy,
          lastPublishedAt: now,
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      // If order is no longer active on server (e.g. completed or cancelled), stop tracking it
      if (e.statusCode == 400 || e.statusCode == 404) {
        await stopBroadcastingForOrder(orderId, notifyBackend: false);
      } else {
        _updateState(
          _state.copyWith(
            status: SupplierBroadcastStatus.networkError,
            errorMessage: e.message,
          ),
        );
      }
    } catch (_) {
      _updateState(
        _state.copyWith(
          status: SupplierBroadcastStatus.networkError,
          errorMessage:
              'Connection interrupted while publishing GPS update. Retrying...',
        ),
      );
    }
  }

  /// Stops publishing GPS updates for a completed, cancelled, or rejected order.
  Future<void> stopBroadcastingForOrder(
    String orderId, {
    bool notifyBackend = true,
  }) async {
    final updatedOrders = Set<String>.from(_state.activeOrderIds)
      ..remove(orderId);
    _lastPublishedPerOrder.remove(orderId);

    if (notifyBackend && orderId.isNotEmpty) {
      try {
        await apiClient.post('/bookings/$orderId/tracking/stop');
      } catch (_) {}
    }

    if (updatedOrders.isEmpty) {
      await _cancelStreamSubscriptions();
      _updateState(
        _state.copyWith(
          status: SupplierBroadcastStatus.stopped,
          activeOrderIds: const {},
          clearError: true,
        ),
      );
    } else {
      _updateState(_state.copyWith(activeOrderIds: updatedOrders));
    }
  }

  /// Stops all active GPS streams immediately (e.g., on logout or dispose).
  Future<void> stopAllBroadcasting() async {
    await _cancelStreamSubscriptions();
    _lastPublishedPerOrder.clear();
    _updateState(const SupplierBroadcastState());
  }

  Future<void> _cancelStreamSubscriptions() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}

/// Fetches real driving route geometry between two coordinates using OSRM.
/// Never returns a fake or fabricated route line.
class OsrmRoutingService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );

  Future<RouteGeometryResult?> fetchDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    CancelToken? cancelToken,
  }) async {
    try {
      final url =
          '${AppConfig.osrmRoutingBaseUrl}/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson';

      final response = await _dio.get(url, cancelToken: cancelToken);
      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final routes = data['routes'];
        if (routes is List && routes.isNotEmpty) {
          final firstRoute = Map<String, dynamic>.from(routes.first as Map);
          final distanceMeters =
              (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final durationSeconds =
              (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;
          final geometry = firstRoute['geometry'];
          if (geometry is Map && geometry['coordinates'] is List) {
            final coords = geometry['coordinates'] as List;
            final points = <LatLng>[];
            for (final c in coords) {
              if (c is List && c.length >= 2) {
                final lng = (c[0] as num).toDouble();
                final lat = (c[1] as num).toDouble();
                points.add(LatLng(lat, lng));
              }
            }
            if (points.length >= 2) {
              final distKm =
                  ((distanceMeters / 1000.0) * 10).roundToDouble() / 10.0;
              final durMin = (durationSeconds / 60.0).ceil().clamp(1, 999);
              return RouteGeometryResult(
                points: points,
                distanceKm: distKm,
                durationMinutes: durMin,
              );
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

/// Subscribes to a single order's live tracking state via Server-Sent Events (SSE)
/// with automatic fallback synchronization so neither customer nor supplier ever
/// needs to refresh manually.
class OrderTrackingRealtimeSubscription {
  final String orderId;
  final ApiClient apiClient;
  final ValueChanged<OrderTrackingModel> onUpdate;
  final ValueChanged<String>? onError;

  Dio? _sseDio;
  CancelToken? _sseCancelToken;
  CancelToken? _snapshotCancelToken;
  StreamSubscription<String>? _sseLineSub;
  Timer? _fallbackSyncTimer;
  bool _isDisposed = false;

  OrderTrackingRealtimeSubscription({
    required this.orderId,
    required this.apiClient,
    required this.onUpdate,
    this.onError,
  });

  Future<void> start() async {
    if (_isDisposed || orderId.isEmpty) return;

    // 1. Fetch immediate snapshot via REST
    await fetchLatestSnapshot(silent: true);
    if (_isDisposed) return;

    // 2. Connect to real-time SSE stream
    _connectSseStream();

    // 3. Start lightweight periodic sync fallback (every 3 seconds)
    _fallbackSyncTimer?.cancel();
    _fallbackSyncTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => fetchLatestSnapshot(silent: true),
    );
  }

  Future<void> fetchLatestSnapshot({bool silent = false}) async {
    if (_isDisposed || orderId.isEmpty) return;
    try {
      _snapshotCancelToken?.cancel();
      _snapshotCancelToken = CancelToken();
      final res = await apiClient.get(
        '/bookings/$orderId/tracking',
        cancelToken: _snapshotCancelToken,
      );
      if (_isDisposed) return;
      if (res['data'] is Map) {
        final model = OrderTrackingModel.fromJson(
          Map<String, dynamic>.from(res['data'] as Map),
        );
        onUpdate(model);

        // Stop active polling/streaming once order reaches terminal state
        if (model.isCompleted || model.isCancelledOrRejected) {
          _stopRealtimeChannels();
        }
      }
    } on ApiException catch (e) {
      if (!silent && !_isDisposed) {
        onError?.call(e.message);
      }
    } catch (e) {
      if (!silent && !_isDisposed) {
        onError?.call(e.toString());
      }
    }
  }

  Future<void> _connectSseStream() async {
    if (_isDisposed) return;
    try {
      final token = await apiClient.tokenStorage.getAccessToken();
      if (_isDisposed || token == null || token.isEmpty) return;

      _sseCancelToken?.cancel();
      _sseCancelToken = CancelToken();
      _sseDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          responseType: ResponseType.stream,
          connectTimeout: const Duration(seconds: 8),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream',
          },
        ),
      );

      final response = await _sseDio!.get<ResponseBody>(
        '/bookings/$orderId/tracking/stream',
        cancelToken: _sseCancelToken,
      );

      final stream = response.data?.stream;
      if (stream == null || _isDisposed) return;

      _sseLineSub?.cancel();
      _sseLineSub = stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (_isDisposed) return;
              if (line.startsWith('data:')) {
                final rawJson = line.substring(5).trim();
                if (rawJson.isNotEmpty) {
                  try {
                    final decoded = jsonDecode(rawJson);
                    if (decoded is Map) {
                      final model = OrderTrackingModel.fromJson(
                        Map<String, dynamic>.from(decoded),
                      );
                      onUpdate(model);
                      if (model.isCompleted || model.isCancelledOrRejected) {
                        _stopRealtimeChannels();
                      }
                    }
                  } catch (_) {}
                }
              }
            },
            onError: (_) {},
            cancelOnError: false,
          );
    } catch (_) {
      // Fallback timer continues syncing seamlessly if SSE connection fails
    }
  }

  void _stopRealtimeChannels() {
    _fallbackSyncTimer?.cancel();
    _fallbackSyncTimer = null;
    _sseLineSub?.cancel();
    _sseLineSub = null;
    _sseCancelToken?.cancel();
    _sseCancelToken = null;
    _snapshotCancelToken?.cancel();
    _snapshotCancelToken = null;
  }

  void dispose() {
    _isDisposed = true;
    _stopRealtimeChannels();
    _sseDio?.close(force: true);
  }
}
