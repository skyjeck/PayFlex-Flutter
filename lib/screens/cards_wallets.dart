import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflex/api_call/wallet_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardsAndWalletsScreen extends StatefulWidget {
  const CardsAndWalletsScreen({super.key, required String authToken});

  @override
  State<CardsAndWalletsScreen> createState() => _CardsAndWalletsScreenState();
}

class _CardsAndWalletsScreenState extends State<CardsAndWalletsScreen> {
  final WalletService _walletService = WalletService();
  final PageController _cardController = PageController(viewportFraction: 0.9);

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _wallets = [];

  int _activeCardIndex = 0;
  bool _showCvv = false;

  @override
  void initState() {
    super.initState();
    _fetchWallets();
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _fetchWallets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await _walletService.getWallets(token);

      if (response['status'] == true && response['data'] != null) {
        setState(() {
          _wallets = response['data'] as List<dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load wallets.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Cards & Wallets',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PayFlexColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: PayFlexColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PayFlexColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchWallets,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PayFlexColors.primary,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchWallets,
      color: PayFlexColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Virtual Cards
            if (_wallets.isNotEmpty) ...[
              SizedBox(
                height: 200,
                child: PageView(
                  controller: _cardController,
                  onPageChanged: (idx) =>
                      setState(() => _activeCardIndex = idx),
                  children: _wallets.map((wallet) {
                    final currency = wallet['currency'] ?? 'NGN';
                    final symbol = wallet['symbol'] ?? '₦';
                    final balance =
                        (wallet['balance'] as num?)?.toDouble() ?? 0.0;
                    final vAccount = wallet['virtual_account'];
                    final acctNum = vAccount != null
                        ? (vAccount['accountNumber'] ??
                              vAccount['account_number'] ??
                              '0000')
                        : '0000';
                    final lastFour = acctNum.length >= 4
                        ? acctNum.substring(acctNum.length - 4)
                        : acctNum.padLeft(4, '0');

                    final gradient = currency == 'USD'
                        ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                        : const [Color(0xFF0D9488), Color(0xFF115E59)];
                    final brand = currency == 'USD' ? 'VISA' : 'Mastercard';

                    return _buildVirtualCard(
                      title: 'PayFlex $currency Card',
                      brand: brand,
                      lastFour: lastFour,
                      expiry: '**/**',
                      balance: '$symbol${balance.toStringAsFixed(2)}',
                      gradient: gradient,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_wallets.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _activeCardIndex == index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _activeCardIndex == index
                          ? PayFlexColors.primary
                          : PayFlexColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
            ],

            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: PayFlexColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: PayFlexColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionControl(
                      icon: Icons.ac_unit_outlined,
                      label: 'Freeze',
                      onTap: () {},
                    ),
                    _buildActionControl(
                      icon: _showCvv
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      label: _showCvv ? 'Hide CVV' : 'Show CVV',
                      onTap: () => setState(() => _showCvv = !_showCvv),
                    ),
                    _buildActionControl(
                      icon: Icons.add_card_rounded,
                      label: 'Top Up',
                      onTap: () {},
                    ),
                    _buildActionControl(
                      icon: Icons.tune_rounded,
                      label: 'Limits',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Wallets Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Wallets',
                    style: TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_wallets.length} Available',
                    style: const TextStyle(
                      color: PayFlexColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_wallets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'No wallets found.',
                    style: TextStyle(color: PayFlexColors.textSecondary),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: _wallets
                      .map((wallet) => _buildWalletCard(wallet))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualCard({
    required String title,
    required String brand,
    required String lastFour,
    required String expiry,
    required String balance,
    required List<Color> gradient,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                brand,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          Text(
            '•••• •••• •••• $lastFour',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BALANCE',
                    style: TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                  Text(
                    balance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                  Text(
                    expiry,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CVV',
                    style: TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                  Text(
                    _showCvv ? '382' : '•••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: PayFlexColors.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: PayFlexColors.textPrimary, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: PayFlexColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(Map<String, dynamic> wallet) {
    final symbol = wallet['symbol'] ?? '₦';
    final currency = wallet['currency'] ?? 'NGN';
    final balance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
    final ledgerBalance = (wallet['ledger_balance'] as num?)?.toDouble() ?? 0.0;
    final vAccount = wallet['virtual_account'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PayFlexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: PayFlexColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    symbol,
                    style: const TextStyle(
                      color: PayFlexColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$currency Wallet',
                      style: const TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ledger: $symbol${ledgerBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: PayFlexColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$symbol${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: PayFlexColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (vAccount != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(color: PayFlexColors.border, height: 1),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PayFlexColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vAccount['bankName'] ?? vAccount['bank_name'] ?? '',
                        style: const TextStyle(
                          color: PayFlexColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vAccount['accountNumber'] ??
                            vAccount['account_number'] ??
                            '',
                        style: const TextStyle(
                          color: PayFlexColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: PayFlexColors.primary,
                    ),
                    onPressed: () => _copyToClipboard(
                      vAccount['accountNumber'] ??
                          vAccount['account_number'] ??
                          '',
                      'Account Number',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
