import 'package:flutter/material.dart';
import 'package:payflex/screens/dashboard.dart';
import 'package:payflex/screens/login.dart';
import 'package:payflex/screens/onboarding.dart';
import 'package:payflex/screens/verify_resetOtp.dart';
import 'package:payflex/screens/reset_password.dart';
import 'package:payflex/screens/set_transaction_pin.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      initialRoute: initialRoute,
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/verify-reset-otp': (context) => const VerifyResetOtpScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/set_transaction_pin': (context) => const SetTransactionPinScreen(),
      },
      // home: const OnboardingScreen(),
    );
  }
}
