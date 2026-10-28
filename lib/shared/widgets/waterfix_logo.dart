import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class WaterFixLogo extends StatelessWidget {
  final double fontSize;
  final bool animate;

  const WaterFixLogo({super.key, this.fontSize = 26, this.animate = false});

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Water ',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: WaterFixColors.primaryBlack,
            letterSpacing: -0.6,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.32,
            vertical: fontSize * 0.08,
          ),
          decoration: BoxDecoration(
            color: WaterFixColors.skyBlue,
            borderRadius: BorderRadius.circular(fontSize * 0.32),
          ),
          child: Text(
            'Fix',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
              letterSpacing: -0.6,
            ),
          ),
        ),
      ],
    );

    if (!animate) return content;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: content,
    );
  }
}
