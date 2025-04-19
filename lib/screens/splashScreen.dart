import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transportaion_and_delivery/screens/Customers/Customers.dart';
import 'package:transportaion_and_delivery/screens/Drivers/Driverdashboard.dart';
import 'package:transportaion_and_delivery/screens/authenticaion/signin_screen.dart';
import 'dart:async';
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
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      // Add timeout to Future.delayed to prevent infinite waiting
      await Future.delayed(const Duration(milliseconds: 2000))
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('Navigation timeout exceeded');
      });
      
      if (!mounted) return;

      final String? role = await _getUserRole(user)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Role fetch timeout exceeded');
      });

      Widget nextScreen;
      
      if (user == null || role == null) {
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
            debugPrint('Unknown role: $role');
            nextScreen = const SigninScreen();
        }
      }

      if (!mounted) return;

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
      
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('Firebase error: ${e.message}');
      debugPrint('Error code: ${e.code}');
      debugPrint('Stack trace: $stackTrace');
      _handleNavigationError();
    } on TimeoutException catch (e) {
      debugPrint('Timeout error: $e');
      _handleNavigationError();
    } catch (e, stackTrace) {
      debugPrint('Navigation error: $e');
      debugPrint('Stack trace: $stackTrace');
      _handleNavigationError();
    }
  }

  void _handleNavigationError() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SigninScreen()),
      );
    }
  }

  Future<String?> _getUserRole(User? user) async {
    if (user == null) {
      debugPrint('getUserRole called with null user');
      return null;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Firestore fetch timeout'),
          );
            
      if (!doc.exists) {
        debugPrint('User document does not exist for uid: ${user.uid}');
        return null;
      }
      
      final data = doc.data();
      if (data == null) {
        debugPrint('Document data is null for user: ${user.uid}');
        return null;
      }
      
      final role = data['role'] as String?;
      if (role == null) {
        debugPrint('Role field is missing for user: ${user.uid}');
        return null;
      }
      
      if (role != 'driver' && role != 'customer') {
        debugPrint('Invalid role value: $role');
        return null;
      }
      
      return role;
      
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('Firestore error: ${e.message}');
      debugPrint('Error code: ${e.code}');
      debugPrint('Stack trace: $stackTrace');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('Timeout while fetching user role: $e');
      return null;
    } catch (e, stackTrace) {
      debugPrint('Unexpected error getting user role: $e');
      debugPrint('Stack trace: $stackTrace');
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