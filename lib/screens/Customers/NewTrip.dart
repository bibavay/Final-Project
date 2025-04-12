import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/location_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Newtrip extends StatefulWidget {
  const Newtrip({super.key});

  @override
  State<Newtrip> createState() => _NewtripState();
}

class Passenger {
  String? gender;
  int? age;
  LatLng? sourceLocation;
  LatLng? destinationLocation;
  bool isSelectingSource = true;
  bool isComplete = false;
}

class _NewtripState extends State<Newtrip> {
  final List<Passenger> passengers = [Passenger()];
  final List<TextEditingController> ageControllers = [TextEditingController()];
  DateTime? tripDate;
  TimeOfDay? tripTime;
  List<MapController> mapControllers = [];
  LatLng? sourceLocation;
  LatLng? destinationLocation;
  bool isSelectingSource = true;
  List<LatLng> routePoints = [];
  final List<String> genderOptions = ['Male', 'Female'];

  final TextEditingController _governorateTextController = TextEditingController();
  final TextEditingController _districtTextController = TextEditingController();
  String? selectedGovernorate;
  String? selectedDistrict;

  final TextEditingController _pickupCityController = TextEditingController();
  final TextEditingController _pickupRegionController = TextEditingController();
  final TextEditingController _dropoffCityController = TextEditingController();
  final TextEditingController _dropoffRegionController = TextEditingController();
  String? selectedPickupCity;
  String? selectedPickupRegion;
  String? selectedDropoffCity;
  String? selectedDropoffRegion;

  final Map<String, List<String>> kurdistanCities = {
    'Erbil': [
      'Erbil City',
      'Shaqlawa',
      'Soran',
      'Koya',
      'Mergasur',
      'Choman',
      'Makhmur',
    ],
    'Sulaymaniyah': [
      'Sulaymaniyah City',
      'Halabja',
      'Ranya',
      'Penjwin',
      'Dukan',
      'Chamchamal',
      'Kalar',
    ],
    'Duhok': [
      'Duhok City',
      'Zakho',
      'Amedi',
      'Akre',
      'Bardarash',
      'Shekhan',
      'Semel',
    ],
    'Halabja': [
      'Halabja City',
      'Shahrizor',
      'Khurmal',
      'Sirwan',
    ],
  };

  final Map<String, Map<String, double>> cityDistances = {
    'Erbil': {
      'Sulaymaniyah': 195.0,
      'Duhok': 155.0,
      'Halabja': 240.0,
    },
    'Sulaymaniyah': {
      'Erbil': 195.0,
      'Duhok': 340.0,
      'Halabja': 75.0,
    },
    'Duhok': {
      'Erbil': 155.0,
      'Sulaymaniyah': 340.0,
      'Halabja': 395.0,
    },
    'Halabja': {
      'Erbil': 240.0,
      'Sulaymaniyah': 75.0,
      'Duhok': 395.0,
    },
  };

  double? estimatedPrice;
  int? passengerCount;

  final _formKey = GlobalKey<FormState>();

