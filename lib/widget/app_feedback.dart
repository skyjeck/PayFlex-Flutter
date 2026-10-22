import 'package:flutter/material.dart';

/// A centralized feedback utility providing styled snackbars for the whole app.
///
/// Usage:
///   AppFeedback.success(context, 'Payment sent!');
///   AppFeedback.error(context, 'Something went wrong.');
///   AppFeedback.info(context, 'Please verify your account.');
///   AppFeedback.copy(context, 'Account Number');
class AppFeedback {
  AppFeedback._();

  // ─── Success (green) ────────────────────────────────────────────────────────

  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF00C853),
      backgroundColor: const Color(0xFF0D1F14),
      textColor: const Color(0xFFB9F4CC),
      borderColor: const Color(0xFF1E6B35),
      duration: const Duration(seconds: 3),
    );
  }

  // ─── Error (red) ────────────────────────────────────────────────────────────

  static void error(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.cancel_rounded,
      iconColor: const Color(0xFFFF5252),
      backgroundColor: const Color(0xFF1F0D0D),
      textColor: const Color(0xFFF8C4C4),
      borderColor: const Color(0xFF6B1E1E),
      duration: const Duration(seconds: 4),
    );
  }

  // ─── Info (blue-slate) ──────────────────────────────────────────────────────

  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_rounded,
      iconColor: const Color(0xFF448AFF),
      backgroundColor: const Color(0xFF0D1520),
      textColor: const Color(0xFFC4D9F8),
      borderColor: const Color(0xFF1E3A6B),
      duration: const Duration(seconds: 3),
    );
  }

  // ─── Copy (clipboard confirmation) ─────────────────────────────────────────

  static void copy(BuildContext context, String label) {
    _show(
      context,
      message: '$label copied to clipboard!',
      icon: Icons.copy_all_rounded,
      iconColor: const Color(0xFF00C853),
      backgroundColor: const Color(0xFF0D1F14),
      textColor: const Color(0xFFB9F4CC),
      borderColor: const Color(0xFF1E6B35),
      duration: const Duration(seconds: 2),
    );
  }

  // ─── Warning (amber) ────────────────────────────────────────────────────────

  static void warning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.warning_rounded,
      iconColor: const Color(0xFFFFC107),
      backgroundColor: const Color(0xFF1F180D),
      textColor: const Color(0xFFF8E6C4),
      borderColor: const Color(0xFF6B4E1E),
      duration: const Duration(seconds: 3),
    );
  }

  // ─── Internal builder ───────────────────────────────────────────────────────

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
    required Duration duration,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          padding: EdgeInsets.zero,
          content: _FeedbackToast(
            message: message,
            icon: icon,
            iconColor: iconColor,
            backgroundColor: backgroundColor,
            textColor: textColor,
            borderColor: borderColor,
          ),
        ),
      );
  }
}

/// The visual toast widget rendered inside the SnackBar.
class _FeedbackToast extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  const _FeedbackToast({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
