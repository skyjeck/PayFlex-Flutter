// lib/widget/pin_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflex/core/theme.dart';

class TransactionPinModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final String confirmButtonText;
  final Future<void> Function(String pin) onConfirm;

  const TransactionPinModal({
    super.key,
    this.title = 'Enter Transaction PIN',
    required this.subtitle,
    this.confirmButtonText = 'Confirm & Authorize',
    required this.onConfirm,
  });

  /// Helper to trigger the PIN modal bottom sheet consistently from any screen
  static Future<void> show({
    required BuildContext context,
    String title = 'Enter Transaction PIN',
    required String subtitle,
    String confirmButtonText = 'Confirm & Authorize',
    required Future<void> Function(String pin) onConfirm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionPinModal(
        title: title,
        subtitle: subtitle,
        confirmButtonText: confirmButtonText,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<TransactionPinModal> createState() => _TransactionPinModalState();
}

class _TransactionPinModalState extends State<TransactionPinModal> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _enteredPin => _controllers.map((c) => c.text.trim()).join();

  Future<void> _submitPin() async {
    final pin = _enteredPin;
    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a complete 4-digit PIN.'),
          backgroundColor: PayFlexColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onConfirm(pin);
      if (mounted) {
        Navigator.pop(context); // Close PIN modal on success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        // Clear PIN boxes on error
        for (final controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: bottomInset + 24,
        ),
        decoration: const BoxDecoration(
          color: PayFlexColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: PayFlexColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Lock Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PayFlexColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: PayFlexColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              widget.title,
              style: const TextStyle(
                color: PayFlexColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle / Transaction details
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PayFlexColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // 4-Digit PIN Input Boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 54,
                  height: 58,
                  child: TextFormField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    obscureText: true,
                    obscuringCharacter: '●',
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    enabled: !_isSubmitting,
                    autofocus: index == 0,
                    style: const TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: PayFlexColors.iconBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: PayFlexColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: PayFlexColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 3) {
                        _focusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }

                      if (_enteredPin.length == 4 && !_isSubmitting) {
                        _submitPin();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PayFlexColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        widget.confirmButtonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
