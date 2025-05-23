import 'package:flutter/material.dart';
import 'package:transportaion_and_delivery/screens/Customers/location_picker.dart';
import 'package:transportaion_and_delivery/service/firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
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
  bool _showValidationErrors = false;

  final mapController = MapController();
  DateTime? deliveryDate;
  TimeOfDay? deliveryTime;
  Package package = Package();
  bool _showMap = false;
  
  final _heightController = TextEditingController();
  final _widthController = TextEditingController();
  final _depthController = TextEditingController();
  final _weightController = TextEditingController();
  
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

  List<LatLng> routePoints = [];

  // Add Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double? estimatedPrice;
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
      'Halabja': 385.0,
    },
    'Halabja': {
      'Erbil': 240.0,
      'Sulaymaniyah': 75.0,
      'Duhok': 385.0,
    },
  };
  
  @override
  void initState() {
    super.initState();
    _checkFirestoreCollection();
  }

  Future<void> _checkFirestoreCollection() async {
    try {
      // Check if collection exists
      final deliveriesRef = _firestore.collection('deliveries');
      final snapshot = await deliveriesRef.limit(1).get();
      
      print('Deliveries collection exists: ${snapshot.docs.isNotEmpty}');
      
      // Create collection if doesn't exist
      if (snapshot.docs.isEmpty) {
        print('Creating deliveries collection...');
        await deliveriesRef.doc('placeholder').set({
          'created': FieldValue.serverTimestamp(),
          'type': 'placeholder'
        });
        await deliveriesRef.doc('placeholder').delete();
      }
    } catch (e) {
      print('Error checking Firestore collection: $e');
    }
  }

  @override
  void dispose() {
    _pickupCityController.dispose();
    _pickupRegionController.dispose();
    _dropoffCityController.dispose();
    _dropoffRegionController.dispose();
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
    setState(() {
      _showValidationErrors = true; // Show validation errors on submit attempt
    });

    // Validate package dimensions
    if (package.height == null || 
        package.width == null || 
        package.depth == null || 
        package.weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all package dimensions and weight'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate locations
    if (_pickupCityController.text.isEmpty || 
        _pickupRegionController.text.isEmpty ||
        _dropoffCityController.text.isEmpty || 
        _dropoffRegionController.text.isEmpty ||
        package.sourceLocation == null ||
        package.destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all pickup and drop-off locations'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate date and time
    if (deliveryDate == null || deliveryTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select delivery date and time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user's phone number from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userPhone = userDoc.data()?['phone'] as String?;

      await FirebaseFirestore.instance.collection('deliveries').add({
        'userId': user.uid,
        'userPhone': userPhone, // Add user's phone number
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'deliveryDate': Timestamp.fromDate(deliveryDate!),
        'deliveryTime': '${deliveryTime!.hour}:${deliveryTime!.minute}',
        'estimatedPrice': estimatedPrice,
        'package': {
          'dimensions': {
            'height': package.height,
            'width': package.width,
            'depth': package.depth,
            'weight': package.weight,
          },
          'locations': {
            'source': {
              'coordinates': GeoPoint(
                package.sourceLocation!.latitude,
                package.sourceLocation!.longitude,
              ),
              'city': _pickupCityController.text,
              'region': _pickupRegionController.text,
            },
            'destination': {
              'coordinates': GeoPoint(
                package.destinationLocation!.latitude,
                package.destinationLocation!.longitude,
              ),
              'city': _dropoffCityController.text,
              'region': _dropoffRegionController.text,
            }
          },
        },
        'routeDetails': {
          'pickupCity': _pickupCityController.text,
          'pickupRegion': _pickupRegionController.text,
          'dropoffCity': _dropoffCityController.text,
          'dropoffRegion': _dropoffRegionController.text,
        },
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                Icon(Icons.location_on, color: Color.fromARGB(255, 3, 76, 83)),
                const SizedBox(width: 8),
                const Text(
                  'Delivery Locations',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Pickup Location Details
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
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                errorStyle: const TextStyle(color: Colors.red),
                helperText: _showValidationErrors && _pickupCityController.text.isEmpty 
                    ? 'Pickup governorate is required' 
                    : null,
                helperStyle: const TextStyle(color: Colors.red),
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (String value) {
                    setState(() {
                      selectedPickupCity = value;
                      selectedPickupRegion = null;
                      _pickupCityController.text = value;
                      _pickupRegionController.clear();
                      _calculateEstimatedPrice();
                    });
                    _calculateEstimatedPrice();
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
                labelText: 'Pickup District',
                hintText: selectedPickupCity == null 
                    ? 'Select a governorate first' 
                    : 'Select district in ${selectedPickupCity}',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                errorStyle: const TextStyle(color: Colors.red),
                helperText: _showValidationErrors && _pickupRegionController.text.isEmpty 
                    ? 'Pickup district is required' 
                    : null,
                helperStyle: const TextStyle(color: Colors.red),
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
            
            // Drop-off Location Details
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
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                errorStyle: const TextStyle(color: Colors.red),
                helperText: _showValidationErrors && _dropoffCityController.text.isEmpty 
                    ? 'Drop-off governorate is required' 
                    : null,
                helperStyle: const TextStyle(color: Colors.red),
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (String value) {
                    setState(() {
                      selectedDropoffCity = value;
                      selectedDropoffRegion = null;
                      _dropoffCityController.text = value;
                      _dropoffRegionController.clear();
                      _calculateEstimatedPrice();
                    });
                    _calculateEstimatedPrice();
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
                labelText: 'Drop-off District',
                hintText: selectedDropoffCity == null 
                    ? 'Select a Governorate first' 
                    : 'Select District in ${selectedDropoffCity}',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                errorStyle: const TextStyle(color: Colors.red),
                helperText: _showValidationErrors && _dropoffRegionController.text.isEmpty 
                    ? 'Drop-off district is required' 
                    : null,
                helperStyle: const TextStyle(color: Colors.red),
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
            
            const SizedBox(height: 20),
            
            // Existing location buttons
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
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color.fromARGB(255, 3, 76, 83),
        title: const Text('New Delivery',style: TextStyle(color: Colors.white),),
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
                        Icon(Icons.info_outline, color:Color.fromARGB(255, 3, 76, 83)),
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
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.calendar_today,
                          color: deliveryDate != null ? Color.fromARGB(255, 3, 76, 83) : Colors.grey
                        ),
                        title: Text(
                          deliveryDate == null 
                              ? 'Select Delivery Date' 
                              : '${deliveryDate!.day}/${deliveryDate!.month}/${deliveryDate!.year}'
                        ),
                        trailing: _showValidationErrors 
                            ? Icon(
                                deliveryDate != null 
                                    ? Icons.check_circle 
                                    : Icons.error_outline,
                                color: deliveryDate != null 
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
                            setState(() => deliveryDate = date);
                            _calculateEstimatedPrice();
                          }
                        },
                        subtitle: _showValidationErrors && deliveryDate == null
                            ? Text(
                                'Delivery date is required',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                            )
                            : null,
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
                          color: deliveryTime != null ? Color.fromARGB(255, 3, 76, 83) : Colors.grey
                        ),
                        title: Text(
                          deliveryTime == null 
                              ? 'Select Delivery Time' 
                              : deliveryTime!.format(context)
                        ),
                        trailing: _showValidationErrors
                            ? Icon(
                                deliveryTime != null 
                                    ? Icons.check_circle 
                                    : Icons.error_outline,
                                color: deliveryTime != null 
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
                            setState(() => deliveryTime = time);
                            _calculateEstimatedPrice();
                          }
                        },
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_showValidationErrors && deliveryTime == null)
                              Text(
                                'Delivery time is required',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            Text(
                              'Business hours: 6:00 AM - 10:00 PM',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                _buildPriceEstimation(),
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
                       backgroundColor: const Color.fromARGB(255, 3, 76, 83),
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
                Icon(Icons.category, color: Color.fromARGB(255, 3, 76, 83)),
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
                      errorStyle: const TextStyle(color: Colors.red),
                      helperText: _showValidationErrors && package.height == null 
                          ? 'Height is required' 
                          : null,
                      helperStyle: const TextStyle(color: Colors.red),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.height),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      package.height = double.tryParse(value);
                      _checkPackageComplete();
                      _calculateEstimatedPrice();
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
                      errorStyle: const TextStyle(color: Colors.red),
                      helperText: _showValidationErrors && package.width == null 
                          ? 'Width is required' 
                          : null,
                      helperStyle: const TextStyle(color: Colors.red),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.width_normal),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      package.width = double.tryParse(value);
                      _checkPackageComplete();
                      _calculateEstimatedPrice();
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
                      errorStyle: const TextStyle(color: Colors.red),
                      helperText: _showValidationErrors && package.depth == null 
                          ? 'Depth is required' 
                          : null,
                      helperStyle: const TextStyle(color: Colors.red),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.square_foot),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      package.depth = double.tryParse(value);
                      _checkPackageComplete();
                      _calculateEstimatedPrice();
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
                      errorStyle: const TextStyle(color: Colors.red),
                      helperText: _showValidationErrors && package.weight == null 
                          ? 'Weight is required' 
                          : null,
                      helperStyle: const TextStyle(color: Colors.red),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.scale),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      package.weight = double.tryParse(value);
                      _checkPackageComplete();
                      _calculateEstimatedPrice();
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

  void _calculateEstimatedPrice() {
    if (selectedPickupCity == null || 
        selectedDropoffCity == null ||
        package.weight == null ||
        package.height == null ||
        package.width == null ||
        package.depth == null) {
      setState(() => estimatedPrice = null);
      return;
    }

    // Base price (starting cost)
    double basePrice = 3000.0; // Base price in IQD

    // Distance pricing
    double distancePrice = 0.0;
    if (selectedPickupCity != selectedDropoffCity) {
      // Get distance between cities from the cityDistances map
      double? distance = cityDistances[selectedPickupCity]?[selectedDropoffCity];
      if (distance != null) {
        // Price per kilometer (50 IQD per km)
        distancePrice = distance * 50.0;
      }
    }

    // Volume calculation (in cubic centimeters)
    double volume = package.height! * package.width! * package.depth!;
    
    // Volume pricing tiers (price per 1000 cubic cm)
    double volumePrice;
    if (volume <= 1000) {
      volumePrice = 1000.0;
    } else if (volume <= 5000) {
      volumePrice = 2000.0;
    } else if (volume <= 10000) {
      volumePrice = 3000.0;
    } else {
      volumePrice = 4000.0 + ((volume - 10000) / 1000).ceil() * 500.0;
    }

    // Weight pricing tiers (in kg)
    double weightPrice;
    if (package.weight! <= 1) {
      weightPrice = 1000.0;
    } else if (package.weight! <= 3) {
      weightPrice = 2000.0;
    } else if (package.weight! <= 5) {
      weightPrice = 3000.0;
    } else if (package.weight! <= 10) {
      weightPrice = 5000.0;
    } else {
      weightPrice = 5000.0 + ((package.weight! - 10) * 1000.0);
    }

    // Special handling fee for large or heavy items
    double specialHandlingFee = 0.0;
    if (package.weight! > 20 || volume > 50000) {
      specialHandlingFee = 5000.0;
    }

    // Same-day delivery premium (if delivery is scheduled for today)
    double urgencyFee = 0.0;
    if (deliveryDate?.day == DateTime.now().day) {
      urgencyFee = 2000.0;
    }

    // Calculate total price
    double totalPrice = basePrice + distancePrice + volumePrice + weightPrice + specialHandlingFee + urgencyFee;

    // Round up to nearest 500 IQD
    totalPrice = (totalPrice / 500).ceil() * 500;

    setState(() {
      estimatedPrice = totalPrice;
    });
  }

  Widget _buildPriceEstimation() {
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
                  'Estimated Price',
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
              Text('• Base delivery fee: 3,000 IQD'),
              if (selectedPickupCity != selectedDropoffCity)
                Text('• Distance fee: Based on ${cityDistances[selectedPickupCity]?[selectedDropoffCity]} km'),
              Text('• Volume and weight handling'),
              if (deliveryDate?.day == DateTime.now().day)
                Text('• Same-day delivery fee: 2,000 IQD'),
              const SizedBox(height: 12),
              const Text(
                'Note: Final price may vary based on actual weight and dimensions',
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