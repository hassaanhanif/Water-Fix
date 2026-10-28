import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tanker_illustration.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../bookings/screens/confirm_booking_screen.dart';
import '../models/supplier_models.dart';

class SupplierProfileScreen extends ConsumerStatefulWidget {
  final String supplierId;
  final SupplierOfferModel? initialOffer;

  const SupplierProfileScreen({
    super.key,
    required this.supplierId,
    this.initialOffer,
  });

  @override
  ConsumerState<SupplierProfileScreen> createState() =>
      _SupplierProfileScreenState();
}

class _SupplierProfileScreenState extends ConsumerState<SupplierProfileScreen> {
  bool _loading = false;
  Map<String, dynamic>? _supplierData;
  List<Map<String, dynamic>> _reviews = [];
  int _requestedQuantity = 1000;
  late final TextEditingController _qtyCtrl;
  String? _qtyError;

  static const List<int> _presetQuantities = [500, 1000, 2000, 3000, 5000];

  @override
  void initState() {
    super.initState();
    _loading = widget.initialOffer == null;
    _requestedQuantity = widget.initialOffer != null && widget.initialOffer!.capacityLiters >= 500
        ? widget.initialOffer!.capacityLiters
        : 1000;
    _qtyCtrl = TextEditingController(text: _requestedQuantity.toString());
    _loadDetail();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _setQuantity(int qty) {
    setState(() {
      _requestedQuantity = qty;
      _qtyCtrl.text = qty.toString();
      _validateQuantity();
    });
  }

  void _validateQuantity() {
    final available = (_supplierData?['availableWaterLiters'] as num?)?.toInt() ??
        widget.initialOffer?.availableWaterLiters ??
        10000;
    if (_requestedQuantity < 500) {
      _qtyError = 'Minimum quantity is 500 litres.';
    } else if (_requestedQuantity > 10000) {
      _qtyError = 'Maximum order quantity is 10,000 litres.';
    } else if (available > 0 && _requestedQuantity > available) {
      _qtyError = 'Exceeds available stock ($available L).';
    } else {
      _qtyError = null;
    }
  }

  Future<void> _loadDetail() async {
    if (widget.initialOffer == null) {
      setState(() => _loading = true);
    }
    try {
      final data = await ref
          .read(waterFixControllerProvider)
          .fetchSupplierPublicDetail(widget.supplierId);
      if (!mounted) return;
      setState(() {
        _supplierData = Map<String, dynamic>.from(data['supplier'] as Map);
        _reviews = (data['reviews'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
      _validateQuantity();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierName =
        _supplierData?['businessName']?.toString() ??
        widget.initialOffer?.businessName ??
        'Water Supplier';
    final isVerified = _supplierData?['isVerified'] == true;
    final city =
        _supplierData?['city']?.toString() ??
        widget.initialOffer?.city ??
        'Islamabad';
    final distanceKm =
        (_supplierData?['distanceKm'] as num?)?.toDouble() ??
        widget.initialOffer?.distanceKm;
    final hasAccurateDist = _supplierData?['hasAccurateDistance'] == true ||
        widget.initialOffer?.hasAccurateDistance == true;
    final ratingAvg =
        (_supplierData?['ratingAverage'] as num?)?.toDouble() ??
        widget.initialOffer?.ratingAverage;
    final reviewCount =
        (_supplierData?['reviewCount'] as num?)?.toInt() ??
        widget.initialOffer?.reviewCount ??
        0;
    final hasHistory =
        _supplierData?['hasSufficientHistory'] == true ||
        widget.initialOffer?.hasSufficientHistory == true;
    final onTimePct =
        (_supplierData?['onTimePercentage'] as num?)?.toInt() ??
        widget.initialOffer?.onTimePercentage;

    final ratePer1000 = (_supplierData?['pricePer1000Liters'] as num?)?.toInt() ??
        widget.initialOffer?.pricePer1000Liters ??
        1800;
    final availableStock = (_supplierData?['availableWaterLiters'] as num?)?.toInt() ??
        widget.initialOffer?.availableWaterLiters ??
        10000;
    final tankersOwned = (_supplierData?['tankersOwned'] as num?)?.toInt() ??
        widget.initialOffer?.tankersOwned ??
        1;
    final serviceRadius = (_supplierData?['serviceRadiusKm'] as num?)?.toInt() ??
        widget.initialOffer?.serviceRadiusKm.toInt() ??
        20;
    const deliveryFee = 250;
    final waterSubtotal = ((ratePer1000 * _requestedQuantity) / 1000).round();
    final totalPrice = waterSubtotal + deliveryFee;

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Back button
                          Row(
                            children: [
                              SquareIconButton(
                                icon: Icons.chevron_left_rounded,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Pastel Tanker Banner matching Screen 10 · Supplier profile
                          AnimatedSectionEntrance(
                            delay: const Duration(milliseconds: 30),
                            child: Container(
                              width: double.infinity,
                              height: 155,
                              decoration: BoxDecoration(
                                color: WaterFixColors.pastelBlueCard,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              alignment: Alignment.center,
                              child: const TankerIllustration(
                                width: 140,
                                height: 95,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Supplier Name + Verified badge ONLY if actually verified
                          AnimatedSectionEntrance(
                            delay: const Duration(milliseconds: 70),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        supplierName,
                                        style: const TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w800,
                                          color: WaterFixColors.primaryBlack,
                                        ),
                                      ),
                                    ),
                                    if (isVerified) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: WaterFixColors.skyBlue,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_rounded, size: 15),
                                            SizedBox(width: 4),
                                            Text(
                                              'Verified',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasAccurateDist && distanceKm != null
                                      ? '$city · ${distanceKm.toStringAsFixed(1)} km from you'
                                      : '$city · Distance unavailable',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: WaterFixColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 3 White Stat Cards matching Screen 10 · Supplier profile
                          AnimatedSectionEntrance(
                            delay: const Duration(milliseconds: 110),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    title: ratingAvg != null && reviewCount > 0
                                        ? '${ratingAvg.toStringAsFixed(1)} ★'
                                        : 'New ★',
                                    subtitle: reviewCount > 0
                                        ? '$reviewCount reviews'
                                        : 'No reviews',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    title: hasHistory && onTimePct != null
                                        ? '$onTimePct%'
                                        : 'N/A',
                                    subtitle: hasHistory
                                        ? 'on time'
                                        : 'Not enough history',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    title:
                                        '${widget.initialOffer?.avgArrivalMinutes ?? 35} min',
                                    subtitle: 'avg. arrival',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Company Inventory Overview & Quantity Selector
                          AnimatedSectionEntrance(
                            delay: const Duration(milliseconds: 150),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Company Water Inventory Snapshot
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: WaterFixColors.cardBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: WaterFixColors.cardBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'COMPANY WATER INVENTORY',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6,
                                              color: WaterFixColors.textSecondary,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: WaterFixColors.skyIce,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'PKR $ratePer1000 / 1,000 L',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: WaterFixColors.deepBrandBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '$availableStock L Available Stock',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: WaterFixColors.primaryBlack,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$tankersOwned tankers fleet · $serviceRadius km service radius · Flat delivery fee PKR $deliveryFee',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: WaterFixColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                const Text(
                                  'Select Water Quantity',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: WaterFixColors.primaryBlack,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _presetQuantities.map((cap) {
                                      final isSelected = _requestedQuantity == cap;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: SelectablePillChip(
                                          label: '$cap L',
                                          isSelected: isSelected,
                                          onTap: () => _setQuantity(cap),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Order quantity (500 L - 10,000 L)',
                                    hintText: 'e.g. 2500',
                                    suffixText: 'Litres',
                                    prefixIcon: const Icon(Icons.water_drop_outlined),
                                    errorText: _qtyError,
                                  ),
                                  onChanged: (val) {
                                    final p = int.tryParse(val.trim());
                                    if (p != null && p > 0) {
                                      setState(() {
                                        _requestedQuantity = p;
                                        _validateQuantity();
                                      });
                                    } else {
                                      setState(() {
                                        _qtyError = 'Enter a valid quantity (500 L - 10,000 L)';
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Live Price Breakdown Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: WaterFixColors.pastelBlueCard,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Water Price ($_requestedQuantity L)',
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: WaterFixColors.primaryBlack,
                                            ),
                                          ),
                                          Text(
                                            'PKR $waterSubtotal',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Flat Delivery Fee',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: WaterFixColors.primaryBlack,
                                            ),
                                          ),
                                          Text(
                                            'PKR $deliveryFee',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 18),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Total Payable (COD)',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: WaterFixColors.primaryBlack,
                                            ),
                                          ),
                                          Text(
                                            'PKR $totalPrice',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: WaterFixColors.primaryBlack,
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

                          const SizedBox(height: 22),

                          // Reviews section matching Screen 10 · Supplier profile
                          AnimatedSectionEntrance(
                            delay: const Duration(milliseconds: 190),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Reviews',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: WaterFixColors.primaryBlack,
                                      ),
                                    ),
                                    Text(
                                      '${_reviews.length} total',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_reviews.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: WaterFixColors.cardBg,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: WaterFixColors.cardBorder,
                                      ),
                                    ),
                                    child: const Text(
                                      'Not enough delivery history — no customer reviews submitted yet.',
                                      style: TextStyle(
                                        color: WaterFixColors.textSecondary,
                                      ),
                                    ),
                                  )
                                else
                                  ..._reviews.map((rev) {
                                    final reviewer =
                                        (rev['customerName'] ?? 'Customer')
                                            .toString();
                                    final initials = reviewer
                                        .trim()
                                        .split(' ')
                                        .where((s) => s.isNotEmpty)
                                        .take(2)
                                        .map((s) => s[0].toUpperCase())
                                        .join();
                                    final stars =
                                        (rev['rating'] as num?)?.toInt() ?? 5;
                                    final comment = (rev['comment'] ?? '')
                                        .toString();

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: WaterFixColors.cardBg,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: WaterFixColors.cardBorder,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 17,
                                                  backgroundColor:
                                                      WaterFixColors
                                                          .skyBlueLight,
                                                  child: Text(
                                                    initials,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: WaterFixColors
                                                          .primaryBlack,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    reviewer,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '$stars ★',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (comment.isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Text(
                                                comment,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: WaterFixColors
                                                      .primaryBlack,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: PrimaryArrowButton(
                      label: 'Book $supplierName · Rs $totalPrice',
                      onPressed: _qtyError != null
                          ? null
                          : () {
                              final offer = SupplierOfferModel(
                                listingId: widget.supplierId,
                                supplierId: widget.supplierId,
                                supplierUserId:
                                    _supplierData?['userId']?.toString() ??
                                    widget.initialOffer?.supplierUserId ??
                                    '',
                                businessName: supplierName,
                                ownerName:
                                    _supplierData?['ownerName']?.toString() ??
                                    widget.initialOffer?.ownerName ??
                                    '',
                                city: city,
                                serviceAreaText: city,
                                isVerified: isVerified,
                                capacityLiters: _requestedQuantity,
                                label: '$_requestedQuantity L delivery',
                                waterPrice: waterSubtotal,
                                deliveryFee: deliveryFee,
                                totalPrice: totalPrice,
                                distanceKm: distanceKm ?? 0.0,
                                hasAccurateDistance: hasAccurateDist,
                                ratingAverage: ratingAvg,
                                reviewCount: reviewCount,
                                availableWaterLiters: availableStock,
                                pricePer1000Liters: ratePer1000,
                                tankersOwned: tankersOwned,
                                serviceRadiusKm: serviceRadius.toDouble(),
                              );

                              Navigator.of(context).push(
                                WaterFixPageRoute(
                                  page: ConfirmBookingScreen(offer: offer),
                                ),
                              );
                            },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StatCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: WaterFixColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WaterFixColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: WaterFixColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
