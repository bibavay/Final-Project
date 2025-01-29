import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  final bool isSource;
  final LatLng? initialLocation;

  const LocationPickerScreen({
    Key? key, 
    required this.isSource,
    this.initialLocation,
  }) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final mapController = MapController();
  LatLng? selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation ?? const LatLng(51.5, -0.09),
              initialZoom: 13.0,
              onTap: (tapPosition, point) {
                setState(() => selectedLocation = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40.0,
                      height: 40.0,
                      point: selectedLocation!,
                      child: Icon(
                        Icons.location_pin,
                        color: widget.isSource ? const Color.fromARGB(255, 12, 141, 227) : Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: 'Search location...',
              onSubmitted: (value) => _searchLocation(value),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: selectedLocation == null ? null : () {
                Navigator.pop(context, selectedLocation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirm Location',style: TextStyle(color: Colors.white),),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchLocation(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        setState(() {
          selectedLocation = LatLng(
            locations.first.latitude,
            locations.first.longitude,
          );
        });
        mapController.move(selectedLocation!, 15);
      }
    } catch (e) {
      print('Error searching location: $e');
    }
  }
}