  // Add this variable to track if form was submitted
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    _showValidationErrors = false;
    mapControllers.add(MapController());
  }

  Future<void> _searchAndNavigate(String value, int index) async {
    if (value.length > 2) {
      try {
        List<Location> locations = await locationFromAddress(value);
        if (locations.isNotEmpty) {
          final point = LatLng(
            locations.first.latitude,
            locations.first.longitude,
          );
          
          mapControllers[index].move(point, 15.0);
          
          setState(() {
            if (passengers[index].isSelectingSource) {
              passengers[index].sourceLocation = point;
            } else {
              passengers[index].destinationLocation = point;
            }
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location not found: $e')),
        );
      }
    }
  }

  Future<void> _getRoute(LatLng source, LatLng destination) async {
    try {
      final response = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${source.longitude},${source.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
        
        setState(() {
          routePoints = coordinates
              .map((point) => LatLng(point[1] as double, point[0] as double))
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching route: $e');
    }
  }

  Widget _buildPassengerList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: passengers.length,
      itemBuilder: (context, index) {
        return _buildPassengerCard(index);
      },
    );
  }

  Widget _buildPassengerMap(int index) {
    if (mapControllers.length <= index) {
      mapControllers.add(MapController());
    }
//
    return Column(
      children: [
        // Search and Current Location Row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              // Search Field
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: passengers[index].isSelectingSource 
                        ? 'Search pickup location' 
                        : 'Search drop-off location',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) => _searchAndNavigate(value, index),
                ),
              ),
              // Current Location Button (only for source)
              if (passengers[index].isSelectingSource)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    onPressed: () async {
                      try {
                        final position = await Geolocator.getCurrentPosition();
                        final currentLocation = LatLng(position.latitude, position.longitude);
                        
                        setState(() {
                          passengers[index].sourceLocation = currentLocation;
                        });
                        
                        mapControllers[index].move(currentLocation, 15.0);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error getting location: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.my_location),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Map
        SizedBox(
          height: 200,
          child: FlutterMap(
            mapController: mapControllers[index],
            options: MapOptions(
              initialCenter: const LatLng(6.927079, 79.861244),
              initialZoom: 13.0,
              onTap: (tapPosition, point) {
                setState(() {
                  if (passengers[index].isSelectingSource) {
                    passengers[index].sourceLocation = point;
                  } else {
                    passengers[index].destinationLocation = point;
                  }
                  
                  // Get route when both points are set
                  if (passengers[index].sourceLocation != null && 
                      passengers[index].destinationLocation != null) {
                    _getRoute(
                      passengers[index].sourceLocation!,
                      passengers[index].destinationLocation!
                    );
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              PolylineLayer(
                polylines: [
                  if (routePoints.isNotEmpty)
                    Polyline(
                      points: routePoints,
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (passengers[index].sourceLocation != null)
                    Marker(
                      width: 40.0,
                      height: 40.0,
                      point: passengers[index].sourceLocation!,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  if (passengers[index].destinationLocation != null)
                    Marker(
                      width: 40.0,
                      height: 40.0,
                      point: passengers[index].destinationLocation!,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    passengers[index].isSelectingSource = true;
                  });
                },
                 icon: const Icon(Icons.location_on, color: Colors.white),
                label: const Text('Pick Up',style: TextStyle(color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: passengers[index].isSelectingSource 
                      ? Colors.blue 
                      : Colors.grey,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    passengers[index].isSelectingSource = false;
                  });
                },
                icon: const Icon(Icons.location_on, color: Colors.white),
                label: const Text('Drop Off',style: TextStyle(color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: !passengers[index].isSelectingSource 
                      ? Colors.red 
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerCard(int index) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Passenger ${index + 1}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (passengers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        passengers.removeAt(index);
                        ageControllers[index].dispose();
                        ageControllers.removeAt(index);
                      });
                      _calculateEstimatedTripPrice(); // Call after setState
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Gender Selection
            DropdownButtonFormField<String>(
              value: passengers[index].gender,
              decoration: InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
               
              ),
              items: [
                DropdownMenuItem(
                  value: 'Male',
                  child: Row(
                    children: const [
                      Icon(Icons.male, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Male'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'Female',
                  child: Row(
                    children: const [
                      Icon(Icons.female, color: Colors.pink),
                      SizedBox(width: 8),
                      Text('Female'),
                    ],
                  ),
                ),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  passengers[index].gender = newValue;
                });
              },
              validator: (value) {
                if (!_showValidationErrors) return null;
                if (value == null || value.isEmpty) {
                  return 'Please select gender';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Age Input
            TextFormField(
              controller: ageControllers[index],
              decoration: InputDecoration(
                labelText: 'Age', // Added asterisk to indicate required field
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                errorStyle: const TextStyle(color: Colors.red),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final age = int.tryParse(value);
                setState(() {
                  passengers[index].age = age;
                });
              },
              validator: (value) {
                if (!_showValidationErrors) return null;
                if (value == null || value.isEmpty) {
                  return 'Age is required';
                }
                final age = int.tryParse(value);
                if (age == null) {
                  return 'Please enter a valid number';
                }
                
                return null;
              },
            ),
            const SizedBox(height: 20),
            // Location Buttons
            ElevatedButton.icon(
              onPressed: () async {
                final position = await Geolocator.getCurrentPosition();
                final result = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationPickerScreen(
                      isSource: true,
                      initialLocation: LatLng(position.latitude, position.longitude),
                    ),
                  ),
                );
                if (result != null) {
                  setState(() => passengers[index].sourceLocation = result);
                }
              },
              icon: const Icon(Icons.my_location, color: Colors.white),
              label: Text(
                passengers[index].sourceLocation == null 
                    ? 'Select Pickup Location' 
                    : 'Change Pickup Location',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 34, 125, 175),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationPickerScreen(
                      isSource: false,
                      initialLocation: passengers[index].destinationLocation,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() => passengers[index].destinationLocation = result);
                }
              },
              icon: const Icon(Icons.place, color: Colors.white),
              label: Text(
                passengers[index].destinationLocation == null 
                    ? 'Select Drop-off Location' 
                    : 'Change Drop-off Location',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_showValidationErrors) ...[  // Only show when validation is triggered
              Row(
                children: [
                  Icon(
                    passengers[index].sourceLocation != null 
                        ? Icons.check_circle 
                        : Icons.error,
                    color: passengers[index].sourceLocation != null 
                        ? Colors.green 
                        : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pickup location ${passengers[index].sourceLocation != null ? 'selected' : 'required'}',
                    style: TextStyle(
                      color: passengers[index].sourceLocation != null 
                          ? Colors.green 
                          : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    passengers[index].destinationLocation != null 
                        ? Icons.check_circle 
                        : Icons.error,
                    color: passengers[index].destinationLocation != null 
                        ? Colors.green 
                        : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Drop-off location ${passengers[index].destinationLocation != null ? 'selected' : 'required'}',
                    style: TextStyle(
                      color: passengers[index].destinationLocation != null 
                          ? Colors.green 
                          : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _checkPassengerComplete(int index) {
    setState(() {
      passengers[index].isComplete = 
          passengers[index].gender != null && 
          passengers[index].age != null &&
          passengers[index].sourceLocation != null &&
          passengers[index].destinationLocation != null &&
          _pickupCityController.text.isNotEmpty &&
          _pickupRegionController.text.isNotEmpty &&
          _dropoffCityController.text.isNotEmpty &&
          _dropoffRegionController.text.isNotEmpty;
    });
  }

  void _addNewPassenger() {
    setState(() {
      passengers.add(Passenger());
      ageControllers.add(TextEditingController());
    });
  }

  Future<void> _saveTrip() async {
    setState(() {
        _showValidationErrors = true; // Show validation errors on submit attempt
    });

    if (_formKey.currentState?.validate() != true) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please fill in all required fields'),
                backgroundColor: Colors.red,
            ),
        );
        return;
    }

    // Check if all passengers have map locations selected
    bool allLocationsSelected = passengers.every((passenger) => 
        passenger.sourceLocation != null && 
        passenger.destinationLocation != null
    );

    if (!allLocationsSelected) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select pickup and drop-off points on the map for all passengers'),
                backgroundColor: Colors.red,
            ),
        );
        return;
    }

    if (_pickupCityController.text.isEmpty || 
        _pickupRegionController.text.isEmpty ||
        _dropoffCityController.text.isEmpty ||
        _dropoffRegionController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select both pickup and drop-off locations')),
        );
        return;
    }

    if (tripDate == null || tripTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select both date and time'),
                backgroundColor: Colors.red,
            ),
        );
        return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      List<Map<String, dynamic>> passengersData = passengers.map((passenger) {
        return {
          'gender': passenger.gender,
          'age': passenger.age,
          'sourceLocation': GeoPoint(
            passenger.sourceLocation?.latitude ?? 0,
            passenger.sourceLocation?.longitude ?? 0,
          ),
          'destinationLocation': GeoPoint(
            passenger.destinationLocation?.latitude ?? 0,
            passenger.destinationLocation?.longitude ?? 0,
          ),
          'pickupCity': _pickupCityController.text,
          'pickupRegion': _pickupRegionController.text,
          'dropoffCity': _dropoffCityController.text,
          'dropoffRegion': _dropoffRegionController.text,
        };
      }).toList();

      await FirebaseFirestore.instance.collection('trips').add({
        'userId': user.uid,
        'tripDate': Timestamp.fromDate(tripDate!),
        'tripTime': '${tripTime!.hour}:${tripTime!.minute}',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'passengers': passengersData,
        'pickupCity': _pickupCityController.text,
        'pickupRegion': _pickupRegionController.text,
        'dropoffCity': _dropoffCityController.text,
        'dropoffRegion': _dropoffRegionController.text,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating trip: $e')),
      );
    }
  }

  void _resetForm() {
    setState(() {
        _showValidationErrors = false;
        // Reset other form fields as needed
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('New Trip',style: TextStyle(color: Colors.white),),
            backgroundColor: const Color.fromARGB(255, 3, 76, 83),
            
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Add Notice Card
              Card(
                color: Colors.blue[50],
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color.fromARGB(255, 3, 76, 83)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Important Notice',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 3, 76, 83),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Please ensure all passenger details are accurate. Once submitted, trip details cannot be modified.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Date and Time Selection Cards
              Card(
                elevation: 2,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.calendar_today, 
                        color: tripDate != null ? Color.fromARGB(255, 3, 76, 83) : Colors.grey
                      ),
                      title: Text(
                        tripDate == null 
                            ? 'Select Trip Date' 
                            : '${tripDate!.day}/${tripDate!.month}/${tripDate!.year}'
                      ),
                      trailing: _showValidationErrors 
                          ? Icon(
                              tripDate != null 
                                  ? Icons.check_circle 
                                  : Icons.error_outline,
                              color: tripDate != null 
                                  ? Colors.green 
                                  : Colors.red,
                              size: 20,
                            )
                          : null,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (date != null) {
                          setState(() => tripDate = date);
                          _calculateEstimatedTripPrice();
                        }
                      },
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_showValidationErrors && tripDate == null)
                            Text(
                              'Trip date is required',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.access_time, 
                        color: tripTime != null ? Color.fromARGB(255, 3, 76, 83) : Colors.grey
                      ),
                      title: Text(
                        tripTime == null 
                            ? 'Select Trip Time' 
                            : tripTime!.format(context)
                      ),
                      trailing: _showValidationErrors
                          ? Icon(
                              tripTime != null 
                                  ? Icons.check_circle 
                                  : Icons.error_outline,
                              color: tripTime != null 
                                  ? Colors.green 
                                  : Colors.red,
                              size: 20,
                            )
                          : null,
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          if (time.hour < 6 || time.hour >= 22) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a time between 6:00 AM and 10:00 PM'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setState(() => tripTime = time);
                          _calculateEstimatedTripPrice();
                        }
                      },
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_showValidationErrors && tripTime == null)
                            Text(
                              'Trip time is required',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          Text(
                            'Available hours: 6:00 AM - 10:00 PM',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                color: Colors.orange[50],
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 8),
               
              ),
              const SizedBox(height: 16),
              // Add the shared location card here
              _buildSharedLocationCard(),
              const SizedBox(height: 16),
              _buildTripPriceEstimation(), // Updated widget
              const SizedBox(height: 16),
              // Existing Passenger List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: passengers.length,
                itemBuilder: (context, index) => _buildPassengerCard(index),
              ),
              const SizedBox(height: 8),
            // Add Passenger Button
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    passengers.add(Passenger());
                    ageControllers.add(TextEditingController());
                  });
                  _calculateEstimatedTripPrice(); // Call after setState
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add, color: Color.fromARGB(255, 3, 76, 83), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Add Passenger (${passengers.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:Color.fromARGB(255, 3, 76, 83),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        
              const SizedBox(height: 10),
              Container(
                width: 325,
                child: ElevatedButton.icon(
                  onPressed: _saveTrip,
                  icon: const Icon(Icons.check_circle_outline,color: Colors.white,),
                  label: const Text('Confirm Trip',style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Color.fromARGB(255, 3, 76, 83),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
                  ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _governorateTextController.dispose();
    _districtTextController.dispose();
    _pickupCityController.dispose();
    _pickupRegionController.dispose();
    _dropoffCityController.dispose();
    _dropoffRegionController.dispose();
    for (var controller in ageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _confirmTrip() {
    // Add logic to save trip details
    if (sourceLocation != null && destinationLocation != null) {
      // Save to Firebase or process trip
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip confirmed!')),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildLocationDetailsCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Location Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pickup Location Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 12),
            // Pickup City Selection
            TextFormField(
              controller: _pickupCityController,
              decoration: InputDecoration(
                labelText: 'Pickup City',
                hintText: 'Select Pickup City',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (String value) {
                    setState(() {
                      selectedPickupCity = value;
                      selectedPickupRegion = null;
                      _pickupCityController.text = value;
                      _pickupRegionController.clear();
                    });
                    _calculateEstimatedTripPrice(); // Call after setState
                  },
                  itemBuilder: (context) => kurdistanCities.keys
                      .map((governorate) => PopupMenuItem<String>(
                            value: governorate,
                            child: Text(governorate),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Pickup Region Selection
            TextFormField(
              controller: _pickupRegionController,
              enabled: selectedPickupCity != null,
              decoration: InputDecoration(
                labelText: 'Pickup Region',
                hintText: selectedPickupCity == null 
                    ? 'Select a governorate first' 
                    : 'Select district in ${selectedPickupCity}',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon: selectedPickupCity == null 
                    ? null 
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (String value) {
                          setState(() {
                            selectedPickupRegion = value;
                            _pickupRegionController.text = value;
                          });
                        },
                        itemBuilder: (context) => kurdistanCities[selectedPickupCity]!
                            .map((district) => PopupMenuItem<String>(
                                  value: district,
                                  child: Text(district),
                                ))
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Drop-off Location Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red[900],
              ),
            ),
            const SizedBox(height: 12),
            // Drop-off fields...
            // (Keep the existing drop-off TextFormFields here)
          ],
        ),
      ),
    );
  }

  Widget _buildSharedLocationCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pickup Location Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 12),
                // Pickup City Selection
                TextFormField(
                  controller: _pickupCityController,
                  decoration: InputDecoration(
                    labelText: 'Pickup Governorate',
                    hintText: 'Select Pickup Governorate',
                    errorStyle: const TextStyle(color: Colors.red),
                    prefixIcon: const Icon(Icons.location_city),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showValidationErrors)
                          Icon(
                            _pickupCityController.text.isNotEmpty 
                                ? Icons.check_circle 
                                : Icons.error_outline,
                            color: _pickupCityController.text.isNotEmpty 
                                ? Colors.green 
                                : Colors.red,
                            size: 20,
                          ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onSelected: (String value) {
                            setState(() {
                              selectedPickupCity = value;
                              selectedPickupRegion = null;
                              _pickupCityController.text = value;
                              _pickupRegionController.clear();
                            });
                            _calculateEstimatedTripPrice(); // Call after setState
                          },
                          itemBuilder: (context) => kurdistanCities.keys
                              .map((governorate) => PopupMenuItem<String>(
                                    value: governorate,
                                    child: Text(governorate),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  validator: (value) {
                    if (!_showValidationErrors) return null;
                    if (value == null || value.isEmpty) {
                      return 'Pickup governorate is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Pickup Region Selection
                TextFormField(
                  controller: _pickupRegionController,
                  enabled: selectedPickupCity != null,
                  decoration: InputDecoration(
                    labelText: 'Pickup District',
                    hintText: selectedPickupCity == null 
                        ? 'Select a governorate first' 
                        : 'Select district in ${selectedPickupCity}',
                    errorStyle: const TextStyle(color: Colors.red),
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showValidationErrors)
                          Icon(
                            _pickupRegionController.text.isNotEmpty 
                                ? Icons.check_circle 
                                : Icons.error_outline,
                            color: _pickupRegionController.text.isNotEmpty 
                                ? Colors.green 
                                : Colors.red,
                            size: 20,
                          ),
                        if (selectedPickupCity != null)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down),
                            onSelected: (String value) {
                              setState(() {
                                selectedPickupRegion = value;
                                _pickupRegionController.text = value;
                              });
                            },
                            itemBuilder: (context) => kurdistanCities[selectedPickupCity]!
                                .map((district) => PopupMenuItem<String>(
                                      value: district,
                                      child: Text(district),
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  validator: (value) {
                    if (!_showValidationErrors) return null;
                    if (value == null || value.isEmpty) {
                      return 'Pickup district is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Drop-off Location Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
                const SizedBox(height: 12),
                // Drop-off City Selection
                TextFormField(
                  controller: _dropoffCityController,
                  decoration: InputDecoration(
                    labelText: 'Drop-off Governorate',
                    hintText: 'Select Drop-off Governorate',
                    errorStyle: const TextStyle(color: Colors.red),
                    prefixIcon: const Icon(Icons.location_city),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showValidationErrors)
                          Icon(
                            _dropoffCityController.text.isNotEmpty 
                                ? Icons.check_circle 
                                : Icons.error_outline,
                            color: _dropoffCityController.text.isNotEmpty 
                                ? Colors.green 
                                : Colors.red,
                            size: 20,
                          ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onSelected: (String value) {
                            setState(() {
                              selectedDropoffCity = value;
                              selectedDropoffRegion = null;
                              _dropoffCityController.text = value;
                              _dropoffRegionController.clear();
                            });
                            _calculateEstimatedTripPrice(); // Call after setState
                          },
                          itemBuilder: (context) => kurdistanCities.keys
                              .map((governorate) => PopupMenuItem<String>(
                                    value: governorate,
                                    child: Text(governorate),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  validator: (value) {
                    if (!_showValidationErrors) return null;
                    if (value == null || value.isEmpty) {
                      return 'Drop-off governorate is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Drop-off Region Selection
                TextFormField(
                  controller: _dropoffRegionController,
                  enabled: selectedDropoffCity != null,
                  decoration: InputDecoration(
                    labelText: 'Drop-off District',
                    hintText: selectedDropoffCity == null 
                        ? 'Select a governorate first' 
                        : 'Select district in ${selectedDropoffCity}',
                    errorStyle: const TextStyle(color: Colors.red),
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showValidationErrors)
                          Icon(
                            _dropoffRegionController.text.isNotEmpty 
                                ? Icons.check_circle 
                                : Icons.error_outline,
                            color: _dropoffRegionController.text.isNotEmpty 
                                ? Colors.green 
                                : Colors.red,
                            size: 20,
                          ),
                        if (selectedDropoffCity != null)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down),
                            onSelected: (String value) {
                              setState(() {
                                selectedDropoffRegion = value;
                                _dropoffRegionController.text = value;
                              });
                            },
                            itemBuilder: (context) => kurdistanCities[selectedDropoffCity]!
                                .map((district) => PopupMenuItem<String>(
                                      value: district,
                                      child: Text(district),
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  validator: (value) {
                    if (!_showValidationErrors) return null;
                    if (value == null || value.isEmpty) {
                      return 'Drop-off district is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
      ),
    );
  }

  void _calculateEstimatedTripPrice() {
    if (selectedPickupCity == null || selectedDropoffCity == null) {
        setState(() => estimatedPrice = null);
        return;
    }

    // Base price (starting cost)
    double basePrice = 5000.0; // Base price in IQD for trips

    // Distance pricing
    double distancePrice = 0.0;
    if (selectedPickupCity != selectedDropoffCity) {
        double? distance = cityDistances[selectedPickupCity]?[selectedDropoffCity];
        if (distance != null) {
            // Price per kilometer (100 IQD per km for passenger trips)
            distancePrice = distance * 100.0;
        }
    }

    // Calculate passenger-based pricing
    double passengerPrice = 0.0;
    int numberOfPassengers = passengers.length; // Use the actual number of passengers
    
    // Price increases with each passenger
    if (numberOfPassengers == 1) {
        passengerPrice = 4000.0;
    } else if (numberOfPassengers == 2) {
        passengerPrice = 8000.0;
    } else if (numberOfPassengers == 3) {
        passengerPrice = 12000.0;
    } else if (numberOfPassengers == 4) {
        passengerPrice = 16000.0;
    } else {
        // For more than 4 passengers, add 2500 IQD per additional passenger
        passengerPrice = 8000.0 + ((numberOfPassengers - 4) * 4000.0);
    }

    // Time of day premium
    double timePremium = 0.0;
    if (tripTime != null) {
        if (tripTime!.hour < 6 || tripTime!.hour >= 22) {
            // Night time premium (per passenger)
            timePremium = 3000.0 * numberOfPassengers;
        } else if (tripTime!.hour >= 16 && tripTime!.hour < 19) {
            // Rush hour premium (per passenger)
            timePremium = 2000.0 * numberOfPassengers;
        }
    }

    // Same-day booking premium (per passenger)
    double urgencyFee = 0.0;
    if (tripDate?.day == DateTime.now().day) {
        urgencyFee = 2000.0 * numberOfPassengers;
    }

    // Calculate total price
    double totalPrice = basePrice + distancePrice + passengerPrice + timePremium + urgencyFee;

    // Round up to nearest 500 IQD
    totalPrice = (totalPrice / 500).ceil() * 500;

    setState(() {
        estimatedPrice = totalPrice;
    });
  }

  Widget _buildTripPriceEstimation() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Color.fromARGB(255, 3, 76, 83)),
                const SizedBox(width: 8),
                const Text(
                  'Estimated Trip Price',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                estimatedPrice == null 
                    ? 'Please fill in all details to see the estimated price'
                    : '${NumberFormat("#,##0").format(estimatedPrice)} IQD',
                style: TextStyle(
                  fontSize: estimatedPrice == null ? 14 : 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 3, 76, 83),
                ),
              ),
            ),
            if (estimatedPrice != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Price Breakdown:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('• Base trip fee: 5,000 IQD'),
              if (selectedPickupCity != selectedDropoffCity)
                Text('• Distance fee: Based on ${cityDistances[selectedPickupCity]?[selectedDropoffCity]} km'),
              if (passengerCount != null)
                Text('• Passenger fee (${passengerCount} passengers)'),
              if (tripTime != null && (tripTime!.hour < 6 || tripTime!.hour >= 22))
                Text('• Night time premium: 3,000 IQD'),
              if (tripTime != null && (tripTime!.hour >= 16 && tripTime!.hour < 19))
                Text('• Rush hour premium: 2,000 IQD'),
              if (tripDate?.day == DateTime.now().day)
                Text('• Same-day booking fee: 2,000 IQD'),
              const SizedBox(height: 12),
              const Text(
                'Note: Final price may vary based on actual distance and conditions',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}