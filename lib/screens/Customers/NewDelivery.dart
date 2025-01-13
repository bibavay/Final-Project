import 'package:flutter/material.dart';

class Newdelivery extends StatefulWidget {
  const Newdelivery({super.key});

  @override
  State<Newdelivery> createState() => _NewdeliveryState();
}

class _NewdeliveryState extends State<Newdelivery> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Delivery"),
      ),
      body: Center(
        child: Text("New Delivery"),
      ),
    );
  }
}