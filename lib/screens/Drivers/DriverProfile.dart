import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transportaion_and_delivery/screens/authenticaion/signin_screen.dart';
import 'package:intl/intl.dart';

class DriverProfile extends StatefulWidget {
  const DriverProfile({super.key});

  @override
  State<DriverProfile> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Map<String, dynamic>? driverData;
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
    _checkRestrictions();
  }

  Future<void> _loadDriverData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('No user ID found');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      print('Fetching data for user: $userId');

      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        print('Driver document found: ${doc.data()}');
        if (mounted) {
          setState(() {
            driverData = doc.data();
            _isLoading = false;
          });
        }
      } else {
        print('No driver document found');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading driver data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editField(String field, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${field.split('_').map((word) => word.capitalize()).join(' ')}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter new ${field.split('_').map((word) => word.capitalize()).join(' ')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .update({field: result});

        await _loadDriverData(); // Reload data
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getDriverRatings() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return _getDefaultRatings();
      }

      // Get all trips and deliveries where this user is the driver
      final tripsQuery = await _firestore
          .collection('trips')
          .where('driverId', isEqualTo: userId)
          .where('feedbackGiven', isEqualTo: true)
          .get();

      final deliveriesQuery = await _firestore
          .collection('deliveries')
          .where('driverId', isEqualTo: userId)
          .where('feedbackGiven', isEqualTo: true)
          .get();

      // Collect all feedback IDs
      List<String> feedbackIds = [];
      feedbackIds.addAll(tripsQuery.docs.map((doc) => doc.data()['feedbackId'] as String));
      feedbackIds.addAll(deliveriesQuery.docs.map((doc) => doc.data()['feedbackId'] as String));

      if (feedbackIds.isEmpty) {
        return _getDefaultRatings();
      }

      // Get all feedback documents
      final feedbacks = await Future.wait(
        feedbackIds.map((id) => _firestore.collection('feedback').doc(id).get())
      );

      double sumProfessionalism = 0;
      double sumDrivingSkills = 0;
      double sumPunctuality = 0;
      double sumVehicleCondition = 0;
      double sumOverall = 0;
      int validFeedbackCount = 0;

      for (var doc in feedbacks) {
        if (!doc.exists) continue;
        
        final data = doc.data();
        if (data == null) continue;

        final ratings = List<Map<String, dynamic>>.from(data['ratings']);
        if (ratings.isEmpty) continue;

        // Assuming the ratings array follows the order:
        // [professionalism, driving skills, punctuality, vehicle condition]
        sumProfessionalism += ratings[0]['rating'];
        sumDrivingSkills += ratings[1]['rating'];
        sumPunctuality += ratings[2]['rating'];
        sumVehicleCondition += ratings[3]['rating'];
        
        // Calculate overall rating as average of all ratings for this feedback
        double feedbackOverall = ratings.fold(0.0, (sum, item) => sum + item['rating']) / ratings.length;
        sumOverall += feedbackOverall;
        
        validFeedbackCount++;
      }

      return {
        'overallRating': validFeedbackCount > 0 ? (sumOverall / validFeedbackCount) : 0.0,
        'professionalism': validFeedbackCount > 0 ? (sumProfessionalism / validFeedbackCount) : 0.0,
        'drivingSkills': validFeedbackCount > 0 ? (sumDrivingSkills / validFeedbackCount) : 0.0,
        'punctuality': validFeedbackCount > 0 ? (sumPunctuality / validFeedbackCount) : 0.0,
        'vehicleCondition': validFeedbackCount > 0 ? (sumVehicleCondition / validFeedbackCount) : 0.0,
        'totalRatings': validFeedbackCount,
      };
    } catch (e) {
      print('Error calculating ratings: $e');
      return _getDefaultRatings();
    }
  }

  Map<String, dynamic> _getDefaultRatings() {
    return {
      'overallRating': 0.0,
      'professionalism': 0.0,
      'drivingSkills': 0.0,
      'punctuality': 0.0,
      'vehicleCondition': 0.0,
      'totalRatings': 0,
    };
  }

  Future<Map<String, int>> _getDriverStatistics() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {'trips': 0, 'deliveries': 0};

      final tripsQuery = await _firestore
          .collection('trips')
          .where('driverId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      final deliveriesQuery = await _firestore
          .collection('deliveries')
          .where('driverId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      return {
        'trips': tripsQuery.docs.length,
        'deliveries': deliveriesQuery.docs.length,
      };
    } catch (e) {
      print('Error fetching statistics: $e');
      return {'trips': 0, 'deliveries': 0};
    }
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.star,
          size: 18,
          color: Colors.amber,
        ),
      ],
    );
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
            onPressed: () async {
              setState(() {
                _isEditing = !_isEditing;
              });
              if (!_isEditing) {
                // When saving (turning off edit mode)
                await _loadDriverData(); // Refresh data
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Changes saved successfully')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Section
            Container(
              //color: const Color.fromARGB(255, 255, 255, 255),
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color.fromARGB(255, 3, 76, 83),
                    child: Icon(Icons.person, size: 50, color: Color.fromARGB(255, 255, 255, 255)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${driverData?['Fname'] ?? ''} ${driverData?['Lname'] ?? ''}',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 3, 76, 83),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    driverData?['email'] ?? '',
                    style: const TextStyle(color: Color.fromARGB(255, 3, 76, 83),),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _getDriverRatings(),
                    builder: (context, snapshot) {
                      final rating = snapshot.data?['overallRating'] ?? 0.0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black45.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Main Content Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Personal Information Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          _buildInfoRow('First Name', driverData?['Fname'] ?? 'N/A', 'Fname'),
                          _buildInfoRow('Last Name', driverData?['Lname'] ?? 'N/A', 'Lname'),
                          _buildInfoRow('Phone', driverData?['phoneNumber'] ?? 'N/A', 'phoneNumber'),
                          _buildInfoRow('Gender', driverData?['gender'] ?? 'N/A', 'gender'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Vehicle Information Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vehicle Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          _buildInfoRow('Car Model', driverData?['carmodel'] ?? 'N/A', 'carmodel'),
                          _buildInfoRow('Car Color', driverData?['carcolor'] ?? 'N/A', 'carcolor'),
                          _buildInfoRow('Car Maker', driverData?['carMaker'] ?? 'N/A', 'carMaker'),
                          _buildInfoRow('Car Plate', driverData?['carPT'] ?? 'N/A', 'carPT'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ratings Card
                  FutureBuilder<Map<String, dynamic>>(
                    future: _getDriverRatings(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final ratings = snapshot.data!;
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rating Summary',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(),
                              _buildRatingRow('Overall Rating', ratings['overallRating']),
                              _buildRatingRow('Professionalism', ratings['professionalism']),
                              _buildRatingRow('Driving Skills', ratings['drivingSkills']),
                              _buildRatingRow('Punctuality', ratings['punctuality']),
                              _buildRatingRow('Vehicle Condition', ratings['vehicleCondition']),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutConfirmation(context),
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this new method for rating rows
  Widget _buildRatingRow(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.star,
                size: 20,
                color: Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [String? field]) {
    final controller = TextEditingController(text: value);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        enabled: _isEditing && field != null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            _getIconForField(field ?? ''),
            color: const Color.fromARGB(255, 3, 76, 83),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: const Color.fromARGB(255, 3, 76, 83).withOpacity(0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 3, 76, 83),
            ),
          ),
        ),
        validator: (value) =>
            value?.isEmpty ?? true ? 'Please enter $label' : null,
        onChanged: _isEditing && field != null
            ? (newValue) async {
                if (newValue.trim().isEmpty) return;
                try {
                  await _firestore
                      .collection('users')
                      .doc(_auth.currentUser?.uid)
                      .update({field: newValue.trim()});
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating $field: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            : null,
      ),
    );
  }

  // Add this helper method to get appropriate icons for each field
  IconData _getIconForField(String field) {
    switch (field.toLowerCase()) {
      case 'fname':
      case 'lname':
        return Icons.person_outline;
      case 'phonenumber':
        return Icons.phone_outlined;
      case 'gender':
        return Icons.people_outline;
      case 'carmodel':
      case 'carmaker':
        return Icons.directions_car_outlined;
      case 'carcolor':
        return Icons.color_lens_outlined;
      case 'carpt':
        return Icons.tag;
      default:
        return Icons.info_outline;
    }
  }

  Future<bool> _isDriverRestricted() async {
    try {
      final ratings = await _getDriverRatings();
      final totalRatings = ratings['totalRatings'] as int;
      final overallRating = ratings['overallRating'] as double;

      if (totalRatings >= 20 && overallRating < 2.5) {
        // Calculate restriction end date (30 days from last rating)
        final lastFeedback = await _firestore
            .collection('feedback')
            .where('driverId', isEqualTo: _auth.currentUser?.uid)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (lastFeedback.docs.isNotEmpty) {
          final lastRatingDate = (lastFeedback.docs.first.data()['createdAt'] as Timestamp).toDate();
          final restrictionEndDate = lastRatingDate.add(const Duration(days: 5));
          
          // Update driver's status in Firestore
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .update({
                'status': 'restricted',
                'restrictionEndDate': Timestamp.fromDate(restrictionEndDate),
                'restrictionReason': 'Low rating average (below 2.5 stars)',
              });

          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error checking driver restrictions: $e');
      return false;
    }
  }

  void _showRestrictionDialog(DateTime endDate) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Account Restricted',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your account has been temporarily restricted due to low rating average.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Restriction ends on: ${DateFormat('MMM dd, yyyy').format(endDate)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'To improve your rating:\n'
              '• Maintain professional behavior\n'
              '• Drive safely and follow traffic rules\n'
              '• Keep your vehicle clean\n'
              '• Be punctual\n'
              '• Provide excellent customer service',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkRestrictions() async {
    if (await _isDriverRestricted()) {
      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .get();
      
      if (doc.exists && doc.data()?['restrictionEndDate'] != null) {
        final endDate = (doc.data()?['restrictionEndDate'] as Timestamp).toDate();
        if (endDate.isAfter(DateTime.now())) {
          if (mounted) {
            _showRestrictionDialog(endDate);
          }
        }
      }
    }
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
           onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', 
           style: TextStyle(color: Colors.red)),
           ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await _auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SigninScreen()),
        (route) => false,
      );
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}