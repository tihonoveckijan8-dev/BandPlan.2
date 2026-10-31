import 'package:flutter/material.dart';

void main() {
  runApp(const BandPlanApp());
}

class BandPlanApp extends StatelessWidget {
  const BandPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BandPlan',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1554FF)),
      home: const Scaffold(
        body: Center(child: Text('BandPlan')),
      ),
    );
  }
}
