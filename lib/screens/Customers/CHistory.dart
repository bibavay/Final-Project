import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CHistory extends StatefulWidget {
  const CHistory({super.key});

  @override
  State<CHistory> createState() => _CHistoryState();
}

class _CHistoryState extends State<CHistory> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Trips',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('trips')
                  .where('userId', isEqualTo: user?.uid)
                  .orderBy('tripDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final trips = snapshot.data?.docs ?? [];

                if (trips.isEmpty) {
                  return const Center(child: Text('No trips found'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final data = trips[index].data() as Map<String, dynamic>;
                    final tripDate = (data['tripDate'] as Timestamp).toDate();
                    final tripTime = data['tripTime'] ?? 'No time specified';

                    return Card(
                      margin: const EdgeInsets.all(8),
                      elevation: 4,
                      child: ListTile(
                        title: Text('Trip on ${tripDate.toLocal()} at $tripTime'),
                        subtitle: Text('Status: ${data['status']}'),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Deliveries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('deliveries')
                  .where('userId', isEqualTo: user?.uid)
                  .orderBy('deliveryDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final deliveries = snapshot.data?.docs ?? [];

                if (deliveries.isEmpty) {
                  return const Center(child: Text('No deliveries found'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: deliveries.length,
                  itemBuilder: (context, index) {
                    final data = deliveries[index].data() as Map<String, dynamic>;
                    final deliveryDate = (data['deliveryDate'] as Timestamp).toDate();
                    final deliveryTime = data['deliveryTime'] ?? 'No time specified';

                    return Card(
                      margin: const EdgeInsets.all(8),
                      elevation: 4,
                      child: ListTile(
                        title: Text('Delivery on ${deliveryDate.toLocal()} at $deliveryTime'),
                        subtitle: Text('Status: ${data['status']}'),
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