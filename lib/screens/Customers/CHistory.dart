import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class FeedbackQuestion {
  final String question;
  double rating = 0;

  FeedbackQuestion(this.question);
}

class CHistory extends StatefulWidget {
  const CHistory({super.key});

  @override
  State<CHistory> createState() => _CHistoryState();
}

class _CHistoryState extends State<CHistory> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;

  final List<FeedbackQuestion> questions = [
    FeedbackQuestion('How would you rate the driver\'s professionalism?'),
    FeedbackQuestion('How would you rate the driver\'s punctuality?'),
    FeedbackQuestion('How would you rate the overall service?'),
  ];

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

  Stream<List<Map<String, dynamic>>> _getExpiredOrders(String type) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    final collection = type == 'Trip' ? 'trips' : 'deliveries';
    final now = DateTime.now();

    return _firestore
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['completed', 'cancelled']) // Add this line
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              final orderDate = type == 'Trip' 
                  ? (data['tripDate'] as Timestamp).toDate()
                  : (data['deliveryDate'] as Timestamp).toDate();
              
              final orderTime = type == 'Trip' 
                  ? data['tripTime'] as String
                  : data['deliveryTime'] as String;
              
              return {
                'id': doc.id,
                ...data,
                'orderDateTime': DateTime(
                  orderDate.year,
                  orderDate.month,
                  orderDate.day,
                  int.parse(orderTime.split(':')[0]),
                  int.parse(orderTime.split(':')[1]),
                ),
              };
            }).where((order) {
              final orderDateTime = order['orderDateTime'] as DateTime;
              return orderDateTime.isBefore(now);
            }).toList();
          } catch (e) {
            print('Error processing orders: $e');
            return [];
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Order History"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car), text: "Trips"),
            Tab(icon: Icon(Icons.local_shipping), text: "Deliveries"),
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
      stream: _getExpiredOrders(type),
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
                  'No expired ${type.toLowerCase()}s',
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
                    color: order['status'] == 'cancelled' ? Colors.red : Colors.green,
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
            const Text('Passengers:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...List.from(order['passengers']).map((passenger) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Gender: ${passenger['gender']}'),
                Text('  Age: ${passenger['age']}'),
                if (passenger['sourceLocation'] != null)
                  Text('  Pickup: (${(passenger['sourceLocation'] as GeoPoint).latitude}, '
                      '${(passenger['sourceLocation'] as GeoPoint).longitude})'),
                if (passenger['destinationLocation'] != null)
                  Text('  Drop-off: (${(passenger['destinationLocation'] as GeoPoint).latitude}, '
                      '${(passenger['destinationLocation'] as GeoPoint).longitude})'),
                const SizedBox(height: 8),
              ],
            )),
          ] else ...[
            const Text('Package Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (order['package'] != null) ...[
              Text('Dimensions:'),
              Text('Height: ${order['package']['dimensions']['height']} cm'),
              Text('Width: ${order['package']['dimensions']['width']} cm'),
              Text('Depth: ${order['package']['dimensions']['depth']} cm'),
              Text('Weight: ${order['package']['dimensions']['weight']} kg'),
            ],
          ],
          const Divider(),
          Text('Status: ${order['status']}'),
          Text('Created: ${DateFormat('MMM dd, yyyy HH:mm').format((order['createdAt'] as Timestamp).toDate())}'),
          
          // Add feedback button if feedback hasn't been given
          if (!(order['feedbackGiven'] ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton.icon(
                onPressed: () => _showFeedbackDialog(order, type),
                icon: const Icon(Icons.star_rate, color: Colors.white),
                label: const Text('Rate this service', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(Map<String, dynamic> order, String type) {
    // Reset ratings
    for (var question in questions) {
      question.rating = 0;
    }

    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Rate your ${type.toLowerCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...questions.map((q) => _buildRatingQuestion(q, setState)),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Additional Comments',
                    hintText: 'Share your experience...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (questions.any((q) => q.rating == 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please rate all questions'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                _submitFeedback(
                  order,
                  type,
                  questions,
                  commentController.text,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Text(
                'Submit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingQuestion(FeedbackQuestion question, StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500
            ),
          ),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: question.rating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemSize: 30,
            glow: false,
            itemBuilder: (context, _) => const Icon(
              Icons.star,
              color: Colors.amber,
            ),
            onRatingUpdate: (rating) {
              setState(() {
                question.rating = rating;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback(
    Map<String, dynamic> order,
    String type,
    List<FeedbackQuestion> questions,
    String comment,
  ) async {
    try {
      final collection = type.toLowerCase() + 's';
      final orderRef = _firestore.collection(collection).doc(order['id']);
      
      await _firestore.runTransaction((transaction) async {
        // Create feedback document
        final feedbackRef = _firestore.collection('feedback').doc();
        transaction.set(feedbackRef, {
          'orderId': order['id'],
          'orderType': type,
          'userId': _auth.currentUser?.uid,
          'ratings': questions.map((q) => {
            'question': q.question,
            'rating': q.rating,
          }).toList(),
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update order with feedback status
        transaction.update(orderRef, {
          'feedbackGiven': true,
          'averageRating': questions.map((q) => q.rating).reduce((a, b) => a + b) / questions.length,
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error submitting feedback: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting feedback: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}