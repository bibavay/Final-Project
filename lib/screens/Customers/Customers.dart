import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/CActive.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/CHistory.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/NewDelivery.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/NewTrip.dart';
import 'package:flutter_application_4th_year_project/screens/authenticaion/signin_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Dashboard"),
        automaticallyImplyLeading: false,
      ),
      body:  Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const Newtrip()));
              },
              child: const Text("New Trip"),
            ),
            SizedBox(height: 20,),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const Newdelivery()));
              },
              child: const Text("New Delivery"),
            ),
            SizedBox(height: 20,),

             ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const History()));
              },
              child: const Text("History"),
            ),
            SizedBox(height: 20,),

             ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CActive()));
              },
              child: const Text("Active"),
            ),
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