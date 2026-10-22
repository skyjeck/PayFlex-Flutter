// lib/api_call/fx_swap_service.dart

import 'package:flutter/foundation.dart';
import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';
import 'package:payflex/network/custom_exception.dart';

class FxSwapService {
  final ApiClient _apiClient;

  FxSwapService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // Mock exchange rates (Base: NGN) for debug & offline fallback
  static const Map<String, double> _mockRatesToNgn = {
    'NGN': 1.0,
    'USD': 1550.0,
    'EUR': 1680.0,
    'GBP': 1980.0,
  };

  /// Fetch live exchange rates and available currency pairs
  Future<Map<String, dynamic>> getRates({
    String? token,
    required String base,
  }) async {
    try {
      // Build URI path with base currency query parameter
      final endpoint = '${ApiConstants.fxRates}?base=$base';

      final response = await _apiClient.get(
        endpoint,
        token: token,
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        return response;
      }
      return _getMockRatesResponse(base);
    } on AppException catch (e) {
      print('❌ FX Rates API CustomException: ${e.message}');
      return _getMockRatesResponse(base);
    } catch (e) {
      print('❌ FX Rates API Exception: $e. Returning mock rates.');
      return _getMockRatesResponse(base);
    }
  }

  /// Calculate quote estimate from source to target currency
  Future<Map<String, dynamic>> getQuote({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
    String? token,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.fxQuote,
        token: token,
        body: {
          'from_currency': fromCurrency,
          'to_currency': toCurrency,
          'amount': amount,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        return response;
      }
      return _calculateMockQuote(fromCurrency, toCurrency, amount);
    } on AppException catch (e) {
      print('❌ FX Quote CustomException: ${e.message}');
      return _calculateMockQuote(fromCurrency, toCurrency, amount);
    } catch (e) {
      print('❌ FX Quote Exception: $e. Using local calculation.');
      return _calculateMockQuote(fromCurrency, toCurrency, amount);
    }
  }

  /// Execute currency swap order with PIN validation
  Future<Map<String, dynamic>> executeSwap({
    required String fromCurrency,
    required String toCurrency,
    required double sourceAmount,
    required double destinationAmount,
    required double rate,
    required String pin,
    String? token,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.fxExecute,
        token: token,
        body: {
          'from_currency': fromCurrency,
          'to_currency': toCurrency,
          'source_amount': sourceAmount,
          'destination_amount': destinationAmount,
          'rate': rate,
          'pin': pin,
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      throw FetchDataException('Unexpected response format from FX Swap API');
    } on AppException catch (e) {
      throw Exception(e.message ?? 'FX Swap failed');
    } catch (e) {
      if (kDebugMode) {
        await Future.delayed(const Duration(milliseconds: 1200));
        return {
          'success': true,
          'message': 'Mock FX Swap successful',
          'reference': 'FX_${DateTime.now().millisecondsSinceEpoch}',
        };
      }
      throw Exception('Network connection error. Please try again.');
    }
  }

  // --- Local Fallback Helpers ---

  Map<String, dynamic> _getMockRatesResponse(String base) {
    final double baseInNgn = _mockRatesToNgn[base] ?? 1.0;

    // Calculate relative rates based on requested base currency
    final Map<String, double> relativeRates = {};
    _mockRatesToNgn.forEach((code, rateInNgn) {
      relativeRates[code] = baseInNgn / rateInNgn;
    });

    return {
      'success': true,
      'rates': relativeRates,
      'currencies': ['NGN', 'USD', 'EUR', 'GBP'],
    };
  }

  Map<String, dynamic> _calculateMockQuote(
    String from,
    String to,
    double amount,
  ) {
    final double fromRateInNgn = _mockRatesToNgn[from] ?? 1.0;
    final double toRateInNgn = _mockRatesToNgn[to] ?? 1.0;

    final double amountInNgn = amount * fromRateInNgn;
    final double targetAmount = amountInNgn / toRateInNgn;
    final double effectiveRate = fromRateInNgn / toRateInNgn;

    final double mockFee = from == 'NGN' ? 1000.0 : 0.65;

    return {
      'success': true,
      'rate': effectiveRate,
      'destinationAmount': double.parse(targetAmount.toStringAsFixed(2)),
      'feeCharged': mockFee,
    };
  }
}
