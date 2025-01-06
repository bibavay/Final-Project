import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/reusabile_widget/reusabile_widget.dart';
import 'package:flutter_application_4th_year_project/utils/color_utils.dart';

class ResetPassword extends StatefulWidget {
  const ResetPassword({super.key});

  @override
  _ResetPasswordState createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final TextEditingController _emailTextController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "reset password",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,color: Colors.white),
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              hexStringToColor("CB2B93"),
              hexStringToColor("9546C4"),
              hexStringToColor("5E61F4")
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 0),
            child: Column(
              children: <Widget>[
                
                const SizedBox(height: 20),
                reusableTextField(
                  "Enter Email Id",
                  Icons.person_outlined,
                  false,
                  _emailTextController,
                ),
                
                firebaseButton(context, "reset password", (){
                  FirebaseAuth.instance.sendPasswordResetEmail(
                    email: _emailTextController.text).then((value) => Navigator.of(context).pop());
                })                
              ],
            ),
          ),
        ),
      ),
    );
  }
}
