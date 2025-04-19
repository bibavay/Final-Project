import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:transportaion_and_delivery/firebase_options.dart';
import 'package:transportaion_and_delivery/screens/splashScreen.dart';
import 'screens/authenticaion/signin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    name: "dev project",
    options: DefaultFirebaseOptions.currentPlatform
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Delivery and transprtation",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 5, 133, 114)
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/signin': (context) => const SigninScreen(), // Update route name to match
        // ...other routes...
      },
    );
  }
}