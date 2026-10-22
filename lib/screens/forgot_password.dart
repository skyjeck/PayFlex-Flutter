import 'package:flutter/material.dart';
import 'package:payflex/api_call/auth_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/network/custom_exception.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();

      // Execute API Call
      final response = await _authService.forgotPassword(email: email);

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Verification code sent to your email!',
            ),
            backgroundColor: PayFlexColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate to 6-digit OTP screen passing user's email
        Navigator.pushNamed(context, '/verify-reset-otp', arguments: email);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to send reset code.'),
            backgroundColor: PayFlexColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to send reset code. Try again.'),
          backgroundColor: PayFlexColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
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
          child: Form(
            key: _formKey,
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
                  'Forgot Password 🔑',
                  style: TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter your email address below to receive a 6-digit reset code.',
                  style: TextStyle(
                    color: Color(0xFFA0A0A0),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 40),

                // Email Input Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email Address',
                      style: TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 15,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your email address';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(val.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'example@gmail.com',
                        hintStyle: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: PayFlexColors.border,
                        prefixIcon: const Icon(
                          Icons.mail_outline_rounded,
                          color: Color(0xFFA0A0A0),
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: PayFlexColors.textPrimary,
                            width: 1.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: PayFlexColors.error,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Submit Button with Loading Indicator
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleForgotPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PayFlexColors.primary,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: PayFlexColors.primary
                          .withOpacity(0.5),
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
                            'Send Reset Code',
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
      ),
    );
  }
}
