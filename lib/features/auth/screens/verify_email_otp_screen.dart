import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import 'pending_approval_screen.dart';
import 'auth_screen.dart';

class VerifyEmailOtpScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyEmailOtpScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailOtpScreen> createState() =>
      _VerifyEmailOtpScreenState();
}

class _VerifyEmailOtpScreenState extends ConsumerState<VerifyEmailOtpScreen> {
  final _otpController = TextEditingController();
  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;
  bool _isResending = false;
  String? _localError;
  String? _successBanner;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldownTimer([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _localError = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _localError = null;
      _successBanner = null;
    });

    final controller = ref.read(waterFixControllerProvider);
    final success = await controller.verifyEmailOtp(otp, email: widget.email);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PendingApprovalScreen(email: widget.email),
        ),
      );
    } else {
      setState(() {
        _localError = controller.authError ?? 'Invalid verification code.';
      });
    }
  }

  Future<void> _handleResend() async {
    if (_cooldownSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _localError = null;
      _successBanner = null;
    });

    final controller = ref.read(waterFixControllerProvider);
    try {
      final res = await controller.resendEmailOtp(email: widget.email);
      if (!mounted) return;
      final wait = (res['waitSeconds'] as num?)?.toInt() ?? 60;
      _startCooldownTimer(wait);
      setState(() {
        _isResending = false;
        _successBanner = 'A fresh 6-digit verification code has been sent to your email.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _localError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);
    final isLoading = controller.isAuthLoading;

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: SquareIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4C81).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 32,
                  color: Color(0xFF0F4C81),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: WaterFixColors.primaryBlack,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: WaterFixColors.textSecondary,
                  ),
                  children: [
                    const TextSpan(
                      text: 'We have sent a single-use 6-digit security code to ',
                    ),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: WaterFixColors.primaryBlack,
                      ),
                    ),
                    const TextSpan(
                      text: '. The code is valid for 5 minutes.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              if (_localError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _localError!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_successBanner != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _successBanner!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Text(
                'ENTER 6-DIGIT CODE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: WaterFixColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('otp_pin_input'),
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  color: WaterFixColors.primaryBlack,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: TextStyle(
                    fontSize: 26,
                    letterSpacing: 8,
                    color: Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF0F4C81),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              PrimaryArrowButton(
                label: 'Verify Code',
                isLoading: isLoading,
                onPressed: _handleVerify,
              ),
              const SizedBox(height: 20),

              Center(
                child: _cooldownSeconds > 0
                    ? Text(
                        'Resend code in ${_cooldownSeconds}s',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: WaterFixColors.textSecondary,
                        ),
                      )
                    : TextButton(
                        onPressed: _isResending ? null : _handleResend,
                        child: _isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Resend Code',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F4C81),
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
