// lib/api_call/transaction_service.dart

import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';
import 'package:payflex/network/custom_exception.dart';

class TransactionService {
  final ApiClient _apiClient;

  TransactionService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetch unified user transaction history from the backend
  Future<dynamic> getTransactions({
    int limit = 20,
    int page = 1,
    String? module,
    String? token,
  }) async {
    // Construct query parameters matching backend Expectations
    final Map<String, String> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (module != null && module.isNotEmpty) {
      queryParams['module'] = module;
    }

    final queryString = Uri(queryParameters: queryParams).query;
    final endpoint = '${ApiConstants.transactionHistory}?$queryString';

    final response = await _apiClient.get(endpoint, token: token);

    if (response is Map<String, dynamic> && response['success'] == true) {
      return response;
    }

    throw FetchDataException(
      response is Map<String, dynamic>
          ? response['message'] ?? 'Failed to load transaction history.'
          : 'Unexpected response format from server.',
    );
  }

  /// Fetch single transaction details by ID
  Future<dynamic> getTransactionDetails({
    required String transactionId,
    String? token,
  }) async {
    final endpoint = '${ApiConstants.transactionHistory}/$transactionId';

    final response = await _apiClient.get(endpoint, token: token);

    if (response is Map<String, dynamic> && response['success'] == true) {
      return response;
    }

    throw FetchDataException(
      response is Map<String, dynamic>
          ? response['message'] ?? 'Failed to retrieve transaction details.'
          : 'Unexpected response format from server.',
    );
  }
}
