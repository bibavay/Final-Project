import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class Droute extends StatefulWidget {
  const Droute({super.key});

  @override
  State<Droute> createState() => _DrouteState();
}

class _DrouteState extends State<Droute> {
  final mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Route'),
      ),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: const LatLng(-1.2921, 36.8219), // Nairobi coordinates
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          // Add markers or polylines here as needed
        ],
      ),
    );
  }
}