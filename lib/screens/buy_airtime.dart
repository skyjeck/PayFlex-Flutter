import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflex/core/utils/currency_formatter.dart';
import 'package:payflex/api_call/airtime_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/widget/pin_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AirtimeScreen extends StatefulWidget {
  const AirtimeScreen({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AirtimeScreen(),
    );
  }

  @override
  State<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends State<AirtimeScreen> {
  final _formKey = GlobalKey<FormState>();
  final AirtimeService _airtimeService = AirtimeService();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  int _selectedTab = 0; // 0 = Airtime, 1 = Data
  Map<String, dynamic>? _selectedOperator;
  Map<String, dynamic>? _selectedDataPlan;

  List<dynamic> _operators = [];
  List<dynamic> _dataPlans = [];
  bool _isLoadingProviders = true;
  bool _isLoadingPlans = false;
  bool _isSubmitting = false;

  final List<int> _quickAmounts = [100, 200, 500, 1000, 2000, 5000];

  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchProviders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final providers = await _airtimeService.getAirtimeProviders(token);

      if (!mounted) return;
      setState(() {
        _operators = providers;
        if (_operators.isNotEmpty) {
          _selectedOperator = _operators.first as Map<String, dynamic>;
          _fetchDataPlans();
        }
        _isLoadingProviders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProviders = false);
      _showSnackBar(e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  Future<void> _fetchDataPlans() async {
    if (_selectedOperator == null) return;
    setState(() {
      _isLoadingPlans = true;
      _dataPlans = [];
      _selectedDataPlan = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final opId =
          (_selectedOperator!['id'] ?? _selectedOperator!['code'] ?? '')
              .toString();

      final plans = await _airtimeService.getDataPlans(token, opId);

      if (!mounted) return;
      setState(() {
        _dataPlans = plans;
        // Automatically pre-select the first data plan if available
        if (_dataPlans.isNotEmpty) {
          _selectedDataPlan = _dataPlans.first as Map<String, dynamic>;
        }
        _isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPlans = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? PayFlexColors.error : PayFlexColors.primary,
      ),
    );
  }

  Map<String, dynamic> _getOperatorTheme(String name) {
    final normalized = name.toUpperCase();
    if (normalized.contains('MTN')) {
      return {
        'color': const Color(0xFFFFCC00),
        'textColor': Colors.black,
        'asset': 'assets/images/mtn.png',
      };
    } else if (normalized.contains('AIRTEL')) {
      return {
        'color': const Color(0xFFE50914),
        'textColor': Colors.white,
        'asset': 'assets/images/airtel.png',
      };
    } else if (normalized.contains('GLO')) {
      return {
        'color': const Color(0xFF00A859),
        'textColor': Colors.white,
        'asset': 'assets/images/glo.png',
      };
    } else if (normalized.contains('9MOBILE') ||
        normalized.contains('EMTS') ||
        normalized.contains('ETISALAT')) {
      return {
        'color': const Color(0xFF005B41),
        'textColor': Colors.white,
        'asset': 'assets/images/9mobile.png',
      };
    } else {
      return {
        'color': PayFlexColors.primary,
        'textColor': Colors.white,
        'asset': null,
      };
    }
  }

  void _handlePurchase() {
    if (_formKey.currentState!.validate()) {
      if (_selectedOperator == null) {
        _showSnackBar('Please select a network provider', isError: true);
        return;
      }

      if (_selectedTab == 1 && _selectedDataPlan == null) {
        _showSnackBar('Please select a data plan', isError: true);
        return;
      }

      _showPinDialog();
    }
  }

  void _showPinDialog() {
    final subtitle = _selectedTab == 0
        ? 'Confirm ${CurrencyFormatter.formatAmount(_amountController.text, symbol: '₦')} top-up for ${_phoneController.text}'
        : 'Confirm ${_selectedDataPlan?['name'] ?? _selectedDataPlan?['plan'] ?? 'Data'} purchase for ${_phoneController.text}';

    TransactionPinModal.show(
      context: context,
      title: 'Enter Transaction PIN',
      subtitle: subtitle,
      confirmButtonText: 'Confirm & Pay',
      onConfirm: (pin) async {
        await _executeTransaction(pin);
      },
    );
  }

  Future<void> _executeTransaction(String pin) async {
    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final operatorCode =
          (_selectedOperator?['code'] ?? _selectedOperator?['id'] ?? '')
              .toString();

      if (_selectedTab == 0) {
        final res = await _airtimeService.buyAirtime(
          token: token,
          phoneNumber: _phoneController.text,
          amount: double.parse(_amountController.text),
          operatorCode: operatorCode,
          pin: pin,
        );

        if (!mounted) return;
        Navigator.pop(context, true);
        _showSnackBar(res['message'] ?? 'Airtime purchase successful!');
      } else {
        final planId =
            (_selectedDataPlan?['id'] ?? _selectedDataPlan?['code'] ?? '')
                .toString();

        final res = await _airtimeService.buyData(
          token: token,
          phoneNumber: _phoneController.text,
          planId: planId,
          operatorCode: operatorCode,
          pin: pin,
        );

        if (!mounted) return;
        Navigator.pop(context, true);
        _showSnackBar(res['message'] ?? 'Data bundle purchase successful!');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackBar(e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PayFlexColors.surface,
      child: Container(
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
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedTab == 0 ? 'Buy Airtime' : 'Buy Data',
                      style: const TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 22,
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
                Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: PayFlexColors.iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _buildSegmentTab(
                        0,
                        'Airtime',
                        Icons.phone_android_rounded,
                      ),
                      _buildSegmentTab(1, 'Data', Icons.wifi_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Select Provider',
                  style: TextStyle(
                    color: PayFlexColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _isLoadingProviders
                    ? const SizedBox(
                        height: 52,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: PayFlexColors.primary,
                          ),
                        ),
                      )
                    : _buildOperatorsList(),
                const SizedBox(height: 20),
                const Text(
                  'Phone Number',
                  style: TextStyle(
                    color: PayFlexColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: '08012345678',
                    hintStyle: const TextStyle(
                      color: PayFlexColors.textMuted,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: PayFlexColors.surface,
                    prefixIcon: const Icon(
                      Icons.phone_rounded,
                      color: PayFlexColors.textSecondary,
                      size: 20,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
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
                  validator: (val) {
                    if (val == null || val.length < 11) {
                      return 'Enter a valid 11-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                if (_selectedTab == 0) ...[
                  const Text(
                    'Amount',
                    style: TextStyle(
                      color: PayFlexColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₦ ',
                      prefixStyle: const TextStyle(
                        color: PayFlexColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      hintText: '50 - 50,000',
                      hintStyle: const TextStyle(
                        color: PayFlexColors.textMuted,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: PayFlexColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: PayFlexColors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: PayFlexColors.border,
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
                    validator: (val) {
                      if (val == null ||
                          val.isEmpty ||
                          (int.tryParse(val) ?? 0) < 50) {
                        return 'Minimum amount is ₦50';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAmounts.map((amt) {
                      final isSelected =
                          _amountController.text == amt.toString();
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _amountController.text = amt.toString();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? PayFlexColors.primary
                                : PayFlexColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? PayFlexColors.primary
                                  : PayFlexColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            '₦$amt',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : PayFlexColors.primaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  const Text(
                    'Select Data Plan',
                    style: TextStyle(
                      color: PayFlexColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isLoadingPlans
                      ? const SizedBox(
                          height: 52,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: PayFlexColors.primary,
                            ),
                          ),
                        )
                      : DropdownButtonFormField<Map<String, dynamic>>(
                          value: _dataPlans.contains(_selectedDataPlan)
                              ? _selectedDataPlan
                              : null,
                          dropdownColor: PayFlexColors.surface,
                          isExpanded: true,
                          style: const TextStyle(
                            color: PayFlexColors.textPrimary,
                            fontSize: 14,
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: PayFlexColors.textMuted,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Choose a package',
                            hintStyle: const TextStyle(
                              color: PayFlexColors.textMuted,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: PayFlexColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: PayFlexColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: PayFlexColors.border,
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
                          items: _dataPlans.map((plan) {
                            final mapPlan = plan as Map<String, dynamic>;
                            final name =
                                mapPlan['name'] ??
                                mapPlan['plan'] ??
                                mapPlan['data_amount'] ??
                                'Plan';
                            final price =
                                mapPlan['price'] ??
                                mapPlan['amount'] ??
                                mapPlan['cost'] ??
                                '';
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: mapPlan,
                              child: Text(
                                price.toString().isNotEmpty
                                    ? '$name - ₦$price'
                                    : '$name',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedDataPlan = val);
                          },
                          validator: (val) {
                            if (val == null && _selectedTab == 1) {
                              return 'Please select a data plan';
                            }
                            return null;
                          },
                        ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handlePurchase,
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
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _selectedTab == 0
                                ? 'Pay Airtime'
                                : 'Buy Data Bundle',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentTab(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
            if (_selectedTab == 1 && _dataPlans.isEmpty) {
              _fetchDataPlans();
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? PayFlexColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : PayFlexColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : PayFlexColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorsList() {
    if (_operators.isEmpty) {
      return const Text(
        'No providers available',
        style: TextStyle(color: PayFlexColors.textSecondary),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _operators.map((op) {
          final mapOp = op as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: _buildOperatorChip(mapOp),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOperatorChip(Map<String, dynamic> op) {
    final name = (op['name'] ?? op['provider'] ?? op['service'] ?? 'Provider')
        .toString();

    final isSelected =
        (_selectedOperator?['id'] != null &&
            _selectedOperator?['id'] == op['id']) ||
        (_selectedOperator?['code'] != null &&
            _selectedOperator?['code'] == op['code']) ||
        (_selectedOperator?['name'] == op['name']);

    final theme = _getOperatorTheme(name);
    final Color brandBg = theme['color'] as Color;
    final Color textColor = theme['textColor'] as Color;
    final String? logoAsset = theme['asset'] as String?;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedOperator = op);
        _fetchDataPlans();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 76,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? brandBg.withOpacity(0.12) : PayFlexColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandBg : PayFlexColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: brandBg, shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: logoAsset != null
                  ? Image.asset(
                      logoAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          name.isNotEmpty
                              ? name.substring(0, 1).toUpperCase()
                              : 'P',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        name.isNotEmpty
                            ? name.substring(0, 1).toUpperCase()
                            : 'P',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected
                    ? PayFlexColors.textPrimary
                    : PayFlexColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
