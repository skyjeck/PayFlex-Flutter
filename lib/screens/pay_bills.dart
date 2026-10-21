// lib/screens/pay_bills_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflex/core/utils/currency_formatter.dart';

import 'package:payflex/api_call/cable_service.dart';
import 'package:payflex/api_call/electricity_service.dart';
import 'package:payflex/api_call/betting_service.dart'; // Import Betting Service
import 'package:payflex/widget/pin_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:payflex/core/theme.dart';

class PayBillsScreen extends StatefulWidget {
  const PayBillsScreen({super.key});

  @override
  State<PayBillsScreen> createState() => _PayBillsScreenState();
}

class _PayBillsScreenState extends State<PayBillsScreen> {
  final _formKey = GlobalKey<FormState>();

  final ElectricityService _electricityService = ElectricityService();
  final CableService _cableService = CableService();
  final BettingService _bettingService =
      BettingService(); // Instantiate Betting Service

  String _selectedCategory = 'Electricity';
  String _selectedMeterType = 'prepaid';

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  List<dynamic> _dynamicProviders = [];
  List<dynamic> _dynamicPackages = [];
  bool _isLoadingProviders = false;
  bool _isLoadingPackages = false;
  bool _isSubmittingPayment = false;

  String? _selectedProviderCode;
  dynamic _selectedPackage;
  bool _isResolvingAccount = false;
  String? _resolvedAccountName;

  final List<Map<String, dynamic>> _categories = [
    {'title': 'Electricity', 'icon': Icons.bolt_rounded},
    {'title': 'Cable TV', 'icon': Icons.tv_rounded},
    {'title': 'Betting', 'icon': Icons.sports_esports_rounded},
  ];

  final List<String> _quickAmounts = ['500', '1000', '2000', '5000', '10000'];

  @override
  void initState() {
    super.initState();
    _fetchProviders(_selectedCategory);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? prefs.getString('token') ?? '';
  }

  String _extractProviderCode(dynamic item) {
    if (item is Map) {
      return item['code']?.toString() ??
          item['slug']?.toString() ??
          item['id']?.toString() ??
          item['name']?.toString() ??
          item.toString();
    }
    return item.toString();
  }

  String _extractProviderName(dynamic item) {
    if (item is Map) {
      return item['name']?.toString() ??
          item['title']?.toString() ??
          item['code']?.toString() ??
          item.toString();
    }
    return item.toString();
  }

  String _extractPackageName(dynamic item) {
    if (item is Map) {
      final name =
          item['name'] ??
          item['title'] ??
          item['package_name'] ??
          item['description'];
      final price = item['price'] ?? item['amount'];
      if (name != null && price != null) {
        return '$name - ₦$price';
      }
      return name?.toString() ?? item.toString();
    }
    return item.toString();
  }

  Future<void> _fetchProviders(String category) async {
    setState(() {
      _isLoadingProviders = true;
      _dynamicProviders = [];
      _selectedProviderCode = null;
      _dynamicPackages = [];
      _selectedPackage = null;
      _resolvedAccountName = null;
    });

    try {
      final token = await _getToken();
      List<dynamic> providers = [];

      switch (category) {
        case 'Electricity':
          providers = await _electricityService.getElectricityProviders(token);
          break;
        case 'Cable TV':
          providers = await _cableService.getCableProviders(token);
          break;
        case 'Betting':
          providers = await _bettingService.getBettingProviders(token);
          break;
        default:
          providers = [];
      }

      setState(() {
        _dynamicProviders = providers;
      });
    } catch (e) {
      debugPrint('Error fetching providers: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProviders = false);
    }
  }

  Future<void> _fetchPackages(String providerCode) async {
    if (_selectedCategory != 'Cable TV') return;

    setState(() {
      _isLoadingPackages = true;
      _dynamicPackages = [];
      _selectedPackage = null;
    });

    try {
      final token = await _getToken();
      final packages = await _cableService.getCablePackages(
        token,
        providerCode,
      );

      setState(() {
        _dynamicPackages = packages is List ? packages : [];
      });
    } catch (e) {
      debugPrint('Error fetching packages: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPackages = false);
    }
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      _identifierController.clear();
      _amountController.clear();
      _phoneController.clear();
      _resolvedAccountName = null;
      _selectedPackage = null;
      _dynamicPackages = [];
    });
    _fetchProviders(category);
  }

