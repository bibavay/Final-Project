import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ActiveOrder {
  final String id;
  final String type; // 'Trip' or 'Delivery'
  final DateTime dateTime;
  final String status;
  final Map<String, dynamic> details;
  
  ActiveOrder({
    required this.id,
    required this.type,
    required this.dateTime,
    required this.status,
    required this.details,
  });

  factory ActiveOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    DateTime orderDateTime;
    Map<String, dynamic> details;
    String type;
    
    if (data['tripDate'] != null) {
      // Trip handling
      orderDateTime = (data['tripDate'] as Timestamp).toDate();
      type = 'Trip';
      details = {
        ...data,
        'orderId': doc.id,
        'id': doc.id,
        'pendingDriverId': data['pendingDriverId'],
        'driverRequestTime': data['driverRequestTime'],
        'pickupLocation': data['pickupLocation'],
        'dropoffLocation': data['dropoffLocation'],
      };
    } else {
      // Delivery handling - standardize to match trip format
      orderDateTime = (data['deliveryDate'] as Timestamp).toDate();
      type = 'Delivery';
      details = {
        ...data,
        'orderId': doc.id,
        'id': doc.id,
        'pendingDriverId': data['pendingDriverId'],
        'driverRequestTime': data['driverRequestTime'],
        'pickupLocation': data['package']?['locations']?['source'],
        'dropoffLocation': data['package']?['locations']?['destination'],
        'package': data['package'] ?? {},
        'deliveryTime': data['deliveryTime'],
        'pickupCity': data['package']?['locations']?['source']?['city'] ?? 'N/A',
        'pickupRegion': data['package']?['locations']?['source']?['region'] ?? 'N/A',
        'dropoffCity': data['package']?['locations']?['destination']?['city'] ?? 'N/A',
        'dropoffRegion': data['package']?['locations']?['destination']?['region'] ?? 'N/A',
      };
    }

    return ActiveOrder(
      id: doc.id,
      type: type,
      dateTime: orderDateTime,
      status: data['status'] ?? 'pending',
      details: details,
    );
  }
}

class CActive extends StatefulWidget {
  const CActive({super.key});

  @override
  State<CActive> createState() => _CActiveState();
}

class _CActiveState extends State<CActive> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<ActiveOrder>> _getActiveOrders(String type) {
  final userId = _auth.currentUser?.uid;
  if (userId == null) return Stream.value([]);

  final collection = type == 'Trip' ? 'trips' : 'deliveries';
  final now = DateTime.now();

  return _firestore
      .collection(collection)
      .where('userId', isEqualTo: userId)
      .where('status', whereIn: ['pending', 'driver_pending', 'confirmed'])
      .orderBy(type == 'Trip' ? 'tripDate' : 'deliveryDate', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final order = ActiveOrder.fromFirestore(doc);
          
          // Get the time from the order
          final orderTime = order.type == 'Trip' 
              ? order.details['tripTime'] as String 
              : order.details['deliveryTime'] as String;
          
          // Parse hours and minutes
          final timeParts = orderTime.split(':');
          final orderDateTime = DateTime(
            order.dateTime.year,
            order.dateTime.month,
            order.dateTime.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );

          // If order is expired, move it to history
          if (orderDateTime.isBefore(now)) {
            _moveToHistory(order);
            return null;
          }

          return order;
        })
        .where((order) => order != null)
        .cast<ActiveOrder>()
        .toList();
      });
}

