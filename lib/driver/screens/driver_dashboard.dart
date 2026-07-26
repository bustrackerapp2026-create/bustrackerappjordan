import 'package:flutter/material.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('شاشة السائق'), backgroundColor: Colors.blue),
      body: const Center(child: Text('مرحباً أيها السائق!')),
    );
  }
}
