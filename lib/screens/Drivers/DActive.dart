import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class Dactive extends StatefulWidget {
  const Dactive({super.key});

  @override
  State<Dactive> createState() => _DactiveState();
}

class _DactiveState extends State<Dactive> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Active Orders"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Trips"),
              Tab(text: "Deliveries"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTripsTab(),
            _buildDeliveriesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('trips')
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error fetching trips: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final trips = snapshot.data?.docs.map((doc) => ActiveOrder.fromFirestore(doc)).toList() ?? [];
        
        if (trips.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No active trips available',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: trips.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final order = trips[index];
            final details = order.details;
            
            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: const Icon(Icons.directions_car, color: Colors.blue),
                title: Text('Trip #${order.id.substring(0, 8)}'),
                subtitle: Text(
                  'Status: ${order.status.toUpperCase()}',
                  style: TextStyle(
                    color: _getStatusColor(order.status),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: ${DateFormat('MMM dd, yyyy').format(order.dateTime)}'),
                        Text('Time: ${details['tripTime'] ?? 'Not specified'}'),
                        const Divider(),
                        if (details['passengers'] != null) ...[
                          Text('Passengers:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...List<Map<String, dynamic>>.from(details['passengers'])
                              .map((passenger) => Padding(
                                padding: const EdgeInsets.only(left: 16, bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('From: ${passenger['pickupCity']}, ${passenger['pickupRegion']}'),
                                    Text('To: ${passenger['dropoffCity']}, ${passenger['dropoffRegion']}'),
                                    Text('Gender: ${passenger['gender'] ?? 'N/A'}'),
                                    Text('Age: ${passenger['age']?.toString() ?? 'N/A'}'),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ))
                              .toList(),
                        ],
                        if (order.status == 'pending')
                          ElevatedButton(
                            onPressed: () => _acceptTrip(order.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            child: const Text('Accept Trip',
                              style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeliveriesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('deliveries')
          .where('status', whereIn: ['pending', 'active'])  // Check for both statuses
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('failed-precondition')) {
            return const Center(
              child: Text('Database index is being created. Please wait a few minutes and try again.'),
            );
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final deliveries = snapshot.data?.docs ?? [];
        
        if (deliveries.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No active deliveries available',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: deliveries.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final delivery = deliveries[index].data() as Map<String, dynamic>;
            final package = delivery['package'] as Map<String, dynamic>;

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: const Icon(Icons.local_shipping, color: Colors.blue),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Delivery Request'),
                    Text(
                      DateFormat('HH:mm').format((delivery['createdAt'] as Timestamp).toDate()),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${package['pickupCity']}, ${package['pickupRegion']}'),
                    Text('${package['dropoffCity']}, ${package['dropoffRegion']}',
                      style: const TextStyle(color: Colors.green)),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(
                          (delivery['deliveryDate'] as Timestamp).toDate())),
                        _buildInfoRow('Time', delivery['deliveryTime'] ?? 'Not specified'),
                        const Divider(),
                        Text('Package Details:', 
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        _buildInfoRow('Dimensions', 
                          '${package['dimensions']['height']}x${package['dimensions']['width']}x${package['dimensions']['depth']} cm'),
                        _buildInfoRow('Weight', '${package['dimensions']['weight']} kg'),
                        const Divider(),
                        ElevatedButton(
                          onPressed: () => _acceptDelivery(deliveries[index].id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(double.infinity, 45),
                          ),
                          child: const Text('Accept Delivery',
                            style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', 
            style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _acceptTrip(String tripId) async {
    try {
      await _firestore.collection('trips').doc(tripId).update({
        'status': 'accepted',
        'driverId': _auth.currentUser?.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip accepted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting trip: $e')),
      );
    }
  }

  Future<void> _acceptDelivery(String deliveryId) async {
    try {
      await _firestore.collection('deliveries').doc(deliveryId).update({
        'status': 'accepted',
        'driverId': _auth.currentUser?.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery accepted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting delivery: $e')),
      );
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'in_progress':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class ActiveOrder {
  final String id;
  final String type;
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
      orderDateTime = (data['tripDate'] as Timestamp).toDate();
      type = 'Trip';
      details = data;
    } else {
      orderDateTime = (data['deliveryDate'] as Timestamp).toDate();
      type = 'Delivery';
      details = data;
    }

    return ActiveOrder(
      id: doc.id,
      type: type,
      dateTime: orderDateTime,
      status: data['status'] ?? 'Pending',
      details: details,
    );
  }
}