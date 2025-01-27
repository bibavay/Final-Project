import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  // Collections
  final CollectionReference users = FirebaseFirestore.instance.collection('users');
  final CollectionReference trips = FirebaseFirestore.instance.collection('trips');
  final CollectionReference tempUsers = FirebaseFirestore.instance.collection('tempUsers');

  // User Methods
  Future<void> addUser(String uid, String email, String userType) async {
    await users.doc(uid).set({
      'email': email,
      'userType': userType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Trip Methods
  Future<String> createTrip(String userId, List<Map<String, dynamic>> passengers) async {
    final docRef = await trips.add({
      'userId': userId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
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
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getActiveTrips() {
    return trips
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots();
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
}
