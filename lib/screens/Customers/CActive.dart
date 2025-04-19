import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

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
        'pickupCity': data['pickupCity'] ?? 'N/A',
        'pickupRegion': data['pickupRegion'] ?? 'N/A',
        'dropoffCity': data['dropoffCity'] ?? 'N/A',
        'dropoffRegion': data['dropoffRegion'] ?? 'N/A',
        'tripTime': data['tripTime'],
        'estimatedPrice': data['estimatedPrice'],
        'passengers': data['passengers'] ?? [],
      };
    } else {
      // Delivery handling - standardize to match trip format
      orderDateTime = (data['deliveryDate'] as Timestamp).toDate();
      type = 'Delivery';
      details = {
        ...data,
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

class _CActiveState extends State<CActive> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<ActiveOrder>> _getActiveOrders() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    final tripsStream = _firestore
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'driver_pending', 'confirmed'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActiveOrder.fromFirestore(doc))
            .toList());

    final deliveriesStream = _firestore
        .collection('deliveries')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'driver_pending', 'confirmed'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActiveOrder.fromFirestore(doc))
            .toList());

    return Rx.combineLatest2<List<ActiveOrder>, List<ActiveOrder>, List<ActiveOrder>>(
      tripsStream,
      deliveriesStream,
      (List<ActiveOrder> trips, List<ActiveOrder> deliveries) {
        final combined = [...trips, ...deliveries];
        combined.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        return combined;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 3, 76, 83),
          foregroundColor: Colors.white,
          title: const Text('Active Orders'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.directions_car), text: "Trips"),
              Tab(icon: Icon(Icons.local_shipping), text: "Deliveries"),
            ],
          ),
        ),
        body: StreamBuilder<List<ActiveOrder>>(
          stream: _getActiveOrders(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = snapshot.data ?? [];
            final trips = orders.where((order) => order.type == 'Trip').toList();
            final deliveries = orders.where((order) => order.type == 'Delivery').toList();

            return TabBarView(
              children: [
                _buildOrdersList(trips),
                _buildOrdersList(deliveries),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<ActiveOrder> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active orders',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: orders.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        return _buildOrderCard(orders[index]);
      },
    );
  }

  Widget _buildOrderCard(ActiveOrder order) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        leading: Icon(
          order.type == 'Trip' ? Icons.directions_car : Icons.local_shipping,
          color: _getStatusColor(order.status),
        ),
        title: Text('${order.type} #${order.id.substring(0, 8)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd, yyyy HH:mm').format(order.dateTime),
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Status: ${order.status.toUpperCase()}',
              style: TextStyle(
                color: _getStatusColor(order.status),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        children: [
          order.type == 'Trip' 
              ? _buildTripDetails(order)
              : _buildDeliveryDetails(order.details),
          if (order.status == 'driver_pending')
            _buildDriverRequest(order.details),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return const Color.fromARGB(255, 235, 141, 0);
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

  Widget _buildTripDetails(ActiveOrder order) {
    final details = order.details;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trip Information:', 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(order.dateTime)),
          _buildInfoRow('Time', details['tripTime'] ?? 'Not specified'),
          _buildInfoRow('Status', order.status.toUpperCase()),
          
          const Divider(height: 24),
          
          Text('Route Details:', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationRow(
                    'Pickup Location',
                    '${details['pickupCity'] ?? 'N/A'}, ${details['pickupRegion'] ?? 'N/A'}',
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildLocationRow(
                    'Drop-off Location',
                    '${details['dropoffCity'] ?? 'N/A'}, ${details['dropoffRegion'] ?? 'N/A'}',
                    Colors.green,
                  ),
                ],
              ),
            ),
          ),

          if (details['passengers'] != null) ...[
            const Divider(height: 24),
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

          const Divider(height: 24),
          Text('Price Information:', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Price:', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${NumberFormat("#,##0").format(details['estimatedPrice'] ?? 0)} IQD',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 3, 76, 83),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetails(Map<String, dynamic> details) {
    final package = details['package'] as Map<String, dynamic>? ?? {};
    final locations = package['locations'] as Map<String, dynamic>? ?? {};
    final source = locations['source'] as Map<String, dynamic>? ?? {};
    final destination = locations['destination'] as Map<String, dynamic>? ?? {};
    final dimensions = package['dimensions'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery Information:', 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInfoRow('Date', details['deliveryDate'] != null 
              ? DateFormat('MMM dd, yyyy').format((details['deliveryDate'] as Timestamp).toDate())
              : 'N/A'),
          _buildInfoRow('Time', details['deliveryTime'] ?? 'N/A'),
          _buildInfoRow('Status', details['status']?.toUpperCase() ?? 'PENDING'),

          const Divider(height: 24),
          Text('Route Details:', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          Text('Package Details:', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

          const Divider(height: 24),
          Text('Price Information:', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Price:', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${NumberFormat("#,##0").format(details['estimatedPrice'] ?? 0)} IQD',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 3, 76, 83),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildDriverRequest(Map<String, dynamic> details) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Driver Request',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (details['driverRating'] != null)
            _buildInfoRow('Driver Rating', 
                '${details['driverRating'].toStringAsFixed(1)} (${details['driverTotalRatings']} reviews)'),
          if (details['driverRequestTime'] != null)
            _buildInfoRow('Requested', 
                DateFormat('MMM dd, yyyy HH:mm').format((details['driverRequestTime'] as Timestamp).toDate())),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToDriverRequest(details['id'], true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToDriverRequest(details['id'], false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respondToDriverRequest(String? orderId, bool accept) async {
    if (orderId == null) return;

    try {
      // Implementation for accepting/declining driver request
      // You'll need to update the order status in Firestore
      // and handle any necessary notifications
    } catch (e) {
      print('Error responding to driver request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}