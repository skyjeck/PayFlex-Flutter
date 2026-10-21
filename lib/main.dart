import 'package:flutter/material.dart';
import 'package:payflex/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final isVerified = prefs.getBool('isVerified') ?? true;
  
  String initialRoute = '/onboarding';
  if (token != null) {
    initialRoute = isVerified ? '/dashboard' : '/login';
  }
  
  runApp(MyApp(initialRoute: initialRoute));
}