  void _onIdentifierChanged(String val) {
    if (_resolvedAccountName != null) {
      setState(() => _resolvedAccountName = null);
    }

    if (val.trim().length >= 5 &&
        _selectedProviderCode != null &&
        !_isResolvingAccount) {
      _verifyCustomerAccount();
    }
  }

  Future<void> _verifyCustomerAccount() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty || _selectedProviderCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a provider and enter account identifier.',
          ),
          backgroundColor: PayFlexColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isResolvingAccount = true;
      _resolvedAccountName = null;
    });

    try {
      final token = await _getToken();
      Map<String, dynamic> result = {};

      if (_selectedCategory == 'Electricity') {
        result = await _electricityService.verifyMeter(
          token: token,
          provider: _selectedProviderCode!,
          meterNumber: identifier,
          type: _selectedMeterType,
        );
      } else if (_selectedCategory == 'Cable TV') {
        result = await _cableService.verifySmartcard(
          token: token,
          provider: _selectedProviderCode!,
          smartcardNumber: identifier,
        );
      } else if (_selectedCategory == 'Betting') {
        result = await _bettingService.verifyBettingAccount(
          token: token,
          provider: _selectedProviderCode!,
          customerId: identifier,
        );
      }

      if (result['success'] == false) {
        final errorMsg =
            result['message'] ??
            'Account verification failed. Please check your account details.';
        setState(() {
          _isResolvingAccount = false;
          _resolvedAccountName = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: PayFlexColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final name =
          result['customerName'] ??
          result['data']?['customerName'] ??
          result['name'] ??
          result['customer_Name'] ??
          result['data']?['customer_name'] ??
          result['data']?['name'];

      setState(() {
        _isResolvingAccount = false;
        _resolvedAccountName = name ?? 'Verified Customer';
      });
    } catch (e) {
      setState(() {
        _isResolvingAccount = false;
        _resolvedAccountName = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: PayFlexColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handlePayBill() {
    if (!_formKey.currentState!.validate()) return;

    if (_resolvedAccountName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify the account identifier first.'),
          backgroundColor: PayFlexColors.error,
        ),
      );
      return;
    }

    _showPinModal();
  }

  void _showPinModal() {
    final recipientName = _resolvedAccountName ?? "Account";
    final subtitle = 'Confirm ₦${_amountController.text} payment for $recipientName';

    // We await the modal so that when onConfirm throws (on error) the pin modal
    // stays open showing the error state, and when it succeeds the modal closes
    // itself first — then we show the success screen cleanly.
    TransactionPinModal.show(
      context: context,
      title: 'Enter Transaction PIN',
      subtitle: subtitle,
      confirmButtonText: 'Confirm & Pay',
      onConfirm: (pin) async {
        // _processPayment returns the electricity token (or null) on success.
        // On error it rethrows so the pin modal can handle the failure state.
        final result = await _processPayment(pin);
        // Store the result so we can use it after the modal is dismissed.
        _pendingSuccessToken = result;
      },
    ).then((_) {
      // This runs after the PIN modal has been fully dismissed (either via
      // success close or user cancel). Only show success if we have a result.
      if (_pendingSuccessToken != null && mounted) {
        final tokenToShow = _pendingSuccessToken;
        _pendingSuccessToken = null;
        _showSuccessDialog(tokenToShow);
      }
    });
  }

  // Holds the electricity token between PIN modal dismissal and success dialog.
  String? _pendingSuccessToken;

  /// Returns the electricity token (or empty string) on success; rethrows on error.
  Future<String?> _processPayment(String pin) async {
    setState(() => _isSubmittingPayment = true);

    try {
      final token = await _getToken();
      final double amount = double.parse(_amountController.text.trim());
      String? generatedToken;

      if (_selectedCategory == 'Electricity') {
        final result = await _electricityService.payElectricity(
          token: token,
          provider: _selectedProviderCode!,
          meterNumber: _identifierController.text.trim(),
          meterType: _selectedMeterType,
          amount: amount,
          phone: _phoneController.text.trim(),
          pin: pin,
        );
        generatedToken = result['token']?.toString();
      } else if (_selectedCategory == 'Cable TV') {
        String packageCode = '';
        if (_selectedPackage is Map) {
          packageCode =
              (_selectedPackage['variation_code'] ??
                      _selectedPackage['package_code'] ??
                      _selectedPackage['code'] ??
                      _selectedPackage['id'] ??
                      _selectedPackage['packageCode'] ??
                      '')
                  .toString();
        } else if (_selectedPackage != null) {
          packageCode = _selectedPackage.toString();
        }

        final phoneNum = _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : '08000000000';

        if (packageCode.trim().isEmpty) {
          throw Exception(
            'Invalid package selected. Please re-select your cable package.',
          );
        }

        await _cableService.subscribeCable(
          token: token,
          provider: _selectedProviderCode!,
          smartcardNumber: _identifierController.text.trim(),
          packageCode: packageCode,
          amount: amount,
          phone: phoneNum,
          pin: pin,
        );
      } else if (_selectedCategory == 'Betting') {
        final phoneNum = _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : '08000000000';

        await _bettingService.fundBettingAccount(
          token: token,
          provider: _selectedProviderCode!,
          customerId: _identifierController.text.trim(),
          amount: amount,
          phone: phoneNum,
          pin: pin,
        );
      }

      return generatedToken; // success — return token to caller
    } catch (e) {
      // Show error snackbar and rethrow so the PIN modal can reset itself.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: PayFlexColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  void _showSuccessDialog([String? electricityToken]) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: PayFlexColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
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
                    'Payment Successful!',
                    style: TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your $_selectedCategory funding of ₦${_amountController.text} was successful.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: PayFlexColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (electricityToken != null &&
                      electricityToken.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PayFlexColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PayFlexColors.border),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'TOKEN',
                            style: TextStyle(
                              fontSize: 11,
                              color: PayFlexColors.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            electricityToken,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: PayFlexColors.primary,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PayFlexColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Done',
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
        );
      },
    );
  }

  InputDecoration _buildInputDecorationWidget(String hint, IconData icon) {
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

  String _getIdentifierLabel() {
    switch (_selectedCategory) {
      case 'Electricity':
        return 'Meter Number';
      case 'Cable TV':
        return 'Smartcard / IUC Number';
      case 'Betting':
        return 'User / Account ID';
      default:
        return 'Account ID';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PayFlexColors.background,
      appBar: AppBar(
        backgroundColor: PayFlexColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: PayFlexColors.textPrimary,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Pay Bills',
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
                // Category Selector
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category['title'] == _selectedCategory;

                      return GestureDetector(
                        onTap: () => _onCategoryChanged(category['title']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? PayFlexColors.primary
                                : PayFlexColors.iconBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? PayFlexColors.primary
                                  : PayFlexColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                category['icon'],
                                size: 18,
                                color: isSelected
                                    ? Colors.white
                                    : PayFlexColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                category['title'],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : PayFlexColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Service Provider Dropdown
                const Text(
                  'Select Service Provider',
                  style: TextStyle(
                    color: PayFlexColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _isLoadingProviders
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: PayFlexColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedProviderCode,
                        isExpanded: true,
                        dropdownColor: PayFlexColors.surface,
                        style: const TextStyle(
                          color: PayFlexColors.textPrimary,
                          fontSize: 15,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: PayFlexColors.textMuted,
                        ),
                        decoration: _buildInputDecorationWidget(
                          'Choose Provider',
                          Icons.business_rounded,
                        ),
                        items: _dynamicProviders.map((p) {
                          final code = _extractProviderCode(p);
                          final name = _extractProviderName(p);
                          return DropdownMenuItem<String>(
                            value: code,
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedProviderCode = val;
                            _selectedPackage = null;
                            _resolvedAccountName = null;
                          });
                          if (val != null) {
                            _fetchPackages(val);
                            if (_identifierController.text.trim().length >= 5) {
                              _onIdentifierChanged(_identifierController.text);
                            }
                          }
                        },
                        validator: (val) =>
                            val == null ? 'Please select a provider' : null,
                      ),

                const SizedBox(height: 20),

                // Cable TV Packages Dropdown
                if (_selectedCategory == 'Cable TV') ...[
                  const Text(
                    'Cable Package',
                    style: TextStyle(
                      color: PayFlexColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isLoadingPackages
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: PayFlexColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : DropdownButtonFormField<dynamic>(
                          value: _selectedPackage,
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
                          decoration: _buildInputDecorationWidget(
                            _dynamicPackages.isEmpty
                                ? 'No packages found'
                                : 'Select Package',
                            Icons.subscriptions_rounded,
                          ),
                          items: _dynamicPackages.map((pkg) {
                            return DropdownMenuItem<dynamic>(
                              value: pkg,
                              child: Text(
                                _extractPackageName(pkg),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedPackage = val;
                              if (val is Map) {
                                final price =
                                    val['price'] ??
                                    val['variation_amount'] ??
                                    val['amount'];
                                if (price != null) {
                                  _amountController.text = price.toString();
                                }
                              }
                            });
                          },
                          validator: (val) =>
                              _selectedCategory == 'Cable TV' && val == null
                              ? 'Please select a package'
                              : null,
                        ),
                  const SizedBox(height: 20),
                ],

                // Meter Type Dropdown (Prepaid vs Postpaid)
                if (_selectedCategory == 'Electricity') ...[
                  const Text(
                    'Meter Type',
                    style: TextStyle(
                      color: PayFlexColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedMeterType,
                    dropdownColor: PayFlexColors.surface,
                    style: const TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: _buildInputDecorationWidget(
                      'Select Meter Type',
                      Icons.tune_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'prepaid',
                        child: Text('Prepaid'),
                      ),
                      DropdownMenuItem(
                        value: 'postpaid',
                        child: Text('Postpaid'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedMeterType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Meter / Smartcard / Account ID Field
                Text(
                  _getIdentifierLabel(),
                  style: const TextStyle(
                    color: PayFlexColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _identifierController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration:
                      _buildInputDecorationWidget(
                        'Enter ${_getIdentifierLabel()}',
                        Icons.badge_rounded,
                      ).copyWith(
                        suffixIcon: _isResolvingAccount
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: PayFlexColors.primary,
                                  ),
                                ),
                              )
                            : TextButton(
                                onPressed: _verifyCustomerAccount,
                                child: const Text('Verify'),
                              ),
                      ),
                  onChanged: _onIdentifierChanged,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter ${_getIdentifierLabel()}'
                      : null,
                ),

                // Account Name Banner
                if (_resolvedAccountName != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: PayFlexColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: PayFlexColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: PayFlexColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _resolvedAccountName!,
                            style: const TextStyle(
                              color: PayFlexColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Amount Field
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
                    fontSize: 15,
                  ),
                  decoration: _buildInputDecorationWidget(
                    'Enter Amount',
                    Icons.payments_rounded,
                  ).copyWith(prefixText: '₦ '),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    final amt = double.tryParse(val.trim());
                    if (amt == null || amt <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Quick Amount Chips
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickAmounts.length,
                    itemBuilder: (context, index) {
                      final amount = _quickAmounts[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _amountController.text = amount;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: PayFlexColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: PayFlexColors.border),
                          ),
                          child: Text(
                            CurrencyFormatter.formatAmount(amount, symbol: '₦'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PayFlexColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Customer Phone Field (Optional)
                const Text(
                  'Customer Phone (Optional)',
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
                  style: const TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: _buildInputDecorationWidget(
                    'Enter Phone Number',
                    Icons.phone_iphone_rounded,
                  ),
                ),

                const SizedBox(height: 32),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmittingPayment ? null : _handlePayBill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PayFlexColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmittingPayment
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : Text(
                            _selectedCategory == 'Betting'
                                ? 'Fund Wallet'
                                : 'Pay Bill',
                            style: const TextStyle(
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
}
