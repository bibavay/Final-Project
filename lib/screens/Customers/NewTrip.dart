import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/location_picker.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/pricing_calculator.dart';
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
            // Replace radio buttons with this dropdown
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Passenger ${index + 1}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                // Remove passenger button
                if (passengers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => setState(() {
                      passengers.removeAt(index);
                      ageControllers[index].dispose();
                      ageControllers.removeAt(index);
                    }),
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
                labelText: 'Age',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => passengers[index].age = int.tryParse(value),
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
            const SizedBox(height: 16),
            Column(
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
                      },
                      itemBuilder: (context) => kurdistanCities.keys
                          .map((city) => PopupMenuItem<String>(
                                value: city,
                                child: Text(city),
                              ))
                          .toList(),
                    ),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please select pickup city' : null,
                ),
                const SizedBox(height: 16),
                // Pickup Region Selection
                TextFormField(
                  controller: _pickupRegionController,
                  enabled: selectedPickupCity != null,
                  decoration: InputDecoration(
                    labelText: 'Pickup Region',
                    hintText: selectedPickupCity == null 
                        ? 'Select a city first' 
                        : 'Select region in ${selectedPickupCity}',
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
                                .map((region) => PopupMenuItem<String>(
                                      value: region,
                                      child: Text(region),
                                    ))
                                .toList(),
                          ),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please select pickup region' : null,
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
                    labelText: 'Drop-off City',
                    hintText: 'Select Drop-off City',
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
                          selectedDropoffCity = value;
                          selectedDropoffRegion = null;
                          _dropoffCityController.text = value;
                          _dropoffRegionController.clear();
                        });
                      },
                      itemBuilder: (context) => kurdistanCities.keys
                          .map((city) => PopupMenuItem<String>(
                                value: city,
                                child: Text(city),
                              ))
                          .toList(),
                    ),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please select drop-off city' : null,
                ),
                const SizedBox(height: 16),
                // Drop-off Region Selection
                TextFormField(
                  controller: _dropoffRegionController,
                  enabled: selectedDropoffCity != null,
                  decoration: InputDecoration(
                    labelText: 'Drop-off Region',
                    hintText: selectedDropoffCity == null 
                        ? 'Select a city first' 
                        : 'Select region in ${selectedDropoffCity}',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: selectedDropoffCity == null 
                        ? null 
                        : PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down),
                            onSelected: (String value) {
                              setState(() {
                                selectedDropoffRegion = value;
                                _dropoffRegionController.text = value;
                              });
                            },
                            itemBuilder: (context) => kurdistanCities[selectedDropoffCity]!
                                .map((region) => PopupMenuItem<String>(
                                      value: region,
                                      child: Text(region),
                                    ))
                                .toList(),
                          ),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please select drop-off region' : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Price Preview Card
            if (_pickupCityController.text.isNotEmpty && 
                _dropoffCityController.text.isNotEmpty &&
                passengers.isNotEmpty)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payments, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Estimated Price',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${NumberFormat.currency(
                        symbol: 'IQD ',
                        decimalDigits: 0,
                      ).format(PricingCalculator.calculateTripPrice(
                        sourceCity: _pickupCityController.text,
                        destinationCity: _dropoffCityController.text,
                        passengerCount: passengers.length,
                      ))}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Price includes base fare and ${passengers.length} passenger${passengers.length > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (passengers.length > 1)
                      Text(
                        'Group discount applied: ${((passengers.length - 1) * PricingCalculator.additionalPassengerDiscount * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.green),
                      ),
                  ],
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
    if (tripDate == null || tripTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select trip date and time')),
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
          // Add these new fields
          'pickupCity': _pickupCityController.text,
          'pickupRegion': _pickupRegionController.text,
          'dropoffCity': _dropoffCityController.text,
          'dropoffRegion': _dropoffRegionController.text,
        };
      }).toList();

      // Rest of the saving logic remains the same
      await FirebaseFirestore.instance.collection('trips').add({
        'userId': user.uid,
        'passengers': passengersData,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
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
      appBar: AppBar(
        title: const Text('New Trip'),
      ),
      body: SingleChildScrollView(
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
                    Icon(Icons.info_outline, color: Colors.blue[700]),
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
                              color: Colors.blue[900],
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
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  tripDate == null 
                      ? 'Select Trip Date' 
                      : '${tripDate!.day}/${tripDate!.month}/${tripDate!.year}'
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) {
                    setState(() => tripDate = date);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(
                  tripTime == null 
                      ? 'Select Trip Time' 
                      : tripTime!.format(context)
                ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    // Validate time between 6 AM and 10 PM
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
                  }
                },
                subtitle: const Text('Available hours: 6:00 AM - 10:00 PM'),
              ),
            ),
            // Add Time Notice Card
            
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
              onTap: () => setState(() {
                passengers.add(Passenger());
                ageControllers.add(TextEditingController());
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add, color: Colors.blue[700], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Add Passenger (${passengers.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
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
}