import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../bookings/screens/my_bookings_screen.dart';
import '../../customer_profile/screens/customer_account_screen.dart';
import '../../suppliers/screens/compare_suppliers_screen.dart';
import 'customer_home_screen.dart';

class CustomerShellScreen extends ConsumerStatefulWidget {
  const CustomerShellScreen({super.key});

  @override
  ConsumerState<CustomerShellScreen> createState() =>
      _CustomerShellScreenState();
}

class _CustomerShellScreenState extends ConsumerState<CustomerShellScreen> {
  int _currentIndex = 0;

  void _setTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  Widget _buildActivePage() {
    switch (_currentIndex) {
      case 0:
        return CustomerHomeView(
          key: const ValueKey('tab_home'),
          onNavigateTab: _setTab,
        );
      case 1:
        return CompareSuppliersView(
          key: const ValueKey('tab_suppliers'),
          onBackToHome: () => _setTab(0),
          aiPickHighlightMode: false,
        );
      case 2:
        return CompareSuppliersView(
          key: const ValueKey('tab_ourpick'),
          onBackToHome: () => _setTab(0),
          ourPickHighlightMode: true,
        );
      case 3:
        return const MyBookingsView(key: ValueKey('tab_bookings'));
      case 4:
      default:
        return const CustomerAccountView(key: ValueKey('tab_account'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
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
          child: _buildActivePage(),
        ),
      ),
      bottomNavigationBar: WaterFixBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _setTab,
      ),
    );
  }
}
