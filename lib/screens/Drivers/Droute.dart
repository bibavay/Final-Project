import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Droute extends StatefulWidget {
  final String orderId;
  final String orderType; // 'Trip' or 'Delivery'

  const Droute({
    super.key, 
    required this.orderId,
    required this.orderType,
  });

  @override
  State<Droute> createState() => _DrouteState();
}

class _DrouteState extends State<Droute> {
  final mapController = MapController();
  LatLng? pickupLocation;
  LatLng? dropoffLocation;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    try {
      print('Fetching locations for order: ${widget.orderId}, type: ${widget.orderType}');
      final collection = widget.orderType == 'Trip' ? 'trips' : 'deliveries';
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.orderId)
          .get();

      if (!doc.exists) {
        print('Document does not exist');
        return;
      }

      final data = doc.data()!;
      print('Retrieved data: $data'); // Debug print
      
      if (widget.orderType == 'Trip') {
        // For trips
        if (data['pickupLocation'] != null) {
          pickupLocation = LatLng(
            data['pickupLocation']['latitude'],
            data['pickupLocation']['longitude'],
          );
        }
        if (data['dropoffLocation'] != null) {
          dropoffLocation = LatLng(
            data['dropoffLocation']['latitude'],
            data['dropoffLocation']['longitude'],
          );
        }
      } else {
        // For deliveries
        if (data['package']?['locations']?['source'] != null) {
          pickupLocation = LatLng(
            data['package']['locations']['source']['latitude'],
            data['package']['locations']['source']['longitude'],
          );
        }
        if (data['package']?['locations']?['destination'] != null) {
          dropoffLocation = LatLng(
            data['package']['locations']['destination']['latitude'],
            data['package']['locations']['destination']['longitude'],
          );
        }
      }

      print('Pickup location: $pickupLocation'); // Debug print
      print('Dropoff location: $dropoffLocation'); // Debug print

      setState(() {});

      // Center map to show both markers
      if (pickupLocation != null && dropoffLocation != null) {
        _fitBounds();
      }
    } catch (e) {
      print('Error fetching locations: $e');
    }
  }

  void _fitBounds() {
    if (pickupLocation == null || dropoffLocation == null) return;
    
    final bounds = LatLngBounds.fromPoints([
      pickupLocation!,
      dropoffLocation!,
    ]);
    
    mapController.fitBounds(
      bounds,
      options: const FitBoundsOptions(
        padding: EdgeInsets.all(50.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Route'),
        backgroundColor: const Color.fromARGB(255, 3, 76, 83),
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: const LatLng(-1.2921, 36.8219),
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: [
              if (pickupLocation != null)
                Marker(
                  point: pickupLocation!,
                  width: 80,
                  height: 80,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 40,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Pickup',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              if (dropoffLocation != null)
                Marker(
                  point: dropoffLocation!,
                  width: 80,
                  height: 80,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Dropoff',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}