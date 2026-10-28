import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/location/islamabad_localities.dart';
import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tanker_illustration.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../../shared/widgets/waterfix_logo.dart';
import '../../bookings/models/booking_model.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../tracking/screens/live_tracking_screen.dart';

class SupplierDashboardScreen extends ConsumerStatefulWidget {
  const SupplierDashboardScreen({super.key});

  @override
  ConsumerState<SupplierDashboardScreen> createState() =>
      _SupplierDashboardScreenState();
}

class _SupplierDashboardScreenState
    extends ConsumerState<SupplierDashboardScreen> {
  int _selectedTab = 0; // 0: Orders, 1: Listings, 2: Wallet, 3: Supplier Account

  final _bNameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _tankersOwnedCtrl = TextEditingController();
  final _availableWaterCtrl = TextEditingController();
  final _pricePer1000Ctrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  String? _loadedProfileId;
  IslamabadLocality? _selectedLocality;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final ctrl = ref.read(waterFixControllerProvider);
      await ctrl.fetchSupplierDashboard();
      await ctrl.fetchWallet();

      // Check if redirected back from Safepay payment return page with query parameters
      if (kIsWeb) {
        try {
          final uri = Uri.base;
          final paymentRef = uri.queryParameters['paymentRef'];
          final status = uri.queryParameters['status'];
          final target = uri.queryParameters['target'];

          if (paymentRef != null && paymentRef.isNotEmpty) {
            if (target == 'orders') {
              setState(() => _selectedTab = 0);
            } else if (target == 'listings') {
              setState(() => _selectedTab = 1);
            } else if (target == 'account') {
              setState(() => _selectedTab = 3);
            } else {
              setState(() => _selectedTab = 2);
            }

            if (status == 'paid') {
              final res = await ctrl.verifySafepayCommissionPayment(
                paymentReference: paymentRef,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Commission payment verified (Rs ${res['amount'] ?? ''}). Wallet updated!',
                    ),
                  ),
                );
              }
            }
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _bNameCtrl.dispose();
    _areaCtrl.dispose();
    _radiusCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _tankersOwnedCtrl.dispose();
    _availableWaterCtrl.dispose();
    _pricePer1000Ctrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
  }

  void _syncProfileControllers(Map<String, dynamic>? profile) {
    if (profile == null) return;
    final id = profile['_id']?.toString();
    if (id != null && id != _loadedProfileId) {
      _loadedProfileId = id;
      _bNameCtrl.text = profile['businessName']?.toString() ?? '';
      _areaCtrl.text = profile['serviceAreaText']?.toString() ?? 'Islamabad';
      final radius = (profile['serviceRadiusKm'] as num?)?.toInt() ?? 15;
      _radiusCtrl.text = (radius > 20 ? 20 : radius).toString();
      _emailCtrl.text = profile['email']?.toString() ??
          ref.read(waterFixControllerProvider).currentUser?.email ??
          '';
      _phoneCtrl.text = profile['phone']?.toString() ??
          ref.read(waterFixControllerProvider).currentUser?.phone ??
          '';
      _tankersOwnedCtrl.text =
          ((profile['tankersOwned'] as num?)?.toInt() ?? 1).toString();
      _availableWaterCtrl.text =
          ((profile['availableWaterLiters'] as num?)?.toInt() ?? 10000)
              .toString();
      _pricePer1000Ctrl.text =
          ((profile['pricePer1000Liters'] as num?)?.toInt() ?? 1800).toString();
      _logoUrlCtrl.text = profile['companyLogo']?.toString() ?? '';

      final currentArea = _areaCtrl.text.toLowerCase();
      try {
        _selectedLocality = kIslamabadLocalities.firstWhere(
          (loc) =>
              loc.name.toLowerCase().contains(currentArea) ||
              loc.sector.toLowerCase().contains(currentArea),
        );
      } catch (_) {}
    }
  }

  void _showLocalityPickerModal(
    BuildContext context,
    ValueChanged<IslamabadLocality> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WaterFixColors.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = kIslamabadLocalities.where((loc) {
              if (filter.isEmpty) return true;
              return loc.name.toLowerCase().contains(filter.toLowerCase()) ||
                  loc.sector.toLowerCase().contains(filter.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Islamabad Locality',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: WaterFixColors.primaryBlack,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (val) => setModalState(() => filter = val),
                      decoration: const InputDecoration(
                        hintText:
                            'Search sector or area (e.g. Hostel City, F-10, G-11)...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final loc = filtered[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: WaterFixColors.primaryBlack,
                            ),
                            title: Text(
                              loc.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Sector: ${loc.sector} · Lat: ${loc.lat}, Lng: ${loc.lng}',
                            ),
                            onTap: () {
                              onSelected(loc);
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditInventorySheet(
    BuildContext context,
    WaterFixController controller,
  ) {
    final profile = controller.supplierProfile;
    final stockCtrl = TextEditingController(
      text: ((profile?['availableWaterLiters'] as num?)?.toInt() ?? 10000)
          .toString(),
    );
    final priceCtrl = TextEditingController(
      text: ((profile?['pricePer1000Liters'] as num?)?.toInt() ?? 1800)
          .toString(),
    );
    final tankersCtrl = TextEditingController(
      text: ((profile?['tankersOwned'] as num?)?.toInt() ?? 4).toString(),
    );
    final radiusCtrl = TextEditingController(
      text: ((profile?['serviceRadiusKm'] as num?)?.toInt() ?? 15).toString(),
    );
    bool isAvail = profile?['isAvailable'] != false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WaterFixColors.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            22,
            22,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Manage Water Inventory',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: WaterFixColors.primaryBlack,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Set your company\'s available water inventory, pricing per 1,000 L, and fleet size.',
                  style: TextStyle(
                    fontSize: 13,
                    color: WaterFixColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Available Water Inventory',
                    hintText: 'e.g. 10000 (Max 500,000 L)',
                    suffixText: 'Litres',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Price per 1,000 Litres',
                    hintText: 'e.g. 1800 (PKR 100 - 25,000)',
                    prefixText: 'PKR ',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: tankersCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Tankers Fleet Size',
                    hintText: 'e.g. 4 (1 - 100 tankers)',
                    suffixText: 'Tankers',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: radiusCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Delivery Radius (Max 20 km)',
                    hintText: 'e.g. 15',
                    suffixText: 'km',
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Accepting Orders',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    isAvail
                        ? 'Customers can discover and book from your inventory'
                        : 'Your company is temporarily paused',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: isAvail,
                  onChanged: (val) {
                    setModalState(() {
                      isAvail = val;
                    });
                  },
                ),
                const SizedBox(height: 18),
                PrimaryArrowButton(
                  label: 'Save Inventory & Pricing',
                  onPressed: () async {
                    final stock =
                        int.tryParse(stockCtrl.text.trim()) ?? 10000;
                    final price =
                        int.tryParse(priceCtrl.text.trim()) ?? 1800;
                    final tankers =
                        int.tryParse(tankersCtrl.text.trim()) ?? 1;
                    int radius = int.tryParse(radiusCtrl.text.trim()) ?? 15;
                    if (radius > 20) radius = 20;
                    if (radius < 1) radius = 1;

                    if (stock < 0 || stock > 500000) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Available inventory must be between 0 and 500,000 litres.'),
                          backgroundColor: WaterFixColors.coralAlertText,
                        ),
                      );
                      return;
                    }
                    if (tankers < 1 || tankers > 100) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tanker fleet size must be between 1 and 100 tankers.'),
                          backgroundColor: WaterFixColors.coralAlertText,
                        ),
                      );
                      return;
                    }
                    if (price < 100 || price > 25000) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Price per 1,000 L must be between PKR 100 and PKR 25,000.'),
                          backgroundColor: WaterFixColors.coralAlertText,
                        ),
                      );
                      return;
                    }

                    Navigator.of(ctx).pop();
                    await controller.updateSupplierProfileData({
                      'availableWaterLiters': stock,
                      'pricePer1000Liters': price,
                      'tankersOwned': tankers,
                      'serviceRadiusKm': radius,
                      'isAvailable': isAvail,
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Company water inventory & pricing updated.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfileModal(
    BuildContext context,
    WaterFixController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WaterFixColors.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            22,
            22,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Professional Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: WaterFixColors.primaryBlack,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Update company details, dispatch area, delivery radius, and fleet information.',
                  style: TextStyle(
                    fontSize: 13,
                    color: WaterFixColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _bNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company / Business Name',
                    prefixIcon: Icon(Icons.business_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Registered Email (Syncs with Account)',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone Number (Syncs with Account)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    _showLocalityPickerModal(context, (loc) {
                      setModalState(() {
                        _selectedLocality = loc;
                        _areaCtrl.text = loc.name;
                      });
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: WaterFixColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: WaterFixColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: WaterFixColors.primaryBlack,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Base Location (Islamabad Localities)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _areaCtrl.text.isNotEmpty
                                    ? _areaCtrl.text
                                    : 'Select locality (50+ available)',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _radiusCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Delivery Radius (Max 20 km strictly enforced)',
                    suffixText: 'km',
                    prefixIcon: Icon(Icons.radar_rounded),
                    helperText: 'Verified delivery distance limit is 20 km.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tankersOwnedCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Tankers Owned (Fleet Size: 1 - 100)',
                    hintText: 'e.g. 4',
                    suffixText: 'Tankers',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryArrowButton(
                        label: 'Save Changes',
                        onPressed: () async {
                          int radius = int.tryParse(_radiusCtrl.text.trim()) ?? 15;
                          if (radius > 20) radius = 20;
                          if (radius < 1) radius = 1;
                          final tankers = int.tryParse(_tankersOwnedCtrl.text.trim()) ?? 1;

                          if (tankers < 1 || tankers > 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tanker fleet size must be between 1 and 100 tankers.'),
                                backgroundColor: WaterFixColors.coralAlertText,
                              ),
                            );
                            return;
                          }

                          final payload = <String, dynamic>{
                            'businessName': _bNameCtrl.text.trim(),
                            'serviceAreaText': _areaCtrl.text.trim(),
                            'serviceRadiusKm': radius,
                            'email': _emailCtrl.text.trim(),
                            'phone': _phoneCtrl.text.trim(),
                            'tankersOwned': tankers,
                            if (_selectedLocality != null) ...{
                              'lat': _selectedLocality!.lat,
                              'lng': _selectedLocality!.lng,
                            },
                          };

                          Navigator.of(ctx).pop();
                          await controller.updateSupplierProfileData(payload);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Company profile updated successfully.'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCompleteDeliveryDialog(
    BuildContext context,
    WaterFixController controller,
    BookingModel booking,
  ) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 4-digit delivery verification code from customer ${booking.customerName} (or leave blank for authorized supplier transition):',
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
              try {
                await controller.updateBookingStatus(
                  bookingId: booking.id,
                  status: 'delivered',
                  deliveryCode: codeCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: WaterFixColors.coralAlertText,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm Delivered'),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(dynamic rawDate) {
    if (rawDate == null) return 'N/A';
    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed == null) return rawDate.toString();
    final local = parsed.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm';
  }

  Color _statusPillBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'settled':
        return WaterFixColors.emeraldSuccessBg;
      case 'partially paid':
      case 'partially_paid':
      case 'pending':
        return WaterFixColors.amberWarningBg;
      case 'outstanding':
      case 'failed':
      case 'cancelled':
      case 'expired':
      case 'refunded':
      case 'reversed':
        return WaterFixColors.coralAlertBg;
      default:
        return WaterFixColors.skyIce;
    }
  }

  Color _statusPillTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'settled':
        return WaterFixColors.emeraldSuccessText;
      case 'partially paid':
      case 'partially_paid':
      case 'pending':
        return WaterFixColors.amberWarningText;
      case 'outstanding':
      case 'failed':
      case 'cancelled':
      case 'expired':
      case 'refunded':
      case 'reversed':
        return WaterFixColors.coralAlertText;
      default:
        return WaterFixColors.deepBrandBlue;
    }
  }

  Widget _buildStatusPill(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusPillBgColor(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: _statusPillTextColor(status),
        ),
      ),
    );
  }

  Future<void> _handlePayCommissionTap(
    BuildContext context,
    WaterFixController controller, {
    String? returnTarget,
  }) async {
    final effectiveTarget = returnTarget ??
        (_selectedTab == 0
            ? 'orders'
            : _selectedTab == 1
                ? 'listings'
                : _selectedTab == 3
                    ? 'account'
                    : 'wallet');

    // Step 1: Fetch the actual outstanding commission from the backend first
    await controller.fetchWallet();
    if (!context.mounted) return;

    final summary = controller.walletSummary;
    final outstanding =
        (summary?['totalCommissionOwed'] as num?)?.toInt() ??
        (summary?['outstandingCommission'] as num?)?.toInt() ??
        0;
    final payable =
        (summary?['amountCurrentlyPayable'] as num?)?.toInt() ?? outstanding;
    final safepayConfigured = summary?['safepayConfigured'] == true;

    if (outstanding <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You have no outstanding commission due at this time (Rs 0).',
          ),
        ),
      );
      return;
    }

    final amountCtrl = TextEditingController(text: payable.toString());
    bool isCreatingSession = false;
    String? errorMsg;

    // Step 2: Show the amount due and a confirmation dialog
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirm Commission Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: WaterFixColors.skyIce,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AUTHORITATIVE COMMISSION BALANCE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: WaterFixColors.deepBrandBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Commission Owed: Rs $outstanding PKR',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: WaterFixColors.primaryBlack,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Amount Currently Payable: Rs $payable PKR',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: WaterFixColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!safepayConfigured)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: WaterFixColors.amberWarningBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Note: Safepay TEST MODE keys are not yet configured in APP/backend/.env. Add SAFEPAY_API_KEY and SAFEPAY_SECRET_KEY in .env and restart the backend to open live Sandbox checkout.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: WaterFixColors.amberWarningText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Payment amount (PKR)',
                    helperText:
                        'Enter up to Rs $outstanding (Full or partial commission settlement)',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Provider: Safepay Official Hosted Checkout (TEST MODE / Sandbox)\nYour wallet balance will only be updated after the backend cryptographically verifies the payment.',
                  style: TextStyle(
                    fontSize: 12,
                    color: WaterFixColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMsg!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: WaterFixColors.coralAlertText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isCreatingSession
                  ? null
                  : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isCreatingSession
                  ? null
                  : () async {
                      final entered = int.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (entered <= 0 || entered > outstanding) {
                        setDialogState(() {
                          errorMsg =
                              'Enter a valid amount between Rs 1 and Rs $outstanding.';
                        });
                        return;
                      }
                      setDialogState(() {
                        isCreatingSession = true;
                        errorMsg = null;
                      });
                      try {
                        // Step 3: Request a Safepay payment session from the backend
                        final sessionData = await controller
                            .initiateSafepayCommissionPayment(
                              amount: entered,
                              returnTarget: effectiveTarget,
                            );
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        if (!context.mounted) return;
                        await _launchAndMonitorSafepaySession(
                          context,
                          controller,
                          sessionData,
                          returnTarget: effectiveTarget,
                        );
                      } catch (e) {
                        setDialogState(() {
                          isCreatingSession = false;
                          errorMsg = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      }
                    },
              icon: isCreatingSession
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(
                isCreatingSession
                    ? 'Creating Session...'
                    : 'Proceed to Safepay Checkout',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchAndMonitorSafepaySession(
    BuildContext context,
    WaterFixController controller,
    Map<String, dynamic> sessionData, {
    String returnTarget = 'wallet',
  }) async {
    final paymentRef = (sessionData['paymentReference'] ?? '').toString();
    final tracker = (sessionData['tracker'] ?? '').toString();
    final checkoutUrl = (sessionData['checkoutUrl'] ?? '').toString();
    final amount = (sessionData['amount'] as num?)?.toInt() ?? 0;

    void navigateToDestination() {
      if (!mounted) return;
      if (returnTarget == 'orders') {
        setState(() => _selectedTab = 0);
      } else if (returnTarget == 'listings') {
        setState(() => _selectedTab = 1);
      } else if (returnTarget == 'account') {
        setState(() => _selectedTab = 3);
      } else {
        setState(() => _selectedTab = 2);
      }
    }

    // Step 4: Open Safepay's official hosted checkout URL
    if (checkoutUrl.isNotEmpty) {
      final uri = Uri.tryParse(checkoutUrl);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }

    if (!context.mounted) return;

    bool isWorking = false;
    String? statusFeedback;
    bool isErrorFeedback = false;
    Timer? autoCheckTimer;
    bool dialogOpen = true;
    int pollAttempts = 0;

    // Step 5 & 6: Handle return from checkout, automatic/manual verification, cancellation, or pending state
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        // Fast background auto-verification polling every 2 seconds while dialog is open
        autoCheckTimer ??= Timer.periodic(const Duration(seconds: 2), (
          timer,
        ) async {
          if (!dialogOpen || !ctx.mounted || isWorking) return;
          pollAttempts++;
          if (pollAttempts > 30) {
            timer.cancel();
            return;
          }
          try {
            final res = await controller.verifySafepayCommissionPayment(
              paymentReference: paymentRef,
              tracker: tracker,
            );
            if (!dialogOpen || !ctx.mounted) return;
            dialogOpen = false;
            timer.cancel();
            Navigator.of(ctx).pop();
            navigateToDestination();
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(
                  'Commission payment verified (Rs ${res['amount'] ?? amount}). Wallet updated!',
                ),
              ),
            );
          } catch (_) {
            // Still pending on Safepay Sandbox; continue checking
          }
        });

        return StatefulBuilder(
          builder: (ctx, setSheetState) => AlertDialog(
            title: const Text('Complete Safepay Test Payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: WaterFixColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: WaterFixColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reference: $paymentRef',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Amount Due: Rs $amount PKR',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: WaterFixColors.deepBrandBlue,
                          ),
                        ),
                        if (tracker.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Tracker: $tracker',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: WaterFixColors.skyIce,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAFEPAY SANDBOX TEST CARD DETAILS',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: WaterFixColors.deepBrandBlue,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '• Card Number: 4242 4242 4242 4242\n'
                          '• Expiry Date: 12/28 (any future date)\n'
                          '• CVV / CVC: 123\n'
                          '• 3DS Simulator / OTP: Click Submit / Success (or enter 123456)\n'
                          '• Country / Address: Any test address in Pakistan',
                          style: TextStyle(
                            fontSize: 12,
                            color: WaterFixColors.primaryBlack,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'After submitting the test card in the Safepay checkout window, return here. The app checks automatically every few seconds, or you can tap "I Paid — Verify Now" below.',
                    style: TextStyle(
                      fontSize: 12,
                      color: WaterFixColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (checkoutUrl.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isWorking
                            ? null
                            : () async {
                                final uri = Uri.tryParse(checkoutUrl);
                                if (uri != null) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Open Safepay Checkout Page'),
                      ),
                    ),
                  if (statusFeedback != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isErrorFeedback
                            ? WaterFixColors.coralAlertBg
                            : WaterFixColors.emeraldSuccessBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusFeedback!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isErrorFeedback
                              ? WaterFixColors.coralAlertText
                              : WaterFixColors.emeraldSuccessText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isWorking
                    ? null
                    : () async {
                        setSheetState(() {
                          isWorking = true;
                          statusFeedback = null;
                        });
                        try {
                          await controller.cancelSafepayCommissionPayment(
                            paymentReference: paymentRef,
                            status: 'cancelled',
                            reason:
                                'Cancelled by supplier from checkout dialog.',
                          );
                          dialogOpen = false;
                          autoCheckTimer?.cancel();
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            navigateToDestination();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Payment session cancelled. Commission balance unchanged.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setSheetState(() {
                            isWorking = false;
                            isErrorFeedback = true;
                            statusFeedback = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                child: const Text(
                  'Cancel Payment',
                  style: TextStyle(color: WaterFixColors.coralAlertText),
                ),
              ),
              TextButton(
                onPressed: isWorking
                    ? null
                    : () async {
                        dialogOpen = false;
                        autoCheckTimer?.cancel();
                        await controller.fetchWallet();
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      },
                child: const Text('Keep Pending'),
              ),
              ElevatedButton(
                onPressed: isWorking
                    ? null
                    : () async {
                        setSheetState(() {
                          isWorking = true;
                          statusFeedback = null;
                        });
                        try {
                          final res = await controller
                              .verifySafepayCommissionPayment(
                                paymentReference: paymentRef,
                                tracker: tracker,
                              );
                          dialogOpen = false;
                          autoCheckTimer?.cancel();
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            navigateToDestination();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Commission payment verified (Rs ${res['amount'] ?? amount}). Wallet updated!',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          await controller.fetchWallet();
                          setSheetState(() {
                            isWorking = false;
                            isErrorFeedback = true;
                            statusFeedback = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                child: const Text('I Paid — Verify Now'),
              ),
            ],
          ),
        );
      },
    );

    dialogOpen = false;
    autoCheckTimer?.cancel();
  }

  Widget _buildActiveTab(
    BuildContext context,
    WaterFixController controller,
    String businessName,
    bool isAvailable,
    Map<String, dynamic>? profile,
    bool isVerified,
  ) {
    switch (_selectedTab) {
      case 0:
        return KeyedSubtree(
          key: const ValueKey('sup_tab_orders'),
          child: _buildOrdersTab(
            context,
            controller,
            businessName,
            isAvailable,
          ),
        );
      case 1:
        return KeyedSubtree(
          key: const ValueKey('sup_tab_listings'),
          child: _buildListingsTab(context, controller),
        );
      case 2:
        return KeyedSubtree(
          key: const ValueKey('sup_tab_wallet'),
          child: _buildWalletTab(context, controller),
        );
      case 3:
      default:
        return KeyedSubtree(
          key: const ValueKey('sup_tab_account'),
          child: _buildSupplierAccountTab(
            context,
            controller,
            profile,
            isVerified,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);
    final profile = controller.supplierProfile;
    _syncProfileControllers(profile);

    final businessName =
        profile?['businessName']?.toString() ?? 'Supplier Dashboard';
    final isVerified = profile?['isVerified'] == true;
    final isAvailable = profile?['isAvailable'] != false;
    final isLocked =
        profile?['isLocked'] == true ||
        controller.currentUser?.isLocked == true ||
        controller.walletSummary?['isLocked'] == true;
    final lockReason =
        (profile?['lockReason'] ??
                controller.currentUser?.lockReason ??
                controller.walletSummary?['lockReason'] ??
                '')
            .toString();

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Supplier Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const WaterFixLogo(fontSize: 24),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: WaterFixColors.primaryBlack,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'SUPPLIER',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SquareIconButton(
                    icon: Icons.notifications_none_rounded,
                    badgeCount: controller.unreadNotificationsCount,
                    onTap: () {
                      Navigator.of(context).push(
                        WaterFixPageRoute(
                          page: const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            if (isLocked)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: WaterFixColors.coralAlertBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: WaterFixColors.coralAlertText.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: WaterFixColors.coralAlertText,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Supplier Account Locked',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: WaterFixColors.coralAlertText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lockReason.isNotEmpty
                                  ? 'Reason: $lockReason. Pay your outstanding commission in the Wallet tab to request account restoration.'
                                  : 'Your account is locked from accepting new orders. Pay your outstanding commission in the Wallet tab.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedTab != 2)
                        TextButton(
                          onPressed: () => setState(() => _selectedTab = 2),
                          child: const Text(
                            'Open Wallet',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: WaterFixColors.coralAlertText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // Animated Main Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildActiveTab(
                  context,
                  controller,
                  businessName,
                  isAvailable,
                  profile,
                  isVerified,
                ),
              ),
            ),

            // Supplier Bottom Navigation Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SupplierNavTab(
                    icon: Icons.inbox_outlined,
                    label: 'Orders',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  _SupplierNavTab(
                    icon: Icons.local_shipping_outlined,
                    label: 'Tankers',
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                  _SupplierNavTab(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    isSelected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2),
                  ),
                  _SupplierNavTab(
                    icon: Icons.storefront_outlined,
                    label: 'Account',
                    isSelected: _selectedTab == 3,
                    onTap: () => setState(() => _selectedTab = 3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab(
    BuildContext context,
    WaterFixController controller,
    String businessName,
    bool isAvailable,
  ) {
    final orders = controller.supplierOrders;
    final gross =
        (controller.walletSummary?['totalGrossEarnings'] as num?)?.toInt() ?? 0;
    final owed =
        (controller.walletSummary?['outstandingCommission'] as num?)?.toInt() ??
        0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dark Supplier Hero Summary Card
          AnimatedSectionEntrance(
            delayMs: 30,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: WaterFixColors.primaryBlack,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          businessName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Switch(
                        value: isAvailable,
                        activeThumbColor: WaterFixColors.skyBlue,
                        onChanged: (v) {
                          controller.updateSupplierProfileData({
                            'isAvailable': v,
                          });
                        },
                      ),
                    ],
                  ),
                  Text(
                    isAvailable
                        ? 'Online · Accepting customer tanker bookings'
                        : 'Offline · Hidden from customer search',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: WaterFixColors.darkMetricCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GROSS EARNINGS',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Rs $gross',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: WaterFixColors.darkMetricCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'COMMISSION OWED',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Rs $owed',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: WaterFixColors.skyBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Customer booking requests',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: WaterFixColors.primaryBlack,
                  ),
                ),
              ),
              IconButton(
                onPressed: controller.fetchSupplierDashboard,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (orders.isEmpty)
            AnimatedSectionEntrance(
              delayMs: 100,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: WaterFixColors.cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: WaterFixColors.cardBorder),
                ),
                child: Column(
                  children: [
                    const SupplierTankerAvatar(size: 64),
                    const SizedBox(height: 12),
                    const Text(
                      'No customer orders yet.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Make sure you have published active tanker capacities in the Tankers tab.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SkyBlueButton(
                      label: 'Manage tanker listings',
                      fullWidth: false,
                      height: 42,
                      onPressed: () => setState(() => _selectedTab = 1),
                    ),
                  ],
                ),
              ),
            )
          else
            ...orders.asMap().entries.map(
              (entry) {
                final idx = entry.key;
                final order = entry.value;
                return AnimatedSectionEntrance(
                  delayMs: 80 + (idx * 50),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SupplierOrderCard(
                      booking: order,
                      isBroadcastingGps: controller.locationBroadcaster.state
                          .isTrackingOrder(order.id),
                      onViewMap: () {
                        Navigator.of(context).push(
                          WaterFixPageRoute(
                            page: OrderTrackingScreen(
                              orderId: order.id,
                              userRole: UserRole.supplier,
                              initialBooking: order,
                            ),
                          ),
                        );
                      },
                      onAccept: () => controller.updateBookingStatus(
                        bookingId: order.id,
                        status: 'accepted',
                      ),
                      onReject: () => controller.updateBookingStatus(
                        bookingId: order.id,
                        status: 'rejected',
                        reason: 'Tanker unavailable for immediate dispatch.',
                      ),
                      onDispatch: () => controller.updateBookingStatus(
                        bookingId: order.id,
                        status: 'dispatched',
                      ),
                      onComplete: () => _showCompleteDeliveryDialog(
                        context,
                        controller,
                        order,
                      ),
                      onCancel: () => controller.updateBookingStatus(
                        bookingId: order.id,
                        status: 'cancelled',
                        reason: 'Their tanker became unavailable.',
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildListingsTab(
    BuildContext context,
    WaterFixController controller,
  ) {
    final profile = controller.supplierProfile;
    final tankersOwned = (profile?['tankersOwned'] as num?)?.toInt() ?? 4;
    final availableWater =
        (profile?['availableWaterLiters'] as num?)?.toInt() ?? 10000;
    final pricePer1000 =
        (profile?['pricePer1000Liters'] as num?)?.toInt() ?? 1800;
    final isAvailable = profile?['isAvailable'] != false;
    final radius = (profile?['serviceRadiusKm'] as num?)?.toInt() ?? 15;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Water Inventory & Availability',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your company water inventory card is the single source of truth for water availability, pricing, and fleet capacity.',
            style: TextStyle(
              fontSize: 13.5,
              color: WaterFixColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),

          // Primary Company Inventory Card (Single Source of Truth)
          AnimatedSectionEntrance(
            delayMs: 30,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: WaterFixColors.primaryBlack,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?['businessName']?.toString() ??
                                  'Irtaza Rehman Water Company',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${profile?['serviceAreaText'] ?? 'Hostel City, Park Road (Near COMSATS)'} · $radius km delivery radius',
                              style: const TextStyle(
                                fontSize: 13,
                                color: WaterFixColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isAvailable,
                            onChanged: (v) async {
                              await controller.updateSupplierProfileData({
                                'isAvailable': v,
                              });
                            },
                          ),
                          Text(
                            isAvailable ? 'Active' : 'Paused',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isAvailable
                                  ? WaterFixColors.primaryBlack
                                  : WaterFixColors.coralAlertText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: WaterFixColors.pastelBlueCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AVAILABLE STOCK',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$availableWater L',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: WaterFixColors.skyBlueLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PRICE / 1,000 L',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PKR $pricePer1000',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: WaterFixColors.pastelSageCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TANKER FLEET',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$tankersOwned tankers',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EBE3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DELIVERY FEE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'PKR 250',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SkyBlueButton(
                    label: 'Update stock & pricing',
                    onPressed: () =>
                        _showEditInventorySheet(context, controller),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletTab(BuildContext context, WaterFixController controller) {
    final summary = controller.walletSummary;
    final totalCommissionOwed =
        (summary?['totalCommissionOwed'] as num?)?.toInt() ??
        (summary?['outstandingCommission'] as num?)?.toInt() ??
        0;
    final amountCurrentlyPayable =
        (summary?['amountCurrentlyPayable'] as num?)?.toInt() ??
        totalCommissionOwed;
    final totalCommissionPaid =
        (summary?['totalCommissionPaid'] as num?)?.toInt() ??
        (summary?['totalSettledCommission'] as num?)?.toInt() ??
        0;
    final pendingPaymentAmount =
        (summary?['pendingPaymentAmount'] as num?)?.toInt() ?? 0;
    final paymentStatus = (summary?['paymentStatus'] ?? '').toString().isNotEmpty
        ? (summary!['paymentStatus']).toString()
        : (totalCommissionOwed > 0
              ? (totalCommissionPaid > 0 ? 'Partially Paid' : 'Outstanding')
              : 'Paid');
    final commPct = (summary?['commissionPercentage'] as num?)?.toInt() ?? 10;
    final gross = (summary?['totalGrossEarnings'] as num?)?.toInt() ?? 0;
    final commCharged =
        (summary?['totalCommissionCharged'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commission wallet',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: WaterFixColors.primaryBlack,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Internal platform commission ledger (Not a bank account)',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh commission ledger',
                onPressed: () => controller.fetchWallet(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Wallet Overview Card
          AnimatedSectionEntrance(
            delayMs: 40,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: WaterFixColors.primaryBlack,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'TOTAL COMMISSION OWED ($commPct% RATE)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusPill(paymentStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rs $totalCommissionOwed',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: WaterFixColors.skyBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildOverviewMetric(
                                label: 'Currently Payable',
                                value: 'Rs $amountCurrentlyPayable',
                              ),
                            ),
                            Expanded(
                              child: _buildOverviewMetric(
                                label: 'Total Commission Paid',
                                value: 'Rs $totalCommissionPaid',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildOverviewMetric(
                                label: 'Pending Payment',
                                value: 'Rs $pendingPaymentAmount',
                              ),
                            ),
                            Expanded(
                              child: _buildOverviewMetric(
                                label: 'Completed Orders Gross',
                                value: 'Rs $gross (Comm: Rs $commCharged)',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Prominent Pay Commission Button (Safepay Test Mode)
                  SkyBlueButton(
                    label: totalCommissionOwed > 0
                        ? 'Pay Commission (Rs $amountCurrentlyPayable)'
                        : 'Pay Commission (No Balance Due)',
                    onPressed: () =>
                        _handlePayCommissionTap(context, controller),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Commission History Section
          const Text(
            'Commission history',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Per-order commission charges accrued from completed tanker deliveries',
            style: TextStyle(
              fontSize: 12.5,
              color: WaterFixColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (controller.walletCommissionHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: const Text(
                'No order commissions accrued yet. A 10% platform commission is calculated automatically when an order is marked delivered.',
                style: TextStyle(color: WaterFixColors.textSecondary),
              ),
            )
          else
            ...controller.walletCommissionHistory.map((item) {
              final bookingCode = (item['bookingCode'] ?? 'N/A').toString();
              final bookingId = (item['bookingId'] ?? '').toString();
              final shortId = bookingId.length > 8
                  ? bookingId.substring(bookingId.length - 8)
                  : bookingId;
              final orderDate = _formatShortDate(
                item['orderDate'] ?? item['createdAt'],
              );
              final orderAmt =
                  (item['grossBookingAmount'] as num?)?.toInt() ?? 0;
              final ratePct =
                  (item['commissionPercentage'] as num?)?.toInt() ?? commPct;
              final commAmt = (item['commissionAmount'] as num?)?.toInt() ?? 0;
              final paidAmt = (item['paidAmount'] as num?)?.toInt() ?? 0;
              final remainingAmt =
                  (item['remainingAmount'] as num?)?.toInt() ?? 0;
              final reversalAmt =
                  (item['reversalAmount'] as num?)?.toInt() ?? 0;
              final commStatus =
                  (item['commissionStatus'] ?? 'Outstanding').toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: WaterFixColors.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: WaterFixColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Order $bookingCode${shortId.isNotEmpty ? " (#$shortId)" : ""}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                          ),
                          _buildStatusPill(commStatus),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Order Date: $orderDate',
                        style: const TextStyle(
                          fontSize: 12,
                          color: WaterFixColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order Amount: Rs $orderAmt',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Rate: $ratePct%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Commission: Rs $commAmt',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: WaterFixColors.deepBrandBlue,
                            ),
                          ),
                        ],
                      ),
                      if (paidAmt > 0 || reversalAmt > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Paid: Rs $paidAmt • Remaining: Rs $remainingAmt${reversalAmt > 0 ? " • Adjustment/Reversal: Rs $reversalAmt" : ""}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: WaterFixColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 22),

          // 3. Payment History Section
          const Text(
            'Payment history',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Safepay Test Mode checkouts and verified manual settlements',
            style: TextStyle(
              fontSize: 12.5,
              color: WaterFixColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (controller.walletPaymentHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: const Text(
                'No commission payments recorded yet. Tap "Pay Commission" above to settle your commission balance via Safepay.',
                style: TextStyle(color: WaterFixColors.textSecondary),
              ),
            )
          else
            ...controller.walletPaymentHistory.map((payment) {
              final refCode = (payment['paymentReference'] ?? '').toString();
              final amt = (payment['amount'] as num?)?.toInt() ?? 0;
              final provider = (payment['provider'] ?? 'Safepay').toString();
              final status = (payment['status'] ?? 'Pending').toString();
              final dateStr = _formatShortDate(payment['createdAt']);
              final tracker = (payment['tracker'] ?? '').toString();
              final providerRef =
                  (payment['providerReference'] ?? tracker).toString();
              final failureReason = (payment['failureReason'] ?? '').toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: WaterFixColors.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: WaterFixColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              refCode,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                          ),
                          _buildStatusPill(status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount: Rs $amt PKR',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: WaterFixColors.deepBrandBlue,
                            ),
                          ),
                          Text(
                            'Provider: $provider',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: $dateStr',
                        style: const TextStyle(
                          fontSize: 12,
                          color: WaterFixColors.textSecondary,
                        ),
                      ),
                      if (providerRef.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Provider Reference / Tracker: $providerRef',
                          style: const TextStyle(
                            fontSize: 12,
                            color: WaterFixColors.textSecondary,
                          ),
                        ),
                      ],
                      if (failureReason.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Note: $failureReason',
                          style: const TextStyle(
                            fontSize: 12,
                            color: WaterFixColors.coralAlertText,
                          ),
                        ),
                      ],
                      if (status.toLowerCase() == 'pending' &&
                          provider.toLowerCase() == 'safepay') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _launchAndMonitorSafepaySession(
                                      context,
                                      controller,
                                      payment,
                                    ),
                                icon: const Icon(
                                  Icons.verified_outlined,
                                  size: 16,
                                ),
                                label: const Text('Resume / Verify'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await controller
                                      .cancelSafepayCommissionPayment(
                                        paymentReference: refCode,
                                      );
                                } catch (_) {}
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: WaterFixColors.coralAlertText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOverviewMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: WaterFixColors.primaryBlack),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: WaterFixColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: WaterFixColors.primaryBlack,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierAccountTab(
    BuildContext context,
    WaterFixController controller,
    Map<String, dynamic>? profile,
    bool isVerified,
  ) {
    final isLocked = profile?['isLocked'] == true ||
        controller.currentUser?.isLocked == true ||
        controller.walletSummary?['isLocked'] == true;
    final summary = controller.walletSummary;
    final outstanding =
        (summary?['outstandingCommission'] as num?)?.toInt() ??
        (summary?['totalCommissionOwed'] as num?)?.toInt() ??
        0;
    final totalPaid =
        (summary?['totalCommissionPaid'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Professional Profile',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage company details, contact info, coverage area, and fleet inventory.',
            style: TextStyle(
              fontSize: 13.5,
              color: WaterFixColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),

          // Header Card with Avatar, Name, Owner & Status Badges
          AnimatedSectionEntrance(
            delayMs: 30,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: Row(
                children: [
                  const SupplierTankerAvatar(size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?['businessName']?.toString() ??
                              'Ashhad Water Supply',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: WaterFixColors.primaryBlack,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Owner: ${controller.currentUser?.name ?? "Supplier Owner"}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: WaterFixColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isLocked
                                    ? WaterFixColors.coralAlertBg
                                    : WaterFixColors.skyBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLocked
                                        ? Icons.lock_outline_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 13,
                                    color: isLocked
                                        ? WaterFixColors.coralAlertText
                                        : WaterFixColors.primaryBlack,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isLocked ? 'Locked' : 'Active Account',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isLocked
                                          ? WaterFixColors.coralAlertText
                                          : WaterFixColors.primaryBlack,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isVerified
                                    ? WaterFixColors.pastelSageCard
                                    : const Color(0xFFEBEBE6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isVerified
                                    ? '✓ Verified'
                                    : 'Standard Supplier',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Account Status & Commission Summary
          AnimatedSectionEntrance(
            delayMs: 60,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACCOUNT STATUS & COMMISSION',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: WaterFixColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isLocked
                                ? WaterFixColors.coralAlertBg
                                : WaterFixColors.pastelBlueCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OUTSTANDING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rs $outstanding',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isLocked
                                      ? WaterFixColors.coralAlertText
                                      : WaterFixColors.primaryBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: WaterFixColors.skyBlueLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'COMMISSION PAID',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rs $totalPaid',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SkyBlueButton(
                    label: 'Open Supplier Wallet',
                    leadingIcon: Icons.account_balance_wallet_outlined,
                    onPressed: () {
                      setState(() => _selectedTab = 2);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Edit Profile Action Card
          AnimatedSectionEntrance(
            delayMs: 80,
            child: SkyBlueButton(
              label: 'Edit Profile',
              leadingIcon: Icons.edit_outlined,
              onPressed: () => _showEditProfileModal(context, controller),
            ),
          ),
          const SizedBox(height: 16),

          // Company & Contact Information (Read-Only)
          AnimatedSectionEntrance(
            delayMs: 100,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'COMPANY & CONTACT DETAILS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: WaterFixColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildProfileInfoRow(
                    icon: Icons.business_rounded,
                    label: 'Company Name',
                    value: profile?['businessName']?.toString() ??
                        'Ashhad Water Supply',
                  ),
                  const Divider(height: 20),
                  _buildProfileInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Registered Email',
                    value: profile?['email']?.toString() ??
                        controller.currentUser?.email ??
                        'N/A',
                  ),
                  const Divider(height: 20),
                  _buildProfileInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Contact Phone',
                    value: profile?['phone']?.toString() ??
                        controller.currentUser?.phone ??
                        'N/A',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fleet & Coverage Details (Read-Only)
          AnimatedSectionEntrance(
            delayMs: 130,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FLEET & COVERAGE SPECIFICATIONS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: WaterFixColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildProfileInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Dispatch Base Location',
                    value: profile?['serviceAreaText']?.toString() ??
                        'Islamabad',
                  ),
                  const Divider(height: 20),
                  _buildProfileInfoRow(
                    icon: Icons.radar_rounded,
                    label: 'Delivery Radius',
                    value:
                        '${(profile?['serviceRadiusKm'] as num?)?.toInt() ?? 15} km (Strict max 20 km)',
                  ),
                  const Divider(height: 20),
                  _buildProfileInfoRow(
                    icon: Icons.local_shipping_outlined,
                    label: 'Fleet Size',
                    value:
                        '${(profile?['tankersOwned'] as num?)?.toInt() ?? 1} tankers owned',
                  ),
                  const Divider(height: 20),
                  _buildProfileInfoRow(
                    icon: Icons.water_drop_outlined,
                    label: 'Available Water Stock',
                    value:
                        '${(profile?['availableWaterLiters'] as num?)?.toInt() ?? 10000} L',
                  ),
                  const Divider(height: 20),
                  _buildProfileInfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Price per 1,000 Litres',
                    value:
                        'PKR ${(profile?['pricePer1000Liters'] as num?)?.toInt() ?? 1800}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          Center(
            child: TextButton.icon(
              icon: const Icon(
                Icons.logout_rounded,
                color: WaterFixColors.coralAlertText,
              ),
              onPressed: () => controller.logout(),
              label: const Text(
                'Log out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: WaterFixColors.coralAlertText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierOrderCard extends StatelessWidget {
  final BookingModel booking;
  final bool isBroadcastingGps;
  final VoidCallback onViewMap;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDispatch;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _SupplierOrderCard({
    required this.booking,
    this.isBroadcastingGps = false,
    required this.onViewMap,
    required this.onAccept,
    required this.onReject,
    required this.onDispatch,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final canTrackOnMap = [
      'accepted',
      'dispatched',
      'arriving',
      'delivered',
    ].contains(booking.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WaterFixColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: WaterFixColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: WaterFixColors.skyBlueLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        booking.status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isBroadcastingGps)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: WaterFixColors.primaryBlack,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.gps_fixed_rounded,
                              size: 11,
                              color: WaterFixColors.skyBlue,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'LIVE GPS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${booking.bookingCode} · Rs ${booking.totalPrice}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${booking.capacityLiters} L Tanker → ${booking.addressLine}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Customer: ${booking.customerName} (${booking.customerPhone})',
            style: const TextStyle(
              fontSize: 13.5,
              color: WaterFixColors.textSecondary,
            ),
          ),
          if (booking.isActive || canTrackOnMap) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (booking.status == 'requested') ...[
                  SkyBlueButton(
                    label: 'Accept order',
                    fullWidth: false,
                    height: 40,
                    onPressed: onAccept,
                  ),
                  OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Reject'),
                  ),
                ],
                if (booking.status == 'accepted')
                  SkyBlueButton(
                    label: 'Dispatch tanker',
                    fullWidth: false,
                    height: 40,
                    onPressed: onDispatch,
                  ),
                if (canTrackOnMap)
                  OutlinedButton.icon(
                    key: Key('supplier_track_order_${booking.id}'),
                    onPressed: onViewMap,
                    icon: const Icon(Icons.map_outlined, size: 17),
                    label: const Text('Track order'),
                  ),
                if (booking.status == 'accepted' ||
                    booking.status == 'dispatched' ||
                    booking.status == 'arriving')
                  ElevatedButton(
                    onPressed: onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WaterFixColors.primaryBlack,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Complete delivery'),
                  ),
                if (booking.isActive)
                  TextButton(
                    onPressed: onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: WaterFixColors.coralAlertText),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SupplierNavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SupplierNavTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? WaterFixColors.skyBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 22, color: WaterFixColors.primaryBlack),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
