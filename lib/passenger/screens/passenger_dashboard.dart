import 'package:flutter/material.dart';

class PassengerDashboard extends StatelessWidget {
  const PassengerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('شاشة الراكب'), backgroundColor: Colors.green),
      body: const Center(child: Text('مرحباً أيها الراكب!')),
    );
  }
}
