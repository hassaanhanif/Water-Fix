import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tanker_illustration.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../../shared/widgets/waterfix_logo.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WaterFixLogo(fontSize: 28, animate: true),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Dark Card from Screen 8 · Welcome
                      AnimatedSectionEntrance(
                        delayMs: 60,
                        child: Container(
                          width: double.infinity,
                          height: 330,
                          decoration: BoxDecoration(
                            color: WaterFixColors.primaryBlack,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: const Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(28),
                                child: Text(
                                  'FRESH WATER.\nFAIR PRICES.\nFAST.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 29,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -18,
                                bottom: -18,
                                child: TiltedTankerBadge(size: 215),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const AnimatedSectionEntrance(
                        delayMs: 140,
                        child: Text(
                          'Water at your door,\nin minutes.',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: WaterFixColors.primaryBlack,
                            height: 1.12,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const AnimatedSectionEntrance(
                        delayMs: 200,
                        child: Text(
                          'Compare tanker suppliers, book a delivery and track it live.',
                          style: TextStyle(
                            fontSize: 16,
                            color: WaterFixColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSectionEntrance(
                delayMs: 260,
                child: PrimaryArrowButton(
                  label: 'Get started',
                  onPressed: () {
                    Navigator.of(context).push(
                      WaterFixPageRoute(
                        page: const AuthScreen(initialIsSignUp: true),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSectionEntrance(
                delayMs: 320,
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        WaterFixPageRoute(
                          page: const AuthScreen(initialIsSignUp: false),
                        ),
                      );
                    },
                    child: const Text(
                      'I already have an account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: WaterFixColors.textSecondary,
                      ),
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
