import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Droute extends StatefulWidget {
  final Map<String, dynamic> orderDetails;
  final String orderType;

  const Droute({
    Key? key,
    required this.orderDetails,
    required this.orderType,
  }) : super(key: key);

  @override
  State<Droute> createState() => _DrouteState();
}

class _DrouteState extends State<Droute> {
  MapController? _mapController;  // Make nullable
  List<LatLng> _routePoints = [];
  bool _isLoading = true;
  String? _error;
  late ScaffoldMessengerState _scaffoldMessenger;
  bool _isMapReady = false;
  String? _selectedPassengerId; // Changed from int? to String?
  List<Map<String, dynamic>> _passengers = [];
  bool _disposed = false;  // Add disposed flag

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void initState() {
    super.initState();
    // Add detailed logging of order details
    print('Initializing Droute with full order details:');
    print('Order Type: ${widget.orderType}');
    widget.orderDetails.forEach((key, value) {
      print('$key: $value');
    });
    
    // Validate order details
    if (widget.orderDetails['orderId'] == null) {
      // Set a default error state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _error = 'Invalid order details: Missing orderId';
          _isLoading = false;
        });
      });
      return;
    }
    
    _mapController = MapController();
    _initializeMap();
  }

  @override
  void dispose() {
    _disposed = true;
    _mapController = null;  // Remove reference to controller
    super.dispose();
  }

  Future<void> _loadPassengers() async {
    try {
      print('Starting to fetch passengers...');
      final firestore = FirebaseFirestore.instance;
      
      final orderId = widget.orderDetails['orderId'];
      print('Order ID being used: $orderId');
      
      if (orderId == null) {
        throw Exception('Cannot load passengers: Order ID is null. Please ensure order details are properly passed to the Droute widget.');
      }

      final passengersSnapshot = await firestore
          .collection('trips')
          .doc(orderId)
          .collection('passengers')
          .get();

      print('Firestore query completed. Documents found: ${passengersSnapshot.docs.length}');

      if (passengersSnapshot.docs.isEmpty) {
        throw Exception('No passengers found for order ID: ${widget.orderDetails['orderId']}');
      }

      final passengers = passengersSnapshot.docs.map((doc) {
        final data = doc.data();
        print('Processing passenger document: ${doc.id}');
        print('Passenger data: $data');
        
        if (data['pickupLocation'] == null || data['dropoffLocation'] == null) {
          throw Exception('Missing location data for passenger ${doc.id}');
        }

        return {
          'id': doc.id,
          'pickupLocation': data['pickupLocation'],
          'dropoffLocation': data['dropoffLocation'],
          'name': data['name'] ?? 'Passenger',
          'isPickedUp': data['isPickedUp'] ?? false,
        };
      }).toList();

      if (!_disposed) {
        setState(() {
          _passengers = passengers;
          _isLoading = false;
        });

        print('Successfully loaded ${_passengers.length} passengers');
        await _loadAllPassengerRoutes();
      }
    } catch (e, stackTrace) {
      print('Error in _loadPassengers: $e');
      print('Stack trace: $stackTrace');
      if (!_disposed) {
        _showError('Error loading passengers: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectPassenger(String passengerId) async {
    try {
      final passenger = _passengers.firstWhere(
        (p) => p['id'].toString() == passengerId,
        orElse: () => throw Exception('Passenger not found'),
      );

      setState(() {
        _selectedPassengerId = passengerId;
        _isLoading = true;
      });

      await _loadRoutePoints(passenger);
    } catch (e) {
      print('Error selecting passenger: $e');
      _showError('Error loading passenger route: $e');
    }
  }

  Future<void> _loadAllPassengerRoutes() async {
    try {
      List<LatLng> allRoutePoints = [];
      for (var passenger in _passengers) {
        final pickupLocation = passenger['pickupLocation'];
        final dropoffLocation = passenger['dropoffLocation'];

        if (pickupLocation != null && dropoffLocation != null) {
          final pickup = LatLng(
            double.parse(pickupLocation['latitude'].toString()),
            double.parse(pickupLocation['longitude'].toString()),
          );
          final dropoff = LatLng(
            double.parse(dropoffLocation['latitude'].toString()),
            double.parse(dropoffLocation['longitude'].toString()),
          );

          final routePoints = await _getRoutePoints(pickup, dropoff);
          allRoutePoints.addAll(routePoints);
        }
      }

      if (mounted && !_disposed && _mapController != null) {
        setState(() {
          _routePoints = allRoutePoints;
          _isLoading = false;
          _error = null;
        });

        // Update map view
        if (_isMapReady) {
          _mapController!.fitBounds(
            LatLngBounds.fromPoints(_routePoints),
            options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
          );
        }
      }
    } catch (e) {
      print('Error loading all passenger routes: $e');
      if (mounted && !_disposed) {
        _showError('Failed to load all passenger routes: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRoutePoints(Map<String, dynamic> passenger) async {
    if (_disposed) return;
    try {
      print('Loading route for passenger with details: $passenger');

      // Get locations from passenger data
      final pickupLocation = passenger['pickupLocation'];
      final dropoffLocation = passenger['dropoffLocation'];

      if (pickupLocation == null || dropoffLocation == null) {
        throw Exception('Location data missing in passenger details');
      }

      print('Pickup location data: $pickupLocation');
      print('Dropoff location data: $dropoffLocation');

      // Parse coordinates
      final pickup = LatLng(
        double.parse(pickupLocation['latitude'].toString()),
        double.parse(pickupLocation['longitude'].toString())
      );

      final dropoff = LatLng(
        double.parse(dropoffLocation['latitude'].toString()),
        double.parse(dropoffLocation['longitude'].toString())
      );

      print('Parsed coordinates - Pickup: $pickup, Dropoff: $dropoff');

      // Get route points
      final routePoints = await _getRoutePoints(pickup, dropoff);
      
      if (mounted && !_disposed && _mapController != null) {
        setState(() {
          _routePoints = routePoints;
          _isLoading = false;
          _error = null;
        });

        // Update map view
        if (_isMapReady) {
          _mapController!.fitBounds(
            LatLngBounds.fromPoints(_routePoints),
            options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
          );
        }
      }
    } catch (e) {
      print('Error loading route: $e');
      if (mounted && !_disposed) {
        _showError('Failed to load route: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _initializeMap() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_disposed) return;  // Check if disposed
      try {
        await _loadPassengers(); // Load passengers first
        if (!_disposed) {  // Check again before setState
          setState(() {
            _isMapReady = true;
          });
        }
      } catch (e) {
        if (!_disposed) {  // Check before showing error
          _showError('Error initializing map: $e');
        }
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    
    setState(() {
      _error = message;
    });

    _scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadRoutePointsFromOrderDetails() async {
    try {
      // Debug prints
      print('Loading route points...');
      print('Order Type: ${widget.orderType}');
      print('Raw Order Details: ${widget.orderDetails}');

      // Add default coordinates for testing
      final defaultLat = 51.5074;
      final defaultLng = -0.1278;

      LatLng pickup;
      LatLng dropoff;

      // For testing, use default coordinates if location is missing
      if (widget.orderDetails['pickupLocation'] == null) {
        print('Warning: Using default pickup location');
        pickup = LatLng(defaultLat, defaultLng);
      } else {
        final pickupData = widget.orderDetails['pickupLocation'];
        print('Pickup Data: $pickupData');
        
        final pickupLat = double.tryParse(pickupData['latitude'].toString()) ?? defaultLat;
        final pickupLng = double.tryParse(pickupData['longitude'].toString()) ?? defaultLng;
        
        pickup = LatLng(pickupLat, pickupLng);
      }

      if (widget.orderDetails['dropoffLocation'] == null) {
        print('Warning: Using default dropoff location');
        dropoff = LatLng(defaultLat + 0.01, defaultLng + 0.01); // Slightly offset
      } else {
        final dropoffData = widget.orderDetails['dropoffLocation'];
        print('Dropoff Data: $dropoffData');
        
        final dropoffLat = double.tryParse(dropoffData['latitude'].toString()) ?? defaultLat;
        final dropoffLng = double.tryParse(dropoffData['longitude'].toString()) ?? defaultLng;
        
        dropoff = LatLng(dropoffLat, dropoffLng);
      }

      print('Final Pickup Point: $pickup');
      print('Final Dropoff Point: $dropoff');

      // Get street route
      final routePoints = await _getRoutePoints(pickup, dropoff);
      
      setState(() {
        _routePoints = routePoints;
        _isLoading = false;
        _error = null;
      });

      // Only try to fit bounds if map is ready
      if (_isMapReady && mounted && _routePoints.isNotEmpty) {
        _mapController!.fitBounds(
          LatLngBounds.fromPoints(_routePoints),
          options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
        );
      }
    } catch (e, stackTrace) {
      print('Error loading route points: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load map: ${e.toString()}';
        });
        _showError(_error!);
      }
    }
  }

  Future<List<LatLng>> _getRoutePoints(LatLng start, LatLng end) async {
    try {
      final response = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=polyline'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final polylinePoints = PolylinePoints();
          List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(geometry);
          return decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        }
      }
      throw Exception('Failed to get route');
    } catch (e) {
      print('Error getting route: $e');
      // Return direct line if routing fails
      return [start, end];
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showError('Location services are disabled. Please enable the services');
        }
        return false;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showError('Location permissions are denied');
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showError('Location permissions are permanently denied');
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        _showError('Error checking location permission: $e');
      }
      return false;
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Failed to load map'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _loadRoutePointsFromOrderDetails(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerList() {
    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _passengers.length,
        itemBuilder: (context, index) {
          final passenger = _passengers[index];
          final isSelected = passenger['id'].toString() == _selectedPassengerId;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              onPressed: () => _selectPassenger(passenger['id'].toString()),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
                foregroundColor: isSelected ? Colors.white : Colors.black87,
              ),
              child: Text('Passenger ${index + 1}'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPassengerMarkers() {
    return MarkerLayer(
      markers: _passengers.map((passenger) {
        final pickupLocation = passenger['pickupLocation'];
        final dropoffLocation = passenger['dropoffLocation'];
        final isPickedUp = passenger['isPickedUp'] ?? false;

        return [
          // Pickup marker
          Marker(
            point: LatLng(
              double.parse(pickupLocation['latitude'].toString()),
              double.parse(pickupLocation['longitude'].toString()),
            ),
            width: 40,
            height: 40,
            child: Icon(
              Icons.person_pin,
              color: isPickedUp ? Colors.grey : Colors.blue,
            ),
          ),
          // Dropoff marker
          Marker(
            point: LatLng(
              double.parse(dropoffLocation['latitude'].toString()),
              double.parse(dropoffLocation['longitude'].toString()),
            ),
            width: 40,
            height: 40,
            child: const Icon(
              Icons.location_on,
              color: Color.fromARGB(255, 3, 173, 0),
            ),
          ),
        ];
      }).expand((marker) => marker).toList(),
    );
  }

  void _markPassengerAsPickedUp(String passengerId) {
    setState(() {
      final passengerIndex = _passengers.indexWhere((p) => p['id'].toString() == passengerId);
      if (passengerIndex != -1) {
        _passengers[passengerIndex]['isPickedUp'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.orderType} Route (${_passengers.length} passengers)'),
      ),
      body: Column(
        children: [
          // Passenger selection buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildPassengerList(),
          ),
          // Map view
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? _buildErrorWidget()
                : _mapController == null  // Check if controller exists
                    ? const Center(child: Text('Map not available'))
                    : FlutterMap(
                        mapController: _mapController!,
                        options: MapOptions(
                          initialCenter: _routePoints.isNotEmpty 
                              ? _routePoints.first 
                              : const LatLng(0, 0),
                          initialZoom: 13,
                          onMapReady: () {
                            if (_routePoints.isNotEmpty && 
                                _isMapReady && 
                                !_disposed && 
                                _mapController != null) {
                              _mapController!.fitBounds(
                                LatLngBounds.fromPoints(_routePoints),
                                options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
                              );
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app',
                          ),
                          if (_routePoints.isNotEmpty) ...[
                            _buildPassengerMarkers(),
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  color: const Color.fromARGB(255, 246, 0, 0),
                                  strokeWidth: 3,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
      // Bottom buttons
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (await _handleLocationPermission()) {
                    try {
                      final position = await Geolocator.getCurrentPosition();
                      _mapController!.move(
                        LatLng(position.latitude, position.longitude),
                        15,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error getting location: ${e.toString()}')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.my_location),
                label: const Text('My Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(0, 45),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_selectedPassengerId != null) {
                    _markPassengerAsPickedUp(_selectedPassengerId!);
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Mark Picked Up'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(0, 45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}