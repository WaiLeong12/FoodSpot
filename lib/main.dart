import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'ForgotPassword.dart';
import 'WelcomePage.dart';
import 'Register.dart';
import 'Login.dart';
import 'FoodMain.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'firebase_options.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(

  );

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  bool _showWelcome = true;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToMainApp(BuildContext context) {
    Navigator.pushNamed(context, '/main');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => WelcomePage(
          onContinue: () => _navigateToMainApp(context),
        ),
        '/signup': (context) => const SignUpPage(),
        '/login': (context) => const LoginPage(),
        '/forgotPassword': (context) => const ResetPasswordPage(),
        '/main': (context) => FoodMain(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      },
    );
  }
}