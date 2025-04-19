import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FeedbackQuestion {
  final String question;
  double rating = 0;

  FeedbackQuestion(this.question);
}

class DHistory extends StatefulWidget {
  const DHistory({super.key});

  @override
  State<DHistory> createState() => _DHistoryState();
}

class _DHistoryState extends State<DHistory> with SingleTickerProviderStateMixin {
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

  Stream<List<Map<String, dynamic>>> _getCompletedOrders(String type) {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) return Stream.value([]);

    final collection = type == 'Trip' ? 'trips' : 'deliveries';
    //final now = DateTime.now();

    return _firestore
        .collection(collection)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed') // Changed to only get completed orders
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              print('Processing completed ${type} with ID: ${doc.id}');
              
              final orderDate = type == 'Trip' 
                  ? (data['tripDate'] as Timestamp).toDate()
                  : (data['deliveryDate'] as Timestamp).toDate();
              
              final orderTime = type == 'Trip' 
                  ? data['tripTime'] as String
                  : data['deliveryTime'] as String;
              
              Map<String, dynamic> orderMap = {
                ...data,
                'id': doc.id,
                'orderDateTime': DateTime(
                  orderDate.year,
                  orderDate.month,
                  orderDate.day,
                  int.parse(orderTime.split(':')[0]),
                  int.parse(orderTime.split(':')[1]),
                ),
              };
              
              return orderMap;
            }).toList();
          } catch (e) {
            print('Error processing completed orders: $e');
            return [];
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 3, 76, 83),
        foregroundColor: Colors.white,
        title: const Text("Order History"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.directions_car),
              text: "Trips"
            ),
            Tab(
              icon: Icon(Icons.local_shipping),
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
    );
  }

  Widget _buildOrdersList(String type) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getCompletedOrders(type),
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
                  'No completed ${type.toLowerCase()}s yet',
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
            try {
              final order = snapshot.data![index];
              final orderDateTime = order['orderDateTime'] as DateTime;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ExpansionTile(
                  leading: Icon(
                    type == 'Trip' ? Icons.directions_car : Icons.local_shipping,
                    color: Colors.green, // Always green since only showing completed orders
                  ),
                  title: Text(
                    '${type} #${order['id'].substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date: ${DateFormat('MMM dd, yyyy HH:mm').format(orderDateTime)}'),
                      Text(
                        'Status: ${order['status']}',
                        style: TextStyle(
                          color: order['status'] == 'cancelled' ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (order['averageRating'] != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Rating: ${order['averageRating'].toStringAsFixed(1)}',
                              style: const TextStyle(color: Colors.amber),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  children: [
                    _buildOrderDetails(order, type),
                  ],
                ),
              );
            } catch (e) {
              print('Error building order item: $e');
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Widget _buildOrderDetails(Map<String, dynamic> order, String type) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (type == 'Trip') ...[
            const Text('Trip Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Customer: ${order['userName'] ?? 'N/A'}'),
            Text('Phone: ${order['userPhone'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            const Text('Location Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.green),
              title: const Text('Pickup Location'),
              subtitle: Text(order['pickupAddress'] ?? 'N/A'),
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: const Text('Drop-off Location'),
              subtitle: Text(order['dropoffAddress'] ?? 'N/A'),
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
            ),
            const SizedBox(height: 8),
            const Text('Passengers:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...List.from(order['passengers'] ?? []).map((passenger) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Gender: ${passenger['gender']}'),
                Text('  Age: ${passenger['age']}'),
                const SizedBox(height: 4),
              ],
            )),
          ] else ...[
            const Text('Delivery Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Sender: ${order['senderName'] ?? 'N/A'}'),
            Text('Recipient: ${order['recipientName'] ?? 'N/A'}'),
            Text('Contact: ${order['recipientPhone'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            const Text('Location Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.green),
              title: const Text('Pickup Location'),
              subtitle: Text(order['pickupAddress'] ?? 'N/A'),
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: const Text('Drop-off Location'),
              subtitle: Text(order['dropoffAddress'] ?? 'N/A'),
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
            ),
            if (order['package'] != null) ...[
              const SizedBox(height: 8),
              const Text('Package:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Weight: ${order['package']['dimensions']['weight']} kg'),
              Text('Size: ${order['package']['dimensions']['height']}x'
                  '${order['package']['dimensions']['width']}x'
                  '${order['package']['dimensions']['depth']} cm'),
            ],
          ],
          const Divider(),
          const SizedBox(height: 8),
          if (order['comment'] != null && order['comment'].toString().isNotEmpty) ...[
            const Text('Customer Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(order['comment'].toString()),
            ),
          ],
        ],
      ),
    );
  }
}