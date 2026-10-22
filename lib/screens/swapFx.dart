import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflex/core/utils/currency_formatter.dart';
import 'package:payflex/api_call/fxSwap_service.dart';
import 'package:payflex/api_call/wallet_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/widget/pin_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FxSwapScreen extends StatefulWidget {
  const FxSwapScreen({super.key});

  @override
  State<FxSwapScreen> createState() => _FxSwapScreenState();
}

class _FxSwapScreenState extends State<FxSwapScreen> {
  final _formKey = GlobalKey<FormState>();
  final FxSwapService _swapService = FxSwapService();
  final WalletService _walletService = WalletService();
  String _authToken = '';

  final TextEditingController _fromAmountController = TextEditingController();
  final TextEditingController _toAmountController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  Timer? _debounceTimer;
  Timer? _rateRefreshTimer;

  bool _isLoadingRates = true;
  bool _isCalculatingQuote = false;
  bool _isSubmitting = false;

  late String _fromCurrency;
  late String _toCurrency;

  double _currentExchangeRate = 1.0;
  double _serviceFee = 0.0;
  double _totalDeduction = 0.0;
  String? _activeQuoteId;

  Map<String, double> _liveRates = {};

  // Real wallet balances fetched from API (keyed by currency code)
  Map<String, double> _userBalances = {
    'NGN': 0.0,
    'USD': 0.0,
    'GBP': 0.0,
    'EUR': 0.0,
  };

