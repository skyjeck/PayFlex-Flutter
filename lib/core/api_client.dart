import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:payflex/core/api_constant.dart';
import 'package:payflex/network/custom_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:payflex/app.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  // Retrieve token automatically from SharedPreferences if not provided explicitly
  Future<Map<String, String>> _getHeaders([String? token]) async {
    String? authToken = token;

    if (authToken == null || authToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      authToken =
          prefs.getString('token') ??
          prefs.getString('access_token') ??
          prefs.getString('auth_token');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
  }

  // Centralized HTTP Request Handler to eliminate duplicate try-catch blocks
  Future<dynamic> _sendRequest(
    Future<http.Response> Function(Map<String, String> headers) requestAction, {
    String? token,
  }) async {
    try {
      final headers = await _getHeaders(token);
      final response = await requestAction(
        headers,
      ).timeout(const Duration(seconds: 15));

      final method = response.request?.method ?? 'HTTP';
      final url = response.request?.url.toString() ?? '';
      print('📡 [$method] $url');
      print('📩 Status Code: ${response.statusCode}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        print('❌ Error Response Body: ${response.body}');
      }

      return await _processResponse(response);
    } on SocketException {
      print('❌ [HTTP ERROR] No Internet connection');
      throw FetchDataException('No Internet connection');
    } on TimeoutException {
      print('❌ [HTTP ERROR] Connection timed out');
      throw FetchDataException('Connection timed out. Please try again.');
    }
  }

  // GET Request
  Future<dynamic> get(
    String endpoint, {
    String? token,
    Map<String, String>? queryParameters,
    required Map<String, String> headers,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}$endpoint',
    ).replace(queryParameters: queryParameters);
    return _sendRequest(
      (headers) => _client.get(uri, headers: headers),
      token: token,
    );
  }

  // POST Request
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    return _sendRequest(
      (headers) => _client.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      token: token,
    );
  }

  // PUT Request
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    return _sendRequest(
      (headers) => _client.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      token: token,
    );
  }

  // PATCH Request
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    return _sendRequest(
      (headers) => _client.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      token: token,
    );
  }

  // DELETE Request
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    return _sendRequest(
      (headers) => _client.delete(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      token: token,
    );
  }

  // Clear session keys safely and return user to login screen on token expiration
  static Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('access_token');
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');

    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  // Response Processor & Exception Handler
  Future<dynamic> _processResponse(http.Response response) async {
    dynamic responseJson;
    try {
      responseJson = jsonDecode(response.body);
    } catch (_) {
      responseJson = {'message': response.body};
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        return responseJson;
      case 400:
        throw BadRequestException(
          responseJson['message'] ?? 'Invalid request',
          responseJson,
        );
      case 401:
      case 403:
        final path = response.request?.url.path ?? '';
        if (!path.contains('/login') && !path.contains('/register')) {
          await logoutUser();
        }
        throw UnauthorisedException(
          responseJson['message'] ?? 'Token expired or unauthorized access',
          responseJson,
        );
      case 404:
        throw FetchDataException(
          responseJson['message'] ?? 'Requested resource not found',
          responseJson,
        );
      case 500:
      default:
        throw FetchDataException(
          responseJson['message'] ??
              'Server error with status code: ${response.statusCode}',
          responseJson,
        );
    }
  }
}
