import 'dart:convert';
import 'package:http/http.dart' as _apiClient;
import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';
import 'package:payflex/network/custom_exception.dart';

class WalletService {
  final ApiClient apiClient = ApiClient();

  /// Fetches the user's wallet details including balance, currency, and virtual account info.
  Future<Object> getWalletBalance(String token) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.walletBalance}',
    );

    print('Calling Wallet API: $uri');

    final response = await _apiClient.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    } else if (response.body != null && response.body.isNotEmpty) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    return {};
  }

  /// Handles wallet funding API call
  Future<Object> fundWallet({
    required String token,
    required double amount,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.addFunds}');
    // print('Calling API Endpoint: $uri');

    final response = await _apiClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}),
    );

    if (response is _apiClient.Response) {
      print('Response Status Code: ${response.statusCode}');
      print(
        'Response Body Preview: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        return {};
      } else {
        throw AppException(
          'Server returned error (${response.statusCode}). Check endpoint path.',
        );
      }
      // ignore: dead_code
    } else if (response is Map<String, dynamic>) {
      return response;
    }
  }

  /// Generates a virtual account for the user's wallet
  Future<Object> generateVirtualAccount(String token) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.generateVirtualAccount}',
    );

    print('Calling Generate Account API: $uri');

    final response = await _apiClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    } else if (response.body != null && response.body.isNotEmpty) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    return {};
  }

  Future<dynamic> getWallets(dynamic token) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.fetchWallets}',
    );
    final response = await _apiClient.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    } else if (response.body != null && response.body.isNotEmpty) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {};
  }
}
