import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tanker_illustration.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../reviews/screens/rate_delivery_screen.dart';
import '../../tracking/screens/live_tracking_screen.dart';
import '../models/booking_model.dart';
import 'booking_alternatives_screen.dart';

class MyBookingsView extends ConsumerStatefulWidget {
  const MyBookingsView({super.key});

  @override
  ConsumerState<MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends ConsumerState<MyBookingsView> {
  bool _showActiveTab = true;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);
    final allBookings = controller.bookings;

    final activeOrActionable = allBookings
        .where((b) => b.isActive || b.isCancelledBySupplier)
        .toList();
    final pastBookings = allBookings.where((b) => !b.isActive).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My bookings',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 16),

          // Active | Past Toggle Chips matching Screen 6 · My bookings
          Row(
            children: [
              SelectablePillChip(
                label: 'Active',
                isSelected: _showActiveTab,
                onTap: () => setState(() => _showActiveTab = true),
              ),
              const SizedBox(width: 10),
              SelectablePillChip(
                label: 'Past',
                isSelected: !_showActiveTab,
                onTap: () => setState(() => _showActiveTab = false),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (controller.isLoadingBookings)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_showActiveTab) ...[
            if (activeOrActionable.isEmpty)
              AnimatedSectionEntrance(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: WaterFixColors.cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: WaterFixColors.cardBorder),
                  ),
                  child: const Column(
                    children: [
                      SupplierTankerAvatar(size: 64),
                      SizedBox(height: 12),
                      Text(
                        'No active deliveries right now.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Select a tanker capacity on the Home screen to book water delivery.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: WaterFixColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...activeOrActionable.asMap().entries.map((entry) {
                final idx = entry.key;
                final booking = entry.value;
                if (booking.isCancelledBySupplier) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AnimatedSectionEntrance(
                      delay: Duration(milliseconds: 40 + (idx * 50)),
                      child: _CancelledBySupplierBookingCard(booking: booking),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AnimatedSectionEntrance(
                    delay: Duration(milliseconds: 40 + (idx * 50)),
                    child: _ActiveDarkBookingCard(booking: booking),
                  ),
                );
              }),
            const SizedBox(height: 14),
          ],

          // Past Section matching Screen 6 · My bookings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Past',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: WaterFixColors.primaryBlack,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _showActiveTab = false),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pastBookings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: const Text(
                'No past bookings yet.',
                style: TextStyle(color: WaterFixColors.textSecondary),
              ),
            )
          else
            ...pastBookings.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedSectionEntrance(
                  delay: Duration(milliseconds: 60 + (entry.key * 40)),
                  child: _PastBookingTile(booking: entry.value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveDarkBookingCard extends StatelessWidget {
  final BookingModel booking;

  const _ActiveDarkBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        Navigator.of(context).push(
          WaterFixPageRoute(page: LiveTrackingScreen(booking: booking)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: WaterFixColors.primaryBlack,
          borderRadius: BorderRadius.circular(24),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    booking.status == 'requested' ? 'Requested' : 'On the way',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: WaterFixColors.primaryBlack,
                    ),
                  ),
                ),
                Text(
                  booking.bookingCode,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              booking.supplierBusinessName,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${booking.capacityLiters} L · ${booking.addressLine}',
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${booking.estimatedArrivalMinutesMin} min away',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: WaterFixColors.skyBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: WaterFixColors.primaryBlack,
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

class _CancelledBySupplierBookingCard extends StatelessWidget {
  final BookingModel booking;

  const _CancelledBySupplierBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WaterFixColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WaterFixColors.cardBorder),
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
                  color: WaterFixColors.coralAlertBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Cancelled by supplier',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: WaterFixColors.coralAlertText,
                  ),
                ),
              ),
              Text(
                booking.bookingCode,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: WaterFixColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            booking.supplierBusinessName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.capacityLiters} L · ${booking.addressLine}',
            style: const TextStyle(
              fontSize: 13.5,
              color: WaterFixColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SkyBlueButton(
            label: 'Find another supplier',
            leadingIcon: Icons.auto_awesome,
            onPressed: () {
              Navigator.of(context).push(
                WaterFixPageRoute(
                  page: BookingAlternativesScreen(cancelledBooking: booking),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PastBookingTile extends StatelessWidget {
  final BookingModel booking;

  const _PastBookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM').format(booking.createdAt);
    final statusCap =
        booking.status[0].toUpperCase() + booking.status.substring(1);

    return PressableScale(
      onTap: () {
        if (booking.status == 'delivered' && !booking.isReviewed) {
          Navigator.of(context).push(
            WaterFixPageRoute(page: RateDeliveryScreen(booking: booking)),
          );
        } else {
          Navigator.of(context).push(
            WaterFixPageRoute(page: LiveTrackingScreen(booking: booking)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: WaterFixColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WaterFixColors.cardBorder),
        ),
        child: Row(
          children: [
            const SupplierTankerAvatar(
              size: 54,
              backgroundColor: WaterFixColors.pastelSageCard,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.supplierBusinessName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: WaterFixColors.primaryBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr · ${booking.capacityLiters} L · $statusCap',
                    style: const TextStyle(
                      fontSize: 13,
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
                  'Rs ${booking.totalPrice}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: WaterFixColors.primaryBlack,
                  ),
                ),
                const SizedBox(height: 4),
                if (booking.isReviewed && booking.reviewRating != null)
                  Text(
                    '${booking.reviewRating} ★',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WaterFixColors.textSecondary,
                    ),
                  )
                else if (booking.status == 'delivered')
                  const Text(
                    'Rate ★',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: WaterFixColors.tankerBlue,
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
