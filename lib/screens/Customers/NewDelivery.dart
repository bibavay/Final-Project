import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/location_picker.dart';
import 'package:flutter_application_4th_year_project/service/firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NewDelivery extends StatefulWidget {
  const NewDelivery({super.key});

  @override
  State<NewDelivery> createState() => _NewDeliveryState();
}

class Package {
  double? height;
  double? width;
  double? depth;
  double? weight;
  LatLng? sourceLocation;
  LatLng? destinationLocation;
  bool isSelectingSource = true;
  bool isComplete = false;
}

class _NewDeliveryState extends State<NewDelivery> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  final mapController = MapController();
  DateTime? deliveryDate;
  TimeOfDay? deliveryTime;
  Package package = Package();
  bool _showMap = false;
  
  final _heightController = TextEditingController();
  final _widthController = TextEditingController();
  final _depthController = TextEditingController();
  final _weightController = TextEditingController();
  
  List<LatLng> routePoints = [];

  @override
  void dispose() {
    _heightController.dispose();
    _widthController.dispose();
    _depthController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _checkPackageComplete() {
    setState(() {
      package.isComplete = 
          package.height != null && 
          package.width != null &&
          package.depth != null &&
          package.weight != null;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      setState(() {
        package.sourceLocation = LatLng(position.latitude, position.longitude);
        mapController.move(package.sourceLocation!, 15.0);
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _saveDelivery() async {
  // Check authentication first
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('Debug: No user logged in');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please login to create a delivery'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  print('Debug: User logged in with ID: ${user.uid}');

  if (deliveryDate == null || deliveryTime == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select delivery date and time')),
    );
    return;
  }

  if (!package.isComplete || 
      package.sourceLocation == null || 
      package.destinationLocation == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please complete all delivery details'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    print('Debug: Creating delivery document');
    final deliveryRef = await FirebaseFirestore.instance.collection('deliveries').add({
      'userId': user.uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryDate': Timestamp.fromDate(deliveryDate!),
      'deliveryTime': '${deliveryTime!.hour}:${deliveryTime!.minute}',
      'package': {
        'dimensions': {
          'height': package.height,
          'width': package.width,
          'depth': package.depth,
          'weight': package.weight,
        },
        'sourceLocation': GeoPoint(
          package.sourceLocation!.latitude,
          package.sourceLocation!.longitude,
        ),
        'destinationLocation': GeoPoint(
          package.destinationLocation!.latitude,
          package.destinationLocation!.longitude,
        ),
      },
    });

    print('Debug: Delivery created with ID: ${deliveryRef.id}');

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery request created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print('Debug: Error creating delivery: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error creating delivery: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Widget _buildLocationButtons() {
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
                Icon(Icons.location_on, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Delivery Locations',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                  setState(() => package.sourceLocation = result);
                }
              },
              icon: const Icon(Icons.my_location, color: Colors.white),
              label: Text(
                package.sourceLocation == null 
                    ? 'Select Pickup Location' 
                    : 'Change Pickup Location',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 27, 135, 189),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 37),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      initialLocation: package.destinationLocation,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() => package.destinationLocation = result);
                }
              },
              icon: const Icon(Icons.place, color: Colors.white),
              label: Text(
                package.destinationLocation == null 
                    ? 'Select Drop-off Location' 
                    : 'Change Drop-off Location',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(217, 244, 67, 54),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Delivery'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
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
                                'Delivery Guidelines',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Please provide accurate package dimensions and weight. Ensure pickup and delivery locations are correct for proper delivery handling.',
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
                    leading: const Icon(Icons.calendar_today,color: Colors.blueAccent,),
                    title: Text(
                      deliveryDate == null 
                          ? 'Select Delivery Date' 
                          : '${deliveryDate!.day}/${deliveryDate!.month}/${deliveryDate!.year}'
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setState(() => deliveryDate = date);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.blueAccent),
                    title: Text(
                      deliveryTime == null 
                          ? 'Select Delivery Time' 
                          : deliveryTime!.format(context)
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (BuildContext context, Widget? child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                            child: child!,
                          );
                        },
                      );
                      
                      if (time != null) {
                        // Check if time is within business hours
                        if (time.hour < 8 || time.hour >= 20) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a time between 8:00 AM and 8:00 PM'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        setState(() => deliveryTime = time);
                      }
                    },
                    subtitle: const Text('Business hours: 8:00 AM - 8:00 PM'),
                  ),
                ),
                const SizedBox(height: 16),
                // Package Dimensions Form
                _buildPackageDimensions(),
                const SizedBox(height: 16),
                _buildLocationButtons(),
                if (_showMap) ...[
                  const SizedBox(height: 16),
                  Stack(
                    children: [
                      SizedBox(
                        height: 300,
                        child: FlutterMap(
                          mapController: mapController,
                          options: MapOptions(
                            center: LatLng(51.5, -0.09),
                            zoom: 13.0,
                            onTap: (tapPosition, point) {
                              setState(() {
                                if (package.isSelectingSource) {
                                  package.sourceLocation = point;
                                } else {
                                  package.destinationLocation = point;
                                }
                                
                                // Get route when both points are set
                                if (package.sourceLocation != null && 
                                    package.destinationLocation != null) {
                                  _getRoute(
                                    package.sourceLocation!,
                                    package.destinationLocation!
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
                                if (package.sourceLocation != null)
                                  Marker(
                                    width: 40.0,
                                    height: 40.0,
                                    point: package.sourceLocation!,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.blue,
                                      size: 40,
                                    ),
                                  ),
                                if (package.destinationLocation != null)
                                  Marker(
                                    width: 40.0,
                                    height: 40.0,
                                    point: package.destinationLocation!,
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
                      Positioned(
                        top: 8,
                        right: 8,
                        child: FloatingActionButton(
                          mini: true,
                          child: const Icon(Icons.close),
                          onPressed: () => setState(() => _showMap = false),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Confirm Button
                Container(
                  width: 300,
                  child: ElevatedButton.icon(
                    onPressed: _saveDelivery,
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Confirm Delivery', style: TextStyle(color: Colors.white)),
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
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
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
  
  Widget _buildPackageDimensions() {
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
                Icon(Icons.category, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Package Dimensions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    decoration: InputDecoration(
                      labelText: 'Height',
                      suffixText: 'cm',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.height),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      package.height = double.tryParse(value);
                      _checkPackageComplete();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _widthController,
                    decoration: InputDecoration(
                      labelText: 'Width',
                      suffixText: 'cm',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.width_normal),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      package.width = double.tryParse(value);
                      _checkPackageComplete();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _depthController,
                    decoration: InputDecoration(
                      labelText: 'Depth',
                      suffixText: 'cm',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.square_foot),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      package.depth = double.tryParse(value);
                      _checkPackageComplete();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    decoration: InputDecoration(
                      labelText: 'Weight',
                      suffixText: 'kg',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.scale),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      package.weight = double.tryParse(value);
                      _checkPackageComplete();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}