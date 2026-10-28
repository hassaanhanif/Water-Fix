import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/islamabad_localities.dart';
import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_and_error_states.dart';
import '../../../shared/widgets/tanker_illustration.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../../shared/widgets/waterfix_logo.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../suppliers/models/supplier_models.dart';
import '../../suppliers/screens/supplier_profile_screen.dart';

class CustomerHomeView extends ConsumerWidget {
  final ValueChanged<int> onNavigateTab;

  const CustomerHomeView({super.key, required this.onNavigateTab});

  static const List<int> capacities = [500, 1000, 2000, 3000, 4000, 5000];

  void _showLocationPickerSheet(
    BuildContext context,
    WaterFixController controller,
  ) {
    final addrController = TextEditingController(
      text: controller.selectedAddressLine,
    );
    IslamabadLocality? selectedLoc;
    String filter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WaterFixColors.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filteredLocalities = kIslamabadLocalities.where((loc) {
              if (filter.isEmpty) return true;
              final q = filter.toLowerCase();
              return loc.name.toLowerCase().contains(q) ||
                  loc.sector.toLowerCase().contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SizedBox(
                height: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Delivery location',
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
                    const SizedBox(height: 10),
                    SkyBlueButton(
                      label: 'Use current GPS location',
                      leadingIcon: Icons.my_location_rounded,
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await controller.useCurrentGpsLocation();
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addrController,
                      decoration: const InputDecoration(
                        hintText:
                            'Search sector or area (e.g. Hostel City, F-10, G-11)...',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          filter = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ISLAMABAD LOCALITIES (50+ VERIFIED AREAS)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredLocalities.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final loc = filteredLocalities[index];
                          final isSelected = selectedLoc?.name == loc.name ||
                              addrController.text.trim() == loc.name;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.location_on_rounded,
                              color: isSelected
                                  ? WaterFixColors.primaryBlack
                                  : WaterFixColors.textSecondary,
                              size: 20,
                            ),
                            title: Text(
                              loc.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                            subtitle: Text(
                              'Sector: ${loc.sector} · Lat: ${loc.lat.toStringAsFixed(3)}, Lng: ${loc.lng.toStringAsFixed(3)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: WaterFixColors.primaryBlack,
                                    size: 18,
                                  )
                                : null,
                            onTap: () {
                              setModalState(() {
                                selectedLoc = loc;
                                addrController.text = loc.name;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryArrowButton(
                      label: 'Save & update location',
                      onPressed: () {
                        final text = addrController.text.trim();
                        if (text.isEmpty) {
                          Navigator.of(ctx).pop();
                          return;
                        }
                        final match = selectedLoc ??
                            kIslamabadLocalities
                                .cast<IslamabadLocality?>()
                                .firstWhere(
                                  (l) =>
                                      l!.name.toLowerCase().contains(
                                            text.toLowerCase(),
                                          ) ||
                                      l.sector.toLowerCase().contains(
                                            text.toLowerCase(),
                                          ),
                                  orElse: () => null,
                                );
                        Navigator.of(ctx).pop();
                        controller.setManualLocation(
                          addressLine: text,
                          city: 'Islamabad',
                          lat: match?.lat,
                          lng: match?.lng,
                          saveToAccount: true,
                        );
                      },
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(waterFixControllerProvider);
    final displaySuppliers = controller.discoveredSuppliers.isNotEmpty
        ? controller.discoveredSuppliers
        : controller.homeTopSuppliers;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Water [Fix] logo + Notification bell button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const WaterFixLogo(fontSize: 27),
              SquareIconButton(
                icon: Icons.notifications_none_rounded,
                badgeCount: controller.unreadNotificationsCount,
                onTap: () {
                  Navigator.of(context).push(
                    WaterFixPageRoute(page: const NotificationsScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Headline: Clean water, on demand.
          const AnimatedSectionEntrance(
            delay: Duration(milliseconds: 30),
            child: Text(
              'Clean water,\non demand.',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: WaterFixColors.primaryBlack,
                height: 1.1,
                letterSpacing: -0.9,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Location Bar matching Screen 1 · Home
          AnimatedSectionEntrance(
            delay: const Duration(milliseconds: 70),
            child: PressableScale(
              onTap: () => _showLocationPickerSheet(context, controller),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: WaterFixColors.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: WaterFixColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: WaterFixColors.primaryBlack,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controller.selectedAddressLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: WaterFixColors.primaryBlack,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: WaterFixColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (controller.locationWarning != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: WaterFixColors.skyBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                controller.locationWarning!,
                style: const TextStyle(
                  fontSize: 12,
                  color: WaterFixColors.primaryBlack,
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Capacity Chips Row matching Screen 1 · Home
          AnimatedSectionEntrance(
            delay: const Duration(milliseconds: 110),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: capacities.map((cap) {
                  final label = '${_formatNumber(cap)} L';
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SelectablePillChip(
                      label: label,
                      isSelected: controller.selectedCapacityLiters == cap,
                      onTap: () => controller.setCapacity(cap),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Hero Dark Banner Card matching Screen 1 · Home
          AnimatedSectionEntrance(
            delay: const Duration(milliseconds: 150),
            child: Container(
              width: double.infinity,
              height: 188,
              decoration: BoxDecoration(
                color: WaterFixColors.primaryBlack,
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'FRESH WATER.\nFAIR PRICES.\nFAST.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SkyBlueButton(
                          label: 'Find suppliers',
                          fullWidth: false,
                          height: 44,
                          onPressed: () => onNavigateTab(1),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: -12,
                    bottom: -14,
                    child: TiltedTankerBadge(size: 162),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Top suppliers near you section
          AnimatedSectionEntrance(
            delay: const Duration(milliseconds: 190),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Top suppliers near you',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: WaterFixColors.primaryBlack,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => onNavigateTab(1),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: WaterFixColors.primaryBlack,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (controller.isLoadingSuppliers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (controller.suppliersError != null)
            ErrorRecoveryCard(
              message: controller.suppliersError!,
              onRetry: controller.discoverSuppliers,
            )
          else if (displaySuppliers.isEmpty)
            EmptySuppliersState(
              onChangeLocation: () =>
                  _showLocationPickerSheet(context, controller),
              onChangeCapacity: () {
                final nextCap = controller.selectedCapacityLiters == 1000
                    ? 2000
                    : 1000;
                controller.setCapacity(nextCap);
              },
              onRetry: controller.discoverSuppliers,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displaySuppliers.length > 4
                  ? 4
                  : displaySuppliers.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.84,
              ),
              itemBuilder: (context, index) {
                final supplier = displaySuppliers[index];
                final isEven = index.isEven;
                return AnimatedSectionEntrance(
                  delay: Duration(milliseconds: 220 + (index * 45)),
                  child: _HomeSupplierGridCard(
                    offer: supplier,
                    pastelColor: isEven
                        ? WaterFixColors.pastelBlueCard
                        : WaterFixColors.pastelSageCard,
                    onTap: () {
                      Navigator.of(context).push(
                        WaterFixPageRoute(
                          page: SupplierProfileScreen(
                            supplierId: supplier.supplierId,
                            initialOffer: supplier,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  static String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class _HomeSupplierGridCard extends StatelessWidget {
  final SupplierOfferModel offer;
  final Color pastelColor;
  final VoidCallback onTap;

  const _HomeSupplierGridCard({
    required this.offer,
    required this.pastelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratingDisplay = offer.ratingAverage != null
        ? '${offer.ratingAverage!.toStringAsFixed(1)} ★'
        : 'New ★';

    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: WaterFixColors.cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: WaterFixColors.cardBorder),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: pastelColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: TankerIllustration(width: 92, height: 64),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          size: 17,
                          color: WaterFixColors.primaryBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: WaterFixColors.primaryBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$ratingDisplay · Rs ${offer.totalPrice}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: WaterFixColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
