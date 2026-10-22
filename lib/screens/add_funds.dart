import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflex/core/utils/currency_formatter.dart';
import 'package:payflex/api_call/wallet_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/network/custom_exception.dart';
import 'package:payflex/widget/app_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddFundsModal extends StatefulWidget {
  final Function(double amount)? onFundAdded;
  final String? accountNumber;
  final String? bankName;

  const AddFundsModal({
    super.key,
    this.onFundAdded,
    this.accountNumber,
    this.bankName,
  });

  /// Static helper to trigger the bottom sheet easily from any screen
  static void show(
    BuildContext context, {
    Function(double amount)? onFundAdded,
    String? accountNumber,
    String? bankName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddFundsModal(
        onFundAdded: onFundAdded,
        accountNumber: accountNumber,
        bankName: bankName,
      ),
    );
  }

  @override
  State<AddFundsModal> createState() => _AddFundsModalState();
}

class _AddFundsModalState extends State<AddFundsModal> {
  int _selectedOptionIndex = 0; // 0: Bank Transfer, 1: Debit Card, 2: USSD
  final TextEditingController _amountController = TextEditingController();

  String _accountNumber = '';
  String _bankName = 'PayFlex Microfinance Bank';

  final WalletService _walletService = WalletService();
  bool _isLoading = false;
  bool _isLoadingAccount = false;

  @override
  void initState() {
    super.initState();
    if (widget.accountNumber != null &&
        widget.accountNumber!.isNotEmpty &&
        widget.accountNumber != 'Not Generated') {
      _accountNumber = widget.accountNumber!;
      if (widget.bankName != null && widget.bankName!.isNotEmpty) {
        _bankName = widget.bankName!;
      }
    } else {
      _fetchAccountDetails();
    }
  }

