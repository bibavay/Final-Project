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
  String _tripStatusFilter = 'all';
  String _deliveryStatusFilter = 'all';
  
  // Add filter options
  final List<String> _statusFilters = ['all', 'pending', 'accepted', 'in_progress'];

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

  Widget _buildFilterChips(String currentFilter, Function(String) onFilterChanged) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: _statusFilters.map((status) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(status.toUpperCase()),
              selected: currentFilter == status,
              onSelected: (_) => onFilterChanged(status),
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: currentFilter == status
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTripsTab() {
    return Column(
      children: [
        _buildFilterChips(_tripStatusFilter, (value) {
          setState(() => _tripStatusFilter = value);
        }),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _tripStatusFilter == 'all'
                ? _firestore
                    .collection('trips')
                    .where('status', whereIn: ['pending', 'accepted', 'in_progress'])
                    .where('driverId', isNull: true)
                    .snapshots()
                : _firestore
                    .collection('trips')
                    .where('status', isEqualTo: _tripStatusFilter)
                    .where('driverId', isEqualTo: _auth.currentUser?.uid)
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
                      children: [_buildTripDetails(order)],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTripDetails(ActiveOrder order) {
    final details = order.details;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trip Information
          Text('Trip Information:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(order.dateTime)),
          _buildInfoRow('Time', details['tripTime'] ?? 'Not specified'),
          _buildInfoRow('Status', order.status.toUpperCase()),
          
          const Divider(height: 24),
          
          // Location Details
          Text('Route Details:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From:', style: TextStyle(color: Colors.grey[600])),
                            Text('${details['pickupCity']}, ${details['pickupRegion']}',
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To:', style: TextStyle(color: Colors.grey[600])),
                            Text('${details['dropoffCity']}, ${details['dropoffRegion']}',
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 24),

          // Passenger Details
          if (details['passengers'] != null) ...[
            Text('Passenger Information:', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...List<Map<String, dynamic>>.from(details['passengers'])
                .map((passenger) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Gender', passenger['gender'] ?? 'N/A'),
                            _buildInfoRow('Age', passenger['age']?.toString() ?? 'N/A'),
                            const Divider(height: 16),
                            _buildInfoRow('Pickup', '${passenger['pickupCity']}, ${passenger['pickupRegion']}'),
                            _buildInfoRow('Drop-off', '${passenger['dropoffCity']}, ${passenger['dropoffRegion']}'),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ],

          const SizedBox(height: 16),

          // Action Buttons
          if (order.status == 'pending')
            ElevatedButton(
              onPressed: () => _acceptTrip(order.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('Accept Trip',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesTab() {
    return Column(
      children: [
        _buildFilterChips(_deliveryStatusFilter, (value) {
          setState(() => _deliveryStatusFilter = value);
        }),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _deliveryStatusFilter == 'all'
                ? _firestore
                    .collection('deliveries')
                    .where('status', whereIn: ['pending', 'accepted', 'in_progress'])
                    .where('driverId', isNull: true)
                    .snapshots()
                : _firestore
                    .collection('deliveries')
                    .where('status', isEqualTo: _deliveryStatusFilter)
                    .where('driverId', isEqualTo: _auth.currentUser?.uid)
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
                  try {
                    final doc = deliveries[index];
                    final delivery = doc.data() as Map<String, dynamic>;
                    final package = delivery['package'] as Map<String, dynamic>? ?? {};
                    final locations = package['locations'] as Map<String, dynamic>? ?? {};
                    final source = locations['source'] as Map<String, dynamic>? ?? {};
                    final destination = locations['destination'] as Map<String, dynamic>? ?? {};

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ExpansionTile(
                        leading: const Icon(Icons.local_shipping, color: Colors.blue),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Delivery #${doc.id.substring(0, 8)}'),
                            if (delivery['createdAt'] != null)
                              Text(
                                DateFormat('HH:mm').format((delivery['createdAt'] as Timestamp).toDate()),
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From: ${source['city'] ?? 'N/A'}, ${source['region'] ?? 'N/A'}'),
                            Text(
                              'To: ${destination['city'] ?? 'N/A'}, ${destination['region'] ?? 'N/A'}',
                              style: const TextStyle(color: Colors.green),
                            ),
                            Text(
                              'Status: ${delivery['status']?.toUpperCase() ?? 'PENDING'}',
                              style: TextStyle(
                                color: _getStatusColor(delivery['status']),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        children: [_buildDeliveryDetails(doc)],
                      ),
                    );
                  } catch (e) {
                    print('Error building delivery item: $e');
                    return const SizedBox.shrink();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryDetails(DocumentSnapshot doc) {
    final delivery = doc.data() as Map<String, dynamic>;
    final package = delivery['package'] as Map<String, dynamic>? ?? {};
    final locations = package['locations'] as Map<String, dynamic>? ?? {};
    final source = locations['source'] as Map<String, dynamic>? ?? {};
    final destination = locations['destination'] as Map<String, dynamic>? ?? {};
    final dimensions = package['dimensions'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... existing delivery information code ...
          _buildInfoRow('Date', delivery['deliveryDate'] != null 
              ? DateFormat('MMM dd, yyyy').format((delivery['deliveryDate'] as Timestamp).toDate())
              : 'N/A'),
          _buildInfoRow('Time', delivery['deliveryTime'] ?? 'N/A'),
          _buildInfoRow('Status', delivery['status']?.toUpperCase() ?? 'PENDING'),

          const Divider(height: 24),

          // Location Details with null checks
          Text('Route Details:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationRow(
                    'Pickup Location',
                    '${source['city'] ?? 'N/A'}, ${source['region'] ?? 'N/A'}',
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildLocationRow(
                    'Drop-off Location',
                    '${destination['city'] ?? 'N/A'}, ${destination['region'] ?? 'N/A'}',
                    Colors.green,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 24),

          // Package Details with null checks
          Text('Package Details:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Dimensions',
                      '${dimensions['height'] ?? 'N/A'}x${dimensions['width'] ?? 'N/A'}x${dimensions['depth'] ?? 'N/A'} cm'),
                  _buildInfoRow('Weight', '${dimensions['weight'] ?? 'N/A'} kg'),
                ],
              ),
            ),
          ),

          if (delivery['status'] == 'pending')
            ElevatedButton(
              onPressed: () => _acceptDelivery(doc.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('Accept Delivery',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
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

Widget _buildLocationRow(String label, String value, Color iconColor) {
  return Row(
    children: [
      Icon(Icons.location_on, color: iconColor),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600])),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    ],
  );
}