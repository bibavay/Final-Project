import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/DActive.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/DHistory.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/results.dart';
import 'package:flutter_application_4th_year_project/screens/authenticaion/signin_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            const SizedBox(height: 20,),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const Results()));
              },
              child: const Text("Results"),
            ),
            const SizedBox(height: 20,),

              ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DHistory()));
              },
              child: const Text("History"),
            ),
            const SizedBox(height: 20,),

              ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const Dactive()));
              },
              child: const Text("Active"),
            ),
            const SizedBox(height: 20,),

            ElevatedButton(
          child: const Text("Logout"),
          onPressed: () {
            FirebaseAuth.instance.signOut().then((Value){
                print("Signed Uot");
                Navigator.push(context,
                MaterialPageRoute(builder: (context) => const SigninScreen()));
            });
            
            },
            )
          ],
        ),
      ),
    );
  }
}