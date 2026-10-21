import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflex/api_call/sendMoney_service.dart';
import 'package:payflex/core/enums/transfer_type.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/widget/pin_modal.dart';
import 'package:payflex/core/utils/currency_formatter.dart';
import 'package:payflex/widget/receipt_widget.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final SendMoneyService _sendMoneyService = SendMoneyService();

  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> _wallets = [];
  Map<String, dynamic>? _selectedWallet;

  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;

  /// Bank code that the backend uses to identify PayFlex (internal transfers).
  /// Auto-detected from the banks list, falls back to empty string.
  String _payflexBankCode = '';

  TransferType _selectedTransferType = TransferType.external;

  bool _isLoadingInitialData = true;
  bool _isResolvingAccount = false;
  bool _isSubmitting = false;

  int _verificationRequestId = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _amountController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final results = await Future.wait([
        _sendMoneyService.getWallets(),
        _sendMoneyService.getBanks(),
      ]);

      if (mounted) {
        final walletRes = results[0];
        final bankRes = results[1];

        setState(() {
          // Extract wallet list
          List rawWallets = [];
          if (walletRes is List) {
            rawWallets = walletRes;
          } else if (walletRes is Map) {
            if (walletRes['data'] is List) {
              rawWallets = walletRes['data'];
            } else if (walletRes['wallets'] is List) {
              rawWallets = walletRes['wallets'];
            } else if (walletRes['data'] is Map &&
                walletRes['data']['wallets'] is List) {
              rawWallets = walletRes['data']['wallets'];
            }
          }
          _wallets = rawWallets
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          if (_wallets.isNotEmpty) {
            _selectedWallet = _wallets.first;
          }

          // Extract banks
          List rawBanks = [];
          if (bankRes is List) {
            rawBanks = bankRes;
          } else if (bankRes is Map) {
            if (bankRes['banks'] is List) {
              rawBanks = bankRes['banks'];
            } else if (bankRes['data'] is List) {
              rawBanks = bankRes['data'];
            } else if (bankRes['data'] is Map &&
                bankRes['data']['banks'] is List) {
              rawBanks = bankRes['data']['banks'];
            }
          }

          _banks = rawBanks
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((bank) {
                final code = bank['code']?.toString().trim();
                return code != null && code.isNotEmpty;
              })
              .toList();

          // --- DEBUG: log all fetched bank codes to find PayFlex's real code ---
          developer.log(
            '🏦 Fetched banks: ${_banks.map((b) => "${b['name']} -> ${b['code']}").join(', ')}',
            name: 'SendMoneyScreen',
          );

          // Auto-detect PayFlex bank code from the banks list
          final payflexBank = _banks.firstWhere(
            (b) =>
                (b['name']?.toString() ?? '').toLowerCase().contains('payflex'),
            orElse: () => {},
          );
          _payflexBankCode = payflexBank['code']?.toString().trim() ?? '';
          developer.log(
            '🔑 PayFlex bank code detected: "$_payflexBankCode"',
            name: 'SendMoneyScreen',
          );

          // Inject Paystack Test Bank at the top of the dropdown list
          _banks.insert(0, {'name': 'Test Bank (Development)', 'code': '001'});
          _isLoadingInitialData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInitialData = false);
        _showSnackBar('Failed to load initial data', isError: true);
      }
    }
  }

  Future<void> _onAccountNumberChanged(String val) async {
    final bool isInternal = _selectedTransferType == TransferType.internal;
    final bool canResolve =
        isInternal ||
        (_selectedTransferType == TransferType.external &&
            _selectedBank != null);

    if (val.length == 10 && canResolve) {
      final currentRequestId = ++_verificationRequestId;

      setState(() {
        _isResolvingAccount = true;
        _accountNameController.clear();
      });

      try {
        final String? bankCode = isInternal
            ? null
            : (_selectedBank!['code'].toString().trim());

        final response = await _sendMoneyService.verifyAccount(
          accountNumber: val,
          bankCode: bankCode != null && bankCode.isNotEmpty ? bankCode : null,
          isInternal: isInternal,
        );

        if (currentRequestId != _verificationRequestId) return;

        if (mounted) {
          String resolvedName = '';
          if (response is Map) {
            final dataMap = response['data'] is Map ? response['data'] : null;
            resolvedName =
                response['accountName'] ??
                response['account_name'] ??
                response['name'] ??
                response['fullName'] ??
                response['full_name'] ??
                dataMap?['accountName'] ??
                dataMap?['account_name'] ??
                dataMap?['name'] ??
                dataMap?['fullName'] ??
                dataMap?['full_name'] ??
                '';
          }

          setState(() {
            _accountNameController.text = resolvedName;
            _isResolvingAccount = false;
          });
        }
      } catch (e) {
        if (currentRequestId != _verificationRequestId) return;

        if (mounted) {
          setState(() {
            _isResolvingAccount = false;
            _accountNameController.clear();
          });
          _showSnackBar('Could not verify recipient account', isError: true);
        }
      }
    } else if (val.length < 10) {
      _verificationRequestId++;
      if (_accountNameController.text.isNotEmpty || _isResolvingAccount) {
        setState(() {
          _isResolvingAccount = false;
          _accountNameController.clear();
        });
      }
    }
  }

  void _handleTransfer() {
    if (_formKey.currentState!.validate()) {
      if (_accountNameController.text.trim().isEmpty) {
        _showSnackBar(
          'Please complete account verification first',
          isError: true,
        );
        return;
      }

      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final balance =
          double.tryParse((_selectedWallet?['balance'] ?? 0).toString()) ?? 0.0;

      if (amount > balance) {
        _showSnackBar('Insufficient wallet balance', isError: true);
        return;
      }

      _showPinBottomSheet();
    }
  }

  void _showPinBottomSheet() async {
    final symbol = _selectedWallet?['symbol'] ?? '₦';
    final formattedAmount = CurrencyFormatter.formatAmount(
      _amountController.text,
      symbol: symbol,
    );
    final recipientLabel = _accountNameController.text.isNotEmpty
        ? _accountNameController.text.trim()
        : _accountNumberController.text.trim();
    final subtitle = 'Sending $formattedAmount to $recipientLabel';

    bool isSuccess = false;
    dynamic successResponse;

    await TransactionPinModal.show(
      context: context,
      title: 'Enter Transaction PIN',
      subtitle: subtitle,
      confirmButtonText: 'Confirm Transfer',
      onConfirm: (pin) async {
        successResponse = await _executeTransfer(pin);
        isSuccess = true;
      },
    );

    if (isSuccess && mounted) {
      _showSuccessDialog(successResponse);
    }
  }

  Future<dynamic> _executeTransfer(String pin) async {
    setState(() => _isSubmitting = true);

    try {
      final bool isInternal = _selectedTransferType == TransferType.internal;
      final double amount = double.parse(_amountController.text.trim());
      final String narration = _noteController.text.trim();

      final String recipient = _accountNumberController.text.trim();
      final String? bankCode = isInternal
          ? null
          : _selectedBank?['code']?.toString().trim();

      final response = await _sendMoneyService.sendMoney(
        amount: amount,
        recipient: recipient,
        bankCode: bankCode,
        accountName: _accountNameController.text.trim(),
        transferType: _selectedTransferType,
        narration: narration.isNotEmpty ? narration : null,
        transactionPin: pin,
        walletId: _selectedWallet?['id']?.toString(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      return response;
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
      throw e;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? PayFlexColors.error : PayFlexColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog(dynamic response) {
    final symbol = _selectedWallet?['symbol'] ?? '₦';
    // Extract reference from response if available
    final String reference = () {
      if (response is Map) {
        return (response['reference'] ??
                response['txnRef'] ??
                response['data']?['reference'] ??
                response['data']?['txnRef'] ??
                'PAYFLEX/TXN/${DateTime.now().millisecondsSinceEpoch}')
            .toString();
      }
      return 'PAYFLEX/TXN/${DateTime.now().millisecondsSinceEpoch}';
    }();

    final String bankName =
        _selectedBank?['name']?.toString() ??
        (_selectedTransferType == TransferType.internal
            ? 'PayFlex Wallet'
            : 'Unknown Bank');

    final GlobalKey receiptKey = GlobalKey();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (dialogContext, anim1, anim2) {
        return _SendMoneySuccessPage(
          symbol: symbol,
          amount: _amountController.text,
          recipientName: _accountNameController.text,
          accountNumber: _accountNumberController.text,
          bankName: bankName,
          narration: _noteController.text,
          reference: reference,
          receiptKey: receiptKey,
        );
      },
    );
  }

  Widget _buildTransferTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedTransferType != TransferType.external) {
                  setState(() {
                    _selectedTransferType = TransferType.external;
                    _accountNameController.clear();
                    _onAccountNumberChanged(_accountNumberController.text);
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTransferType == TransferType.external
                      ? PayFlexColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Other Bank',
                    style: TextStyle(
                      color: _selectedTransferType == TransferType.external
                          ? Colors.white
                          : PayFlexColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedTransferType != TransferType.internal) {
                  setState(() {
                    _selectedTransferType = TransferType.internal;
                    _accountNameController.clear();
                    _onAccountNumberChanged(_accountNumberController.text);
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTransferType == TransferType.internal
                      ? PayFlexColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'PayFlex User',
                    style: TextStyle(
                      color: _selectedTransferType == TransferType.internal
                          ? Colors.white
                          : PayFlexColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitialData) {
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
            'Send Money',
            style: TextStyle(
              color: PayFlexColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: PayFlexColors.primary),
        ),
      );
    }

    final String symbol = _selectedWallet?['symbol'] ?? '₦';
    final String balanceText = (_selectedWallet?['balance'] ?? '0.00')
        .toString();

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
          'Send Money',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wallet Selector & Balance Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F382C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PayFlexColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available Balance',
                            style: TextStyle(
                              color: PayFlexColors.border,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.formatAmount(
                              balanceText,
                              symbol: symbol,
                            ),
                            style: const TextStyle(
                              color: PayFlexColors.surface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (_wallets.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: PayFlexColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              value: _selectedWallet,
                              dropdownColor: const Color(0xFF0F382C),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: PayFlexColors.primary,
                                size: 18,
                              ),
                              items: _wallets.map((walletMap) {
                                final code =
                                    walletMap['currency_code'] ??
                                    walletMap['currency'] ??
                                    'NGN';
                                final isSelected =
                                    _selectedWallet?['id'] == walletMap['id'] ||
                                    _selectedWallet == walletMap;

                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: walletMap,
                                  child: Text(
                                    code,
                                    style: TextStyle(
                                      color: isSelected
                                          ? PayFlexColors.primary
                                          : PayFlexColors.surface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedWallet = val);
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Transfer Type Toggle
                _buildTransferTypeSelector(),

                const SizedBox(height: 20),

                // Bank Selector (Shown only when TransferType is external)
                if (_selectedTransferType == TransferType.external) ...[
                  const Text(
                    'Select Bank',
                    style: TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    isExpanded: true,
                    value: _selectedBank,
                    dropdownColor: PayFlexColors.surface,
                    style: const TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontSize: 15,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: PayFlexColors.textSecondary,
                    ),
                    decoration: _buildInputDecoration(
                      'Choose Destination Bank',
                      Icons.account_balance_outlined,
                    ),
                    items: _banks.map((bankMap) {
                      final String bankName =
                          bankMap['name']?.toString() ?? 'Unknown Bank';
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: bankMap,
                        child: Text(bankName, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBank = val;
                        _onAccountNumberChanged(_accountNumberController.text);
                      });
                    },
                    validator: (val) =>
                        _selectedTransferType == TransferType.external &&
                            val == null
                        ? 'Please select a bank'
                        : null,
                  ),
                  const SizedBox(height: 20),
                ],

                // Account Number Field (for both internal and external transfers)
                const Text(
                  'Account Number',
                  style: TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 15,
                  ),
                  onChanged: _onAccountNumberChanged,
                  decoration:
                      _buildInputDecoration(
                        '10-digit account number',
                        Icons.numbers_rounded,
                      ).copyWith(
                        counterText: '',
                        suffixIcon: _isResolvingAccount
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: PayFlexColors.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                  validator: (val) {
                    if (val == null || val.length != 10) {
                      return 'Enter a valid 10-digit account number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Account Name — shown for both internal and external transfers (resolved via verify API)
                const Text(
                  'Account Name',
                  style: TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _accountNameController,
                  readOnly: true,
                  style: const TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration:
                      _buildInputDecoration(
                        'Resolving recipient name...',
                        Icons.person_outline_rounded,
                      ).copyWith(
                        suffixIcon: _accountNameController.text.isNotEmpty
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: PayFlexColors.primary,
                                size: 20,
                              )
                            : null,
                      ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Recipient verification required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Amount Input
                const Text(
                  'Amount',
                  style: TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration:
                      _buildInputDecoration(
                        '0.00',
                        Icons.payments_outlined,
                      ).copyWith(
                        prefixText: '$symbol ',
                        prefixStyle: const TextStyle(
                          color: PayFlexColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  validator: (val) {
                    if (val == null ||
                        val.isEmpty ||
                        (double.tryParse(val) ?? 0) <= 0) {
                      return 'Enter a valid transfer amount';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Narration
                const Text(
                  'Narration (Optional)',
                  style: TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  style: const TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: _buildInputDecoration(
                    'What is this transfer for?',
                    Icons.edit_note_rounded,
                  ),
                ),

                const SizedBox(height: 36),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleTransfer,
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
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Continue',
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

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: PayFlexColors.textSecondary,
        fontSize: 14,
      ),
      filled: true,
      fillColor: const Color(0xFFE2E8F0),
      prefixIcon: Icon(icon, color: PayFlexColors.textSecondary, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: PayFlexColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: PayFlexColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: PayFlexColors.error, width: 1),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Send Money Success Page (shown via showGeneralDialog)
// ─────────────────────────────────────────────────────────────

class _SendMoneySuccessPage extends StatefulWidget {
  final String symbol;
  final String amount;
  final String recipientName;
  final String accountNumber;
  final String bankName;
  final String narration;
  final String reference;
  final GlobalKey receiptKey;

  const _SendMoneySuccessPage({
    required this.symbol,
    required this.amount,
    required this.recipientName,
    required this.accountNumber,
    required this.bankName,
    required this.narration,
    required this.reference,
    required this.receiptKey,
  });

  @override
  State<_SendMoneySuccessPage> createState() => _SendMoneySuccessPageState();
}

class _SendMoneySuccessPageState extends State<_SendMoneySuccessPage> {
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final formattedAmount = CurrencyFormatter.formatAmount(
      widget.amount,
      symbol: widget.symbol,
    );

    return Scaffold(
      backgroundColor: PayFlexColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // ── Success icon + heading ─────────────────────────
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: PayFlexColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: PayFlexColors.primary,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Transfer Successful',
                style: TextStyle(
                  color: PayFlexColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You transferred $formattedAmount to ${widget.recipientName}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PayFlexColors.textSecondary,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 32),

              // ── Receipt preview (captured on share) ───────────
              RepaintBoundary(
                key: widget.receiptKey,
                child: SendMoneyReceiptWidget(
                  amount: formattedAmount,
                  recipientName: widget.recipientName,
                  accountNumber: widget.accountNumber,
                  bankName: widget.bankName,
                  reference: widget.reference,
                  narration: widget.narration,
                ),
              ),

              const SizedBox(height: 32),

              // ── Action buttons ─────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PayFlexColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSharing
                      ? null
                      : () async {
                          setState(() => _isSharing = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final msg = await captureAndDownloadReceipt(
                              widget.receiptKey,
                              'payflex_transfer_${widget.reference}.png',
                            );
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
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
                                  content: Text(
                                    'Could not download receipt: $e',
                                  ),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    _isSharing ? 'Saving...' : 'Download Receipt',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
