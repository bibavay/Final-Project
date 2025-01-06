import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/reusabile_widget/reusabile_widget.dart';
import 'package:flutter_application_4th_year_project/screens/authenticaion/home_screen.dart';
import 'package:flutter_application_4th_year_project/service/firestore.dart';
import 'package:flutter_application_4th_year_project/utils/color_utils.dart';
import 'package:geolocator/geolocator.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailTextController = TextEditingController();
  final TextEditingController _firstnameTextController = TextEditingController();
  final TextEditingController _lastnameTextController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordTextController = TextEditingController();
  final TextEditingController _confirmPasswordTextController = TextEditingController();
  final TextEditingController _carptTextController = TextEditingController();
  final TextEditingController _passNumberTextController = TextEditingController();
  final TextEditingController _governorateTextController = TextEditingController();
  final TextEditingController _districtTextController = TextEditingController();
  final TextEditingController _carModelTextController = TextEditingController();
  final TextEditingController _carColorTextController = TextEditingController();
final TextEditingController _carMakerTextController = TextEditingController();
final TextEditingController _carTypeTextController = TextEditingController();
final TextEditingController _genderTextController = TextEditingController();
final TextEditingController _locationTextController = TextEditingController();
final TextEditingController _carYearTextController = TextEditingController();
final TextEditingController _DCTextController = TextEditingController();
  final FirestoreService firestoreService = FirestoreService();

  final _formKey = GlobalKey<FormState>();

  String _gender = 'male';
String _User = 'Driver';
String? selectedGovernorate;
String? selectedDistrict;
  final List<String> governorates = ['Duhok', 'Arbil', 'Sulaymaniyah'];
  final Map<String, List<String>> districts = {
    'Duhok': ['Baroshki', 'Masike', 'Malta'],
    'Arbil': ['kuya', 'Taq Taq'],
    'Sulaymaniyah': ['Kalar', 'ranya'],
  };
String? selectedCarType;
  final List<String> carTypes = ['Sedan', 'SUV', 'Truck', 'Coupe', 'Convertible'];
String? selectedCarMaker;
  final List<String> carMaker = ['1', '2', '3', '4'];
String? selectedCarColor;
  final List<String> carColor = ['red', 'green', 'blue', 'yellow'];
String? selectedCarYear;
  final List<String> carYear = ['2010', '2011', '2012', '2013'];
String? selectedCarModel;
  final List<String> carModel = ['Toyota', 'Nissan'];

