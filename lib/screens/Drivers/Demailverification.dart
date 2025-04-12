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
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;
  Timer? resendTimer;
  int timeLeft = 60;

  @override
  void initState() {
    super.initState();
    verifyEmail();
    _startEmailVerificationCheck();
  }

  @override
  void dispose() {
    timer?.cancel();
    resendTimer?.cancel();
    super.dispose();
  }

  void _startEmailVerificationCheck() {
    timer = Timer.periodic(Duration(seconds: 3), (timer) async {
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

  void _startResendTimer() {
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (timeLeft > 0) {
            timeLeft--;
          } else {
            canResendEmail = true;
            resendTimer?.cancel();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 100,
              color:Color.fromARGB(255, 3, 76, 83),
            ),
            const SizedBox(height: 30),
            const Text(
              'Verify your email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:Color.fromARGB(255, 3, 76, 83),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'We have sent a verification link to ${FirebaseAuth.instance.currentUser?.email}',
                
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16,color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            _buildResendButton(),
            const SizedBox(height: 16),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pop(); // Return to previous screen
                }
              },
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Waiting for verification...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> verifyEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.sendEmailVerification();
      setState(() {
        canResendEmail = false;
        timeLeft = 60;
      });
      _startResendTimer();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Widget _buildResendButton() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: canResendEmail ? verifyEmail : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: canResendEmail ? Color.fromARGB(255, 3, 76, 83) : Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            canResendEmail 
                ? 'Resend Verification Email' 
                : 'Wait ${timeLeft}s to resend',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        if (!canResendEmail)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: LinearProgressIndicator(
              value: timeLeft / 60,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 3, 76, 83)),
            ),
          ),
      ],
    );
  }
}