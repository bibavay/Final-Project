import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'edit_profile.dart'; // Import the EditProfile screen

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    var isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context); // Optional: navigate back if needed
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          "Profile",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(isDark ? LineAwesomeIcons.sun : LineAwesomeIcons.moon),
          )
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
                  )
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Taxi",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Text(
                "ahmed@gmail.com",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>  const EditProfile(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    "Edit Profile",
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
