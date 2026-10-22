import 'dart:developer' as developer;
import 'package:payflex/core/api_client.dart';
import 'package:payflex/core/api_constant.dart';
import 'package:payflex/core/enums/transfer_type.dart';

class SendMoneyService {
  final ApiClient _apiClient;

  SendMoneyService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Resolve bank account details (verify recipient name)
  /// For internal transfers, omit bankCode so the backend uses PayFlex's own lookup.
  Future<dynamic> verifyAccount({
    required String accountNumber,
    String? bankCode,
    bool isInternal = false,
  }) async {
    final body = <String, dynamic>{'accountNumber': accountNumber};
    if (isInternal) {
      body['transferType'] = 'INTERNAL';
    } else {
      body['transferType'] = 'EXTERNAL';
      if (bankCode != null && bankCode.isNotEmpty) {
        body['bankCode'] = bankCode;
      }
    }
    developer.log('🔍 verifyAccount payload: $body', name: 'SendMoneyService');
    return await _apiClient.post(
      ApiConstants.fetchBankUser,
      body: body,
    );
  }

  /// Get list of supported banks
  Future<dynamic> getBanks() async {
    return await _apiClient.get(ApiConstants.fetchBanks);
  }

  Future<dynamic> getWallets() async {
    return await _apiClient.get(ApiConstants.fetchWallets);
  }

  /// Execute wallet-to-wallet or wallet-to-bank transfer.
  ///
  /// For INTERNAL transfers the backend expects:
  ///   { transferType, recipient (email/phone), amount, pin }
  /// For EXTERNAL transfers the backend expects:
  ///   { transferType, recipient_account, bank_code, amount, pin }
  Future<dynamic> sendMoney({
    required double amount,
    required String recipient,
    required TransferType transferType,
    String? bankCode,
    String? accountName,
    String? narration,
    String? transactionPin,
    String? walletId,
  }) async {
    final isInternal = transferType == TransferType.internal;
    final transferTypeStr = isInternal ? 'INTERNAL' : 'EXTERNAL';

    final body = <String, dynamic>{
      'transferType': transferTypeStr,
      'amount': amount,
      'accountNumber': recipient,
      if (!isInternal) ...{
        if (bankCode != null && bankCode.isNotEmpty) 'bankCode': bankCode,
        if (accountName != null && accountName.isNotEmpty)
          'accountName': accountName,
      },
      if (narration != null) 'narration': narration,
      if (transactionPin != null) 'pin': transactionPin,
      if (walletId != null) 'wallet_id': walletId,
    };

    developer.log('🚀 sendMoney payload: $body', name: 'SendMoneyService');

    return await _apiClient.post(
      ApiConstants.sendMoney,
      body: body,
    );
  }
}
