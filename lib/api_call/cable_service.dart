import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';

class CableService {
  // Common headers builder
  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Safely decode JSON responses to avoid FormatException on HTML error pages
  dynamic _parseResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      ApiClient.logoutUser();
      throw Exception('Session expired. Please log in again.');
    }

    final contentType = response.headers['content-type'] ?? '';

    if (contentType.contains('application/json')) {
      return jsonDecode(response.body);
    }

    // Server returned HTML or plain text (e.g. 404/500 pages)
    throw Exception(
      'Server Error (${response.statusCode}): ${response.reasonPhrase}',
    );
  }

  // 1. Fetch Cable TV Providers
  Future<List<dynamic>> getCableProviders(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.getAllCable}');
    print('📡 Fetching Cable TV providers from: $url');

    final response = await http.get(url, headers: _getHeaders(token));

    print('📩 Cable TV Providers Status Code: ${response.statusCode}');
    print('📩 Cable TV Providers Response Body: ${response.body}');

    final data = _parseResponse(response);

    if (response.statusCode == 200) {
      final providers = data['providers'] ?? data['data'] ?? [];
      return providers is List ? providers : [];
    } else {
      throw Exception(data['message'] ?? 'Failed to load cable providers.');
    }
  }

  // 2. Fetch Cable Packages / Bouquets
  Future<List<dynamic>> getCablePackages(
    String token,
    String providerId,
  ) async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.getCablePackages}',
    );
    print('📡 Fetching Cable Packages from: $url');

    final response = await http.post(
      url,
      headers: _getHeaders(token),
      body: jsonEncode({
        'provider':
            providerId, // or 'provider_id': providerId, depending on your API
      }),
    );

    print('📩 Cable Packages Status Code: ${response.statusCode}');
    print('📩 Cable Packages Response Body: ${response.body}');

    final data = _parseResponse(response);

    if (response.statusCode == 200 &&
        (data['success'] == true || data['status'] == true)) {
      final packages = data['packages'] ?? data['plans'] ?? data['data'] ?? [];
      return packages is List ? packages : [];
    } else {
      throw Exception(data['message'] ?? 'Failed to load cable packages.');
    }
  }

  // 3. Verify Smartcard / IUC Number
  Future<Map<String, dynamic>> verifySmartcard({
    required String token,
    required String provider,
    required String smartcardNumber,
  }) async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.verifySmartCard}',
    );

    final payload = {
      'provider': provider.toLowerCase().trim(),
      'smartcardNumber': smartcardNumber.trim(),
    };

    print('📡 Verifying Smartcard/IUC Number at: $url');
    print('📦 Verification Payload: $payload');

    final response = await http.post(
      url,
      headers: _getHeaders(token),
      body: jsonEncode(payload),
    );

    print('📩 Smartcard Verification Status Code: ${response.statusCode}');
    print('📩 Smartcard Verification Response Body: ${response.body}');

    final data = _parseResponse(response);

    // Return parsed JSON for both 200 and 400 so UI receives data['success'] and data['message']
    if (response.statusCode == 200 || response.statusCode == 400) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(data['message'] ?? 'Smartcard/IUC verification failed.');
    }
  }

  // 4. Pay Cable TV Subscription
  Future<Map<String, dynamic>> subscribeCable({
    required String token,
    required String provider,
    required String smartcardNumber,
    required String packageCode,
    required double amount,
    required String pin,
    String subscriptionType = 'change',
    required String phone,
  }) async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.subscribeCableService}',
    );

    final payload = {
      'provider': provider.toLowerCase().trim(),
      'smartcardNumber': smartcardNumber.trim(),
      'packageCode': packageCode, // Changed key from 'package' to 'packageCode'
      'amount': amount,
      'subscriptionType': subscriptionType,
      'pin': pin,
      'phone': phone.trim().isNotEmpty
          ? phone.trim()
          : '08000000000', // Added phone field
    };

    print('📡 Sending Cable TV Subscription Request to: $url');
    print('📦 Payload: $payload');

    final response = await http.post(
      url,
      headers: _getHeaders(token),
      body: jsonEncode(payload),
    );

    print('📩 Cable Subscription Status Code: ${response.statusCode}');
    print('📩 Cable Subscription Response Body: ${response.body}');

    final data = _parseResponse(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(
        data['message'] ?? 'Cable TV subscription payment failed.',
      );
    }
  }
}
