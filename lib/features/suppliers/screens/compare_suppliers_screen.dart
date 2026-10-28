import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_and_error_states.dart';
import '../../../shared/widgets/tanker_illustration.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../bookings/screens/confirm_booking_screen.dart';
import '../models/supplier_models.dart';
import 'supplier_profile_screen.dart';

class CompareSuppliersView extends ConsumerStatefulWidget {
  final VoidCallback? onBackToHome;
  final bool aiPickHighlightMode;
  final bool ourPickHighlightMode;

  const CompareSuppliersView({
    super.key,
    this.onBackToHome,
    this.aiPickHighlightMode = false,
    this.ourPickHighlightMode = false,
  });

  bool get isOurPickMode => aiPickHighlightMode || ourPickHighlightMode;

  @override
  ConsumerState<CompareSuppliersView> createState() =>
      _CompareSuppliersViewState();
}

class _CompareSuppliersViewState extends ConsumerState<CompareSuppliersView> {
  static const _sortModes = [
    (id: 'best_match', label: 'Best match'),
    (id: 'cheapest', label: 'Cheapest'),
    (id: 'fastest', label: 'Fastest'),
    (id: 'best_rated', label: 'Best rated'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isOurPickMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(waterFixControllerProvider).fetchOurPicksRecommendations();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);
    final isOurPick = widget.isOurPickMode;
    final suppliers = (isOurPick &&
            controller.ourPicksSuppliers.isNotEmpty)
        ? controller.ourPicksSuppliers
        : controller.discoveredSuppliers;

    final topOffer = suppliers.isNotEmpty ? suppliers.first : null;
    final moreOptions = topOffer != null
        ? suppliers.where((s) => s.supplierId != topOffer.supplierId).toList()
        : <SupplierOfferModel>[];

    final isLoading = isOurPick
        ? (controller.isLoadingOurPicks && suppliers.isEmpty)
        : (controller.isLoadingSuppliers && suppliers.isEmpty);
    final errorMessage = isOurPick
        ? controller.ourPicksError
        : controller.suppliersError;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header matching Screen 2 · Compare suppliers
          Row(
            children: [
              if (widget.onBackToHome != null) ...[
                SquareIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: widget.onBackToHome!,
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOurPick ? 'Our Pick' : 'Suppliers',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: WaterFixColors.primaryBlack,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatLiters(controller.selectedCapacityLiters)} · ${_shortAddr(controller.selectedAddressLine)} · ASAP',
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

          // Filter / Sort Row: Best match | Cheapest | Fastest | Best rated
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sortModes.map((mode) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SelectablePillChip(
                    label: mode.label,
                    isSelected: controller.selectedSortBy == mode.id,
                    onTap: () => controller.setSortBy(mode.id),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(36),
                child: CircularProgressIndicator(),
              ),
            )
          else if (errorMessage != null && suppliers.isEmpty)
            ErrorRecoveryCard(
              message: errorMessage,
              onRetry: () {
                controller.discoverSuppliers();
                controller.fetchOurPicksRecommendations();
              },
            )
          else if (topOffer == null)
            EmptySuppliersState(
              onChangeCapacity: () {
                final nextCap = controller.selectedCapacityLiters == 1000
                    ? 2000
                    : 1000;
                controller.setCapacity(nextCap);
              },
              onRetry: () {
                controller.discoverSuppliers();
                controller.fetchOurPicksRecommendations();
              },
              onReturnHome: widget.onBackToHome,
            )
          else ...[
            // Featured Dark Our Pick Card matching Screen 2 · Compare suppliers
            AnimatedSectionEntrance(
              delay: const Duration(milliseconds: 40),
              child: _FeaturedOurPickCard(
                offer: topOffer,
                onBookNow: () {
                  Navigator.of(context).push(
                    WaterFixPageRoute(
                      page: ConfirmBookingScreen(offer: topOffer),
                    ),
                  );
                },
                onViewProfile: () {
                  Navigator.of(context).push(
                    WaterFixPageRoute(
                      page: SupplierProfileScreen(
                        supplierId: topOffer.supplierId,
                        initialOffer: topOffer,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            if (moreOptions.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'More options',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: WaterFixColors.primaryBlack,
                    ),
                  ),
                  Text(
                    '${moreOptions.length} other option${moreOptions.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: WaterFixColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...moreOptions.asMap().entries.map((entry) {
                final idx = entry.key;
                final offer = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AnimatedSectionEntrance(
                    delay: Duration(milliseconds: 90 + (idx * 50)),
                    child: _SupplierOptionCard(
                      offer: offer,
                      pastelColor: idx.isEven
                          ? WaterFixColors.pastelBlueCard
                          : WaterFixColors.pastelSageCard,
                      onTap: () {
                        Navigator.of(context).push(
                          WaterFixPageRoute(
                            page: SupplierProfileScreen(
                              supplierId: offer.supplierId,
                              initialOffer: offer,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  static String _formatLiters(int l) {
    return '${l.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} L';
  }

  static String _shortAddr(String addr) {
    final parts = addr.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return addr;
  }
}

class _FeaturedOurPickCard extends StatelessWidget {
  final SupplierOfferModel offer;
  final VoidCallback onBookNow;
  final VoidCallback onViewProfile;

  const _FeaturedOurPickCard({
    required this.offer,
    required this.onBookNow,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final ratingStr = (offer.ratingAverage != null && offer.reviewCount > 0)
        ? '${offer.ratingAverage!.toStringAsFixed(1)} ★ (${offer.reviewCount})'
        : 'New supplier (No reviews)';

    final distanceDisplay = offer.hasAccurateDistance
        ? '${offer.distanceKm.toStringAsFixed(1)} km'
        : 'Unavailable';

    return Container(
      width: double.infinity,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: WaterFixColors.skyBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: WaterFixColors.primaryBlack,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'OUR PICK',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: WaterFixColors.primaryBlack,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Rs ${offer.totalPrice}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onViewProfile,
            child: Text(
              offer.businessName,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$ratingStr · ${offer.tankersOwned > 0 ? '${offer.tankersOwned} tankers fleet' : '${offer.capacityLiters} L'} · ${offer.availableWaterLiters > 0 ? '${offer.availableWaterLiters} L stock' : 'Stock ready'}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 18),

          // 3 Metric Boxes: ARRIVES | DISTANCE | ON TIME
          Row(
            children: [
              Expanded(
                child: _DarkMetricBox(
                  label: 'ARRIVES',
                  value: offer.arrivalText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DarkMetricBox(
                  label: 'DISTANCE',
                  value: distanceDisplay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DarkMetricBox(
                  label: 'ON TIME',
                  value:
                      offer.hasSufficientHistory &&
                          offer.onTimePercentage != null
                      ? '${offer.onTimePercentage}%'
                      : 'New',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            offer.recommendationExplanation,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SkyBlueButton(label: 'Book now', onPressed: onBookNow),
        ],
      ),
    );
  }
}

class _DarkMetricBox extends StatelessWidget {
  final String label;
  final String value;

  const _DarkMetricBox({required this.label, required this.value});

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
              letterSpacing: 0.6,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierOptionCard extends StatelessWidget {
  final SupplierOfferModel offer;
  final Color pastelColor;
  final VoidCallback onTap;

  const _SupplierOptionCard({
    required this.offer,
    required this.pastelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratingPart = (offer.ratingAverage != null && offer.reviewCount > 0)
        ? '${offer.ratingAverage!.toStringAsFixed(1)} ★ (${offer.reviewCount})'
        : 'New supplier';
    final onTimePart =
        offer.hasSufficientHistory && offer.onTimePercentage != null
        ? '${offer.onTimePercentage}% on time'
        : offer.reliabilityText;
    final distPart = offer.hasAccurateDistance
        ? ' · ${offer.distanceKm.toStringAsFixed(1)} km'
        : '';

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WaterFixColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WaterFixColors.cardBorder),
        ),
        child: Row(
          children: [
            SupplierTankerAvatar(size: 58, backgroundColor: pastelColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.businessName,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: WaterFixColors.primaryBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$ratingPart · ${offer.tankersOwned > 0 ? '${offer.tankersOwned} tankers · ' : ''}${offer.availableWaterLiters > 0 ? '${offer.availableWaterLiters} L stock · ' : ''}$onTimePart$distPart',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WaterFixColors.textSecondary,
                    ),
                  ),
                  if (offer.badges.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: offer.badges.map((b) {
                        final isCheapest = b == 'Cheapest';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isCheapest
                                ? WaterFixColors.skyBlue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCheapest
                                  ? WaterFixColors.skyBlue
                                  : WaterFixColors.primaryBlack,
                            ),
                          ),
                          child: Text(
                            b,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: WaterFixColors.primaryBlack,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs ${offer.totalPrice}',
                  style: const TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: WaterFixColors.primaryBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offer.arrivalText,
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
    );
  }
}