  final List<Map<String, String>> _currencies = const [
    {'code': 'NGN', 'name': 'Nigerian Naira', 'symbol': '₦', 'flag': '🇳🇬'},
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$', 'flag': '🇺🇸'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£', 'flag': '🇬🇧'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '🇪🇺'},
  ];

  @override
  void initState() {
    super.initState();
    _fromCurrency = 'NGN';
    _toCurrency = 'USD';
    _loadTokenAndBalances();
    _fetchRates();
    _startRateAutoRefresh();
  }

  @override
  void dispose() {
    _fromAmountController.dispose();
    _toAmountController.dispose();
    _pinController.dispose();
    _debounceTimer?.cancel();
    _rateRefreshTimer?.cancel();
    super.dispose();
  }

  void _startRateAutoRefresh() {
    _rateRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchRates(showLoading: false);
    });
  }

  /// Load auth token from prefs and then fetch real wallet balances
  Future<void> _loadTokenAndBalances() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('token') ?? '';
    await _fetchWalletBalances();
  }

  /// Fetch real wallet balances from the API (all wallets) and populate _userBalances
  Future<void> _fetchWalletBalances() async {
    try {
      // Use getWallets to fetch ALL currency wallets (not just primary NGN)
      final response = await _walletService.getWallets(_authToken);
      final responseMap = response is Map<String, dynamic> ? response : <String, dynamic>{};

      // Extract the wallets list — handle common backend response shapes
      List walletList = [];
      if (response is List) {
        walletList = response;
      } else if (responseMap['wallets'] is List) {
        walletList = responseMap['wallets'];
      } else if (responseMap['data'] is List) {
        walletList = responseMap['data'];
      } else if (responseMap['data'] is Map && responseMap['data']['wallets'] is List) {
        walletList = responseMap['data']['wallets'];
      } else {
        // Single wallet object fallback
        final walletData =
            responseMap['wallet'] ??
            responseMap['data'] ??
            responseMap['account'] ??
            responseMap;
        if (walletData is Map) {
          walletList = [walletData];
        }
      }

      final Map<String, double> updated = {};
      for (final w in walletList) {
        if (w is Map) {
          final code = (w['currency_code'] ?? w['currency'] ?? '').toString().toUpperCase();
          final bal = double.tryParse(
                (w['availableBalance'] ?? w['balance'] ?? 0).toString(),
              ) ??
              0.0;
          if (code.isNotEmpty) updated[code] = bal;
        }
      }

      if (mounted && updated.isNotEmpty) {
        setState(() {
          _userBalances
            ..clear()
            ..addAll({'NGN': 0.0, 'USD': 0.0, 'GBP': 0.0, 'EUR': 0.0})
            ..addAll(updated);
        });
      }
    } catch (_) {
      // Keep default zeros if fetch fails
    }
  }

  /// Optimistically update local balances immediately after a successful swap
  /// so the UI reflects the correct numbers before the API re-fetch resolves.
  void _applyOptimisticSwapBalance(
    String fromCurrency,
    double sourceAmount,
    String toCurrency,
    double destinationAmount,
  ) {
    setState(() {
      final currentFrom = _userBalances[fromCurrency] ?? 0.0;
      _userBalances[fromCurrency] = (currentFrom - sourceAmount).clamp(0.0, double.infinity);

      final currentTo = _userBalances[toCurrency] ?? 0.0;
      _userBalances[toCurrency] = currentTo + destinationAmount;
    });
  }

  Future<void> _fetchRates({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoadingRates = true);
    try {
      final res = await _swapService.getRates(base: _fromCurrency);
      if (res['rates'] != null && mounted) {
        setState(() {
          _liveRates = Map<String, double>.from(
            (res['rates'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ),
          );
          _recalculateRate();
        });

        if (_fromAmountController.text.isNotEmpty) {
          _onFromAmountChanged(_fromAmountController.text);
        }
      }
    } catch (_) {
      // Handled inside service
    } finally {
      if (mounted && showLoading) {
        setState(() => _isLoadingRates = false);
      }
    }
  }

  void _recalculateRate() {
    if (_liveRates.containsKey(_toCurrency)) {
      _currentExchangeRate = _liveRates[_toCurrency] ?? 1.0;
    }
  }

  void _onFromAmountChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (value.isEmpty) {
      _toAmountController.clear();
      setState(() {
        _isCalculatingQuote = false;
        _serviceFee = 0.0;
        _totalDeduction = 0.0;
        _activeQuoteId = null;
      });
      return;
    }

    final double? parsedFrom = double.tryParse(value);
    if (parsedFrom == null || parsedFrom <= 0) {
      _toAmountController.clear();
      return;
    }

    setState(() => _isCalculatingQuote = true);

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final quoteRes = await _swapService.getQuote(
          fromCurrency: _fromCurrency,
          toCurrency: _toCurrency,
          amount: parsedFrom,
        );

        if (mounted && quoteRes['success'] == true) {
          setState(() {
            _activeQuoteId = quoteRes['quoteId']?.toString();
            _currentExchangeRate =
                (quoteRes['rate'] as num?)?.toDouble() ?? _currentExchangeRate;
            
            // Extract the fee correctly, handling "NGN 1000" strings or numbers
            final feeRaw = quoteRes['feeCharged'] ?? quoteRes['fee'];
            double parsedFee = 0.0;
            if (feeRaw is num) {
              parsedFee = feeRaw.toDouble();
            } else if (feeRaw is String) {
              final cleaned = feeRaw.replaceAll(RegExp(r'[^0-9.]'), '');
              parsedFee = double.tryParse(cleaned) ?? 0.0;
            }
            _serviceFee = parsedFee;
            _totalDeduction = parsedFrom + _serviceFee;

            final destAmount =
                (quoteRes['destinationAmount'] as num?)?.toDouble() ??
                (parsedFrom * _currentExchangeRate);
            _toAmountController.text = destAmount.toStringAsFixed(2);
          });
        }
      } catch (e) {
        if (mounted) {
          final double fallbackFee = _fromCurrency == 'NGN' ? 1000.0 : 0.65;
          final double calculatedTo = parsedFrom * _currentExchangeRate;
          setState(() {
            _serviceFee = fallbackFee;
            _totalDeduction = parsedFrom + fallbackFee;
            _toAmountController.text = calculatedTo.toStringAsFixed(2);
          });
        }
      } finally {
        if (mounted) setState(() => _isCalculatingQuote = false);
      }
    });
  }

  void _setPercentageAmount(double percentage) {
    final balance = _userBalances[_fromCurrency] ?? 0.0;
    if (balance <= 0) return;

    final amount = balance * percentage;
    _fromAmountController.text = amount.toStringAsFixed(2);
    _onFromAmountChanged(_fromAmountController.text);
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _activeQuoteId = null;
    });
    _fetchRates();
  }

  Map<String, String> _getCurrencyData(String code) {
    return _currencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'code': code, 'name': code, 'symbol': '', 'flag': '🏳️'},
    );
  }

  void _handleSwapSubmit() {
    if (_formKey.currentState!.validate()) {
      _showPreviewModal();
    }
  }

  void _showConfirmationModal() {
    final fromData = _getCurrencyData(_fromCurrency);
    final toData = _getCurrencyData(_toCurrency);

    final subtitle =
        'Swapping ${fromData['symbol']}${_fromAmountController.text} $_fromCurrency → ${toData['symbol']}${_toAmountController.text} $_toCurrency';

    TransactionPinModal.show(
      context: context,
      title: 'Confirm FX Swap',
      subtitle: subtitle,
      confirmButtonText: 'Confirm & Swap Now',
      onConfirm: (pin) async {
        await _executeSwapOrderWithPin(pin);
      },
    );
  }

  void _showPreviewModal() {
    final fromData = _getCurrencyData(_fromCurrency);
    final toData = _getCurrencyData(_toCurrency);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: PayFlexColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PayFlexColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Swap Preview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: PayFlexColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PayFlexColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PayFlexColors.border),
              ),
              child: Column(
                children: [
                  _buildDetailRow('You Pay', '${fromData['symbol']}${_fromAmountController.text} $_fromCurrency'),
                  const SizedBox(height: 12),
                  _buildDetailRow('You Receive', '${toData['symbol']}${_toAmountController.text} $_toCurrency'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Exchange Rate', '1 $_fromCurrency = ${_currentExchangeRate.toStringAsFixed(4)} $_toCurrency'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Service Fee', '${fromData['symbol']}${_serviceFee.toStringAsFixed(2)} $_fromCurrency'),
                  const Divider(height: 24, color: PayFlexColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Deduction',
                        style: TextStyle(
                          color: PayFlexColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${fromData['symbol']}${_totalDeduction.toStringAsFixed(2)} $_fromCurrency',
                        style: const TextStyle(
                          color: PayFlexColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showConfirmationModal();
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
                  'Confirm & Proceed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _executeSwapOrderWithPin(String pin) async {
    final double sourceAmount = double.parse(_fromAmountController.text);
    final double destinationAmount = double.parse(_toAmountController.text);
    // Capture currencies before clearing
    final String fromCurrency = _fromCurrency;
    final String toCurrency = _toCurrency;

    final res = await _swapService.executeSwap(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      sourceAmount: sourceAmount,
      destinationAmount: destinationAmount,
      rate: _currentExchangeRate,
      pin: pin,
    );

    if (mounted) {
      _pinController.clear();
      _fromAmountController.clear();
      _toAmountController.clear();
      setState(() {
        _serviceFee = 0.0;
        _totalDeduction = 0.0;
        _activeQuoteId = null;
      });

      // Immediately reflect the deducted/received amounts in the UI
      _applyOptimisticSwapBalance(fromCurrency, sourceAmount, toCurrency, destinationAmount);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Currency Swap Successful!'),
          backgroundColor: PayFlexColors.primary,
        ),
      );
      // Also re-fetch authoritative balances from API in the background
      _fetchRates();
      _fetchWalletBalances();
    }
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isGreen = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: PayFlexColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlight || isGreen
                  ? PayFlexColors.primaryDark
                  : PayFlexColors.textPrimary,
              fontSize: isHighlight ? 16 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromData = _getCurrencyData(_fromCurrency);
    final toData = _getCurrencyData(_toCurrency);

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
          'FX Swap',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: PayFlexColors.primary,
            ),
            onPressed: () => _fetchRates(showLoading: true),
            tooltip: 'Refresh Rates',
          ),
        ],
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
                // Live Exchange Rate Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PayFlexColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PayFlexColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: PayFlexColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.trending_up_rounded,
                          color: PayFlexColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Live Rate',
                              style: TextStyle(
                                color: PayFlexColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _isLoadingRates
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    '1 $_fromCurrency = ${_currentExchangeRate.toStringAsFixed(4)} $_toCurrency',
                                    style: const TextStyle(
                                      color: PayFlexColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Quick Selection Percentage Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [0.25, 0.50, 0.75, 1.0].map((percentage) {
                    final label = '${(percentage * 100).toInt()}%';
                    return GestureDetector(
                      onTap: () => _setPercentageAmount(percentage),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: PayFlexColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: PayFlexColors.border),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: PayFlexColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Fixed Overlay Swap Stack
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        _buildCurrencyInputCard(
                          title: 'You Pay',
                          currencyCode: _fromCurrency,
                          currencyData: fromData,
                          controller: _fromAmountController,
                          onAmountChanged: _onFromAmountChanged,
                          onCurrencyChanged: (newCode) {
                            if (newCode != null) {
                              setState(() {
                                if (newCode == _toCurrency) {
                                  _toCurrency = _fromCurrency;
                                }
                                _fromCurrency = newCode;
                                _activeQuoteId = null;
                              });
                              _fetchRates();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildCurrencyInputCard(
                          title: 'You Receive',
                          currencyCode: _toCurrency,
                          currencyData: toData,
                          controller: _toAmountController,
                          readOnly: true,
                          isLoading: _isCalculatingQuote,
                          onCurrencyChanged: (newCode) {
                            if (newCode != null) {
                              setState(() {
                                if (newCode == _fromCurrency) {
                                  _fromCurrency = _toCurrency;
                                }
                                _toCurrency = newCode;
                                _activeQuoteId = null;
                              });
                              _fetchRates();
                            }
                          },
                        ),
                      ],
                    ),
                    Positioned(
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _swapCurrencies,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: PayFlexColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: PayFlexColors.background,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.swap_vert_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PayFlexColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PayFlexColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'Service Fee',
                        '${fromData['symbol']}${_serviceFee.toStringAsFixed(2)} $_fromCurrency',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Total Deduction',
                        '${fromData['symbol']}${_totalDeduction.toStringAsFixed(2)} $_fromCurrency',
                      ),
                      const Divider(color: PayFlexColors.border, height: 20),
                      _buildDetailRow('Estimated Arrival', 'Instant'),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isCalculatingQuote ? null : _handleSwapSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PayFlexColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Preview Swap',
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

  Widget _buildCurrencyInputCard({
    required String title,
    required String currencyCode,
    required Map<String, String> currencyData,
    required TextEditingController controller,
    required ValueChanged<String?> onCurrencyChanged,
    ValueChanged<String>? onAmountChanged,
    bool readOnly = false,
    bool isLoading = false,
  }) {
    final balance = _userBalances[currencyCode] ?? 0.0;
    final symbol = currencyData['symbol'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PayFlexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: PayFlexColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                'Balance: ${CurrencyFormatter.formatAmount(balance, symbol: symbol)}',
                style: const TextStyle(
                  color: PayFlexColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: PayFlexColors.iconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PayFlexColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currencyCode,
                    dropdownColor: PayFlexColors.surface,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: PayFlexColors.textSecondary,
                    ),
                    items: _currencies.map((c) {
                      final code = c['code'] ?? '';
                      final flag = c['flag'] ?? '🏳️';

                      return DropdownMenuItem<String>(
                        value: code,
                        child: Row(
                          children: [
                            Text(flag, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              code,
                              style: const TextStyle(
                                color: PayFlexColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: onCurrencyChanged,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: isLoading
                    ? const Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextFormField(
                        controller: controller,
                        readOnly: readOnly,
                        onChanged: onAmountChanged,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: PayFlexColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: PayFlexColors.textMuted,
                            fontSize: 22,
                          ),
                          border: InputBorder.none,
                        ),
                        validator: (val) {
                          if (readOnly) return null;

                          if (val == null || val.isEmpty) {
                            return 'Enter amount';
                          }

                          final parsed = double.tryParse(val) ?? 0;
                          if (parsed <= 0) {
                            return 'Amount must be greater than zero';
                          }

                          final totalReq = _totalDeduction > 0
                              ? _totalDeduction
                              : parsed + _serviceFee;
                          if (totalReq > balance) {
                            return 'Insufficient balance for amount + fee';
                          }

                          return null;
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: PayFlexColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
