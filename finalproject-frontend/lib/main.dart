import 'package:flutter/material.dart';

// auth
import 'package:finalproject/screens/LoginScreen.dart';
import 'package:finalproject/screens/RegisterScreen.dart';

// main tabs
import 'package:finalproject/screens/home.dart';
import 'package:finalproject/screens/ListMyTripScreen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',

      routes: {
        '/login'   : (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home'    : (context) => const HomeScreen(),
        '/mytrips' : (context) => ListMyTripScreen(),
      },
    );
  }
}
