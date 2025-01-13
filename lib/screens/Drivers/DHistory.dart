import 'package:flutter/material.dart';

class DHistory extends StatefulWidget {
  const DHistory({super.key});

  @override
  State<DHistory> createState() => _DHistoryState();
}

class _DHistoryState extends State<DHistory> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
      ),
      body: Center(
        child:  Text("History"),
      ),
    );
  }
}