import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/reusabile_widget/reusabile_widget.dart';
import 'package:flutter_application_4th_year_project/screens/profile/profile.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final TextEditingController _userNameTextController = TextEditingController();
  final TextEditingController _emailTextController = TextEditingController();
  final TextEditingController _passwordTextController = TextEditingController();

  @override
  void dispose() {
    // Dispose controllers when not needed
    _userNameTextController.dispose();
    _emailTextController.dispose();
    _passwordTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context); // Navigate back to the previous screen
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          "Edit Profile",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            onPressed: () {}, // You can define action for the theme toggle button here
            icon: Icon(isDark ? LineAwesomeIcons.sun : LineAwesomeIcons.moon),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: const Image(
                        image: AssetImage("assets/images/taxii.png"),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: Colors.yellow,
                      ),
                      child: const Icon(LineAwesomeIcons.pencil_alt_solid),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              reusableTextField(
                "Enter UserName",
                Icons.person_outline,
                false,
                _userNameTextController,
              ),
              const SizedBox(height: 20),
              reusableTextField(
                "Enter Email Id",
                Icons.email_outlined,
                false,
                _emailTextController,
              ),
              const SizedBox(height: 20),
              reusableTextField(
                "Enter Password",
                Icons.lock_outlined,
                true,
                _passwordTextController,
              ),
              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Profile(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    "Confirm Changes",
                    style: TextStyle(color: Colors.black87),
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
