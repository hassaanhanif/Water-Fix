import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(waterFixControllerProvider).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);
    final items = controller.notifications;

    final now = DateTime.now();
    final todayItems = <Map<String, dynamic>>[];
    final earlierItems = <Map<String, dynamic>>[];

    for (final item in items) {
      final created =
          DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? now;
      final isToday =
          created.year == now.year &&
          created.month == now.month &&
          created.day == now.day;
      if (isToday) {
        todayItems.add(item);
      } else {
        earlierItems.add(item);
      }
    }

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header matching Screen 12 · Notifications
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        SquareIconButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 14),
                        const Flexible(
                          child: Text(
                            'Notifications',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: WaterFixColors.primaryBlack,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => controller.markAllNotificationsRead(),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: WaterFixColors.primaryBlack,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: WaterFixColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: WaterFixColors.cardBorder),
                  ),
                  child: const Text(
                    'No notifications yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: WaterFixColors.textSecondary),
                  ),
                )
              else ...[
                if (todayItems.isNotEmpty) ...[
                  const Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: WaterFixColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...todayItems.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AnimatedSectionEntrance(
                        delay: Duration(milliseconds: 30 + (entry.key * 35)),
                        child: _NotificationCard(item: entry.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (earlierItems.isNotEmpty) ...[
                  const Text(
                    'EARLIER',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: WaterFixColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...earlierItems.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AnimatedSectionEntrance(
                        delay: Duration(milliseconds: 60 + (entry.key * 35)),
                        child: _NotificationCard(item: entry.value),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = (item['type'] ?? '').toString();
    final title = (item['title'] ?? 'Notification').toString();
    final body = (item['body'] ?? '').toString();
    final isRead = item['isRead'] == true;
    final createdAt =
        DateTime.tryParse(item['createdAt']?.toString() ?? '') ??
        DateTime.now();

    Color iconBg = WaterFixColors.skyBlueLight;
    IconData iconData = Icons.check_rounded;
    Color iconColor = WaterFixColors.primaryBlack;

    if (type.contains('dispatched') || type.contains('arriving')) {
      iconBg = WaterFixColors.skyBlue;
      iconData = Icons.local_shipping_outlined;
    } else if (type.contains('cancelled') || type.contains('rejected')) {
      iconBg = WaterFixColors.coralAlertBg;
      iconData = Icons.close_rounded;
      iconColor = WaterFixColors.coralAlertText;
    } else if (type.contains('review')) {
      iconBg = WaterFixColors.pastelSageCard;
      iconData = Icons.star_border_rounded;
    } else if (type.contains('schedule')) {
      iconBg = const Color(0xFFEBEBE6);
      iconData = Icons.access_time_rounded;
    }

    final diffMinutes = DateTime.now().difference(createdAt).inMinutes;
    final timeStr = diffMinutes < 60
        ? '${diffMinutes < 1 ? 1 : diffMinutes} min'
        : diffMinutes < 1440
        ? '${(diffMinutes / 60).floor()} h'
        : DateFormat('d MMM').format(createdAt);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WaterFixColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRead ? WaterFixColors.cardBorder : WaterFixColors.skyBlue,
          width: isRead ? 1 : 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: WaterFixColors.primaryBlack,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
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
    );
  }
}
