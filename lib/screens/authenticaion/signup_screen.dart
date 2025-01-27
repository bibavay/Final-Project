import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/reusabile_widget/reusabile_widget.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/Cemailverification.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/Demailverification.dart';
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

  Timer? _emailCheckTimer;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _emailCheckTimer?.cancel();
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

  Widget reusableTextFieldpassword(
      String hintText, IconData icon, bool isPasswordType, TextEditingController controller,
      {String? Function(String?)? validator, bool isPasswordVisible = false, VoidCallback? toggleVisibility}) {
    return TextFormField(
      controller: controller,
      obscureText: isPasswordType && !isPasswordVisible,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        suffixIcon: isPasswordType
            ? IconButton(
                icon: Icon(
                  isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: toggleVisibility,
              )
            : null,
      ),
    );
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
                 Column(
  children: [
    // Name Fields Row
    Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _firstnameTextController,
            decoration: InputDecoration(
              labelText: 'First Name',
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              prefixIcon: Icon(Icons.person_outline),
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
            validator: (value) => value?.isEmpty ?? true ? 'Please enter first name' : null,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: TextFormField(
            controller: _lastnameTextController,
            decoration: InputDecoration(
              labelText: 'Last Name',
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              prefixIcon: Icon(Icons.person_outline),
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
            validator: (value) => value?.isEmpty ?? true ? 'Please enter last name' : null,
          ),
        ),
      ],
    ),
    const SizedBox(height: 20),
    
    // Phone Number Field
    TextFormField(
      controller: _phoneNumberController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Icon(Icons.phone_android_outlined),
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
      validator: (value) => value?.isEmpty ?? true ? 'Please enter phone number' : null,
    ),
    const SizedBox(height: 20),
    
    // Email Field  
    TextFormField(
      controller: _emailTextController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Icon(Icons.email_outlined),
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
        if (value?.isEmpty ?? true) return 'Please enter email';
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    ),
    const SizedBox(height: 20),
    
    // Password Fields
    TextFormField(
      controller: _passwordTextController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: 'Password',
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
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
      validator: _validatePassword,
    ),
    const SizedBox(height: 20),
    
    // Confirm Password Field
    TextFormField(
      controller: _confirmPasswordTextController,
      obscureText: !_isConfirmPasswordVisible,
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
        ),
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
      validator: _validateConfirmPassword,
    ),
  ],
),
                  const SizedBox(height: 20),
                  //!Location
                  TextFormField(
  controller: _governorateTextController,
  decoration: InputDecoration(
    labelText: 'Governorate',
    hintText: 'Select Governorate',
    prefixIcon: Icon(Icons.location_city),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    filled: true,
        fillColor: Colors.grey.shade50,
    suffixIcon: PopupMenuButton<String>(
      icon: Icon(Icons.arrow_drop_down),
      onSelected: (String value) {
        setState(() {
          selectedGovernorate = value;
          selectedDistrict = null;
          _governorateTextController.text = value;
          _districtTextController.clear();
        });
      },
      itemBuilder: (context) => governorates
          .map((governorate) => PopupMenuItem<String>(
                value: governorate,
                child: Text(governorate),
              ))
          .toList(),
    ),
  ),
  validator: (value) => value?.isEmpty ?? true ? 'Please select governorate' : null,
),
const SizedBox(height: 20),
TextFormField(
  controller: _districtTextController,
  decoration: InputDecoration(
    labelText: 'District',
    hintText: selectedGovernorate == null 
        ? 'Select governorate first' 
        : 'Select district',
    prefixIcon: Icon(Icons.location_on),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    filled: true,
        fillColor: Colors.grey.shade50,
    suffixIcon: PopupMenuButton<String>(
      icon: Icon(Icons.arrow_drop_down),
      enabled: selectedGovernorate != null,
      onSelected: (String value) {
        setState(() {
          selectedDistrict = value;
          _districtTextController.text = value;
        });
      },
      itemBuilder: (context) => selectedGovernorate == null
          ? []
          : districts[selectedGovernorate]!
              .map((district) => PopupMenuItem<String>(
                    value: district,
                    child: Text(district),
                  ))
              .toList(),
    ),
  ),
  validator: (value) => value?.isEmpty ?? true ? 'Please select district' : null,
  enabled: selectedGovernorate != null,
),SizedBox(height: 16.0),
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
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      filled: true,
        fillColor: Colors.grey.shade50,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'male',
                        child: Row(
                          children: [
                            Icon(Icons.male),
                            SizedBox(width: 8),
                            Text('Male'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'female',
                        child: Row(
                          children: [
                            Icon(Icons.female),
                            SizedBox(width: 8),
                            Text('Female'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        _gender = value!;
                        _genderTextController.text = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select gender';
                      }
                      return null;
                    },
                  ),
                  //! User Type
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _User,
                    decoration: InputDecoration(
                      labelText: 'User Type',
                      prefixIcon: Icon(Icons.person_pin_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Customer',
                        child: Row(
                          children: [
                            Icon(Icons.person),
                            SizedBox(width: 8),
                            Text('Customer'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Driver',
                        child: Row(
                          children: [
                            Icon(Icons.drive_eta),
                            SizedBox(width: 8),
                            Text('Driver'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        _User = value!;
                        _DCTextController.text = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select user type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_User == 'Driver') ...[
                    //! Car Type
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _carTypeTextController,
                      decoration: InputDecoration(
                        labelText: 'Car Type',
                        hintText: 'Select or enter car type',
                        prefixIcon: Icon(Icons.directions_car),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: PopupMenuButton<String>(
                          icon: Icon(Icons.arrow_drop_down),
                          onSelected: (String value) {
                            setState(() {
                              selectedCarType = value;
                              _carTypeTextController.text = value;
                            });
                          },
                          itemBuilder: (context) => carTypes.map((type) => 
                            PopupMenuItem(value: type, child: Text(type))
                          ).toList(),
                        ),
                        filled: true,
                         fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter car type' : null,
                    ),

                    //! Car Maker
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _carMakerTextController,
                      decoration: InputDecoration(
                        labelText: 'Car Maker',
                        hintText: 'Select or enter car maker',
                        prefixIcon: Icon(Icons.factory),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: PopupMenuButton<String>(
                          icon: Icon(Icons.arrow_drop_down),
                          onSelected: (String value) {
                            setState(() {
                              selectedCarMaker = value;
                              _carMakerTextController.text = value;
                            });
                          },
                          itemBuilder: (context) => carMaker.map((maker) => 
                            PopupMenuItem(value: maker, child: Text(maker))
                          ).toList(),
                        ),
                        filled: true,
                         fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter car maker' : null,
                    ),

                    //! Car Model
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _carModelTextController,
                      decoration: InputDecoration(
                        labelText: 'Car Model',
                        hintText: 'Select or enter car model',
                        prefixIcon: Icon(Icons.car_rental),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: PopupMenuButton<String>(
                          icon: Icon(Icons.arrow_drop_down),
                          onSelected: (String value) {
                            setState(() {
                              selectedCarModel = value;
                              _carModelTextController.text = value;
                            });
                          },
                          itemBuilder: (context) => carModel.map((model) => 
                            PopupMenuItem(value: model, child: Text(model))
                          ).toList(),
                        ),
                        filled: true,
                         fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter car model' : null,
                    ),

                    //! Car Year
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _carYearTextController,
                      decoration: InputDecoration(
                        labelText: 'Car Year',
                        hintText: 'Select or enter car year',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: PopupMenuButton<String>(
                          icon: Icon(Icons.arrow_drop_down),
                          onSelected: (String value) {
                            setState(() {
                              selectedCarYear = value;
                              _carYearTextController.text = value;
                            });
                          },
                          itemBuilder: (context) => carYear.map((year) => 
                            PopupMenuItem(value: year, child: Text(year))
                          ).toList(),
                        ),
                        filled: true,
                         fillColor: Colors.grey.shade50,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Please enter car year';
                        int? year = int.tryParse(value!);
                        if (year == null || year < 1900 || year > DateTime.now().year) {
                          return 'Please enter a valid year';
                        }
                        return null;
                      },
                    ),

                    //! Car Color
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _carColorTextController,
                      decoration: InputDecoration(
                        labelText: 'Car Color',
                        hintText: 'Select or enter car color',
                        prefixIcon: Icon(Icons.color_lens),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: PopupMenuButton<String>(
                          icon: Icon(Icons.arrow_drop_down),
                          onSelected: (String value) {
                            setState(() {
                              selectedCarColor = value;
                              _carColorTextController.text = value;
                            });
                          },
                          itemBuilder: (context) => carColor.map((color) => 
                            PopupMenuItem(value: color, child: Text(color))
                          ).toList(),
                        ),
                        filled: true,
                         fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter car color' : null,
                    ),

                    //! Car Plate Number
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _carptTextController,
                      decoration: InputDecoration(
                        labelText: 'Car Plate Number',
                        hintText: 'Enter plate number',
                        prefixIcon: Icon(Icons.numbers_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                         fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter plate number' : null,
                    ),

                    //! Number of Passengers
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passNumberTextController,
                      decoration: InputDecoration(
                        labelText: 'Number of Passengers',
                        hintText: 'Select or enter number',
                        prefixIcon: Icon(Icons.person_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: PopupMenuButton<String>(
                          icon: Icon(Icons.arrow_drop_down),
                          onSelected: (String value) {
                            setState(() {
                              _passNumberTextController.text = value;
                            });
                          },
                          itemBuilder: (context) => List.generate(8, (i) => i + 1)
                              .map((num) => PopupMenuItem(
                                    value: num.toString(),
                                    child: Text('$num passenger${num > 1 ? 's' : ''}'),
                                  ))
                              .toList(),
                        ),
                        filled: true,
                         fillColor: Colors.grey.shade50,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Please enter number of passengers';
                        int? passengers = int.tryParse(value!);
                        if (passengers == null || passengers < 1 || passengers > 8) {
                          return 'Please enter a valid number (1-8)';
                        }
                        return null;
                      },
                    ),
                  ],
                  //!firebase button
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  firebaseButton(
                    context,
                    "Sign Up",
                    () async {
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

                          final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                            email: _emailTextController.text,
                            password: _passwordTextController.text,
                          );

                          if (userCredential.user != null) {
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

                              await firestoreService.addDriver(
                                userCredential.user!.uid, // Add UID
                                _emailTextController.text,
                                _firstnameTextController.text,
                                _lastnameTextController.text,
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

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const DEmailverify()),
                              );
                            } else {
                              await firestoreService.addCustomer(
                                userCredential.user!.uid, // Add UID
                                _emailTextController.text,
                                _firstnameTextController.text,
                                _lastnameTextController.text,
                                phoneNumber,
                                _governorateTextController.text,
                                _districtTextController.text,
                                _genderTextController.text,
                                GeoPoint(latitude, longitude),
                                _DCTextController.text,
                              );

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const CEmailverify()),
                              );
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error creating account: $e')),
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

// Helper function to validate and parse integers
int _validateAndParseInt(String input, String fieldName) {
  if (input.isEmpty) {
    throw FormatException("$fieldName cannot be empty");
  }
  return int.parse(input);
}

// Helper function to validate and parse location
GeoPoint _validateAndParseLocation(String input) {
  List<String> locationParts = input.split(', ');
  if (locationParts.length != 2) {
    throw FormatException("Invalid location format");
  }
  double latitude = double.parse(locationParts[0].split(': ')[1]);
  double longitude = double.parse(locationParts[1].split(': ')[1]);
  return GeoPoint(latitude, longitude);
}

// Helper function to handle Firebase errors
void _handleFirebaseError(dynamic error, BuildContext context) {
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
}
