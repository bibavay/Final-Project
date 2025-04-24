import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:transportaion_and_delivery/firebase_options.dart';
import 'package:transportaion_and_delivery/screens/splashScreen.dart';
import 'screens/authenticaion/signin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force specific orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
      builder: (context, child) {
        // Add this to handle text scaling
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.0,
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 5, 133, 114)
        ),
        useMaterial3: true,
        // Add responsive text themes
        textTheme: Typography.material2018().black.copyWith(
          bodyLarge: const TextStyle(fontSize: 16),
          bodyMedium: const TextStyle(fontSize: 14),
          titleLarge: const TextStyle(fontSize: 20),
          titleMedium: const TextStyle(fontSize: 18),
        ),
        // Add responsive padding
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ResponsiveWrapper(
        child: SplashScreen(),
      ),
      routes: {
        '/signin': (context) => const ResponsiveWrapper(
          child: SigninScreen(),
        ),
        // ...other routes...
      },
    );
  }
}

// Add this ResponsiveWrapper widget
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;

  const ResponsiveWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final Size screenSize = MediaQuery.of(context).size;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate text scale factor based on screen width
        final textScale = screenSize.width / 375; // 375 is base width (iPhone X)
        
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: textScale.clamp(0.8, 1.2), // Limit scaling
          ),
          child: child,
        );
      },
    );
  }
}