// lib/core/constants/api_constants.dart

import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Base URL handler (Handles Android Emulator vs iOS/Web localhost)
  // static String get baseUrl {
  //   if (kIsWeb) return 'http://localhost:4000/api';
  //   if (Platform.isAndroid) return 'http://10.0.2.2:4000/api';
  //   return 'http://localhost:4000/api';
  // }

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:4000/api';
    if (Platform.isAndroid)
      return 'http://10.0.2.2:4000/api'; // Android Emulator

    // Physical iOS / Physical Android / macOS target
    return 'http://192.168.1.138:4000/api';
  }

  // Authentication Endpoints
  static const String register = '/users/register';
  static const String login = '/users/login';
  static const String verifyEmail = '/users/verify-otp';
  static const String verifyKyc = '/users/kyc/submit';
  static const String resendOtp = '/users/resend-otp';
  static const String setTransactionPin = '/users/set-pin';
  static const String fetchUserProfile = '/users/profile';
  static const String updateUserProfile = '/users/update';
  static const String forgotPassword = '/users/forgot-password';
  static const String verifyResetOtp = '/users/verify-reset-otp';
  static const String resetPassword = '/users/reset-password';

  // Wallet & banks Endpoints
  static const String walletBalance = '/wallet/balance';
  static const String addFunds = '/wallet/fund';

  static const String fetchBanks = '/transfers/banks';
  static const String sendMoney = '/transfers/send-money';
  static const String fetchBankUser = '/transfers/bank-lookup';
  static const String transactionHistory = '/history';

  static const String generateVirtualAccount =
      '/wallet/generate-virtual-account';
  static const String fetchWallets = '/wallet/fetch-wallet';
  //Airtime Providers Endpoint
  static const String airtimeProviders = '/services/airtime/providers';
  static const String buyAirtime = '/services/airtime/purchase'; // ✅
  static const String dataPlans = '/services/data/plans'; // ✅
  static const String payBills = '/services/bills';
  static const String buyData = '/services/data/purchase';

  static const String getAllCable = '/services/cables/all';

  //Electricity Providers Endpoint and multi-choice
  // lib/core/constants/api_constants.dart
  static const String electricityProviders = '/services/electricity/all';
  static const String verifyCustomers = '/services/verify-customer';
  static const String verifySmartCard = '/services/cables/verify-smartcard';
  static const String verifyMeter = '/services/verify-meter';
  static const String getCablePackages = '/services/cable/packages';
  static const String subscribeCableService = '/services/cable/purchase';
  static const String subscribeElectricity = '/services/electricity/purchase';
  static const String serviceHistory = '/services/history';

  // Betting Services (New)
  static const String bettingProviders = '/services/betting/providers';
  static const String verifyBettingCustomer = '/services/betting/verify';
  static const String fundBettingWallet = '/services/betting/fund';

  // FX Swap Endpoints
  static const String fxRates = '/swap-fx/rates';
  static const String fxQuote = '/swap-fx/quote';
  static const String fxExecute = '/swap-fx/swap';
  static const String fxHistory = '/swap-fx/history';

  // loans
  static const String applyLoan = '/loan/apply';
  static const String myLoan = '/loan/my-loans';
  static const String repayLoan = '/loan/repay';

  //notifications

  static const String getAllNotification = '/notifications';
}
