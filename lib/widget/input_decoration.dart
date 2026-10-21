import 'package:flutter/material.dart';
import 'package:payflex/core/theme.dart';

InputDecoration _buildInputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: PayFlexColors.textMuted, fontSize: 14),
    prefixIcon: Icon(icon, color: PayFlexColors.textMuted, size: 20),
    filled: true,
    fillColor: PayFlexColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PayFlexColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PayFlexColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PayFlexColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PayFlexColors.error),
    ),
  );
}
