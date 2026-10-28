import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_and_error_states.dart';
import '../../../shared/widgets/tanker_illustration.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../suppliers/models/supplier_models.dart';
import '../models/booking_model.dart';
import 'confirm_booking_screen.dart';

class BookingAlternativesScreen extends ConsumerStatefulWidget {
  final BookingModel cancelledBooking;

  const BookingAlternativesScreen({super.key, required this.cancelledBooking});

  @override
  ConsumerState<BookingAlternativesScreen> createState() =>
      _BookingAlternativesScreenState();
}

class _BookingAlternativesScreenState
    extends ConsumerState<BookingAlternativesScreen> {
  bool _loading = true;
  List<SupplierOfferModel> _alternatives = [];

  @override
  void initState() {
    super.initState();
    _loadAlternatives();
  }

  Future<void> _loadAlternatives() async {
    setState(() => _loading = true);
    try {
      final list = await ref
          .read(waterFixControllerProvider)
          .fetchAlternativesForBooking(widget.cancelledBooking.id);
      if (!mounted) return;
      setState(() {
        _alternatives = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.cancelledBooking;
    final bestReplacement = _alternatives.isNotEmpty
        ? _alternatives.first
        : null;
    final otherReplacements = _alternatives.length > 1
        ? _alternatives.sublist(1)
        : <SupplierOfferModel>[];

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header matching Screen 7 · Booking failed: alternatives
              Row(
                children: [
                  SquareIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking ${b.bookingCode}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: WaterFixColors.primaryBlack,
                          ),
                        ),
                        Text(
                          '${b.capacityLiters} L · ${b.addressLine}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: WaterFixColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Coral Alert Banner matching Screen 7 · Booking failed: alternatives
              AnimatedSectionEntrance(
                delay: const Duration(milliseconds: 40),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: WaterFixColors.coralAlertBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: WaterFixColors.coralAlertText,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${b.supplierBusinessName} couldn't deliver",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              "Their tanker became unavailable. You haven't been charged.",
                              style: TextStyle(
                                fontSize: 13.5,
                                color: WaterFixColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Replacements Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Replacements',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: WaterFixColors.primaryBlack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: WaterFixColors.skyBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'AI found ${_alternatives.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (bestReplacement == null)
                EmptySuppliersState(
                  onRetry: _loadAlternatives,
                  onReturnHome: () => Navigator.of(context).pop(),
                )
              else ...[
                // Dark BEST REPLACEMENT Card matching Screen 7
                AnimatedSectionEntrance(
                  delay: const Duration(milliseconds: 80),
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
                            const Text(
                              'BEST REPLACEMENT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                                color: WaterFixColors.skyBlue,
                              ),
                            ),
                            Text(
                              'Rs ${bestReplacement.totalPrice}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          bestReplacement.businessName,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${bestReplacement.ratingAverage?.toStringAsFixed(1) ?? "New"} ★ (${bestReplacement.reviewCount}) · ${bestReplacement.priceComparisonText ?? "Same price as your original booking"}',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _ReplacementMetric(
                                label: 'ARRIVES',
                                value: bestReplacement.arrivalText,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ReplacementMetric(
                                label: 'DISTANCE',
                                value:
                                    '${bestReplacement.distanceKm.toStringAsFixed(1)} km',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ReplacementMetric(
                                label: 'ON TIME',
                                value: bestReplacement.onTimePercentage != null
                                    ? '${bestReplacement.onTimePercentage}%'
                                    : 'New',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SkyBlueButton(
                          label: 'Rebook with ${bestReplacement.businessName}',
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              WaterFixPageRoute(
                                page: ConfirmBookingScreen(
                                  offer: bestReplacement,
                                  replacedFromBookingId: b.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...otherReplacements.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnimatedSectionEntrance(
                      delay: Duration(milliseconds: 120 + (entry.key * 45)),
                      child: PressableScale(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            WaterFixPageRoute(
                              page: ConfirmBookingScreen(
                                offer: entry.value,
                                replacedFromBookingId: b.id,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: WaterFixColors.cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: WaterFixColors.cardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              const SupplierTankerAvatar(size: 56),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.value.businessName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${entry.value.ratingAverage?.toStringAsFixed(1) ?? "New"} ★ · ${entry.value.capacityLiters} L · ${entry.value.reliabilityText}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: WaterFixColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rs ${entry.value.totalPrice}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.value.arrivalText,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: WaterFixColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel this booking',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: WaterFixColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplacementMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ReplacementMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: WaterFixColors.darkMetricCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
