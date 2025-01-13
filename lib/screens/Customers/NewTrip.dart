import 'package:flutter/material.dart';

class Newtrip extends StatefulWidget {
  const Newtrip({super.key});

  @override
  State<Newtrip> createState() => _NewtripState();
}

class _NewtripState extends State<Newtrip> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Trip"),
      ),
      body: Center(
        child: Text("New Trip"),
      ),
    );
  }
}