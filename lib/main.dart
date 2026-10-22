import 'package:flutter/material.dart';
import 'package:payflex/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final isVerified = prefs.getBool('isVerified') ?? true;
  final isPinSet = prefs.getBool('isPinSet') ?? false;
  
  String initialRoute = '/onboarding';
  if (token != null) {
    if (!isVerified) {
      initialRoute = '/login';
    } else if (!isPinSet) {
      initialRoute = '/login';
    } else {
      initialRoute = '/dashboard';
    }
  }
  
  runApp(MyApp(initialRoute: initialRoute));
}
