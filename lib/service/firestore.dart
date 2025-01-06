import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService{
  final CollectionReference data = FirebaseFirestore.instance.collection('User');
  Future<void> addUsers(
    String email,
    String Fname,
    String Lname,
    String password,
    String confirmPassword,
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
    await data.add({
      'Fname': Fname,
      'Lname': Lname,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
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
    });
    return;
  }
   Future<void> addUser(
    String email,
    String Fname,
    String Lname,
    String password,
    String confirmPassword,
    int phoneNumber,
    String governorate,
    String district,
    String gender,
    GeoPoint location,
    String DC,

  ) async {
    await data.add({
      'email': email,
      'Fname': Fname,
      'Lname': Lname,
      'password': password,
      'confirmPassword': confirmPassword,
      'phoneNumber': phoneNumber,
      'governorate': governorate,
      'district': district,
      'gender': gender,
      'location': location,
      'DC': DC,
    });
    return;
  }
}