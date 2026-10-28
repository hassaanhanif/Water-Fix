import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../bookings/models/booking_model.dart';
import '../../customer_profile/screens/schedule_deliveries_screen.dart';

class RateDeliveryScreen extends ConsumerStatefulWidget {
  final BookingModel booking;

  const RateDeliveryScreen({super.key, required this.booking});

  @override
  ConsumerState<RateDeliveryScreen> createState() => _RateDeliveryScreenState();
}

class _RateDeliveryScreenState extends ConsumerState<RateDeliveryScreen> {
  int _rating = 5;
  final Set<String> _selectedTags = {'On time', 'Full quantity'};
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  static const _tags = [
    'On time',
    'Full quantity',
    'Clean water',
    'Polite driver',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(waterFixControllerProvider)
          .submitReview(
            bookingId: widget.booking.id,
            rating: _rating,
            tags: _selectedTags.toList(),
            comment: _commentController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted! Thank you.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: WaterFixColors.coralAlertText,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Tilted Sky-Blue Checkmark Badge matching Screen 5 · Rate delivery
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.65, end: 1.0),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Transform.rotate(
                          angle: 6 * (math.pi / 180),
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: WaterFixColors.skyBlue,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 44,
                              color: WaterFixColors.primaryBlack,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSectionEntrance(
                        delay: const Duration(milliseconds: 60),
                        child: Column(
                          children: [
                            const Text(
                              'DELIVERED',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: WaterFixColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${b.capacityLiters} L at your door',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 29,
                                fontWeight: FontWeight.w800,
                                color: WaterFixColors.primaryBlack,
                                letterSpacing: -0.7,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${b.supplierBusinessName} · ${b.estimatedArrivalMinutesMin} min · Rs ${b.totalPrice}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: WaterFixColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 5 Interactive Star Icons
                      AnimatedSectionEntrance(
                        delay: const Duration(milliseconds: 110),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (idx) {
                            final starNum = idx + 1;
                            final isSelected = starNum <= _rating;
                            return IconButton(
                              onPressed: () =>
                                  setState(() => _rating = starNum),
                              iconSize: 38,
                              icon: AnimatedScale(
                                scale: isSelected ? 1.08 : 1.0,
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  isSelected
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: isSelected
                                      ? WaterFixColors.skyBlue
                                      : WaterFixColors.primaryBlack,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 22),

                      AnimatedSectionEntrance(
                        delay: const Duration(milliseconds: 150),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'What went well?',
                                style: TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w800,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _tags.map((tag) {
                                  final selected = _selectedTags.contains(tag);
                                  return SelectablePillChip(
                                    label: tag,
                                    isSelected: selected,
                                    onTap: () {
                                      setState(() {
                                        if (selected) {
                                          _selectedTags.remove(tag);
                                        } else {
                                          _selectedTags.add(tag);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _commentController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Add a comment (optional)',
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Scheduled Deliveries Banner matching Screen 5 · Rate delivery
                              PressableScale(
                                onTap: () {
                                  Navigator.of(context).push(
                                    WaterFixPageRoute(
                                      page: const ScheduleDeliveriesScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: WaterFixColors.skyBlueLight,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 20,
                                        color: WaterFixColors.primaryBlack,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Need water every week? Scheduled deliveries are coming soon.',
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
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PrimaryArrowButton(
                label: 'Submit review',
                isLoading: _isSubmitting,
                onPressed: _submitReview,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: WaterFixColors.textSecondary,
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
