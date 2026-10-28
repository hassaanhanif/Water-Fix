import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tanker_illustration.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../suppliers/models/supplier_models.dart';
import '../../tracking/screens/live_tracking_screen.dart';

class ConfirmBookingScreen extends ConsumerStatefulWidget {
  final SupplierOfferModel offer;
  final String? replacedFromBookingId;

  const ConfirmBookingScreen({
    super.key,
    required this.offer,
    this.replacedFromBookingId,
  });

  @override
  ConsumerState<ConfirmBookingScreen> createState() =>
      _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends ConsumerState<ConfirmBookingScreen> {
  bool _isSubmitting = false;
  late final String _idempotencyKey;
  late int _selectedQuantity;
  late final TextEditingController _customQuantityController;
  String? _quantityError;

  static const List<int> _quickQuantities = [500, 1000, 2000, 3000, 5000];

  int get _effectiveRate => widget.offer.pricePer1000Liters > 0
      ? widget.offer.pricePer1000Liters
      : ((widget.offer.waterPrice / (widget.offer.capacityLiters > 0 ? widget.offer.capacityLiters : 1000)) * 1000).round();

  int get _deliveryFee => widget.offer.deliveryFee > 0 ? widget.offer.deliveryFee : 250;

  int get _waterPrice {
    if (_selectedQuantity == widget.offer.capacityLiters && widget.offer.waterPrice > 0) {
      return widget.offer.waterPrice;
    }
    return ((_effectiveRate * _selectedQuantity) / 1000).round();
  }

  int get _totalPrice {
    if (_selectedQuantity == widget.offer.capacityLiters && widget.offer.totalPrice > 0) {
      return widget.offer.totalPrice;
    }
    return _waterPrice + _deliveryFee;
  }

  @override
  void initState() {
    super.initState();
    _idempotencyKey =
        'wf_${DateTime.now().millisecondsSinceEpoch}_${widget.offer.listingId}';
    _selectedQuantity = widget.offer.capacityLiters >= 500 ? widget.offer.capacityLiters : 1000;
    _customQuantityController = TextEditingController(text: _selectedQuantity.toString());
    _validateQuantity();
  }

  @override
  void dispose() {
    _customQuantityController.dispose();
    super.dispose();
  }

  void _onSelectQuantity(int qty) {
    setState(() {
      _selectedQuantity = qty;
      _customQuantityController.text = qty.toString();
      _validateQuantity();
    });
  }

  void _onCustomQuantityChanged(String text) {
    final parsed = int.tryParse(text.trim());
    setState(() {
      if (parsed != null && parsed > 0) {
        _selectedQuantity = parsed;
      }
      _validateQuantity();
    });
  }

  void _validateQuantity() {
    final rawText = _customQuantityController.text.trim();
    final parsed = int.tryParse(rawText);
    if (parsed == null || parsed < 500) {
      _quantityError = 'Minimum order quantity is 500 L';
    } else if (parsed > 10000) {
      _quantityError = 'Maximum order quantity is 10,000 L';
    } else if (widget.offer.availableWaterLiters > 0 && parsed > widget.offer.availableWaterLiters) {
      _quantityError = 'Exceeds available stock (${widget.offer.availableWaterLiters} L in stock)';
    } else {
      _quantityError = null;
    }
  }

  Future<void> _confirmBooking() async {
    if (_isSubmitting || _quantityError != null) return;
    setState(() => _isSubmitting = true);

    final controller = ref.read(waterFixControllerProvider);
    try {
      final booking = await controller.createBooking(
        offer: widget.offer,
        idempotencyKey: _idempotencyKey,
        customWaterQuantity: _selectedQuantity,
        customExpectedTotal: _totalPrice,
        replacedFromBookingId: widget.replacedFromBookingId,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        WaterFixPageRoute(page: LiveTrackingScreen(booking: booking)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: WaterFixColors.coralAlertText,
        ),
      );
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);
    final offer = widget.offer;
    final ratingStr = offer.ratingAverage != null
        ? '${offer.ratingAverage!.toStringAsFixed(1)} ★'
        : 'New ★';

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header matching Screen 3 · Confirm booking
                    Row(
                      children: [
                        SquareIconButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Confirm booking',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: WaterFixColors.primaryBlack,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Supplier Summary Card
                    AnimatedSectionEntrance(
                      delay: const Duration(milliseconds: 40),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: WaterFixColors.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: WaterFixColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const SupplierTankerAvatar(size: 62),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    offer.businessName,
                                    style: const TextStyle(
                                      fontSize: 17.5,
                                      fontWeight: FontWeight.w800,
                                      color: WaterFixColors.primaryBlack,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$ratingStr · ${offer.tankersOwned > 0 ? '${offer.tankersOwned} tankers' : 'Water supplier'}',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: WaterFixColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PKR $_effectiveRate / 1,000 L · ${offer.availableWaterLiters > 0 ? '${offer.availableWaterLiters} L in stock' : 'Stock available'}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: WaterFixColors.textSecondary,
                                    ),
                                  ),
                                  if (offer.isAiPick) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: WaterFixColors.skyBlue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Our pick',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: WaterFixColors.primaryBlack,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Water Quantity Selection Card
                    AnimatedSectionEntrance(
                      delay: const Duration(milliseconds: 60),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
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
                                  'WATER QUANTITY',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                    color: WaterFixColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'PKR $_effectiveRate / 1,000 L',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: WaterFixColors.primaryBlack,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _quickQuantities.map((qty) {
                                  final isSelected = _selectedQuantity == qty;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () => _onSelectQuantity(qty),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? WaterFixColors.skyBlue
                                              : WaterFixColors.scaffoldBg,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSelected
                                                ? WaterFixColors.primaryBlack
                                                : WaterFixColors.cardBorder,
                                            width: isSelected ? 1.8 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$qty L',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: WaterFixColors.primaryBlack,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _customQuantityController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              onChanged: _onCustomQuantityChanged,
                              decoration: InputDecoration(
                                labelText: 'Custom Water Quantity',
                                hintText: 'Enter quantity (500 L - 10,000 L)',
                                suffixText: 'L',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: WaterFixColors.cardBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: WaterFixColors.primaryBlack,
                                    width: 1.6,
                                  ),
                                ),
                              ),
                            ),
                            if (_quantityError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _quantityError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: WaterFixColors.coralAlertText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Delivery Details Card (DELIVER TO | QUANTITY | ARRIVAL | CONTACT)
                    AnimatedSectionEntrance(
                      delay: const Duration(milliseconds: 80),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: WaterFixColors.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: WaterFixColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DELIVER TO',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: WaterFixColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              controller.selectedAddressLine,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(
                                height: 1,
                                color: WaterFixColors.cardBorder,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'QUANTITY',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.7,
                                          color: WaterFixColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$_selectedQuantity L',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: WaterFixColors.primaryBlack,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'ARRIVAL',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.7,
                                          color: WaterFixColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        offer.arrivalText,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: WaterFixColors.primaryBlack,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(
                                height: 1,
                                color: WaterFixColors.cardBorder,
                              ),
                            ),
                            const Text(
                              'CONTACT',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: WaterFixColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              controller.currentUser?.phone ??
                                  '+92 300 0000000',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Price Breakdown Card matching Screen 3 · Confirm booking
                    AnimatedSectionEntrance(
                      delay: const Duration(milliseconds: 120),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: WaterFixColors.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: WaterFixColors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Water · $_selectedQuantity L',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: WaterFixColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Rs $_waterPrice',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: WaterFixColors.primaryBlack,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Delivery',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: WaterFixColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Rs $_deliveryFee',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: WaterFixColors.primaryBlack,
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(
                                height: 1,
                                color: WaterFixColors.cardBorder,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: WaterFixColors.primaryBlack,
                                  ),
                                ),
                                Text(
                                  'Rs $_totalPrice',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: WaterFixColors.primaryBlack,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Payment Section matching Screen 3 · Confirm booking
                    AnimatedSectionEntrance(
                      delay: const Duration(milliseconds: 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: WaterFixColors.primaryBlack,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: WaterFixColors.cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: WaterFixColors.primaryBlack,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: WaterFixColors.skyBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: WaterFixColors.primaryBlack,
                                      width: 1.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    'Cash on delivery',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: WaterFixColors.primaryBlack,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: WaterFixColors.cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: WaterFixColors.cardBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: WaterFixColors.textMuted,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    'Mobile wallet or card',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                      color: WaterFixColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Info Banner matching Screen 3 · Confirm booking
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: WaterFixColors.skyBlueLight,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 18,
                                  color: WaterFixColors.primaryBlack,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'If this supplier cancels, WaterFix finds you another one automatically.',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: WaterFixColors.primaryBlack,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                label: _quantityError != null
                    ? _quantityError!
                    : 'Confirm booking · Rs $_totalPrice',
                isLoading: _isSubmitting,
                onPressed: (_quantityError == null && !_isSubmitting)
                    ? _confirmBooking
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
