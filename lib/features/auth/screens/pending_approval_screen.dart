import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/waterfix_buttons.dart';

class PendingApprovalScreen extends ConsumerStatefulWidget {
  final String? email;

  const PendingApprovalScreen({super.key, this.email});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  bool _isChecking = false;

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    final controller = ref.read(waterFixControllerProvider);
    await controller.fetchAccountStatus();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (controller.currentUser?.isApproved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Congratulations! Your account has been approved by admin.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.currentUser?.isRejected == true
                ? 'Application not approved. Please see reason below.'
                : 'Application is still under review by administrators.',
          ),
          backgroundColor: const Color(0xFF0F4C81),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final controller = ref.read(waterFixControllerProvider);
    await controller.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);
    final user = controller.currentUser;
    final isRejected = user?.isRejected == true;
    final isSupplier = user?.isSupplier == true;
    final rejectionReason = user?.rejectionReason ?? '';

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Status Icon
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: isRejected
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isRejected
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F4C81))
                          .withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  isRejected
                      ? Icons.cancel_outlined
                      : Icons.hourglass_top_rounded,
                  size: 42,
                  color: isRejected
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF0F4C81),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                isRejected
                    ? 'Registration Not Approved'
                    : 'Awaiting Admin Approval',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: WaterFixColors.primaryBlack,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Explanation
              Text(
                isRejected
                    ? 'Your CNIC registration was reviewed by WaterFix administrators and could not be approved at this time.'
                    : isSupplier
                        ? 'Your email has been verified and your CNIC is now in the administrative review queue. Once approved, you will be able to manage your fleet and accept water delivery requests.'
                        : 'Your email has been verified and your CNIC is being reviewed by WaterFix administrators. Once approved, you will be able to book clean water tankers across Islamabad.',
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: WaterFixColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildRow(
                      'Account Status',
                      isRejected ? 'Rejected' : 'Pending Verification',
                      color: isRejected
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF0284C7),
                    ),
                    const Divider(height: 20),
                    _buildRow(
                      'Email Verified',
                      'Yes (Verified)',
                      color: const Color(0xFF16A34A),
                    ),
                    const Divider(height: 20),
                    _buildRow(
                      'CNIC Number',
                      user?.cnicMasked.isNotEmpty == true
                          ? user!.cnicMasked
                          : 'Under Review',
                    ),
                    if (isRejected && rejectionReason.isNotEmpty) ...[
                      const Divider(height: 20),
                      _buildRow(
                        'Reason',
                        rejectionReason,
                        color: const Color(0xFFDC2626),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // Action buttons
              PrimaryArrowButton(
                label: 'Check Approval Status',
                isLoading: _isChecking,
                onPressed: _checkStatus,
              ),
              const SizedBox(height: 12),
              SkyBlueButton(
                label: 'Sign Out',
                onPressed: _handleLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: WaterFixColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color ?? WaterFixColors.primaryBlack,
          ),
        ),
      ],
    );
  }
}
