import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Collections
  final CollectionReference users = FirebaseFirestore.instance.collection('users');
  final CollectionReference trips = FirebaseFirestore.instance.collection('trips');
  final CollectionReference tempUsers = FirebaseFirestore.instance.collection('tempUsers');
  final CollectionReference deliveries = FirebaseFirestore.instance.collection('deliveries');

  // User Methods
  Future<void> addUser(String uid, String email, String userType) async {
    await users.doc(uid).set({
      'email': email,
      'userType': userType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Trip Methods
  Future<String> createTrip({
    required String userId,
    required DateTime tripDate,
    required TimeOfDay tripTime,
    required List<Map<String, dynamic>> passengers,
    required String sourceCity,
    required String destinationCity,
    required String carType,
  }) async {
    final docRef = await trips.add({
      'userId': userId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'tripDate': Timestamp.fromDate(tripDate),
      'tripTime': '${tripTime.hour}:${tripTime.minute}',
      'passengers': passengers.map((passenger) => {
        'gender': passenger['gender'],
        'age': passenger['age'],
        'sourceLocation': {
          'latitude': passenger['sourceLocation'].latitude,
          'longitude': passenger['sourceLocation'].longitude,
          'address': passenger['sourceAddress'],
        },
        'destinationLocation': {
          'latitude': passenger['destinationLocation'].latitude,
          'longitude': passenger['destinationLocation'].longitude,
          'address': passenger['destinationAddress'],
        }
      }).toList(),
      'carType': carType,
    });
    
    return docRef.id;
  }

  Future<void> updateTripStatus(String tripId, String status) async {
    await trips.doc(tripId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getUserTrips(String userId) {
    return trips
        .where('userId', isEqualTo: userId)
        .orderBy('tripDate', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getActiveTrips() {
    return trips
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot> getTripDetails(String tripId) async {
    return await trips.doc(tripId).get();
  }

  Future<void> addDriver(
    String uid,
    String email,
    String Fname,
    String Lname,
    int phoneNumber,
    String carPT,
    int passNumber,
    String governorate,
    String district,
    String carmodel,
    String carcolor,
    String carMaker,
    String carType,
    String gender,
    GeoPoint location,
    int carYear,
    String DC,
  ) async {
    await users.doc(uid).set({
      'userType': 'driver',
      'email': email,
      'Fname': Fname,
      'Lname': Lname,
      'phoneNumber': phoneNumber,
      'carPT': carPT,
      'passNumber': passNumber,
      'governorate': governorate,
      'district': district,
      'carmodel': carmodel,
      'carcolor': carcolor,
      'carMaker': carMaker,
      'carType': carType,
      'gender': gender,
      'location': location,
      'carYear': carYear,
      'DC': DC,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addCustomer(
    String uid,
    String email,
    String Fname,
    String Lname,
    int phoneNumber,
    String governorate,
    String district,
    String gender,
    GeoPoint location,
    String DC,
  ) async {
    await users.doc(uid).set({
      'userType': 'customer',
      'email': email,
      'Fname': Fname,
      'Lname': Lname,
      'phoneNumber': phoneNumber,
      'governorate': governorate,
      'district': district,
      'gender': gender,
      'location': location,
      'DC': DC,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> storeTempUserData(String uid, Map<String, dynamic> userData) async {
    await tempUsers.doc(uid).set({
      ...userData,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 1)),
      ),
    });
  }

  Future<void> moveToVerifiedUsers(String uid) async {
    final tempDoc = await tempUsers.doc(uid).get();
    if (tempDoc.exists) {
      final userData = tempDoc.data() as Map<String, dynamic>;
      await users.doc(uid).set(userData);
      await tempUsers.doc(uid).delete();
    }
  }

  // Delivery Methods
  Future<String> createDeliveryWithDimensions({
    required String userId,
    required DateTime deliveryDate,
    required TimeOfDay deliveryTime,
    required double height,
    required double width,
    required double depth,
    required double weight,
    required LatLng sourceLocation,
    required LatLng destinationLocation,
    required String sourceCity,
    required String destinationCity,
  }) async {
    final docRef = await deliveries.add({
      'userId': userId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryDate': Timestamp.fromDate(deliveryDate),
      'deliveryTime': '${deliveryTime.hour}:${deliveryTime.minute}',
      'package': {
        'dimensions': {
          'height': height,
          'width': width,
          'depth': depth,
          'weight': weight,
        },
        'sourceLocation': GeoPoint(
          sourceLocation.latitude,
          sourceLocation.longitude,
        ),
        'destinationLocation': GeoPoint(
          destinationLocation.latitude,
          destinationLocation.longitude,
        ),
      },
    });
    return docRef.id;
  }

  Future<void> changeDeliveryStatus(String deliveryId, String status) async {
    await deliveries.doc(deliveryId).update({'status': status});
  }

  Stream<QuerySnapshot> getDeliveriesForUser(String userId) {
    return deliveries
        .where('userId', isEqualTo: userId)
        .orderBy('deliveryDate', descending: true)
        .snapshots();
  }

  Future<String> createDelivery({
    required String userId,
    required DateTime deliveryDate,
    required TimeOfDay deliveryTime,
    required Map<String, dynamic> package,
    required String sourceCity,
    required String destinationCity,
  }) async {
    final dimensions = package['dimensions'] as Map<String, dynamic>;
    
    final docRef = await deliveries.add({
      'userId': userId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryDate': Timestamp.fromDate(deliveryDate),
      'deliveryTime': '${deliveryTime.hour}:${deliveryTime.minute}',
      'package': package,
      'pickupCity': sourceCity,        // Add this
      'dropoffCity': destinationCity,  // Add this
    });
    return docRef.id;
  }

  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    await deliveries.doc(deliveryId).update({'status': status});
  }

  Stream<QuerySnapshot> getUserDeliveries(String userId) {
    return deliveries
      .where('userId', isEqualTo: userId)
      .orderBy('deliveryDate', descending: true)
      .snapshots();
  }

  Stream<QuerySnapshot> getPendingDeliveries() {
    return deliveries
      .where('status', isEqualTo: 'pending')
      .orderBy('deliveryDate')
      .snapshots();
  }

  Future<DocumentSnapshot> getDeliveryById(String deliveryId) {
    return deliveries.doc(deliveryId).get();
  }

  Stream<QuerySnapshot> getCompletedDeliveries() {
    return deliveries
      .where('status', isEqualTo: 'completed')
      .orderBy('deliveryDate', descending: true)
      .snapshots();
  }

  Stream<QuerySnapshot> getDriverDeliveries(String driverId) {
    return deliveries
      .where('driverId', isEqualTo: driverId)
      .orderBy('deliveryDate')
      .snapshots();
  }

  Future<void> assignDriverToDelivery(String deliveryId, String driverId) async {
    await deliveries.doc(deliveryId).update({
      'driverId': driverId,
      'status': 'assigned',
      'assignedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDeliveryLocation(String deliveryId, GeoPoint currentLocation) async {
    await deliveries.doc(deliveryId).update({
      'currentLocation': currentLocation,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeDelivery(String deliveryId, {
    required String driverId,
    required String customer,
    required String pickupLocation,
    required String dropLocation,
    required double amount,
  }) async {
    await deliveries.doc(deliveryId).update({
      'driverId': driverId,
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'customer': customer,
      'pickupLocation': pickupLocation,
      'dropLocation': dropLocation,
      'amount': amount,
      'type': 'Delivery'
    });
  }

  Future<void> completeTrip(String tripId, {
    required String driverId,
    required String customer,
    required String pickupLocation,
    required String dropLocation,
    required double amount,
  }) async {
    await trips.doc(tripId).update({
      'driverId': driverId,
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'customer': customer,
      'pickupLocation': pickupLocation,
      'dropLocation': dropLocation,
      'amount': amount,
      'type': 'Trip'
    });
  }

  // In firestore.dart
Stream<QuerySnapshot> getCompletedTrips(String driverId, {String? type}) {
  Query query = _firestore
      .collection('trips') // Or whatever your collection is called
      .where('driverId', isEqualTo: driverId)
      .where('status', isEqualTo: 'completed');
      
  if (type != null) {
    query = query.where('type', isEqualTo: type);
  }
  
  return query.snapshots();
}

  Future<void> addFeedback(String tripId, String feedbackContent, double rating) async {
    // First create the feedback document
    final feedbackRef = _firestore.collection('feedback').add({
      'tripId': tripId,
      'content': feedbackContent,
      'rating': rating,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Then update the trip with the feedback reference
    await trips.doc(tripId).update({
      'feedbackId': (await feedbackRef).id
    });
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
    String timeStr;
    
    if (data['tripDate'] != null) {
      orderDateTime = (data['tripDate'] as Timestamp).toDate();
      timeStr = data['tripTime'] ?? '00:00';
      type = 'Trip';
      details = {
        ...data,
        'formattedDateTime': _formatDateTime(orderDateTime, timeStr),
      };
    } else {
      orderDateTime = (data['deliveryDate'] as Timestamp).toDate();
      timeStr = data['deliveryTime'] ?? '00:00';
      type = 'Delivery';
      details = {
        'package': data['package'] ?? {},
        'deliveryTime': timeStr,
        'pickupCity': data['pickupCity'] ?? 'N/A',
        'dropoffCity': data['dropoffCity'] ?? 'N/A',
        'sourceLocation': data['package']?['sourceLocation'],
        'destinationLocation': data['package']?['destinationLocation'],
        'formattedDateTime': _formatDateTime(orderDateTime, timeStr),
      };
    }

    return ActiveOrder(
      id: doc.id,
      type: type,
      dateTime: orderDateTime,
      status: data['status'] ?? 'Pending',
      details: details,
    );
  }

  // Add this static helper method to format the date and time
  static String _formatDateTime(DateTime date, String timeStr) {
    final formattedDate = DateFormat('MMM dd, yyyy').format(date);
    return '$formattedDate at $timeStr';
  }
}

final Map<String, dynamic> newOrder = {
  "pickupLocation": {
    "latitude": 51.5074,
    "longitude": -0.1278
  },
  "dropoffLocation": {
    "latitude": 51.5074,
    "longitude": -0.1278
  },
  "type": "Trip",
  "status": "confirmed",
  "passengers": [
    {
      "id": 1,
      "name": "Passenger 1",
      "pickupLocation": {
        "latitude": 37.7749,
        "longitude": -122.4194
      },
      "dropoffLocation": {
        "latitude": 37.7858,
        "longitude": -122.4064
      }
    },
    {
      "id": 2,
      "name": "Passenger 2",
      "pickupLocation": {
        "latitude": 37.7849,
        "longitude": -122.4294
      },
      "dropoffLocation": {
        "latitude": 37.7958,
        "longitude": -122.4164
      }
    }
  ],
  "passengerDetails": {
    "name": "John Doe",
    "phone": "+1234567890"
  }
};
