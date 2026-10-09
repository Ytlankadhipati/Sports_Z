import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sports_z/shared/theme/app_theme.dart';
import 'package:sports_z/shared/widgets/sz_auth_ui.dart';
import 'package:sports_z/features/auth/data/datasources/auth_service.dart';

import '../controllers/auth_controller.dart';
import 'home_screen.dart';
import 'role_selection_screen.dart';

// ─────────────────────────────────────────────────────────────
// A05 — Phone + OTP  (single-screen combined flow)
// Figma: M1_A05_PhoneOTP  |  "Continue with phone"
// ─────────────────────────────────────────────────────────────

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _authService = AuthService();

  bool _sent = false;
  bool _loading = false;
  String? _error;
  String? _verificationId;

  final List<TextEditingController> _otpCtrl = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  int _timerSecs = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrl) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timerSecs = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timerSecs--);
      if (_timerSecs <= 0) t.cancel();
    });
  }

  String get _maskedPhone {
    final ph = _phoneCtrl.text.trim();
    if (ph.length < 6) return '+91 $ph';
    return '+91 ${ph.substring(0, 2)}••• ••${ph.substring(ph.length - 3)}';
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    HapticFeedback.lightImpact();

    await _authService.sendOTP(
      phoneNumber: '+91$phone',
      codeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _sent = true;
          _verificationId = verificationId;
        });
        _startTimer();
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = err;
        });
      },
      onAutoVerified: () {
        if (!mounted) return;
        _goHome();
      },
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    if (_verificationId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    HapticFeedback.lightImpact();

    final err = await _authService.verifyOTP(
      verificationId: _verificationId!,
      smsCode: otp,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    _goHome();
  }

  void _goHome() async {
    final data = await ref
        .read(authControllerProvider.notifier)
        .verifyWithBackend();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loading = false;
        _error = ref.read(authControllerProvider).errorMessage ?? 'Could not verify your SportsZ account. Check your connection and retry.';
      });
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => data['role'] == null
            ? const RoleSelectionScreen()
            : const HomeScreen(),
      ),
      (_) => false,
    );
  }

  void _changePhone() {
    setState(() {
      _sent = false;
      _error = null;
      _verificationId = null;
      for (final c in _otpCtrl) c.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiLoading = ref.watch(authControllerProvider).isLoading;
    final loading = _loading || apiLoading;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SzPageHeader(id: 'A05', onBack: () => Navigator.maybePop(context)),
            Expanded(child: _sent ? _buildOtpView() : _buildPhoneView()),
            SzStickyFooter(
              child: SzGoldButton(
                label: _sent ? 'Verify and continue' : 'Send code',
                loading: loading,
                onPressed: _sent ? _verifyOtp : _sendCode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SzSectionTitle(
            title: 'Continue with phone',
            subtitle: "We'll send a one-time code to verify your number.",
          ),
          const SzFormLabel(text: 'Phone number'),
          _PhoneField(controller: _phoneCtrl),
          const SizedBox(height: 8),
          const Text(
            'Standard message rates may apply.',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SzErrorCard(message: _error!),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SzSectionTitle(
            title: 'Enter verification code',
            subtitle: 'We sent a six-digit code to $_maskedPhone.',
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(6, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 5 ? 7 : 0),
                  child: _OtpBox(
                    controller: _otpCtrl[i],
                    focusNode: _otpFocus[i],
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) {
                        _otpFocus[i + 1].requestFocus();
                      } else if (v.isEmpty && i > 0) {
                        _otpFocus[i - 1].requestFocus();
                      }
                      if (_otpCtrl.every((c) => c.text.isNotEmpty)) {
                        _verifyOtp();
                      }
                    },
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Center(
            child: _timerSecs > 0
                ? RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'Resend code in '),
                        TextSpan(
                          text: '00:${_timerSecs.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepAccent,
                          ),
                        ),
                      ],
                    ),
                  )
                : TextButton(
                    onPressed: _sendCode,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      textStyle: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Resend code'),
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SzErrorCard(message: _error!),
          ],
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _changePhone,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                textStyle: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Change phone number'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Phone field with +91 prefix ─────────────────────────────
class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  const _PhoneField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            alignment: Alignment.center,
            child: const Text(
              '+91',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: '98765 43210',
                hintStyle: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 16,
                ),
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single OTP digit box ─────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.gold),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.gold),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.gold, width: 2),
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
