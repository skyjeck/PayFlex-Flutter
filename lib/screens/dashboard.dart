// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflex/screens/TransactioHistory.dart';
import 'package:payflex/screens/kycVerifcation.dart';
import 'package:payflex/screens/loan_screen.dart';
import 'package:payflex/screens/set_transaction_pin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:payflex/core/utils/currency_formatter.dart';

import 'package:payflex/api_call/wallet_service.dart';
import 'package:payflex/api_call/transaction_service.dart';
import 'package:payflex/api_call/auth_service.dart';
import 'package:payflex/core/theme.dart';

import 'package:payflex/screens/add_funds.dart';
import 'package:payflex/screens/buy_airtime.dart';
import 'package:payflex/screens/cards_wallets.dart';
import 'package:payflex/screens/notifications.dart';
import 'package:payflex/screens/pay_bills.dart';
import 'package:payflex/screens/send_money.dart';
import 'package:payflex/screens/settings_security.dart';
import 'package:payflex/screens/swapFx.dart';
import 'package:payflex/screens/user_profile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isBalanceVisible = true;

  final WalletService _walletService = WalletService();
  final TransactionService _transactionService = TransactionService();
  final AuthService _authService = AuthService();
  String _profileImage = '';

  // Fetch balance variables
  var _walletBalance = 'loading...';
  String _accountNumber = 'Not Generated';
  bool isLoading = true;
  String _userName = 'User';

  // Transaction state variables
  List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoadingTransactions = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await Future.wait([
      _fetchBalance(),
      _fetchRecentTransactions(),
      _fetchUserProfile(),
    ]);
  }

  Future<void> _fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) return;

      final response = await _authService.getUserProfile(token: token);
      if (response['success'] == true) {
        final profile = response['profile'] ?? {};
        final imageUrl = profile['profileImage']?.toString() ?? '';
        if (mounted && imageUrl.isNotEmpty) {
          setState(() {
            _profileImage = imageUrl;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _fetchBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final storedName = prefs.getString('userName') ?? prefs.getString('name');

      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found. Please log in again.');
      }

      final response = await _walletService.getWalletBalance(token);
      final responseMap = response is Map<String, dynamic> ? response : {};

      final walletData =
          responseMap['wallet'] ??
          responseMap['data'] ??
          responseMap['account'] ??
          responseMap;

      final currency = walletData['currency'] ?? 'NGN';
      final symbol = currency == 'USD' ? '\$' : '₦';

      final rawBalance =
          walletData['availableBalance'] ??
          walletData['balance'] ??
          walletData['amount'] ??
          0;

      final double balanceValue = (rawBalance is num)
          ? rawBalance.toDouble()
          : double.tryParse(rawBalance.toString()) ?? 0.0;

      final virtualAccount = walletData['virtualAccount'];
      final String accountNumber =
          (virtualAccount != null && virtualAccount['accountNumber'] != null)
          ? virtualAccount['accountNumber'].toString()
          : (walletData['accountNumber']?.toString() ?? 'Not Generated');

      if (!mounted) return;

      setState(() {
        _walletBalance = CurrencyFormatter.formatAmount(
          balanceValue,
          symbol: symbol,
        );
        _accountNumber = accountNumber;
        if (storedName != null && storedName.isNotEmpty) {
          _userName = storedName;
        }
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchRecentTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await _transactionService.getTransactions(
        limit: 4,
        token: token,
      );

      if (!mounted) return;

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

      setState(() {
        _recentTransactions = rawList
            .take(4)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _isLoadingTransactions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTransactions = false;
      });
    }
  }

  Future<void> _handleGenerateAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found. Please log in again.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating virtual account...')),
      );

      await _walletService.generateVirtualAccount(token);

      await _fetchBalance();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Virtual account generated successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate account: $e')));
    }
  }

  void _navigateToVerifyKyc() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const KycVerificationScreen()),
    );
    _loadDashboardData();
  }

  void _navigateToNotification() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    _loadDashboardData();
  }

  void _navigateToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileDetailScreen()),
    );
    _loadDashboardData();
  }

  void _navigateToSendMoney() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SendMoneyScreen()),
    );
    _loadDashboardData();
  }

  void _navigateToAirtimeTop() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AirtimeScreen()),
    );
    _loadDashboardData();
  }

  void _navigateToBills() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PayBillsScreen()),
    );
    _loadDashboardData();
  }

  void _navigateToSetPin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SetTransactionPinScreen()),
    );
    _loadDashboardData();
  }

  void _navigateToSwapFx() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FxSwapScreen()),
    );
    _loadDashboardData();
  }

  void _navigateToLoan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoanScreen()),
    );
    _loadDashboardData();
  }

  void _navigateToWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in again.')));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardsAndWalletsScreen(authToken: token),
      ),
    );

    if (!mounted) return;
    _loadDashboardData();
  }

  void _navigateSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    _loadDashboardData();
  }

  void _navigateToTransaction() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()),
    );
    _loadDashboardData();
  }

  void _showAddFundsModal() async {
    // Guard: only allow adding funds if the user is verified and has a virtual account
    final prefs = await SharedPreferences.getInstance();
    final isVerified = prefs.getBool('isVerified') ?? false;

    if (!mounted) return;

    if (!isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email before adding funds.'),
          backgroundColor: PayFlexColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_accountNumber == 'Not Generated') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please generate your virtual account number before adding funds.',
          ),
          backgroundColor: PayFlexColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddFundsModal(
        accountNumber: _accountNumber,
        onFundAdded: (amount) {
          _loadDashboardData();
        },
      ),
    ).then((_) => _loadDashboardData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PayFlexColors.background,
      appBar: AppBar(
        backgroundColor: PayFlexColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            color: PayFlexColors.textPrimary,
            size: 28,
          ),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Welcome back, ',
                    style: TextStyle(
                      color: PayFlexColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: PayFlexColors.textPrimary,
            ),
            onPressed: _navigateToNotification,
          ),
        ],
      ),

      drawer: _buildNavigationDrawer(),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: PayFlexColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(),

                const SizedBox(height: 24),

                const Text(
                  'Quick Services',
                  style: TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                _buildQuickActions(),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToTransaction,
                      child: const Text(
                        'See All',
                        style: TextStyle(
                          color: PayFlexColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _buildTransactionList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      backgroundColor: PayFlexColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              color: PayFlexColors.background,
              border: Border(
                bottom: BorderSide(color: PayFlexColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToProfile();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: PayFlexColors.primary,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: PayFlexColors.iconBg,
                      backgroundImage: _profileImage.isNotEmpty
                          ? NetworkImage(_profileImage)
                          : null,
                      child: _profileImage.isEmpty
                          ? Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: PayFlexColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PayFlexColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _buildDrawerTile(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  title: 'Dashboard',
                  isSelected: true,
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerTile(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  title: 'My Profile',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToProfile();
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.send_outlined,
                  activeIcon: Icons.send_rounded,
                  title: 'Send Money',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToSendMoney();
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet_rounded,
                  title: 'Cards & Wallets',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToWallet();
                  },
                ),

                _buildDrawerTile(
                  icon: Icons.verified,
                  activeIcon: Icons.receipt_long_rounded,
                  title: 'KYC Verification',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToVerifyKyc();
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: PayFlexColors.border, height: 1),
                ),

                _buildDrawerTile(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateSettings();
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.help_outline_rounded,
                  activeIcon: Icons.help_rounded,
                  title: 'Help & Support',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: PayFlexColors.iconBg,
              leading: const Icon(
                Icons.logout_rounded,
                color: PayFlexColors.error,
              ),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  color: PayFlexColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onTap: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected ? PayFlexColors.primaryLight : Colors.transparent,
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected
              ? PayFlexColors.primary
              : PayFlexColors.textSecondary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? PayFlexColors.primary
                : PayFlexColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F382C),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F382C).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Total Available Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('🇳🇬', style: TextStyle(fontSize: 11)),
                        SizedBox(width: 4),
                        Text(
                          'NGN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: Icon(
                  _isBalanceVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isBalanceVisible = !_isBalanceVisible;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            _isBalanceVisible ? _walletBalance : '••••••••',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _accountNumber != 'Not Generated'
                  ? GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _accountNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Account number $_accountNumber copied!',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PayFlex • $_accountNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.copy_rounded,
                              color: Colors.white70,
                              size: 13,
                            ),
                          ],
                        ),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: _handleGenerateAccount,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.15),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: PayFlexColors.primary,
                      ),
                      label: const Text(
                        'Generate Account',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

              TextButton.icon(
                onPressed: _showAddFundsModal,
                style: TextButton.styleFrom(
                  backgroundColor: PayFlexColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text(
                  'Add Funds',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(Icons.send_rounded, 'Send', _navigateToSendMoney),
        _buildActionButton(
          Icons.add_card_rounded,
          'Top Up',
          _navigateToAirtimeTop,
        ),
        _buildActionButton(Icons.receipt_rounded, 'Bills', _navigateToBills),
        _buildActionButton(Icons.monetization_on, 'SwapFx', _navigateToSwapFx),
        _buildActionButton(Icons.credit_score_rounded, 'Loan', _navigateToLoan),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: PayFlexColors.iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: PayFlexColors.primary, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: PayFlexColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_isLoadingTransactions) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PayFlexColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PayFlexColors.border),
        ),
        child: const CircularProgressIndicator(color: PayFlexColors.primary),
      );
    }

    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PayFlexColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PayFlexColors.border),
        ),
        child: const Text(
          'No recent transactions',
          style: TextStyle(color: PayFlexColors.textSecondary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PayFlexColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentTransactions.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 60, color: PayFlexColors.border),
        itemBuilder: (context, index) {
          final tx = _recentTransactions[index];

          final String title =
              tx['title'] ??
              tx['narration'] ??
              tx['recipient_name'] ??
              tx['recipientName'] ??
              tx['description'] ??
              (tx['unifiedModule'] != null
                  ? tx['unifiedModule'].toString().toUpperCase()
                  : tx['type']?.toString().toUpperCase()) ??
              'Transaction';

          final String rawDate =
              tx['createdAt'] ?? tx['created_at'] ?? tx['date'] ?? '';
          final double amount =
              double.tryParse((tx['amount'] ?? 0).toString()) ?? 0.0;

          final String typeStr = (tx['unifiedModule'] ?? tx['type'] ?? '')
              .toString()
              .toLowerCase();

          final bool isDebit =
              typeStr == 'debit' ||
              typeStr == 'transfer' ||
              typeStr == 'withdrawal' ||
              typeStr == 'electricity' ||
              typeStr == 'cable' ||
              typeStr == 'airtime' ||
              typeStr == 'data' ||
              (tx['isDebit'] == true);

          return _buildTransactionTile(
            title: title,
            subtitle: rawDate.isNotEmpty
                ? _formatTransactionDate(rawDate)
                : 'Recently',
            amount:
                '${isDebit ? '-' : '+'}₦${CurrencyFormatter.formatAmount(amount, symbol: '')}',
            isDebit: isDebit,
          );
        },
      ),
    );
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
        return '${dt.day}/${dt.month}/${dt.year}, $timeStr';
      }
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildTransactionTile({
    required String title,
    required String subtitle,
    required String amount,
    required bool isDebit,
  }) {
    return ListTile(
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
        title,
        style: const TextStyle(
          color: PayFlexColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: PayFlexColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: Text(
        amount,
        style: TextStyle(
          color: isDebit ? PayFlexColors.textPrimary : PayFlexColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
