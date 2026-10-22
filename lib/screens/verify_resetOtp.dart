import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflex/api_call/auth_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/network/custom_exception.dart';

class VerifyResetOtpScreen extends StatefulWidget {
  final String? email;

  const VerifyResetOtpScreen({super.key, this.email});

  @override
  State<VerifyResetOtpScreen> createState() => _VerifyResetOtpScreenState();
}

class _VerifyResetOtpScreenState extends State<VerifyResetOtpScreen> {
  final AuthService _authService = AuthService();
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _timerSeconds = 60;
  Timer? _timer;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retrieve email passed via constructor or Navigator arguments
    if (_userEmail.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (widget.email != null && widget.email!.isNotEmpty) {
        _userEmail = widget.email!;
      } else if (args is String) {
        _userEmail = args;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _timerSeconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onOtpDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste of 6-digit code into box
      final pastedCode = value.replaceAll(RegExp(r'\D'), '');
      if (pastedCode.length == 6) {
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = pastedCode[i];
        }
        _focusNodes[5].requestFocus();
        _handleVerifyOtp();
        return;
      }
    }

    if (value.isNotEmpty) {
      // Move to next focus box if available
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_otpCode.length == 6) {
          _handleVerifyOtp();
        }
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_timerSeconds > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      final response = await _authService.forgotPassword(email: _userEmail);

      if (!mounted) return;

      if (response['success'] == true) {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'A new 6-digit code has been sent.',
            ),
            backgroundColor: PayFlexColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Failed to resend code. Try again.',
            ),
            backgroundColor: PayFlexColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to resend OTP. Please try again.'),
          backgroundColor: PayFlexColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpCode;

    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit verification code.'),
          backgroundColor: PayFlexColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.verifyResetOtp(
        email: _userEmail,
        otp: otp,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'OTP verified successfully!'),
            backgroundColor: PayFlexColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate to Reset Password screen passing email & verified OTP
        Navigator.pushReplacementNamed(
          context,
          '/reset-password',
          arguments: {'email': _userEmail, 'otp': otp},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Invalid or expired OTP code.',
            ),
            backgroundColor: PayFlexColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Verification failed. Try again.'),
          backgroundColor: PayFlexColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An unexpected error occurred. Please try again.'),
          backgroundColor: PayFlexColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PayFlexColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Back Button
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: PayFlexColors.textPrimary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              const SizedBox(height: 32),

              // Header Title
              const Text(
                'Verify OTP 🔒',
                style: TextStyle(
                  color: PayFlexColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFFA0A0A0),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                      text: _userEmail.isNotEmpty ? _userEmail : 'your email',
                      style: const TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: '. Enter it below to continue.'),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 6-Digit Pin Input Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) {
                        // Move focus back when deleting on an empty box
                        if (event is RawKeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.backspace &&
                            _controllers[index].text.isEmpty &&
                            index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: PayFlexColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            6,
                          ), // Supports pasting full 6 digits
                        ],
                        onChanged: (value) => _onOtpDigitChanged(index, value),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: PayFlexColors.border,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PayFlexColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // Resend Code Section
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Didn't receive the code? ",
                      style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: (_timerSeconds == 0 && !_isResending)
                          ? _handleResendOtp
                          : null,
                      child: Text(
                        _timerSeconds > 0
                            ? 'Resend in ${_timerSeconds}s'
                            : 'Resend Code',
                        style: TextStyle(
                          color: _timerSeconds > 0
                              ? const Color(0xFF666666)
                              : PayFlexColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PayFlexColors.primary,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: PayFlexColors.primary.withOpacity(
                      0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Verify & Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
