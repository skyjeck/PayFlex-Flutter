// lib/widget/receipt_widget.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:payflex/core/theme.dart';

/// Captures a widget identified by [key] as a PNG image and saves it to the
/// device's photo gallery / camera roll.
///
/// Returns a human-readable success message on success, or throws on failure.
Future<String> captureAndDownloadReceipt(GlobalKey key, String fileName) async {
  final context = key.currentContext;
  if (context == null) throw Exception('Receipt widget is not rendered yet.');

  final boundary = context.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw Exception('Could not locate render boundary.');

  // Request required permissions
  if (Platform.isIOS) {
    var status = await Permission.photosAddOnly.request();
    if (!status.isGranted) {
      status = await Permission.photos.request();
      if (!status.isGranted) {
        throw Exception('Photo library access is required. Please enable it in Settings.');
      }
    }
  } else if (Platform.isAndroid) {
    await Permission.storage.request();
  }

  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) throw Exception('Could not capture receipt image.');

  final Uint8List pngBytes = byteData.buffer.asUint8List();

  final result = await ImageGallerySaver.saveImage(
    pngBytes,
    quality: 100,
    name: fileName.replaceAll('.png', ''),
  );

  // result is a Map on both platforms; check the 'isSuccess' key
  final bool success = result is Map
      ? (result['isSuccess'] as bool? ?? false)
      : result == true;

  if (!success) {
    final errorMsg = result is Map ? result['errorMessage']?.toString() : null;
    throw Exception(errorMsg != null ? 'Gallery save failed: $errorMsg' : 'Gallery save returned unsuccessful status.');
  }

  return 'Receipt saved to your photo gallery!';
}

// ─────────────────────────────────────────────────────────────
// ELECTRICITY RECEIPT
// ─────────────────────────────────────────────────────────────

class ElectricityReceiptWidget extends StatelessWidget {
  final String amount;
  final String meterNumber;
  final String provider;
  final String meterToken;
  final String customerName;
  final String reference;
  final String status;

  const ElectricityReceiptWidget({
    super.key,
    required this.amount,
    required this.meterNumber,
    required this.provider,
    required this.meterToken,
    required this.customerName,
    required this.reference,
    this.status = 'SUCCESSFUL',
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now());
    return _ReceiptShell(
      headerIcon: Icons.electric_bolt_rounded,
      headerTitle: 'Electricity Payment',
      status: status,
      amount: amount,
      dateStr: dateStr,
      rows: [
        _ReceiptRow(label: 'Customer', value: customerName),
        _ReceiptRow(label: 'Meter No.', value: meterNumber),
        _ReceiptRow(label: 'Provider', value: provider),
        _ReceiptRow(label: 'Reference', value: reference),
      ],
      highlightSection: meterToken.isNotEmpty
          ? _TokenHighlight(token: meterToken)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SEND MONEY RECEIPT
// ─────────────────────────────────────────────────────────────

class SendMoneyReceiptWidget extends StatelessWidget {
  final String amount;
  final String recipientName;
  final String accountNumber;
  final String bankName;
  final String reference;
  final String narration;
  final String status;

  const SendMoneyReceiptWidget({
    super.key,
    required this.amount,
    required this.recipientName,
    required this.accountNumber,
    required this.bankName,
    required this.reference,
    this.narration = '',
    this.status = 'SUCCESSFUL',
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now());
    return _ReceiptShell(
      headerIcon: Icons.send_rounded,
      headerTitle: 'Money Transfer',
      status: status,
      amount: amount,
      dateStr: dateStr,
      rows: [
        _ReceiptRow(label: 'Recipient', value: recipientName),
        _ReceiptRow(label: 'Account', value: accountNumber),
        _ReceiptRow(label: 'Bank', value: bankName),
        if (narration.isNotEmpty)
          _ReceiptRow(label: 'Narration', value: narration),
        _ReceiptRow(label: 'Reference', value: reference),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GENERIC TRANSACTION RECEIPT (used from TransactionHistory)
// ─────────────────────────────────────────────────────────────

class TransactionReceiptWidget extends StatelessWidget {
  final Map<String, dynamic> txn;

  const TransactionReceiptWidget({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final String? token = txn['token']?.toString();
    final bool hasToken = token != null && token.isNotEmpty;
    final String dateStr =
        txn['date'] ??
        DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now());
    final bool isDebit = txn['isDebit'] == true;

    return _ReceiptShell(
      headerIcon: isDebit
          ? Icons.arrow_upward_rounded
          : Icons.arrow_downward_rounded,
      headerTitle: txn['title'] ?? 'Transaction',
      status: txn['status'] ?? 'SUCCESSFUL',
      amount: '${isDebit ? '-' : '+'}₦${txn['amount']}',
      dateStr: dateStr,
      rows: [
        _ReceiptRow(label: 'Sender', value: txn['sender'] ?? '—'),
        _ReceiptRow(label: 'Recipient', value: txn['recipient'] ?? '—'),
        _ReceiptRow(label: 'Date', value: dateStr),
        _ReceiptRow(label: 'Reference', value: txn['reference'] ?? '—'),
      ],
      highlightSection: hasToken ? _TokenHighlight(token: token ?? '') : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INTERNAL SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _ReceiptShell extends StatelessWidget {
  final IconData headerIcon;
  final String headerTitle;
  final String status;
  final String amount;
  final String dateStr;
  final List<_ReceiptRow> rows;
  final Widget? highlightSection;

  const _ReceiptShell({
    required this.headerIcon,
    required this.headerTitle,
    required this.status,
    required this.amount,
    required this.dateStr,
    required this.rows,
    this.highlightSection,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = status.toUpperCase().contains('SUCCESS');

    return Container(
      color: PayFlexColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row (Wrapped in Expanded to prevent RenderFlex overflow) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PayFlex',
                      style: TextStyle(
                        color: PayFlexColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PayFlexColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? PayFlexColors.primaryLight
                      : PayFlexColors.iconBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                      size: 14,
                      color: isSuccess
                          ? PayFlexColors.primary
                          : PayFlexColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: isSuccess
                            ? PayFlexColors.primary
                            : PayFlexColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Amount hero card ───────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F382C), Color(0xFF1A6B4A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(headerIcon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    amount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Token highlight (electricity only) ─────────────
          if (highlightSection != null) ...[
            const SizedBox(height: 16),
            highlightSection!,
          ],

          const SizedBox(height: 16),

          // ── Detail rows ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PayFlexColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PayFlexColors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1)
                    const Divider(height: 16, color: PayFlexColors.border),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Footer ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 12,
                color: PayFlexColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Secured by PayFlex  •  ${DateFormat('yyyy').format(DateTime.now())}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PayFlexColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: PayFlexColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: PayFlexColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TokenHighlight extends StatelessWidget {
  final String token;

  const _TokenHighlight({required this.token});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PayFlexColors.primaryLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PayFlexColors.primary, width: 1.5),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.electric_bolt_rounded,
                color: PayFlexColors.primary,
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                'ELECTRICITY TOKEN',
                style: TextStyle(
                  color: PayFlexColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              token,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PayFlexColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
