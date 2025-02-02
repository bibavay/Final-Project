import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CHistory extends StatefulWidget {
  const CHistory({super.key});

  @override
  State<CHistory> createState() => _CHistoryState();
}

class _CHistoryState extends State<CHistory> {
  final user = FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot> getCompletedTrips() {
    return FirebaseFirestore.instance
        .collection('trips')
        .where('userId', isEqualTo: user?.uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('tripDate', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getCompletedDeliveries() {
    return FirebaseFirestore.instance
        .collection('deliveries')
        .where('userId', isEqualTo: user?.uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('deliveryDate', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Trips'),
              Tab(text: 'Deliveries'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Trips History Tab
            StreamBuilder<QuerySnapshot>(
              stream: getCompletedTrips(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data?.docs.isEmpty ?? true) {
                  return const Center(child: Text('No completed trips'));
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
                        leading: const Icon(Icons.directions_car, color: Colors.grey),
                        title: Text('Trip on ${DateFormat('MMM dd, yyyy').format(tripDate)}'),
                        subtitle: Text('Time: ${data['tripTime']}'),
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                    );
                  },
                );
              },
            ),

            // Deliveries History Tab
            StreamBuilder<QuerySnapshot>(
              stream: getCompletedDeliveries(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data?.docs.isEmpty ?? true) {
                  return const Center(child: Text('No completed deliveries'));
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
                        leading: const Icon(Icons.local_shipping, color: Colors.grey),
                        title: Text('Delivery on ${DateFormat('MMM dd, yyyy').format(deliveryDate)}'),
                        subtitle: Text('Time: ${data['deliveryTime']}'),
                        trailing: const Icon(Icons.check_circle, color: Colors.blue),
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