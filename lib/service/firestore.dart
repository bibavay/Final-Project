import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class FirestoreService {
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
  }) async {
    final docRef = await deliveries.add({
      'userId': userId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryDate': Timestamp.fromDate(deliveryDate),
      'deliveryTime': '${deliveryTime.hour}:${deliveryTime.minute}',
      'package': {
        'dimensions': {
          'height': package['dimensions']['height'],
          'width': package['dimensions']['width'],
          'depth': package['dimensions']['depth'],
          'weight': package['dimensions']['weight'],
        },
        'sourceLocation': GeoPoint(
          package['sourceLocation'].latitude,
          package['sourceLocation'].longitude,
        ),
        'destinationLocation': GeoPoint(
          package['destinationLocation'].latitude,
          package['destinationLocation'].longitude,
        ),
      },
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

  Future<void> completeDelivery(String deliveryId) async {
    await deliveries.doc(deliveryId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
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
    
    if (data['tripDate'] != null) {
      orderDateTime = (data['tripDate'] as Timestamp).toDate();
    } else if (data['deliveryDate'] != null) {
      orderDateTime = (data['deliveryDate'] as Timestamp).toDate();
    } else {
      orderDateTime = DateTime.now();
    }

    final isTrip = data['passengers'] != null;
    final details = isTrip 
        ? data 
        : {'package': data['package'], 'deliveryTime': data['deliveryTime']};

    return ActiveOrder(
      id: doc.id,
      type: isTrip ? 'Trip' : 'Delivery',
      dateTime: orderDateTime,
      status: data['status'] ?? 'Pending',
      details: details,
    );
  }
}
