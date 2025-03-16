import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_4th_year_project/service/firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class DHistory extends StatefulWidget {
  const DHistory({super.key});

  @override
  State<DHistory> createState() => _DHistoryState();
}

class _DHistoryState extends State<DHistory> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  TabController? _tabController; // Change to nullable

 @override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);
  print('Current User: ${_auth.currentUser?.uid}'); // Debug print
}

  @override
  void dispose() {
    // Safely dispose
    _tabController?.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _getCompletedOrders(String type) {
  final driverId = _auth.currentUser?.uid;
  print('Fetching completed orders for driver: $driverId'); // Debug print

  if (driverId == null) {
    print('No driver ID found');
    return Stream.value([]);
  }

  final collection = type == 'Trip' ? 'trips' : 'deliveries';
  print('Querying collection: $collection'); // Debug print

  final query = _firestore
      .collection(collection)
      .where('driverId', isEqualTo: driverId)
      .where('status', isEqualTo: 'completed')
      .orderBy('completedAt', descending: true);

  print('Query path: ${query.parameters}'); // Debug print

  return query.snapshots().map((snapshot) {
    print('Found ${snapshot.docs.length} completed $type orders'); // Debug print
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      print('Document ID: ${doc.id}'); // Debug print
      print('Document data: $data'); // Debug print
      
      try {
        return {
          'id': doc.id,
          'driverId': data['driverId'] ?? '',
          'status': data['status'] ?? '',
          'completedAt': data['completedAt'],
          'customer': data['customer'] ?? 'Unknown',
          'pickupLocation': data['pickupLocation'] ?? 'N/A',
          'dropLocation': data['dropLocation'] ?? 'N/A',
          'feedbackId': data['feedbackId'],
          'amount': data['amount'] ?? 0.0,
          'type': type,
        };
      } catch (e) {
        print('Error processing document ${doc.id}: $e');
        return null;
      }
    })
    .where((item) => item != null)
    .cast<Map<String, dynamic>>()
    .toList();
  });
}

  @override
  Widget build(BuildContext context) {
  if (_tabController == null) {
    return const Center(child: CircularProgressIndicator());
  }

  return Scaffold(
    appBar: AppBar(
      backgroundColor: Color.fromARGB(255, 3, 76, 83),
      foregroundColor: Colors.white,
      title: const Text("Order History"),
      bottom: TabBar(
        controller: _tabController!,
        tabs: const [
          Tab(icon: Icon(Icons.directions_car), text: "Trips"),
          Tab(icon: Icon(Icons.local_shipping), text: "Deliveries"),
        ],
      ),
    ),
    body: Column(
      children: [
        // Debug section with better formatting
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[200],
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('trips')
                .where('driverId', isEqualTo: _auth.currentUser?.uid)
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Text('Loading...');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Debug Info:'),
                  Text('Number of documents: ${snapshot.data?.docs.length}'),
                  if (snapshot.data?.docs.isNotEmpty ?? false)
                    Text('First document: ${snapshot.data?.docs.first.data()}'),
                ],
              );
            },
          ),
        ),
        // Main content
        Expanded(
          child: TabBarView(
            controller: _tabController!,
            children: [
              _buildOrdersList('Trip'),
              _buildOrdersList('Delivery'),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildOrdersList(String type) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getCompletedOrders(type),
      builder: (context, snapshot) {
        // Add debug prints
        print('Stream Builder State: ${snapshot.connectionState}');
        print('Has Error: ${snapshot.hasError}');
        if (snapshot.hasError) print('Error: ${snapshot.error}');
        print('Has Data: ${snapshot.hasData}');
        if (snapshot.hasData) print('Data Length: ${snapshot.data!.length}');

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
                  'No completed ${type.toLowerCase()}s',
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
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: Icon(
                  type == 'Trip' ? Icons.directions_car : Icons.local_shipping,
                  color: Colors.green,
                ),
                title: Text(
                  '${type} #${order['id'].substring(0, 8)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: ${DateFormat('MMM dd, yyyy HH:mm').format((order['completedAt'] as Timestamp).toDate())}'),
                    if (order['averageRating'] != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(' ${order['averageRating'].toStringAsFixed(1)}/5.0'),
                        ],
                      ),
                  ],
                ),
                children: [
                  _buildOrderDetails(order, type),
                ],
              ),
            );
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
          // Location details
          Text('From: ${order['pickupLocation'] ?? 'N/A'}'),
          Text('To: ${order['dropLocation'] ?? 'N/A'}'),
          const Divider(),
          
          // Customer details
          Text('Customer: ${order['customer'] ?? 'Unknown'}'),
          
          // Feedback section
          if (order['feedbackId'] != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Customer Feedback',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('feedback').doc(order['feedbackId']).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                
                final feedbackData = snapshot.data!.data() as Map<String, dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    RatingBarIndicator(
                      rating: feedbackData['averageRating'] ?? 0.0,
                      itemBuilder: (context, _) => const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      itemCount: 5,
                      itemSize: 20.0,
                    ),
                    if (feedbackData['comment'] != null &&
                        feedbackData['comment'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '"${feedbackData['comment']}"',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}