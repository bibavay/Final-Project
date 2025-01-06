import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/reusabile_widget/reusabile_widget.dart';
import 'package:flutter_application_4th_year_project/screens/authenticaion/home_screen.dart';
import 'package:flutter_application_4th_year_project/screens/authenticaion/reset_password.dart';
import 'package:flutter_application_4th_year_project/screens/authenticaion/signup_screen.dart';
import 'package:flutter_application_4th_year_project/utils/color_utils.dart';

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final TextEditingController _passwordTextController = TextEditingController();
  final TextEditingController _emailTextController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,

      decoration: BoxDecoration(gradient: LinearGradient(colors:
       [
        hexStringToColor("FFFFFF"),
          hexStringToColor("FFFFFF"),
          hexStringToColor("FFFFFF")],
          begin: Alignment.topCenter, end: Alignment.bottomCenter
          )),
          child: SingleChildScrollView(
            child: Padding(padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).size.height * 0.2,20,0),
            child: Column(
              children: <Widget>[
                LogoWidget("assets/images/taxii.png"), //function j Reusabile.widget
                  const SizedBox(
                  height: 10,
                ),
                reusableTextField("Enter UserName", Icons.person_outline, false, //function j Reusabile.widget ma ya inay
                    _emailTextController),
                const SizedBox(
                  height: 20,
                ),
                reusableTextField("Enter Password", Icons.lock_outline, true, //function j Reusabile.widget
                    _passwordTextController),
                const SizedBox(
                  height: 1,
                ),
                
                forgetPassword(context),
                firebaseButton(context, "Sign In", (){
                  FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: _emailTextController.text,
                  password: _passwordTextController.text)
                  .then((value){
                  Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()));
                  }).onError((error,StackTrace){
                    print("Error ${error.toString()}");
                  });
                }), //function j Reusabile.widget ma ya inay
                signUpOption()
              ],
            ),
            ),
          ),
          ),
    );
  }
    Row signUpOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have account?",
            style: TextStyle(color: Color.fromARGB(179, 90, 90, 90))),
        GestureDetector(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const SignUpScreen()));
          },
          child: const Text(
            " Sign Up",
            style: TextStyle(color: Color.fromARGB(255, 91, 91, 91), fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }

  Widget forgetPassword(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 35,
      alignment: Alignment.bottomRight,
      child: TextButton(
        child: const Text(
          "Forgot Password?",
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.right,
        ),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (context) => const ResetPassword())),
      ),
    );
  }
}