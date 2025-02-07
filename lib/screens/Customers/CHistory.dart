import 'package:flutter/material.dart';

class CHistory extends StatefulWidget {
  const CHistory({super.key});

  @override
  State<CHistory> createState() => _CHistoryState();
}

class _CHistoryState extends State<CHistory> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(title: Text("History"),),
     body: Center(child: Text("History"),),
      
      
    );
  }
}