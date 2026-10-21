// lib/screens/transaction_history_screen.dart

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:payflex/api_call/transaction_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/core/utils/currency_formatter.dart';
import 'package:payflex/widget/receipt_widget.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TransactionService _transactionService = TransactionService();

  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<String> _filters = [
    'All',
    'Transfers',
    'Top Ups',
    'Bills',
    'Swaps',
  ];

  List<Map<String, dynamic>> _allTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Maps chip filter label to the backend `module` query parameter
  String? _getModuleQueryParam(String filter) {
    switch (filter) {
      case 'Transfers':
        return 'transfer';
      case 'Top Ups':
        return 'wallet';
      case 'Bills':
        return 'electricity'; // Alternatively fetch all services without a specific category
      case 'Swaps':
        return 'swap';
      default:
        return null;
    }
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final moduleParam = _getModuleQueryParam(_selectedFilter);

      final response = await _transactionService.getTransactions(
        limit: 50,
        page: 1,
        module: moduleParam,
        token: token,
      );

      if (!mounted) return;

      // Clean extraction to handle unified payload { data: { history: [...] } }
      List rawList = [];
      if (response is Map<String, dynamic>) {
        final data = response['data'];
        if (data is Map) {
          if (data['history'] is List) {
            rawList = data['history'];
          } else if (data['transactions'] is List) {
            rawList = data['transactions'];
          }
        } else if (data is List) {
          rawList = data;
        } else if (response['transactions'] is List) {
          rawList = response['transactions'];
        }
      } else if (response is List) {
        rawList = response;
      }

      final mappedTransactions = rawList
          .whereType<Map>()
          .map((item) => _normalizeTransaction(Map<String, dynamic>.from(item)))
          .toList();

      setState(() {
        _allTransactions = mappedTransactions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load transactions: $e'),
          backgroundColor: PayFlexColors.error,
        ),
      );
    }
  }

  Map<String, dynamic> _normalizeTransaction(Map<String, dynamic> raw) {
    final moduleTag =
        (raw['unifiedModule'] ?? raw['type'] ?? raw['category'] ?? '')
            .toString()
            .toLowerCase();

    // Categorization logic using unifiedModule tag
    String category = 'Transfers';
    if (moduleTag == 'swap') {
      category = 'Swaps';
    } else if (moduleTag.contains('top') ||
        moduleTag.contains('deposit') ||
        moduleTag.contains('credit') ||
        moduleTag.contains('fund') ||
        moduleTag == 'wallet') {
      category = 'Top Ups';
    } else if (moduleTag.contains('bill') ||
        moduleTag.contains('utility') ||
        moduleTag.contains('airtime') ||
        moduleTag.contains('data') ||
        moduleTag.contains('electricity') ||
        moduleTag.contains('cable') ||
        moduleTag == 'service') {
      category = 'Bills';
    }

    final bool isDebit =
        moduleTag == 'debit' ||
        moduleTag == 'transfer' ||
        moduleTag == 'withdrawal' ||
        moduleTag == 'bill' ||
        moduleTag.contains('electricity') ||
        moduleTag.contains('cable') ||
        moduleTag.contains('airtime') ||
        moduleTag.contains('data') ||
        (raw['isDebit'] == true);

    final String title =
        raw['title'] ??
        raw['narration'] ??
        raw['recipient_name'] ??
        raw['recipientName'] ??
        raw['description'] ??
        (raw['type'] != null
            ? raw['type'].toString().toUpperCase()
            : moduleTag.toUpperCase());

    final double rawAmount =
        double.tryParse((raw['amount'] ?? 0).toString()) ?? 0.0;
    final String formattedAmount = CurrencyFormatter.formatAmount(
      rawAmount,
      symbol: '',
    );

    final String rawDate =
        raw['createdAt'] ?? raw['created_at'] ?? raw['date'] ?? '';

    // Extract electricity meter token — check every known backend shape
    final String? token = () {
      const tokenKeys = ['token', 'meterToken', 'tokenCode', 'meter_token', 'electricityToken'];

      // Top-level fields
      for (final k in tokenKeys) {
        final v = raw[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }

      // Nested under common wrapper objects
      for (final wrapper in ['meta', 'details', 'data', 'providerResponse', 'result', 'metadata', 'extraData', 'serviceData', 'billData', 'response']) {
        if (raw[wrapper] is Map) {
          final nested = raw[wrapper] as Map;
          for (final k in tokenKeys) {
            final v = nested[k];
            if (v != null && v.toString().isNotEmpty) return v.toString();
          }
        }
      }
      return null;
    }();

    return {
      'id':
          raw['id']?.toString() ??
          raw['_id']?.toString() ??
          'TXN-${raw['reference']}',
      'title': title,
      'category': category,
      'moduleTag': moduleTag,
      'amount': formattedAmount,
      'rawAmount': rawAmount,
      'isDebit': isDebit,
      'date': rawDate.isNotEmpty ? _formatTransactionDate(rawDate) : 'Recently',
      'status': (raw['status'] ?? 'Successful').toString().toUpperCase(),
      'reference':
          raw['reference'] ?? raw['txnRef'] ?? raw['id'] ?? 'PAYFLEX/TXN/REF',
      'sender':
          raw['sender'] ??
          raw['senderName'] ??
          raw['source'] ??
          'PayFlex Wallet',
      'recipient':
          raw['recipient'] ??
          raw['recipientName'] ??
          raw['destination'] ??
          'Beneficiary',
      // Extra fields for receipt
      'meterNumber':
          raw['meterNumber'] ??
          raw['meter_number'] ??
          raw['smartCardNumber'] ??
          raw['identifier'] ??
          '',
      'provider':
          raw['provider'] ??
          raw['disco'] ??
          raw['serviceProvider'] ??
          '',
      'customerName':
          raw['customerName'] ??
          raw['customer_name'] ??
          raw['accountName'] ??
          '',
      'token': token,
    };
  }

  String _formatTransactionDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final txDate = DateTime(dt.year, dt.month, dt.day);

      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final timeStr = '$hour:$minute $period';

      if (txDate == today) {
        return 'Today, $timeStr';
      } else if (txDate == yesterday) {
        return 'Yesterday, $timeStr';
      } else {
        return '${DateFormat('MMM d, yyyy').format(dt)}, $timeStr';
      }
    } catch (_) {
      return isoString;
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    return _allTransactions.where((txn) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch =
          txn['title'].toString().toLowerCase().contains(query) ||
          txn['reference'].toString().toLowerCase().contains(query) ||
          txn['recipient'].toString().toLowerCase().contains(query) ||
          (txn['token'] != null &&
              txn['token'].toString().toLowerCase().contains(query));
      return matchesSearch;
    }).toList();
  }

  void _showTransactionReceipt(Map<String, dynamic> txn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionReceiptBottomSheet(txn: txn),
    );
  }


  Future<void> _downloadAccountStatement(BuildContext buttonContext) async {
    if (_allTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions available to download.'),
          backgroundColor: PayFlexColors.error,
        ),
      );
      return;
    }

    try {
      final List<List<dynamic>> csvData = [
        ['Date', 'Reference', 'Description', 'Category', 'Amount', 'Status']
      ];

      for (var txn in _allTransactions) {
        csvData.add([
          txn['date'],
          txn['reference'],
          txn['title'],
          txn['category'],
          txn['amount'],
          txn['status']
        ]);
      }

      final String csvString = const ListToCsvConverter().convert(csvData);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/PayFlex_Account_Statement.csv');
      await file.writeAsString(csvString);

      Rect? sharePositionOrigin;
      final box = buttonContext.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'PayFlex Account Statement',
        text: 'Here is your PayFlex account statement.',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate statement: $e'),
            backgroundColor: PayFlexColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredTransactions;

    return Scaffold(
      backgroundColor: PayFlexColors.background,
      appBar: AppBar(
        backgroundColor: PayFlexColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: PayFlexColors.textPrimary,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Transaction History',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (actionContext) => IconButton(
              icon: const Icon(
                Icons.file_download_outlined,
                color: PayFlexColors.primary,
              ),
              onPressed: () => _downloadAccountStatement(actionContext),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchTransactions,
          color: PayFlexColors.primary,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: const TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by beneficiary, ref, token...',
                        hintStyle: const TextStyle(
                          color: PayFlexColors.textSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: PayFlexColors.textSecondary,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  color: PayFlexColors.textSecondary,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: PayFlexColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: PayFlexColors.border,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: PayFlexColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Filter Chips wired to reload data from API based on module query
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final isSelected = _selectedFilter == filter;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(filter),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.black
                                    : PayFlexColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                              backgroundColor: PayFlexColors.surface,
                              selectedColor: PayFlexColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? PayFlexColors.primary
                                      : PayFlexColors.border,
                                ),
                              ),
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (_selectedFilter != filter) {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                  _fetchTransactions();
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: PayFlexColors.primary,
                        ),
                      )
                    : filteredList.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 56,
                                  color: PayFlexColors.textSecondary,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No transactions found',
                                  style: TextStyle(
                                    color: PayFlexColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Try adjusting your filters or search query.',
                                  style: TextStyle(
                                    color: PayFlexColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final txn = filteredList[index];
                          return _buildTransactionCard(txn);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> txn) {
    final bool isDebit = txn['isDebit'];
    final bool hasToken =
        txn['token'] != null && txn['token'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PayFlexColors.border),
      ),
      child: ListTile(
        onTap: () => _showTransactionReceipt(txn),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: isDebit
              ? PayFlexColors.iconBg
              : PayFlexColors.primaryLight,
          child: Icon(
            isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: isDebit ? PayFlexColors.textPrimary : PayFlexColors.primary,
            size: 18,
          ),
        ),
        title: Text(
          txn['title'],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: PayFlexColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          hasToken ? '${txn['date']} • Token Available' : txn['date'],
          style: TextStyle(
            color: hasToken
                ? PayFlexColors.primary
                : PayFlexColors.textSecondary,
            fontSize: 12,
            fontWeight: hasToken ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isDebit ? '-' : '+'}₦${txn['amount']}',
              style: TextStyle(
                color: isDebit
                    ? PayFlexColors.textPrimary
                    : PayFlexColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              txn['status'],
              style: TextStyle(
                color:
                    txn['status'] == 'SUCCESSFUL' || txn['status'] == 'SUCCESS'
                    ? PayFlexColors.primary
                    : PayFlexColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionReceiptBottomSheet extends StatefulWidget {
  final Map<String, dynamic> txn;

  const TransactionReceiptBottomSheet({super.key, required this.txn});

  @override
  State<TransactionReceiptBottomSheet> createState() =>
      _TransactionReceiptBottomSheetState();
}

class _TransactionReceiptBottomSheetState
    extends State<TransactionReceiptBottomSheet> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final txn = widget.txn;
    final String? token = txn['token']?.toString();
    final String moduleTag = txn['moduleTag']?.toString() ?? '';
    final bool isElectricity = moduleTag.contains('electricity') ||
        txn['category']?.toString() == 'Bills' && (token != null && token.isNotEmpty);

    return Container(
      decoration: const BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle + title ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: PayFlexColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Text(
                        'Transaction Details',
                        style: TextStyle(
                          color: PayFlexColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Receipt preview (captured for sharing) ─────────
                RepaintBoundary(
                  key: _receiptKey,
                  child: TransactionReceiptWidget(txn: txn),
                ),

                // ── Electricity token prominent card ───────────────
                if (token != null && token.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: PayFlexColors.primaryLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: PayFlexColors.primary, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.electric_bolt_rounded,
                            color: PayFlexColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'METER TOKEN — Tap icon to copy',
                                  style: TextStyle(
                                    color: PayFlexColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  token,
                                  style: const TextStyle(
                                    color: PayFlexColors.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: PayFlexColors.primary,
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: token));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Meter Token copied to clipboard!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Transaction meta rows ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PayFlexColors.border.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PayFlexColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildReceiptRow('Status', txn['status'],
                            isHighlight: true),
                        const Divider(height: 20, color: PayFlexColors.border),
                        _buildReceiptRow('Date & Time', txn['date']),
                        const Divider(height: 20, color: PayFlexColors.border),
                        _buildReceiptRow('Sender', txn['sender']),
                        const Divider(height: 20, color: PayFlexColors.border),
                        _buildReceiptRow('Recipient', txn['recipient']),
                        if (isElectricity && (txn['meterNumber'] ?? '').toString().isNotEmpty) ...[
                          const Divider(height: 20, color: PayFlexColors.border),
                          _buildReceiptRow('Meter No.', txn['meterNumber']),
                        ],
                        if (isElectricity && (txn['provider'] ?? '').toString().isNotEmpty) ...[
                          const Divider(height: 20, color: PayFlexColors.border),
                          _buildReceiptRow('Provider', txn['provider']),
                        ],
                        const Divider(height: 20, color: PayFlexColors.border),
                        _buildReceiptRow(
                          'Reference',
                          txn['reference'],
                          canCopy: true,
                          context: context,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Action buttons ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: PayFlexColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              color: PayFlexColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSharing
                              ? null
                              : () async {
                                  setState(() => _isSharing = true);
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    final msg = await captureAndDownloadReceipt(
                                      _receiptKey,
                                      'payflex_receipt_${txn['reference'] ?? DateTime.now().millisecondsSinceEpoch}.png',
                                    );
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded,
                                                  color: Colors.white, size: 18),
                                              const SizedBox(width: 8),
                                              Expanded(child: Text(msg)),
                                            ],
                                          ),
                                          backgroundColor: PayFlexColors.primary,
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Could not download receipt: $e'),
                                          backgroundColor: PayFlexColors.error,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isSharing = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PayFlexColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          icon: _isSharing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_rounded, size: 18),
                          label: Text(
                            _isSharing ? 'Saving...' : 'Download Receipt',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool canCopy = false,
    BuildContext? context,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: PayFlexColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isHighlight
                        ? PayFlexColors.primary
                        : PayFlexColors.textPrimary,
                    fontSize: 12,
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
              if (canCopy && context != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied to clipboard!'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: PayFlexColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
