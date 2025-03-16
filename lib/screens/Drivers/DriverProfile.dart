import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_4th_year_project/screens/authenticaion/signin_screen.dart';
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
      final feedbacks = await _firestore
          .collection('feedback')
          .where('driverId', isEqualTo: _auth.currentUser?.uid)
          .get();

      if (feedbacks.docs.isEmpty) {
        return {
          'overallRating': 0.0,
          'professionalism': 0.0,
          'drivingSkills': 0.0,
          'punctuality': 0.0,
          'vehicleCondition': 0.0,
          'totalRatings': 0,
        };
      }

      double sumOverall = 0;
      double sumProfessionalism = 0;
      double sumDriving = 0;
      double sumPunctuality = 0;
      double sumVehicle = 0;
      int count = 0;

      for (var doc in feedbacks.docs) {
        final ratings = List<Map<String, dynamic>>.from(doc.data()['ratings']);
        if (ratings.isNotEmpty) {
          sumProfessionalism += ratings[0]['rating'];
          sumDriving += ratings[1]['rating'];
          sumPunctuality += ratings[2]['rating'];
          sumVehicle += ratings[3]['rating'];
          sumOverall += ratings[4]['rating'];
          count++;
        }
      }

      return {
        'overallRating': count > 0 ? (sumOverall / count) : 0.0,
        'professionalism': count > 0 ? (sumProfessionalism / count) : 0.0,
        'drivingSkills': count > 0 ? (sumDriving / count) : 0.0,
        'punctuality': count > 0 ? (sumPunctuality / count) : 0.0,
        'vehicleCondition': count > 0 ? (sumVehicle / count) : 0.0,
        'totalRatings': count,
      };
    } catch (e) {
      print('Error calculating ratings: $e');
      return {
        'overallRating': 0.0,
        'professionalism': 0.0,
        'drivingSkills': 0.0,
        'punctuality': 0.0,
        'vehicleCondition': 0.0,
        'totalRatings': 0,
      };
    }
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
    return Scaffold(
     appBar: AppBar(title: Text("Profile"),
     backgroundColor: const Color.fromARGB(255, 2, 111, 37),
     foregroundColor: Color.fromARGB(255, 255, 255, 255),),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _getDriverRatings(),
                    builder: (context, snapshot) {
                      final rating = snapshot.data?['overallRating'] ?? 0.0;
                      final totalRatings = snapshot.data?['totalRatings'] ?? 0;
                      
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.star,
                                size: 28,
                                color: Colors.amber,
                              ),
                            ],
                          ),
                          Text(
                            '$totalRatings ${totalRatings == 1 ? 'Review' : 'Reviews'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildInfoCard(
                    'Personal Information',
                    [
                      _buildInfoRow('First Name', driverData?['Fname'] ?? 'N/A', 'Fname'),
                      _buildInfoRow('Last Name', driverData?['Lname'] ?? 'N/A', 'Lname'),
                      _buildInfoRow('Email', driverData?['email'] ?? 'N/A'),
                      _buildInfoRow('Phone Number', 
                          driverData?['phoneNumber']?.toString() ?? 'N/A', 'phoneNumber'),
                      _buildInfoRow('Gender', driverData?['gender'] ?? 'N/A', 'gender'),
                      _buildInfoRow('Status', driverData?['status'] ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    'Vehicle Information',
                    [
                      _buildInfoRow('Car Model', driverData?['carmodel'] ?? 'N/A', 'carmodel'),
                      _buildInfoRow('Car Color', driverData?['carcolor'] ?? 'N/A', 'carcolor'),
                      _buildInfoRow('Car Maker', driverData?['carMaker'] ?? 'N/A', 'carMaker'),
                      _buildInfoRow('Car Type', driverData?['carType'] ?? 'N/A', 'carType'),
                      _buildInfoRow('Car Year', 
                          driverData?['carYear']?.toString() ?? 'N/A', 'carYear'),
                      _buildInfoRow('Car Plate', driverData?['carPT'] ?? 'N/A', 'carPT'),
                      _buildInfoRow('Passenger Capacity', 
                          driverData?['passNumber']?.toString() ?? 'N/A', 'passNumber'),
                      _buildInfoRow('Driving Certificate', driverData?['DC'] ?? 'N/A', 'DC'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    'Location Information',
                    [
                      _buildInfoRow('Governorate', driverData?['governorate'] ?? 'N/A', 'governorate'),
                      _buildInfoRow('District', driverData?['district'] ?? 'N/A', 'district'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, dynamic>>(
                    future: Future.wait([
                      _getDriverStatistics(),
                      _getDriverRatings(),
                    ]).then((results) => {
                      ...results[0] as Map<String, int>,
                      'restricted': (results[1]['totalRatings'] >= 1 && 
                                    results[1]['overallRating'] < 2.5),
                    }),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final stats = snapshot.data ?? {'trips': 0, 'deliveries': 0, 'restricted': false};
                      final totalServices = stats['trips']! + stats['deliveries']!;

                      return Column(
                        children: [
                          if (stats['restricted'] == true)
                            Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.red),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Your account is currently restricted due to low rating average.',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _buildInfoCard(
                            'Service Statistics',
                            [
                              _buildInfoRow(
                                'Total Services',
                                totalServices.toString(),
                              ),
                              _buildInfoRow(
                                'Total Trips',
                                stats['trips'].toString(),
                              ),
                              _buildInfoRow(
                                'Total Deliveries',
                                stats['deliveries'].toString(),
                              ),
                              _buildInfoRow(
                                'Service Type Distribution',
                                stats['trips']! > 0 || stats['deliveries']! > 0
                                    ? '${((stats['trips']! / totalServices) * 100).toStringAsFixed(1)}% Trips, '
                                      '${((stats['deliveries']! / totalServices) * 100).toStringAsFixed(1)}% Deliveries'
                                    : 'No services yet',
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _getDriverRatings(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final ratings = snapshot.data ?? {
                        'overallRating': 0.0,
                        'professionalism': 0.0,
                        'drivingSkills': 0.0,
                        'punctuality': 0.0,
                        'vehicleCondition': 0.0,
                        'totalRatings': 0,
                      };

                      return _buildInfoCard(
                        'Customer Ratings (Out of 5.0)',
                        [
                          _buildInfoRow(
                            'Overall Rating',
                            '${ratings['overallRating'].toStringAsFixed(1)}/5.0 ⭐',
                          ),
                          _buildInfoRow(
                            'Professionalism',
                            '${ratings['professionalism'].toStringAsFixed(1)}/5.0 ⭐',
                          ),
                          _buildInfoRow(
                            'Driving Skills',
                            '${ratings['drivingSkills'].toStringAsFixed(1)}/5.0 ⭐',
                          ),
                          _buildInfoRow(
                            'Punctuality',
                            '${ratings['punctuality'].toStringAsFixed(1)}/5.0 ⭐',
                          ),
                          _buildInfoRow(
                            'Vehicle Condition',
                            '${ratings['vehicleCondition'].toStringAsFixed(1)}/5.0 ⭐',
                          ),
                          _buildInfoRow(
                            'Total Reviews',
                            '${ratings['totalRatings']}',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24), // Add spacing before logout button
                  
                  Card(
                    elevation: 4,
                    color: Color.fromARGB(255, 3, 76, 83),
                    shape: RoundedRectangleBorder(
                      
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      onTap: () => _showLogoutConfirmation(context),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 24,
                      ),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16), // Bottom padding
                ],
              ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Changed from start to center
        children: [
          // Label section - 40% of width
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          // Value section - 60% of width
          Expanded(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center, // Changed from start to center
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                    softWrap: true,
                  ),
                ),
                if (field != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 24, // Fixed height to match text
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      alignment: Alignment.center,
                      onPressed: () => _editField(field, value),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes'),
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