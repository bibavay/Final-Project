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
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,color: Color.fromARGB(255, 0, 0, 0)),
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              hexStringToColor("FFFFFE"),
              hexStringToColor("FFFFFE"),
              hexStringToColor("FFFFFE")
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
                TextFormField(
  controller: _emailTextController,
  keyboardType: TextInputType.emailAddress,
  decoration: InputDecoration(
    labelText: 'Email',
    hintText: 'Enter your email address',
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    prefixIcon: Icon(Icons.person_outlined),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.blue, width: 2),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
  ),
  validator: (value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
      return 'Please enter a valid email';
    }
    return null;
  },
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
