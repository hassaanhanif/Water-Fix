import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'tanker_illustration.dart';
import 'waterfix_buttons.dart';

/// Section 10 required empty marketplace state:
/// Displays "No water suppliers available near you yet."
/// with actions to Change location, Change capacity, Retry search, or Return home.
class EmptySuppliersState extends StatelessWidget {
  final VoidCallback? onChangeLocation;
  final VoidCallback? onChangeCapacity;
  final VoidCallback? onRetry;
  final VoidCallback? onReturnHome;

  const EmptySuppliersState({
    super.key,
    this.onChangeLocation,
    this.onChangeCapacity,
    this.onRetry,
    this.onReturnHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WaterFixColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WaterFixColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SupplierTankerAvatar(size: 72),
          const SizedBox(height: 16),
          const Text(
            'No water suppliers available near you yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'As independent tanker suppliers register and publish listings for your selected capacity and area, they will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: WaterFixColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (onChangeLocation != null)
                OutlinedButton.icon(
                  onPressed: onChangeLocation,
                  icon: const Icon(Icons.location_on_outlined, size: 16),
                  label: const Text('Change location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WaterFixColors.primaryBlack,
                  ),
                ),
              if (onChangeCapacity != null)
                OutlinedButton.icon(
                  onPressed: onChangeCapacity,
                  icon: const Icon(Icons.water_drop_outlined, size: 16),
                  label: const Text('Change capacity'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WaterFixColors.primaryBlack,
                  ),
                ),
              if (onRetry != null)
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry search'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WaterFixColors.primaryBlack,
                  ),
                ),
              if (onReturnHome != null)
                SkyBlueButton(
                  label: 'Return home',
                  fullWidth: false,
                  height: 40,
                  onPressed: onReturnHome,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ErrorRecoveryCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRecoveryCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WaterFixColors.coralAlertBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: WaterFixColors.coralAlertText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: WaterFixColors.primaryBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry connection'),
              style: TextButton.styleFrom(
                foregroundColor: WaterFixColors.primaryBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
