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
    print('Raw Firestore data: $data'); // Debug print
    print('Delivery Time: ${data['deliveryTime']}'); // Add this debug print
    
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
      details = {
        'package': data['package'] ?? {},
        'deliveryTime': data['deliveryTime'],
        // Map the location data from the package field
        'pickupCity': data['package']?['locations']?['source']?['city'] ?? 'N/A',
        'pickupRegion': data['package']?['locations']?['source']?['region'] ?? 'N/A',
        'dropoffCity': data['package']?['locations']?['destination']?['city'] ?? 'N/A',
        'dropoffRegion': data['package']?['locations']?['destination']?['region'] ?? 'N/A',
        'sourceLocation': data['package']?['locations']?['source']?['coordinates'],
        'destinationLocation': data['package']?['locations']?['destination']?['coordinates'],
      };
      
      print('Mapped delivery details: $details'); // Debug print
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
      .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
      .snapshots()
      .map((snapshot) {
        final orders = snapshot.docs
            .map((doc) => ActiveOrder.fromFirestore(doc))
            .where((order) {
              // Check if order is not null
              if (order == null) return false;

              try {
                final timeStr = type == 'Trip' 
                    ? order.details['tripTime'] 
                    : order.details['deliveryTime'];
                
                if (timeStr == null) return false;
                
                final timeParts = timeStr.split(':');
                if (timeParts.length != 2) return false;

                final orderDateTime = DateTime(
                  order.dateTime.year,
                  order.dateTime.month,
                  order.dateTime.day,
                  int.parse(timeParts[0]),
                  int.parse(timeParts[1]),
                );

                // If order time has passed, move it to history
                if (orderDateTime.isBefore(now)) {
                  _moveToHistory(order);
                  return false;
                }

                return true;
              } catch (e) {
                print('Error processing time for order ${order.id}: $e');
                return false;
              }
            })
            .toList();
        
        orders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        return orders;
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Active Orders"),
          elevation: 2,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.directions_car),
                text: "Trips",
              ),
              Tab(
                icon: Icon(Icons.local_shipping),
                text: "Deliveries",
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
                  color: isExpired ? Colors.red : Theme.of(context).primaryColor,
                ),
                title: Text(
                  '${type} #${order.id.substring(0, 8)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(order.dateTime)}\n'
                  'Status: ${order.status}',
                ),
                children: [
                  _buildDetailsSection(order),
                  if (!isExpired) _buildActionButtons(order),
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.type == 'Trip') ...[
            const Text('Trip Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Add Trip Location Details
            Text('Pickup Location:', style: TextStyle(fontWeight: FontWeight.w600)),
            if (order.details['pickupCity'] != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('City: ${order.details['pickupCity']}'),
                    Text('Region: ${order.details['pickupRegion'] ?? 'N/A'}'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Drop-off Location:', style: TextStyle(fontWeight: FontWeight.w600)),
            if (order.details['dropoffCity'] != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('City: ${order.details['dropoffCity']}'),
                    Text('Region: ${order.details['dropoffRegion'] ?? 'N/A'}'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Existing passenger details
            if (order.details['passengers'] != null) ...[
              for (var passenger in order.details['passengers'])
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Passenger Details:'),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gender: ${passenger['gender'] ?? 'N/A'}'),
                          Text('Age: ${passenger['age']?.toString() ?? 'N/A'}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
            ],
          ] else ...[
            // Delivery Details
            const Text('Delivery Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Add Delivery Location Details
            Text('Pickup Location:', style: TextStyle(fontWeight: FontWeight.w600)),
            if (order.details['pickupCity'] != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('City: ${order.details['pickupCity']}'),
                    Text('Region: ${order.details['pickupRegion'] ?? 'N/A'}'),
                    
                    ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Drop-off Location:', style: TextStyle(fontWeight: FontWeight.w600)),
            if (order.details['dropoffCity'] != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('City: ${order.details['dropoffCity']}'),
                    Text('Region: ${order.details['dropoffRegion'] ?? 'N/A'}'),
                    if (order.details['package']?['destinationLocation'] != null)
                      Text('Coordinates: (${(order.details['package']['destinationLocation'] as GeoPoint).latitude}, '
                          '${(order.details['package']['destinationLocation'] as GeoPoint).longitude})'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Existing package details
            if (order.details['package'] != null) ...[
              Text('Package Dimensions:', style: TextStyle(fontWeight: FontWeight.w600)),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Height: ${order.details['package']['dimensions']?['height']?.toString() ?? 'N/A'} cm'),
                    Text('Width: ${order.details['package']['dimensions']?['width']?.toString() ?? 'N/A'} cm'),
                    Text('Depth: ${order.details['package']['dimensions']?['depth']?.toString() ?? 'N/A'} cm'),
                    Text('Weight: ${order.details['package']['dimensions']?['weight']?.toString() ?? 'N/A'} kg'),
                  ],
                ),
              ),
            ],
           
          ],
          const SizedBox(height: 16),
          _detailRow('Status', order.status),
          _detailRow('Date & Time', order.details['formattedDateTime'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ActiveOrder order) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => _modifyOrder(order),
            icon: const Icon(Icons.edit),
            label: const Text('Modify'),
          ),
          ElevatedButton.icon(
            onPressed: () => _cancelOrder(order),
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
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

  Future<void> _modifyOrder(ActiveOrder order) async {
    try {
      final collection = order.type == 'Trip' ? 'trips' : 'deliveries';
      await _firestore.collection(collection).doc(order.id).update({
        'status': 'modification_requested',
        'modificationRequestedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modification request sent'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelOrder(ActiveOrder order) async {
    try {
      final collection = order.type == 'Trip' ? 'trips' : 'deliveries';
      await _firestore.collection(collection).doc(order.id).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month}-${dateTime.day} ${dateTime.hour}:${dateTime.minute}';
  }
}