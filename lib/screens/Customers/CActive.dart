import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CActive extends StatefulWidget {
  const CActive({super.key});

  @override
  State<CActive> createState() => _CActiveState();
}

class _CActiveState extends State<CActive> {
  final user = FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot> getActiveOrders() {
    return FirebaseFirestore.instance
        .collection('trips')
        .where('userId', isEqualTo: user?.uid)
        .where('status', whereIn: ['pending', 'active'])
        .orderBy('tripDate', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getActiveDeliveries() {
    return FirebaseFirestore.instance
        .collection('deliveries')
        .where('userId', isEqualTo: user?.uid)
        .where('status', whereIn: ['pending', 'active'])
        .orderBy('deliveryDate', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Active Orders'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Trips'),
              Tab(text: 'Deliveries'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Trips Tab
            StreamBuilder<QuerySnapshot>(
              stream: getActiveOrders(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data?.docs.isEmpty ?? true) {
                  return const Center(child: Text('No active trips'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final trip = snapshot.data!.docs[index];
                    final data = trip.data() as Map<String, dynamic>;
                    final tripDate = (data['tripDate'] as Timestamp).toDate();

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.directions_car, color: Colors.green),
                        title: Text('Trip on ${DateFormat('MMM dd, yyyy').format(tripDate)}'),
                        subtitle: Text(
                          'Status: ${data['status']}\nTime: ${data['tripTime']}',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // Navigate to trip details
                        },
                      ),
                    );
                  },
                );
              },
            ),

            // Deliveries Tab
            StreamBuilder<QuerySnapshot>(
              stream: getActiveDeliveries(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data?.docs.isEmpty ?? true) {
                  return const Center(child: Text('No active deliveries'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final delivery = snapshot.data!.docs[index];
                    final data = delivery.data() as Map<String, dynamic>;
                    final deliveryDate = (data['deliveryDate'] as Timestamp).toDate();

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping, color: Colors.blue),
                        title: Text('Delivery on ${DateFormat('MMM dd, yyyy').format(deliveryDate)}'),
                        subtitle: Text(
                          'Status: ${data['status']}\nTime: ${data['deliveryTime']}',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // Navigate to delivery details
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}