Future<void> _moveToHistory(ActiveOrder order) async {
  try {
    final collection = order.type == 'Trip' ? 'trips' : 'deliveries';
    final docRef = _firestore.collection(collection).doc(order.id);
    
    // Update the status to 'completed' if it's not already cancelled
    if (order.status != 'cancelled') {
      await docRef.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    // Copy the order to history collection
    await _firestore.collection('history').add({
      ...order.details,
      'originalId': order.id,
      'type': order.type,
      'userId': _auth.currentUser?.uid,
      'status': order.status == 'cancelled' ? 'cancelled' : 'completed',
      'movedToHistoryAt': FieldValue.serverTimestamp(),
    });

  } catch (e) {
    print('Error moving order to history: $e');
  }
}

Future<void> _acceptDriver(Map<String, dynamic> details) async {
  try {
    // Add debug logging
    print('Accepting driver with details: $details');
    
    // Get and validate order ID
    final String orderId = details['orderId'] ?? '';
    if (orderId.isEmpty) {
      throw Exception('Order ID not found in details: $details');
    }

    // Get and validate pending driver ID
    final String? pendingDriverId = details['pendingDriverId'];
    if (pendingDriverId == null) {
      throw Exception('No pending driver ID found in order');
    }

    final collection = details['type'] == 'Trip' ? 'trips' : 'deliveries';
    final orderRef = _firestore.collection(collection).doc(orderId);

    // Check if document exists and has pending driver
    final docSnap = await orderRef.get();
    if (!docSnap.exists) {
      throw Exception('Order document not found');
    }

    final data = docSnap.data() as Map<String, dynamic>;
    if (data['pendingDriverId'] != pendingDriverId) {
      throw Exception('Pending driver ID mismatch or not found');
    }

    // Update the order with driver confirmation
    await orderRef.update({
      'status': 'confirmed',
      'driverId': pendingDriverId,
      'confirmedAt': FieldValue.serverTimestamp(),
      'pendingDriverId': null, // Clear the pending state
      'driverRequestTime': null // Clear the request time
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Driver accepted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print('Error accepting driver: $e'); // Debug print
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _declineDriver(Map<String, dynamic> details) async {
  try {
    // Get the order ID from the details
    final String orderId = details['orderId'] ?? '';
    if (orderId.isEmpty) {
      throw Exception('Order ID not found');
    }

    final collection = details['type'] == 'Trip' ? 'trips' : 'deliveries';
    final orderRef = _firestore.collection(collection).doc(orderId);

    // Check if document exists first
    final docSnap = await orderRef.get();
    if (!docSnap.exists) {
      throw Exception('Order document not found');
    }

    await orderRef.update({
      'status': 'pending',
      'pendingDriverId': null,
      'driverRating': null,
      'driverTotalRatings': null,
      'driverRequestTime': null,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Driver request declined'),
        backgroundColor: Colors.orange,
      ),
    );
  } catch (e) {
    print('Error declining driver: $e'); // Add debug print
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange;
    case 'driver_pending':
      return Colors.blue;
    case 'confirmed':
      return Colors.green;
    case 'in_progress':
      return Colors.indigo;
    default:
      return Colors.grey;
  }
}

Future<Map<String, dynamic>> _getDriverRatings(String driverId) async {
  try {
    // Get all trips and deliveries where this driver is assigned
    final tripsQuery = await _firestore
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .where('feedbackGiven', isEqualTo: true)
        .get();

    final deliveriesQuery = await _firestore
        .collection('deliveries')
        .where('driverId', isEqualTo: driverId)
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

      sumProfessionalism += ratings[0]['rating'];
      sumDrivingSkills += ratings[1]['rating'];
      sumPunctuality += ratings[2]['rating'];
      sumVehicleCondition += ratings[3]['rating'];
      
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
  backgroundColor: Color.fromARGB(255, 3, 76, 83),
  foregroundColor: Colors.white,
  title: const Text("Active Order"),
  bottom: TabBar(
    controller: _tabController,
    indicatorColor: Colors.white, // Makes the indicator white
    labelColor: Colors.white, // Makes the selected tab text white
    unselectedLabelColor: Colors.white70, // Makes unselected tab text slightly transparent white
    tabs: const [
      Tab(
        icon: Icon(Icons.directions_car), // White car icon
        text: "Trips"
      ),
      Tab(
        icon: Icon(Icons.local_shipping), // White shipping icon
        text: "Deliveries"
      ),
    ],
  ),
),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOrdersList('Trip'),
            _buildOrdersList('Delivery'),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(String type) {
    return StreamBuilder<List<ActiveOrder>>(
      stream: _getActiveOrders(type),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == 'Trip' ? Icons.directions_car : Icons.local_shipping,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No active ${type.toLowerCase()}s',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final order = snapshot.data![index];
            final bool isExpired = order.dateTime.isBefore(DateTime.now());
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: Icon(
                  type == 'Trip' ? Icons.directions_car : Icons.local_shipping,
                  color: _getStatusColor(order.status),
                ),
                title: Text(
                  '${type} #${order.id.substring(0, 8)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: ${DateFormat('MMM dd, yyyy HH:mm').format(order.dateTime)}'),
                    Text(
                      'Status: ${order.status}',
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                children: [
                  _buildDetailsSection(order),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailsSection(ActiveOrder order) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Driver info section - same for both types
        if (order.status == 'driver_pending' || order.status == 'confirmed') 
          _buildDriverInfo(order.details, order),

        // Location details - standardized for both types
        Text('${order.type} Details:', 
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8,),

        // Pickup Location
        Text('Pickup Location:', 
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('City: ${order.details['pickupCity'] ?? 'N/A'}'),
              Text('Region: ${order.details['pickupRegion'] ?? 'N/A'}'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Dropoff Location
        Text('Drop-off Location:', 
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('City: ${order.details['dropoffCity'] ?? 'N/A'}'),
              Text('Region: ${order.details['dropoffRegion'] ?? 'N/A'}'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Type-specific details
        if (order.type == 'Delivery' && order.details['package'] != null) 
          _buildPackageDetails(order.details['package']),

        const SizedBox(height: 16),
        _detailRow('Status', order.status),
        _detailRow('Date & Time', 
            DateFormat('MMM dd, yyyy HH:mm').format(order.dateTime)),
      ],
    ),
  );
}

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month}-${dateTime.day} ${dateTime.hour}:${dateTime.minute}';
  }

  Widget _buildDriverRequest(Map<String, dynamic> order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Driver Request',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildDriverRating(
            order['driverRating'] ?? 0.0,
            order['driverTotalRatings'] ?? 0,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptDriver(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Accept Driver'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () => _declineDriver(order),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRating(double rating, int totalRatings) {
  return Row(
    children: [
      const Icon(Icons.star, color: Colors.amber, size: 20),
      const SizedBox(width: 4),
      Text(
        '${rating.toStringAsFixed(1)} ($totalRatings reviews)',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

  Widget _buildAcceptedDriverInfo(Map<String, dynamic> details) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.green.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Text(
              'Driver Confirmed',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDriverRating(
          details['driverRating'] ?? 0.0,
          details['driverTotalRatings'] ?? 0,
        ),
        const SizedBox(height: 8),
        if (details['confirmedAt'] != null) ...[
          Text(
            'Confirmed: ${DateFormat('MMM dd, yyyy HH:mm').format((details['confirmedAt'] as Timestamp).toDate())}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildDriverInfo(Map<String, dynamic> details, ActiveOrder order) {
  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: details['status'] == 'driver_pending' 
          ? Colors.blue.shade50 
          : Colors.green.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: details['status'] == 'driver_pending' 
            ? Colors.blue.shade200 
            : Colors.green.shade200
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          details['status'] == 'driver_pending' 
              ? 'Driver Request Received'
              : 'Driver Assigned',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: details['status'] == 'driver_pending' 
                ? Colors.blue.shade700 
                : Colors.green.shade700,
          ),
        ),
        const SizedBox(height: 16),
        
        // Add the detailed ratings section
        FutureBuilder<Map<String, dynamic>>(
          future: _getDriverRatings(details['pendingDriverId'] ?? details['driverId']),
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
                      'Driver Rating Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildRatingRow('Overall', ratings['overallRating']),
                    _buildRatingRow('Professionalism', ratings['professionalism']),
                    _buildRatingRow('Driving Skills', ratings['drivingSkills']),
                    _buildRatingRow('Punctuality', ratings['punctuality']),
                    _buildRatingRow('Vehicle', ratings['vehicleCondition']),
                    Text(
                      '${ratings['totalRatings']} total reviews',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        
        // Add accept/decline buttons for pending driver requests
        if (details['status'] == 'driver_pending') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptDriver({
                    'orderId': order.id,
                    'type': order.type,
                    'pendingDriverId': details['pendingDriverId'],
                    'driverRating': details['driverRating'],
                    'driverTotalRatings': details['driverTotalRatings'],
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept Driver'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineDriver({
                    ...details,
                    'orderId': order.id,
                    'type': order.type,
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

Widget _buildPackageDetails(Map<String, dynamic> package) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Package Details:', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Height: ${package['dimensions']?['height']?.toString() ?? 'N/A'} cm'),
      Text('Width: ${package['dimensions']?['width']?.toString() ?? 'N/A'} cm'),
      Text('Depth: ${package['dimensions']?['depth']?.toString() ?? 'N/A'} cm'),
      Text('Weight: ${package['dimensions']?['weight']?.toString() ?? 'N/A'} kg'),
    ],
  );
}
}