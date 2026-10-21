import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';

class ElectricityService {
  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      ApiClient.logoutUser();
      throw Exception('Session expired. Please log in again.');
    }
  }
  String _normalizeProviderSlug(String provider) {
    final lower = provider.trim().toLowerCase();
    if (lower.contains('ikeja')) return 'ikeja';
    if (lower.contains('eko')) return 'eko';
    if (lower.contains('abuja')) return 'aedc';
    if (lower.contains('ibadan')) return 'ibedc';
    if (lower.contains('enugu')) return 'eedc';
    if (lower.contains('jos')) return 'jedc';
    if (lower.contains('kano')) return 'kedco';
    if (lower.contains('port')) return 'phed';
    if (lower.contains('kaduna')) return 'kaedco';

    return lower.replaceAll(' electric', '').replaceAll(' ', '-');
  }

  // Verify Meter Account / Customer Name
  Future<Map<String, dynamic>> verifyMeter({
    required String token,
    required String provider,
    required String meterNumber,
    String type = 'prepaid',
  }) async {
    final url = '${ApiConstants.baseUrl}${ApiConstants.verifyMeter}';
    final formattedProvider = _normalizeProviderSlug(provider);

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'provider': formattedProvider,
        'meterNumber': meterNumber,
        'customerId': meterNumber, // Sent for backwards compatibility
        'type': type.toLowerCase(),
      }),
    );

    print('📩 Meter Verification Response: ${response.body}');
    _checkUnauthorized(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['data'] ?? body;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to verify meter.');
    }
  }

  // Fetch Electricity Providers / Disco Lists
  Future<List<dynamic>> getElectricityProviders(String token) async {
    final url = '${ApiConstants.baseUrl}${ApiConstants.electricityProviders}';
    print('📡 Fetching electricity providers from: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('📩 Electricity Providers Status Code: ${response.statusCode}');
    print('📩 Electricity Providers Response Body: ${response.body}');
    _checkUnauthorized(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final providers = data['providers'] ?? data['data'] ?? [];
      return providers is List ? providers : [];
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ??
            'Failed to load electricity providers',
      );
    }
  }

  // Pay Electricity Bill (Matching all required keys)
  Future<Map<String, dynamic>> payElectricity({
    required String token,
    required String provider,
    required String meterNumber,
    required double amount,
    required String phone,
    required String pin,
    String meterType = 'prepaid',
  }) async {
    final url = '${ApiConstants.baseUrl}${ApiConstants.subscribeElectricity}';
    final formattedProvider = _normalizeProviderSlug(provider);

    final payload = {
      'provider': formattedProvider,
      'meterNumber': meterNumber,
      'meterType': meterType.toLowerCase(),
      'amount': amount,
      'phone': phone,
      'pin': pin,
    };

    print('📤 Pay Electricity Payload: ${jsonEncode(payload)}');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    print('📩 Pay Electricity Response: ${response.body}');
    _checkUnauthorized(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(
        errorData['message'] ?? 'Failed to process electricity payment.',
      );
    }
  }
}
