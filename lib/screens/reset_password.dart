import 'package:flutter/material.dart';
import 'package:payflex/api_call/auth_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/network/custom_exception.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  final String? otp;

  const ResetPasswordScreen({super.key, this.email, this.otp});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _email = '';
  String _otp = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retrieve email & otp from constructor or Navigator arguments
    if (_email.isEmpty || _otp.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, String>) {
        _email = widget.email ?? args['email'] ?? '';
        _otp = widget.otp ?? args['otp'] ?? '';
      } else {
        _email = widget.email ?? '';
        _otp = widget.otp ?? '';
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newPassword = _passwordController.text.trim();

      // Execute Reset Password API Call
      final response = await _authService.resetPassword(
        email: _email,
        otp: _otp,
        newPassword: newPassword,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ??
                  'Password reset successfully! Please log in.',
            ),
            backgroundColor: PayFlexColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Clear route history and navigate back to Login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Failed to reset password. Try again.',
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
          content: Text(e.message ?? 'Password reset failed. Try again.'),
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
                  'Create New Password 🔐',
                  style: TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your new password must be different from previously used passwords.',
                  style: TextStyle(
                    color: Color(0xFFA0A0A0),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 36),

                // New Password Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Password',
                      style: TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 15,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (val.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: '••••••••••••',
                        hintStyle: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: PayFlexColors.border,
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFFA0A0A0),
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFFA0A0A0),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
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

                const SizedBox(height: 24),

                // Confirm Password Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confirm New Password',
                      style: TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 15,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (val != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: '••••••••••••',
                        hintStyle: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: PayFlexColors.border,
                        prefixIcon: const Icon(
                          Icons.lock_reset_rounded,
                          color: Color(0xFFA0A0A0),
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFFA0A0A0),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
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

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
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
                            'Reset Password',
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