  Future<void> _fetchAccountDetails() async {
    setState(() => _isLoadingAccount = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await _walletService.getWalletBalance(token);

      if (response is Map<String, dynamic>) {
        final virtualAccount =
            response['virtualAccount'] ?? response['virtual_account'];
        String? fetchedAccount;
        String? fetchedBank;

        if (virtualAccount != null && virtualAccount is Map) {
          fetchedAccount = virtualAccount['accountNumber']?.toString() ??
              virtualAccount['account_number']?.toString();
          fetchedBank = virtualAccount['bankName']?.toString() ??
              virtualAccount['bank_name']?.toString();
        }

        fetchedAccount ??= response['accountNumber']?.toString() ??
            response['account_number']?.toString();

        if (mounted && fetchedAccount != null && fetchedAccount.isNotEmpty) {
          setState(() {
            _accountNumber = fetchedAccount!;
            if (fetchedBank != null && fetchedBank.isNotEmpty) {
              _bankName = fetchedBank;
            }
          });
        }
      }
    } catch (e) {
      print('Failed to fetch virtual account details: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAccount = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _proceedWithCard() async {
    print("===== PROCEED WITH CARD TAPPED =====");
    final text = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(text) ?? 0.0;
    print("Parsed amount: $amount");

    if (amount <= 0) {
      print("Validation failed: amount is <= 0");
      AppFeedback.error(context, 'Please enter a valid amount.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      print("Retrieved token length: ${token.length}");

      print("Calling _walletService.fundWallet...");
      await _walletService.fundWallet(token: token, amount: amount);
      print("Fund wallet request completed successfully!");

      if (!mounted) return;

      Navigator.pop(context); // Close modal

      if (widget.onFundAdded != null) {
        widget.onFundAdded!(amount);
      }

      AppFeedback.success(context, 'Successfully initiated funding for ${CurrencyFormatter.formatAmount(amount, symbol: '₦')}');
    } on AppException catch (e) {
      print("Caught AppException: ${e.message}");
      if (!mounted) return;
      AppFeedback.error(context, e.message ?? 'Failed to initiate funding.');
    } catch (e) {
      print("Caught unexpected exception: $e");
      if (!mounted) return;
      AppFeedback.error(context, 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppFeedback.copy(context, label);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 12,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: PayFlexColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Modal Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Funds',
                style: TextStyle(
                  color: PayFlexColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: PayFlexColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Method Selection Tabs
          Row(
            children: [
              _buildTabButton(
                0,
                'Bank Transfer',
                Icons.account_balance_outlined,
              ),
              const SizedBox(width: 8),
              _buildTabButton(1, 'Debit Card', Icons.credit_card_outlined),
              const SizedBox(width: 8),
              _buildTabButton(2, 'USSD', Icons.dialpad_outlined),
            ],
          ),

          const SizedBox(height: 24),

          // Tab Content Display
          if (_selectedOptionIndex == 0) _buildBankTransferSection(),
          if (_selectedOptionIndex == 1) _buildCardDepositSection(),
          if (_selectedOptionIndex == 2) _buildUssdSection(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final isSelected = _selectedOptionIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedOptionIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? PayFlexColors.primaryLight
                : PayFlexColors.iconBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? PayFlexColors.primary : PayFlexColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? PayFlexColors.primary
                    : PayFlexColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? PayFlexColors.primary
                      : PayFlexColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Bank Transfer View
  Widget _buildBankTransferSection() {
    final String displayAccount = _isLoadingAccount
        ? 'Loading...'
        : (_accountNumber.isNotEmpty && _accountNumber != 'Not Generated'
            ? _accountNumber
            : 'Not Generated');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PayFlexColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PayFlexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transfer to your unique PayFlex account:',
            style: TextStyle(color: PayFlexColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Bank Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bank Name',
                style: TextStyle(
                  color: PayFlexColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              Text(
                _bankName,
                style: const TextStyle(
                  color: PayFlexColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: PayFlexColors.border, height: 1),
          ),

          // Account Number with Copy Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Account Number',
                style: TextStyle(
                  color: PayFlexColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  Text(
                    displayAccount,
                    style: TextStyle(
                      color: _accountNumber.isNotEmpty &&
                              _accountNumber != 'Not Generated' &&
                              !_isLoadingAccount
                          ? PayFlexColors.primary
                          : PayFlexColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (_accountNumber.isNotEmpty &&
                      _accountNumber != 'Not Generated' &&
                      !_isLoadingAccount) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          _copyToClipboard(_accountNumber, 'Account Number'),
                      child: const Icon(
                        Icons.copy_rounded,
                        color: PayFlexColors.primary,
                        size: 18,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: PayFlexColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  color: PayFlexColors.primary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transfers to this account will instantly reflect in your balance.',
                    style: TextStyle(
                      color: PayFlexColors.primaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Debit Card View
  Widget _buildCardDepositSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Amount',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: PayFlexColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            prefixText: '₦ ',
            prefixStyle: const TextStyle(
              color: PayFlexColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            hintText: '0.00',
            hintStyle: const TextStyle(color: PayFlexColors.textMuted),
            filled: true,
            fillColor: PayFlexColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: PayFlexColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: PayFlexColors.border),
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

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _proceedWithCard,
            style: ElevatedButton.styleFrom(
              backgroundColor: PayFlexColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: PayFlexColors.primary.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Proceed to Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  // 3. USSD Code View
  Widget _buildUssdSection() {
    final String ussdCode = _accountNumber.isNotEmpty &&
            _accountNumber != 'Not Generated'
        ? "*737*50*000*$_accountNumber#"
        : "Generate account first";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PayFlexColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PayFlexColors.border),
      ),
      child: Column(
        children: [
          const Text(
            'Dial the USSD code below on your registered phone number:',
            textAlign: TextAlign.center,
            style: TextStyle(color: PayFlexColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SelectableText(
                  ussdCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PayFlexColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (_accountNumber.isNotEmpty &&
                  _accountNumber != 'Not Generated') ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _copyToClipboard(ussdCode, 'USSD Code'),
                  child: const Icon(
                    Icons.copy_rounded,
                    color: PayFlexColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
