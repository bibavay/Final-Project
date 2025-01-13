import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/DriverDashboard.dart';

class DEmailverify extends StatefulWidget {
  const DEmailverify({super.key});

  @override
  State<DEmailverify> createState() => _DEmailverifyState();
}

class _DEmailverifyState extends State<DEmailverify> {
  Timer? _emailCheckTimer;

  @override
  void initState() {
    super.initState();
    _startEmailVerificationCheck();
  }

  @override
  void dispose() {
    _emailCheckTimer?.cancel();
    super.dispose();
  }

  void _startEmailVerificationCheck() {
    _emailCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (user != null && user.emailVerified) {
        timer.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DriverDashboard(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Email Verification"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text("Please verify your email"),
            Text("A verification link has been sent to your email"),
            Text("Please click on the link to verify your email"),
          ],
        ),
      ),
    );
  }
}