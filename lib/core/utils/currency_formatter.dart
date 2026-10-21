import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatAmount(dynamic amount, {String symbol = '₦'}) {
    if (amount == null) return '${symbol}0.00';
    
    double? value;
    if (amount is double) {
      value = amount;
    } else if (amount is int) {
      value = amount.toDouble();
    } else if (amount is String) {
      value = double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), ''));
    }

    if (value == null) return '${symbol}0.00';

    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '$symbol${formatter.format(value)}';
  }
}