@override
  void dispose() {
    _passwordTextController.dispose();
    _confirmPasswordTextController.dispose();
    _governorateTextController.dispose();
    _districtTextController.dispose();
    _carptTextController.dispose();
    _passNumberTextController.dispose();
    _carYearTextController.dispose();
    _locationTextController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordTextController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
       // backgroundColor: const Color.fromARGB(0, 0, 0, 0),
        elevation: 0,
        title: Text(
          "Sign Up",
          style: TextStyle(
           // background: Paint()..color = Colors.amberAccent,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color.fromARGB(255, 167, 167, 167),
          ),
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              hexStringToColor("FFFFFB"),
              hexStringToColor("FFFFFB"),
              hexStringToColor("FFFFFB")
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 0),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: reusableTextField(
                        "First Name",
                        Icons.person_outline,
                        false,
                        _firstnameTextController,
                      ),
                    ),
                    const SizedBox(width: 20), // Adjust the width as needed
                    Expanded(
                      child: reusableTextField(
                        "Last Name",
                        Icons.person_outline,
                        false,
                        _lastnameTextController,
                      ),
                    ),
                  ],
                ),
                 const SizedBox(height: 20),
                reusableTextField(
                  "Phone Number",
                  Icons.phone_android_outlined,
                  false,
                 _phoneNumberController,
                  keyboardType: TextInputType.phone, 
                  //! lazm bheta gohrin
                ),
                const SizedBox(height: 20),
                reusableTextField(
                  "Enter Email Id",
                  Icons.email_outlined,
                  false,
                  _emailTextController,
                ),
                const SizedBox(height: 20),
                Column(
                    children: [
                      reusableTextFieldpassword(
                        "Enter Password",
                        Icons.lock_outlined,
                        true,
                        _passwordTextController,
                      validator: _validatePassword,

                      ),
                      const SizedBox(height: 20),
                      reusableTextFieldpassword(
                        "Confirm Password",
                        Icons.lock_outlined,
                        true,
                        _confirmPasswordTextController,
                        validator: _validateConfirmPassword,
                      ),
                    ],
                  ),
                
                const SizedBox(height: 20),
                //!Location           
                 DropdownButtonFormField<String>(
              value: selectedGovernorate,
              hint: Text('Select Governorate'),
              onChanged: (value) {
                setState(() {
                  selectedGovernorate = value;
                  selectedDistrict = null; // Reset district when governorate changes
                  _governorateTextController.text = value!;
                });
              },
              items: governorates.map((governorate) {
                return DropdownMenuItem<String>(
                  value: governorate,
                  child: Text(governorate),
                );
              }).toList(),
            ),
            DropdownButtonFormField<String>(
              value: selectedDistrict,
              hint: Text('Select District'),
              onChanged: (value) {
                setState(() {
                  selectedDistrict = value;
                  _districtTextController.text = value!;
                });
              },
              items: selectedGovernorate == null
                  ? []
                  : districts[selectedGovernorate]!.map((district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district),
                      );
                    }).toList(),
            ),
              SizedBox(height: 16.0),
              //! Get Current Location Button
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      Position position = await _getCurrentLocation();
                      print('Current location: ${position.latitude}, ${position.longitude}');
                      _locationTextController.text = 'Lat: ${position.latitude}, Lon: ${position.longitude}';
                    } catch (e) {
                      print('Error: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error: $e"),
                        ),
                      );
                    }
                  },
                  child: Text('Get Current Location'),
                ),
                const SizedBox(height: 20),
                // reusableTextField(
                //   "Current Location",
                //   Icons.location_on,
                //   false,
                //   _locationTextController,
                // ),
            //! gender
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Male'),
                    leading: Radio<String>(
                      value: 'male',
                      groupValue: _gender,
                      onChanged: (String? value) {
                        setState(() {
                          _gender = value!;
                          _genderTextController.text = value;

                        });
                      },
                    ),
                  ),
                ),
                 Expanded(
                  child: ListTile(
                    title: const Text('Female'),
                    leading: Radio<String>(
                      value: 'female',
                      groupValue: _gender,
                      onChanged: (String? value) {
                        setState(() {
                          _gender = value!;
                          _genderTextController.text = value;

                        });
                      },
                    ),
                  ),
                ),

              ],
            ),
            const SizedBox(height: 20),
           Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Customer'),
                    leading: Radio<String>(
                      value: 'Customer',
                      groupValue: _User,
                      onChanged: (String? value) {
                        setState(() {
                          _User = value!;
                          _DCTextController.text = value;
                        });
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Driver'),
                    leading: Radio<String>(
                      value: 'Driver',
                      groupValue: _User,
                      onChanged: (String? value) {
                        setState(() {
                          _User = value!;
                          _DCTextController.text = value;

                        });
                      },
                    ),
                  ),
                ),
                
              ],
            ),
            if (_User == 'Driver') ...[
              //! Car Type
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedCarType,
                hint: Text('Select Car Type'),
                onChanged: (value) {
                  setState(() {
                    selectedCarType = value;
                    _carTypeTextController.text = value!;
                  });
                },
                items: carTypes.map((carType) {
                  return DropdownMenuItem<String>(
                    value: carType,
                    child: Text(carType),
                  );
                }).toList(),
              ),
              //! Car Maker
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedCarMaker,
                hint: Text('Select Car Maker'),
                onChanged: (value) {
                  setState(() {
                    selectedCarMaker = value;
                    _carMakerTextController.text = value!;
                  });
                },
                items: carMaker.map((carMaker) {
                  return DropdownMenuItem<String>(
                    value: carMaker,
                    child: Text(carMaker),
                  );
                }).toList(),
              ),
              //! Car Model
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedCarModel,
                hint: Text('Select Car Model'),
                onChanged: (value) {
                  setState(() {
                    selectedCarModel = value;
                    _carModelTextController.text = value!;
                  });
                },
                items: carModel.map((carModel) {
                  return DropdownMenuItem<String>(
                    value: carModel,
                    child: Text(carModel),
                  );
                }).toList(),
              ),
              //! Car Year
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedCarYear,
                hint: Text('Select Car Year'),
                onChanged: (value) {
                  setState(() {
                    selectedCarYear = value;
                    _carYearTextController.text = value!;
                  });
                },
                items: carYear.map((carYear) {
                  return DropdownMenuItem<String>(
                    value: carYear,
                    child: Text(carYear),
                  );
                }).toList(),
              ),
              //! Car Plate Number
              const SizedBox(height: 20),
              reusableTextField(
                "Car Plate Number",
                Icons.numbers_outlined,
                false,
                _carptTextController,
              ),
              //! Car Color
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedCarColor,
                hint: Text('Select Car Color'),
                onChanged: (value) {
                  setState(() {
                    selectedCarColor = value;
                    _carColorTextController.text = value!;
                  });
                },
                items: carColor.map((carColor) {
                  return DropdownMenuItem<String>(
                    value: carColor,
                    child: Text(carColor),
                  );
                }).toList(),
              ),
              //! Number of Passengers
              const SizedBox(height: 20),
              reusableTextField(
                "Number of Passenger",
                Icons.person_rounded,
                true,
                _passNumberTextController,
              ),
            ],
                //!firebase button
            const SizedBox(height: 20),
