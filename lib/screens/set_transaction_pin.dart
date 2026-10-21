import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/api_call/auth_service.dart';

class SetTransactionPinScreen extends StatefulWidget {
  const SetTransactionPinScreen({super.key});

  @override
  State<SetTransactionPinScreen> createState() =>
      _SetTransactionPinScreenState();
}

class _SetTransactionPinScreenState extends State<SetTransactionPinScreen> {
  final AuthService _authService = AuthService();

  // Step 1: Create PIN, Step 2: Confirm PIN
  bool _isConfirming = false;
  bool _isLoading = false;

  final List<TextEditingController> _pinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  String _firstPin = '';
  String _errorMessage = '';

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onPinChanged(String value, int index) {
    setState(() => _errorMessage = '');

    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _handlePinCompletion();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _clearPinFields() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  String get _currentEnteredPin => _pinControllers.map((c) => c.text).join();

  void _handlePinCompletion() {
    final enteredPin = _currentEnteredPin;

    if (enteredPin.length < 4) return;

    if (!_isConfirming) {
      // Transition to Confirm Step
      setState(() {
        _firstPin = enteredPin;
        _isConfirming = true;
      });
      _clearPinFields();
    } else {
      // Validate Match
      if (enteredPin == _firstPin) {
        _submitPin(enteredPin);
      } else {
        setState(() {
          _errorMessage = 'PINs do not match. Try again.';
        });
        _clearPinFields();
      }
    }
  }

  Future<void> _submitPin(String pin) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Session expired. Please log in again.');
      }

      final response = await _authService.setTransactionPin(
        pin: pin,
        token: token,
      );

      if (!mounted) return;

      final message =
          response['message'] ?? 'Transaction PIN created successfully.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: PayFlexColors.primary,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      final cleanError = e.toString().replaceAll('Exception: ', '');

      setState(() {
        _errorMessage = cleanError;
        _isLoading = false;
      });

      _clearPinFields();
    }
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
            size: 20,
          ),
          onPressed: () {
            if (_isConfirming) {
              setState(() {
                _isConfirming = false;
                _firstPin = '';
                _errorMessage = '';
              });
              _clearPinFields();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isConfirming
                    ? 'Confirm Transaction PIN'
                    : 'Set Transaction PIN',
                style: const TextStyle(
                  color: PayFlexColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Re-enter your 4-digit PIN to confirm.'
                    : 'Create a 4-digit PIN for securing transfer & bill payments.',
                style: const TextStyle(
                  color: PayFlexColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),

              // PIN Field Inputs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  4,
                  (index) => SizedBox(
                    width: 60,
                    height: 64,
                    child: TextFormField(
                      controller: _pinControllers[index],
                      focusNode: _focusNodes[index],
                      autofocus: index == 0,
                      obscureText: true,
                      obscuringCharacter: '•',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(1),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: PayFlexColors.surface,
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _pinControllers[index].text.isNotEmpty
                                ? PayFlexColors.primary
                                : PayFlexColors.border,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: PayFlexColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _onPinChanged(value, index),
                    ),
                  ),
                ),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: PayFlexColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading || _currentEnteredPin.length < 4
                      ? null
                      : _handlePinCompletion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PayFlexColors.primary,
                    disabledBackgroundColor: PayFlexColors.primary.withOpacity(
                      0.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          _isConfirming ? 'Save PIN' : 'Continue',
                          style: const TextStyle(
                            color: Colors.black,
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
      ),
    );
  }
}
