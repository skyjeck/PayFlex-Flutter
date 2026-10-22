import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';

class BettingService {
  final ApiClient _apiClient;

  BettingService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetch list of betting providers
  Future<List<Map<String, dynamic>>> getBettingProviders(String token) async {
    final response = await _apiClient.get(
      ApiConstants.bettingProviders,
      token: token,
    );

    final rawList = response['data'] ?? response['providers'] ?? response;
    if (rawList is List) {
      return List<Map<String, dynamic>>.from(rawList);
    }
    return [];
  }

  /// Verify Customer Betting Account ID
  Future<Map<String, dynamic>> verifyBettingAccount({
    required String token,
    required String provider,
    required String customerId,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.verifyBettingCustomer,
      token: token,
      body: {
        'provider': provider.toLowerCase().trim(),
        'customerId': customerId.trim(),
      },
    );

    return Map<String, dynamic>.from(response);
  }

  /// Fund Betting Account
  Future<Map<String, dynamic>> fundBettingAccount({
    required String token,
    required String provider,
    required String customerId,
    required double amount,
    required String phone,
    required String pin,
  }) async {
    final payload = {
      'provider': provider.toLowerCase().trim(),
      'customerId': customerId.trim(),
      'amount': amount,
      'phone': phone.trim().isNotEmpty ? phone.trim() : '08000000000',
      'pin': pin,
    };

    final response = await _apiClient.post(
      ApiConstants.fundBettingWallet,
      token: token,
      body: payload,
    );

    return Map<String, dynamic>.from(response);
  }
}
