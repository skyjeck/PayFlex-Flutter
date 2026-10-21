import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';

class AirtimeService {
  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      ApiClient.logoutUser();
      throw Exception('Session expired. Please log in again.');
    }
  }

  // Fetch Airtime Providers
  Future<List<dynamic>> getAirtimeProviders(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.airtimeProviders}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    _checkUnauthorized(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['providers'] ?? data['data'] ?? [];
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to load providers',
      );
    }
  }

  // Fetch Data Plans for selected provider
  Future<List<dynamic>> getDataPlans(String token, String providerId) async {
    final url =
        '${ApiConstants.baseUrl}${ApiConstants.dataPlans}?provider=$providerId';
    print('📡 Fetching data plans from: $url');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('📩 Data Plans Status Code: ${response.statusCode}');
    print('📩 Data Plans Response Body: ${response.body}');
    _checkUnauthorized(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Try multiple possible response shapes from the backend
      final plans = data['plans'] ?? data['data'] ?? data['dataPlans'] ?? [];
      print('📦 Parsed plans (${plans.length} items): $plans');
      return plans is List ? plans : [];
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to load data plans',
      );
    }
  }

  // Purchase Airtime
  Future<Map<String, dynamic>> buyAirtime({
    required String token,
    required String phoneNumber,
    required double amount,
    required String operatorCode,
    required String pin,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.buyAirtime}');

    final payload = {
      'provider':
          operatorCode, // Backend expects "provider" (e.g. "mtn", "airtel")
      'phone': phoneNumber, // Backend expects "phone"
      'amount': amount,
      'pin': pin,
    };

    print('📡 Sending Buy Airtime Request to: $url');
    print('📦 Payload: $payload');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      print('📩 Buy Airtime Status Code: ${response.statusCode}');
      print('📩 Buy Airtime Response Body: ${response.body}');
      _checkUnauthorized(response);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Airtime purchase failed.');
      }
    } catch (e) {
      print('❌ Buy Airtime Error: $e');
      rethrow;
    }
  }

  // Purchase Data Bundle
  Future<Map<String, dynamic>> buyData({
    required String token,
    required String phoneNumber,
    required String planId,
    required String operatorCode,
    required String pin,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.buyData}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'phone': phoneNumber,
        'planId': planId,
        'operator': operatorCode,
        'pin': pin,
      }),
    );

    _checkUnauthorized(response);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Data purchase failed.');
    }
  }
}