const SizedBox(height: 20),
firebaseButton(
  context,
  "Sign Up",
  () {
    if (_formKey.currentState!.validate()) {
      try {
        // Validate phone number input
        if (_phoneNumberController.text.isEmpty) {
          throw FormatException("Phone number cannot be empty");
        }
        int phoneNumber = int.parse(_phoneNumberController.text);

       
        // Validate location input
        List<String> locationParts = _locationTextController.text.split(', ');
        if (locationParts.length != 2) {
          throw FormatException("Invalid location format");
        }
        double latitude = double.parse(locationParts[0].split(': ')[1]);
        double longitude = double.parse(locationParts[1].split(': ')[1]);

        FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailTextController.text,
          password: _passwordTextController.text,
        ).then((value) {
          print("Create New Account");

          // Add data to Firestore
          if (_User == 'Driver') {
             // Validate passenger number input
        if (_passNumberTextController.text.isEmpty) {
          throw FormatException("Passenger number cannot be empty");
        }
        int passengerNumber = int.parse(_passNumberTextController.text);

        // Validate car year input
        if (_carYearTextController.text.isEmpty) {
          throw FormatException("Car year cannot be empty");
        }
        int carYear = int.parse(_carYearTextController.text);

            firestoreService.addUsers(
              
              _emailTextController.text,
              _firstnameTextController.text,
              _lastnameTextController.text,
              _passwordTextController.text,
              _confirmPasswordTextController.text,
              phoneNumber,
              _carptTextController.text,
              passengerNumber,
              _governorateTextController.text,
              _districtTextController.text,
              _carModelTextController.text,
              _carColorTextController.text,
              _carMakerTextController.text,
              _carTypeTextController.text,
              _genderTextController.text,
              GeoPoint(latitude, longitude),
              carYear,
              _DCTextController.text,
            );
          } else {
             {
            firestoreService.addUser(
              _emailTextController.text,
              _firstnameTextController.text,
              _lastnameTextController.text,
              _passwordTextController.text,
              _confirmPasswordTextController.text,
              phoneNumber,
              _governorateTextController.text,
              _districtTextController.text,
              _genderTextController.text,
              GeoPoint(latitude, longitude),
              _DCTextController.text,
            );
          }
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        }).catchError((error) {
          if (error is FirebaseAuthException) {
            if (error.code == 'email-already-in-use') {
              print("The email address is already in use by another account.");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("The email address is already in use by another account."),
                ),
              );
            } else {
              print("Error: ${error.message}");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Error: ${error.message}"),
                ),
              );
            }
          } else {
            print("Error: ${error.toString()}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Error: ${error.toString()}"),
              ),
            );
          }
        });
      } catch (e) {
        print("Error: ${e.toString()}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid input: ${e.toString()}"),
          ),
        );
      }
    }
  },
),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
