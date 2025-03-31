import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/Customers.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/DriverDashboard.dart';
import 'package:flutter_application_4th_year_project/screens/authenticaion/signin_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Increased duration
    );

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn), // Faster fade in
    ));

    _fadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut), // Later fade out
    ));

    _fadeController.forward();
    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    final User? user = FirebaseAuth.instance.currentUser;

    // Longer delay for logo visibility
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (!mounted) return;

    final String? role = await _getUserRole(user);
    Widget nextScreen;
    
    if (user == null) {
      nextScreen = const SigninScreen();
    } else {
      switch (role) {
        case 'driver':
          nextScreen = const DriverDashboard();
          break;
        case 'customer':
          nextScreen = const CustomerDashboard();
          break;
        default:
          nextScreen = const SigninScreen();
      }
    }

    // Start fade out and navigate
    await _fadeController.forward();
    
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500), // Reduced from 1000
      ),
    );
  }

  Future<String?> _getUserRole(User? user) async {
    if (user == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return doc.data()?['role'] as String?;
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeInAnimation.value * _fadeOutAnimation.value,
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 250,
                height: 250,
                
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            
            ],
          ),
        ),
      ),
    );
  }
}