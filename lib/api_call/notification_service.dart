import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';

class NotificationService {
  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      ApiClient.logoutUser();
      throw Exception('Session expired. Please log in again.');
    }
  }

  // Fetch User Notifications
  Future<Map<String, dynamic>> getNotifications({
    required String token,
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final queryParams = '?page=$page&limit=$limit&unreadOnly=$unreadOnly';
    final url =
        '${ApiConstants.baseUrl}${ApiConstants.getAllNotification}$queryParams';

    print('📡 Fetching notifications from: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📩 Notifications Status Code: ${response.statusCode}');
      _checkUnauthorized(response);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'] ?? {};
      } else {
        throw Exception(data['message'] ?? 'Failed to load notifications');
      }
    } catch (e) {
      print('❌ Get Notifications Error: $e');
      rethrow;
    }
  }

  // Mark a single notification as read
  Future<Map<String, dynamic>> markAsRead({
    required String token,
    required String notificationId,
  }) async {
    final url =
        '${ApiConstants.baseUrl}${ApiConstants.getAllNotification}/$notificationId/read';

    print('📡 Marking notification $notificationId as read: $url');

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📩 Mark As Read Status Code: ${response.statusCode}');
      _checkUnauthorized(response);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(
          data['message'] ?? 'Failed to mark notification as read',
        );
      }
    } catch (e) {
      print('❌ Mark As Read Error: $e');
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<Map<String, dynamic>> markAllAsRead({required String token}) async {
    final url =
        '${ApiConstants.baseUrl}${ApiConstants.getAllNotification}/read-all';

    print('📡 Marking all notifications as read: $url');

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📩 Mark All As Read Status Code: ${response.statusCode}');
      _checkUnauthorized(response);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(
          data['message'] ?? 'Failed to mark all notifications as read',
        );
      }
    } catch (e) {
      print('❌ Mark All As Read Error: $e');
      rethrow;
    }
  }
}
