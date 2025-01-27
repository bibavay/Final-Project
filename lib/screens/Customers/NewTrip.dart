import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final MapController mapController = MapController();
  LatLng? sourceLocation;
  LatLng? destinationLocation;
  bool isSelectingSource = true;
  final List<MapController> mapControllers = [];

  @override
  void initState() {
    super.initState();
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
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
                icon: const Icon(Icons.location_on),
                label: const Text('Pick Up'),
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
                icon: const Icon(Icons.location_on),
                label: const Text('Drop Off'),
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
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Passenger ${index + 1}', 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPassengerMap(index),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Gender'),
              value: passengers[index].gender,
              items: ['Male', 'Female']
                  .map((gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  passengers[index].gender = value;
                  _checkPassengerComplete(index);
                });
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: ageControllers[index],
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                passengers[index].age = int.tryParse(value);
                _checkPassengerComplete(index);
              },
            ),
            SizedBox(height: 8),
            if (passengers[index].isComplete && index == passengers.length - 1)
             ElevatedButton.icon(
onPressed: _addNewPassenger,
style: ElevatedButton.styleFrom(
backgroundColor: const Color.fromARGB(224, 228, 216, 1),
foregroundColor: Colors.white,
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(8),
),
elevation: 2,
),
icon: const Icon(Icons.person_add),
label: const Text(
'Add Another Passenger',
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.bold,
),
),
),
          ],
        ),
      ),
    );
  }

  void _checkPassengerComplete(int index) {
    setState(() {
      passengers[index].isComplete = 
          passengers[index].gender != null && 
          passengers[index].age != null;
    });
  }

  void _addNewPassenger() {
    setState(() {
      passengers.add(Passenger());
      ageControllers.add(TextEditingController());
    });
  }

  Future<void> _saveTrip() async {
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
        };
      }).toList();

      await FirebaseFirestore.instance.collection('trips').add({
        'userId': user.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'passengers': passengersData,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating trip: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Trip')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: passengers.length,
                itemBuilder: (context, index) => _buildPassengerCard(index),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveTrip,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm Trip'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blue[700],
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
}