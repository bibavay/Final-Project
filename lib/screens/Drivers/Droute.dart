import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Droute extends StatefulWidget {
  final String orderId;
  final String orderType;

  const Droute({
    Key? key,
    required this.orderId,
    required this.orderType,
  }) : super(key: key);

  @override
  State<Droute> createState() => _DrouteState();
}

class _DrouteState extends State<Droute> {
  List<Location> pickupLocations = [];
  List<Location> dropoffLocations = [];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final DocumentSnapshot orderDoc = await FirebaseFirestore.instance
          .collection(widget.orderType.toLowerCase() == 'trip' ? 'trips' : 'deliveries')
          .doc(widget.orderId)
          .get();

      if (!orderDoc.exists) return;

      final data = orderDoc.data() as Map<String, dynamic>;
      List<Location> newPickupLocations = [];
      List<Location> newDropoffLocations = [];

      if (widget.orderType.toLowerCase() == 'trip') {
        if (data['passengers'] != null) {
          for (var passenger in data['passengers']) {
            if (passenger['locations'] != null) {
              // Add pickup location
              if (passenger['locations']['source'] != null) {
                newPickupLocations.add(
                  Location(
                    latLng: LatLng(
                      passenger['locations']['source']['latitude'],
                      passenger['locations']['source']['longitude'],
                    ),
                    name: 'Pickup',
                  ),
                );
              }
              // Add dropoff location
              if (passenger['locations']['destination'] != null) {
                newDropoffLocations.add(
                  Location(
                    latLng: LatLng(
                      passenger['locations']['destination']['latitude'],
                      passenger['locations']['destination']['longitude'],
                    ),
                    name: 'Dropoff',
                  ),
                );
              }
            }
          }
        }
      } else {
        // Handle delivery locations
        final package = data['package'] as Map<String, dynamic>;
        final locations = package['locations'] as Map<String, dynamic>;

        // Add pickup location
        if (locations['source'] != null) {
          newPickupLocations.add(
            Location(
              latLng: LatLng(
                locations['source']['latitude'],
                locations['source']['longitude'],
              ),
              name: 'Pickup',
            ),
          );
        }

        // Add dropoff location
        if (locations['destination'] != null) {
          newDropoffLocations.add(
            Location(
              latLng: LatLng(
                locations['destination']['latitude'],
                locations['destination']['longitude'],
              ),
              name: 'Dropoff',
            ),
          );
        }
      }

      setState(() {
        pickupLocations = newPickupLocations;
        dropoffLocations = newDropoffLocations;
      });
    } catch (e) {
      print('Error loading locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapView(
      pickupLocations: pickupLocations,
      dropoffLocations: dropoffLocations,
    );
  }
}

class MapView extends StatelessWidget {
  final List<Location> pickupLocations;
  final List<Location> dropoffLocations;

  const MapView({
    Key? key,
    required this.pickupLocations,
    required this.dropoffLocations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate bounds to fit all markers
    final bounds = LatLngBounds.fromPoints([
      ...pickupLocations.map((loc) => loc.latLng),
      ...dropoffLocations.map((loc) => loc.latLng),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map'),
        backgroundColor: const Color.fromARGB(255, 3, 76, 83),
      ),
      body: FlutterMap(
        options: MapOptions(
          bounds: bounds,
          boundsOptions: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: [
              // Pickup location markers
              ...pickupLocations.map(
                (location) => Marker(
                  point: location.latLng,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
              ),
              // Dropoff location markers
              ...dropoffLocations.map(
                (location) => Marker(
                  point: location.latLng,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Location {
  final LatLng latLng;
  final String name;

  Location({required this.latLng, required this.name});
}