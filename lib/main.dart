import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/state/waterfix_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/customer_home/screens/customer_shell_screen.dart';
import 'features/supplier_dashboard/screens/supplier_dashboard_screen.dart';
import 'shared/widgets/tanker_illustration.dart';
import 'shared/widgets/waterfix_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.loadSavedBaseUrl();
  runApp(const ProviderScope(child: WaterFixApp()));
}

class WaterFixApp extends ConsumerStatefulWidget {
  const WaterFixApp({super.key});

  @override
  ConsumerState<WaterFixApp> createState() => _WaterFixAppState();
}

class _WaterFixAppState extends ConsumerState<WaterFixApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(waterFixControllerProvider).restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);

    Widget homeScreen;
    if (controller.isInitializing) {
      homeScreen = const _BrandedSplashScreen();
    } else if (!controller.isAuthenticated) {
      homeScreen = const WelcomeScreen();
    } else if (controller.isAdmin) {
      homeScreen = const AdminDashboardScreen();
    } else if (controller.isSupplier) {
      homeScreen = const SupplierDashboardScreen();
    } else {
      homeScreen = const CustomerShellScreen();
    }

    return MaterialApp(
      title: 'WaterFix',
      debugShowCheckedModeBanner: false,
      theme: WaterFixTheme.lightTheme,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: homeScreen,
      ),
    );
  }
}

class _BrandedSplashScreen extends StatelessWidget {
  const _BrandedSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TiltedTankerBadge(size: 110),
            SizedBox(height: 24),
            WaterFixLogo(fontSize: 34, animate: true),
            SizedBox(height: 18),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: WaterFixColors.primaryBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
