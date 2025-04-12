import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_4th_year_project/service/firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class CustomerProfile extends StatefulWidget {
  const CustomerProfile({super.key});

  @override
  State<CustomerProfile> createState() => _CustomerProfileState();
}

class _CustomerProfileState extends State<CustomerProfile> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();
  bool _isLoading = true;
  bool _isEditing = false;
  Map<String, dynamic>? userData;
  String? _currentAddress;
  Position? _currentPosition;
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeUserData().then((_) => _loadUserData());
    _getCurrentPosition();
    _setupUserDataListener();
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('No user ID found - user not logged in');
        setState(() => _isLoading = false);
        return;
      }

      print('Loading data for user ID: $userId');

      // Get the customer profile data using FirestoreService
      final customerData = await _firestoreService.getCustomerProfile(userId);

      if (customerData != null) {
        print('Customer data loaded:');
        print('First Name: ${customerData['firstName']}');
        print('Last Name: ${customerData['lastName']}');
        print('Phone: ${customerData['phone']}');

        if (mounted) {
          setState(() {
            userData = customerData;
            _firstNameController.text = customerData['firstName']?.toString() ?? '';
            _lastNameController.text = customerData['lastName']?.toString() ?? '';
            _phoneController.text = customerData['phone']?.toString() ?? '';
            _emailController.text = customerData['email']?.toString() ?? '';
            _currentAddress = customerData['currentAddress']?.toString() ?? '';
            
            if (customerData['location'] != null) {
              final GeoPoint location = customerData['location'];
              _currentPosition = Position(
                latitude: location.latitude,
                longitude: location.longitude,
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0,
              );
            }
            _isLoading = false;
          });
        }
      } else {
        print('No customer data found in Firestore');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading customer data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled')),
      );
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied')),
      );
      return false;
    }

    return true;
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _currentPosition = position);
      _getAddressFromLatLng();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _getAddressFromLatLng() async {
    try {
      if (_currentPosition != null) {
        final placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          setState(() {
            _currentAddress = '${place.street}, ${place.subLocality}, '
                '${place.locality}, ${place.postalCode}';
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      final updateData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'currentAddress': _currentAddress,
        if (_currentPosition != null)
          'location': GeoPoint(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
      };

      print('Updating profile with data:');
      print(updateData);

      await _firestore.collection('users').doc(userId).update(updateData);

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating profile: $e');
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setupUserDataListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _userDataSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && !_isEditing) {
        final data = snapshot.data()!;
        setState(() {
          userData = data;
          if (!_isEditing) {
            _firstNameController.text = data['firstName'] ?? '';
            _lastNameController.text = data['lastName'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _emailController.text = data['email'] ?? '';
            _currentAddress = data['currentAddress'] ?? '';
          }
        });
      }
    }, onError: (error) {
      print('Error listening to user data: $error');
    });
  }

  // Add this method to initialize user data if needed
  Future<void> _initializeUserData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final docRef = _firestore.collection('users').doc(userId);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'firstName': '',
        'lastName': '',
        'phone': '',
        'email': _auth.currentUser?.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 3, 76, 83),
        foregroundColor: Colors.white,
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _updateProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              //color: const Color.fromARGB(255, 3, 76, 83),
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor:Color.from(alpha: 1, red: 0.02, green: 0.392, blue: 0.427),
                    child: Icon(Icons.person, size: 50, color: Color.fromARGB(255, 255, 255, 255)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_firstNameController.text} ${_lastNameController.text}',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 3, 76, 83),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isEditing) Text(
                    _emailController.text,
                    style: const TextStyle(color: Color.fromARGB(255, 3, 76, 83)),
                  ),
                ],
              ),
            ),
            // Form Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                color: Color.fromARGB(255, 3, 76, 83),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _firstNameController,
                              enabled: _isEditing,
                              decoration: InputDecoration(
                                labelText: 'First Name',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Please enter your first name' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _lastNameController,
                              enabled: _isEditing,
                              decoration: InputDecoration(
                                labelText: 'Last Name',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Please enter your last name' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contact Information',
                              style: TextStyle(
                                color: Color.fromARGB(255, 3, 76, 83),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              enabled: _isEditing,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Please enter your phone number' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              enabled: _isEditing,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please enter your email';
                                if (!value!.contains('@')) return 'Please enter a valid email';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Location',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 3, 76, 83),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _getCurrentPosition,
                                  color: const Color.fromARGB(255, 3, 76, 83),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, 
                                  color: Color.fromARGB(255, 3, 76, 83)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _currentAddress ?? 'No location available',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                
                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Show confirmation dialog
                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Logout'),
                              content: const Text('Are you sure you want to logout?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Logout', 
                                    style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ) ?? false;

                          if (!shouldLogout) return;

                          try {
                            await _auth.signOut();
                            if (!mounted) return;
                            
                            // Navigate to signin screen and clear navigation stack
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/signin', // Make sure this matches the route name in your main.dart
                              (route) => false,
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error logging out: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(197, 163, 6, 6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24), // Bottom padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}