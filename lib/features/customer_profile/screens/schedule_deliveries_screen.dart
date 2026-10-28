import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';

class ScheduleDeliveriesScreen extends ConsumerStatefulWidget {
  const ScheduleDeliveriesScreen({super.key});

  @override
  ConsumerState<ScheduleDeliveriesScreen> createState() =>
      _ScheduleDeliveriesScreenState();
}

class _ScheduleDeliveriesScreenState
    extends ConsumerState<ScheduleDeliveriesScreen> {
  String _mode = 'Recurring';
  final Set<String> _selectedDays = {'Mon', 'Thu'};
  String _selectedWindow = 'Morning';
  int _quantityLiters = 2000;
  bool _saving = false;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _windows = [
    (title: 'Morning', sub: '8–10 AM'),
    (title: 'Midday', sub: '12–2 PM'),
    (title: 'Evening', sub: '5–7 PM'),
  ];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(waterFixControllerProvider).currentUser?.preferences;
    if (prefs != null && prefs.isNotEmpty) {
      if (prefs['scheduleMode'] != null) {
        _mode = prefs['scheduleMode'].toString();
      }
      if (prefs['repeatDays'] is List &&
          (prefs['repeatDays'] as List).isNotEmpty) {
        _selectedDays
          ..clear()
          ..addAll((prefs['repeatDays'] as List).map((e) => e.toString()));
      }
      if (prefs['deliveryWindow'] != null) {
        _selectedWindow = prefs['deliveryWindow'].toString();
      }
      if (prefs['scheduleQuantityLiters'] is num) {
        _quantityLiters = (prefs['scheduleQuantityLiters'] as num).toInt();
      }
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(waterFixControllerProvider)
          .saveSchedulePreferences(
            mode: _mode,
            repeatDays: _selectedDays.toList(),
            deliveryWindow: _selectedWindow,
            quantityLiters: _quantityLiters,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recurring delivery schedule preference saved!'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysStr = _selectedDays.isEmpty
        ? 'Selected days'
        : _selectedDays.join(' and ');
    final windowSub = _windows
        .firstWhere((w) => w.title == _selectedWindow)
        .sub;

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
                    // Header matching Screen 11 · Schedule deliveries
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
                                  'Schedule',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: WaterFixColors.primaryBlack,
                                  ),
                                ),
                              ),
                            ],
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
                          child: const Text(
                            'Coming soon',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: WaterFixColors.primaryBlack,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // One time | Recurring Toggle matching Screen 11
                    AnimatedSectionEntrance(
                      delay: const Duration(milliseconds: 40),
                      child: Row(
                        children: [
                          Expanded(
                            child: PressableScale(
                              onTap: () => setState(() => _mode = 'One time'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _mode == 'One time'
                                      ? WaterFixColors.primaryBlack
                                      : WaterFixColors.cardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _mode == 'One time'
                                        ? WaterFixColors.primaryBlack
                                        : WaterFixColors.cardBorder,
                                  ),
                                ),
                                child: Text(
                                  'One time',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _mode == 'One time'
                                        ? Colors.white
                                        : WaterFixColors.primaryBlack,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PressableScale(
                              onTap: () => setState(() => _mode = 'Recurring'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _mode == 'Recurring'
                                      ? WaterFixColors.primaryBlack
                                      : WaterFixColors.cardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _mode == 'Recurring'
                                        ? WaterFixColors.primaryBlack
                                        : WaterFixColors.cardBorder,
                                  ),
                                ),
                                child: Text(
                                  'Recurring',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _mode == 'Recurring'
                                        ? Colors.white
                                        : WaterFixColors.primaryBlack,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    AnimatedSectionEntrance(
                      delay: const Duration(milliseconds: 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REPEAT ON',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: _days.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final day = entry.value;
                              final selected = _selectedDays.contains(day);
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: idx < _days.length - 1 ? 6 : 0,
                                  ),
                                  child: PressableScale(
                                    onTap: () {
                                      setState(() {
                                        if (selected &&
                                            _selectedDays.length > 1) {
                                          _selectedDays.remove(day);
                                        } else {
                                          _selectedDays.add(day);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? WaterFixColors.primaryBlack
                                            : WaterFixColors.cardBg,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: selected
                                              ? WaterFixColors.primaryBlack
                                              : WaterFixColors.cardBorder,
                                        ),
                                      ),
                                      child: Text(
                                        day,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : WaterFixColors.primaryBlack,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    AnimatedSectionEntrance(
                      delay: const Duration(milliseconds: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DELIVERY WINDOW',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: _windows.map((w) {
                              final selected = _selectedWindow == w.title;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: w.title != 'Evening' ? 10 : 0,
                                  ),
                                  child: PressableScale(
                                    onTap: () => setState(
                                      () => _selectedWindow = w.title,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? WaterFixColors.skyBlue
                                            : WaterFixColors.cardBg,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: selected
                                              ? WaterFixColors.primaryBlack
                                              : WaterFixColors.cardBorder,
                                          width: selected ? 1.8 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            w.title,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: WaterFixColors.primaryBlack,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            w.sub,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  WaterFixColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    AnimatedSectionEntrance(
                      delay: const Duration(milliseconds: 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QUANTITY',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: WaterFixColors.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: WaterFixColors.cardBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SquareIconButton(
                                  icon: Icons.remove_rounded,
                                  onTap: () {
                                    if (_quantityLiters > 1000) {
                                      setState(() => _quantityLiters -= 1000);
                                    }
                                  },
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Text(
                                    '$_quantityLiters L',
                                    key: ValueKey(_quantityLiters),
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                      color: WaterFixColors.primaryBlack,
                                    ),
                                  ),
                                ),
                                SquareIconButton(
                                  icon: Icons.add_rounded,
                                  backgroundColor: WaterFixColors.skyBlue,
                                  onTap: () {
                                    if (_quantityLiters < 10000) {
                                      setState(() => _quantityLiters += 1000);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Summary Sky-Blue Banner matching Screen 11
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: WaterFixColors.skyBlueLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Every $daysStr · $windowSub · $_quantityLiters L',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: WaterFixColors.primaryBlack,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'AI picks the best available supplier each time.',
                                        style: TextStyle(
                                          fontSize: 13.5,
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryArrowButton(
                label: 'Schedule deliveries',
                isLoading: _saving,
                onPressed: _saveSchedule,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
