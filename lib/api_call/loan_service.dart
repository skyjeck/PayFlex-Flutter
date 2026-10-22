import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';
import 'package:payflex/network/custom_exception.dart';

class LoanService {
  final ApiClient _apiClient;

  LoanService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Map<String, dynamic> _handleResponse(
    dynamic response,
    String fallbackErrorMessage,
  ) {
    if (response is Map<String, dynamic>) {
      final isSuccess =
          response['success'] == true || response['status'] == 'success';
      if (isSuccess) {
        return response;
      }
      throw FetchDataException(
        response['message']?.toString() ?? fallbackErrorMessage,
      );
    }
    throw FetchDataException('Unexpected response format from server.');
  }

  /// Submit a new loan application to the backend
  Future<Map<String, dynamic>> applyForLoan({
    required double amount,
    required int tenureMonths,
    required String purpose,
    String? token,
  }) async {
    final body = {
      'amount': amount,
      'tenureMonths': tenureMonths,
      'purpose': purpose,
    };

    final response = await _apiClient.post(
      ApiConstants.applyLoan,
      body: body,
      token: token,
    );

    return _handleResponse(response, 'Failed to apply for loan.');
  }

  /// Fetch active and past loans for the authenticated user
  Future<Map<String, dynamic>> getMyLoans({String? token}) async {
    final response = await _apiClient.get(
      ApiConstants.myLoan,
      token: token,
    );

    return _handleResponse(response, 'Failed to fetch loan history.');
  }

  /// Pay standard scheduled EMI or custom installment amount
  Future<Map<String, dynamic>> repayLoan({
    required String loanId,
    double? customAmount,
    String? token,
  }) async {
    final body = {
      'loanId': loanId,
      if (customAmount != null) 'customAmount': customAmount,
    };

    final response = await _apiClient.post(
      ApiConstants.repayLoan,
      body: body,
      token: token,
    );

    return _handleResponse(response, 'Failed to process repayment.');
  }

  /// Get early settlement quote breakdown and savings estimate
  Future<Map<String, dynamic>> getPayoffQuote({
    required String loanId,
    String? token,
  }) async {
    final endpoint = '${ApiConstants.myLoan}/$loanId/payoff-quote';

    final response = await _apiClient.get(
      endpoint,
      token: token,
    );

    return _handleResponse(response, 'Failed to fetch payoff quote.');
  }

  /// Execute full early settlement with interest discount
  Future<Map<String, dynamic>> settleLoanEarly({
    required String loanId,
    String? token,
  }) async {
    final endpoint = '${ApiConstants.myLoan}/$loanId/settle-early';

    final body = {'loanId': loanId};

    final response = await _apiClient.post(
      endpoint,
      body: body,
      token: token,
    );

    return _handleResponse(response, 'Failed to settle loan early.');
  }
}
