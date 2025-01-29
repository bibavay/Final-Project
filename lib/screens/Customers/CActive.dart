import 'package:flutter/material.dart';



class CActive extends StatefulWidget {
  const CActive({super.key});

  @override
  State<CActive> createState() => _CActiveState();
}

class _CActiveState extends State<CActive> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CActive'),
      ),
      body: Center(
        child: Text('CActive Screen'),
      ),
    );
  }
}