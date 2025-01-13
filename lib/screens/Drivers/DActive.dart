import 'package:flutter/material.dart';

class Dactive extends StatefulWidget {
  const Dactive({super.key});

  @override
  State<Dactive> createState() => _DactiveState();
}

class _DactiveState extends State<Dactive> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Active"),
      ),
      body: Center(
        child:  Text("Active"),
      ),
    );
  }
}