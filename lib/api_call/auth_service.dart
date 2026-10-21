import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  /// Helper to safely process all API responses into Map<String, dynamic>
  Map<String, dynamic> _parseResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    } else if (response is Map) {
      return Map<String, dynamic>.from(response);
    } else if (response is String && response.isNotEmpty) {
      try {
        final decoded = jsonDecode(response);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'message': response};
      } catch (_) {
        return {'message': response};
      }
    }
    return {'data': response};
  }

  /// Handles user registration API call
  Future<Map<String, dynamic>> registerUser({
    required String firstName,
    required String lastName,
    String? otherName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.register,
      body: {
        'firstName': firstName,
        'lastName': lastName,
        if (otherName != null && otherName.isNotEmpty) 'otherName': otherName,
        'email': email,
        'phone': phoneNumber,
        'password': password,
      },
      data: {},
    );
    return _parseResponse(response);
  }

  /// Handles OTP / Email Verification API call
  Future<Map<String, dynamic>> verifyEmail({
    required String userId,
    required String otp,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.verifyEmail,
      body: {'userId': userId, 'otp': otp},
      data: {},
    );
    return _parseResponse(response);
  }

  /// Handles Resending Verification OTP
  Future<Map<String, dynamic>> resendVerificationOtp({
    required String email,
    required String userId,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.resendOtp,
      body: {'userId': userId, 'email': email},
      data: {},
    );
    return _parseResponse(response);
  }

  /// Handles login API call
  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.login,
      body: {'email': email, 'password': password},
      data: {},
    );
    return _parseResponse(response);
  }

  /// Handles setting up transaction PIN
  Future<Map<String, dynamic>> setTransactionPin({
    required String pin,
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.setTransactionPin,
      token: token,
      body: {'pin': pin},
      data: {},
    );
    return _parseResponse(response);
  }

  /// Fetches authenticated user profile
  Future<Map<String, dynamic>> getUserProfile({required String token}) async {
    final response = await _apiClient.get(
      ApiConstants.fetchUserProfile,
      token: token,
      headers: {},
    );
    return _parseResponse(response);
  }

  /// Updates or edits the user profile (with optional profile photo upload)
  Future<Map<String, dynamic>> updateUserProfile({
    required Map<String, dynamic> data,
    required String token,
    File? imageFile,
  }) async {
    try {
      if (imageFile != null) {
        return await submitMultipartRequest(
          endpoint: ApiConstants.updateUserProfile,
          method: 'PUT',
          token: token,
          fields: data.map((key, value) => MapEntry(key, value.toString())),
          fileKey: 'avatar', // Field key expected by your backend file parser
          file: imageFile,
        );
      }

      final response = await _apiClient.put(
        ApiConstants.updateUserProfile,
        token: token,
        body: data,
      );
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to communicate with server: $e',
      };
    }
  }

  /// Handles Tier 1 / Tier 2 text-based KYC verification or passes payload directly
  Future<Map<String, dynamic>> submitKycVerification({
    required Map<String, dynamic> data,
    String? token,
    File? documentFile,
    required Map<String, String> fields,
  }) async {
    try {
      // 1. If an image document is attached (Tier 3), use Multipart Upload
      if (documentFile != null) {
        final uri = Uri.parse(ApiConstants.verifyKyc);
        final request = http.MultipartRequest('POST', uri);

        // Attach Authorization Header if token exists
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        // Convert dynamic values in 'data' map to String for multipart fields
        data.forEach((key, value) {
          if (value != null) {
            request.fields[key] = value.toString();
          }
        });

        // Attach Image File
        request.files.add(
          await http.MultipartFile.fromPath(
            'documentImage', // Must match the field name expected by Multer in Express (e.g., upload.single('documentImage'))
            documentFile.path,
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        // Parse JSON response string
        return jsonDecode(response.body);
      }

      // 2. Default JSON Post for Tier 2 (BVN/NIN standard text fields)
      final response = await _apiClient.post(
        ApiConstants.verifyKyc,
        token: token,
        data: data,
        body: data,
      );

      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to process verification request: $e',
      };
    }
  }

  /// Handles Tier 3 KYC verification with document image upload via Multipart Request
  Future<Map<String, dynamic>> submitTier3KycVerification({
    required Map<String, String> fields,
    required File documentImage,
    required String token,
    String fileFieldKey = 'document',
  }) async {
    return await submitMultipartRequest(
      endpoint: ApiConstants.verifyKyc,
      method: 'POST',
      token: token,
      fields: fields,
      fileKey: fileFieldKey,
      file: documentImage,
    );
  }

  /// Generic Multipart Utility Method for HTTP File Uploads
  Future<Map<String, dynamic>> submitMultipartRequest({
    required String endpoint,
    required String method,
    required String token,
    required Map<String, String> fields,
    required String fileKey,
    required File file,
  }) async {
    try {
      final uri = Uri.parse(
        endpoint.startsWith('http')
            ? endpoint
            : '${ApiConstants.baseUrl}$endpoint',
      );

      final request = http.MultipartRequest(method, uri);

      // Set Authentication & Headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Attach text form fields
      request.fields.addAll(fields);

      // Attach file stream
      final stream = http.ByteStream(file.openRead());
      final length = await file.length();
      final filename = file.path.split('/').last;

      final multipartFile = http.MultipartFile(
        fileKey,
        stream,
        length,
        filename: filename,
      );

      request.files.add(multipartFile);

      // Send request and resolve stream
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _parseResponse(response.body);
    } catch (e) {
      return {'success': false, 'message': 'File upload failed: $e'};
    }
  }
}
