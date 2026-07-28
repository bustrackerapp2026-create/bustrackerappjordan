import 'package:flutter/material.dart';

class DriverMapTab extends StatelessWidget {
  const DriverMapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '🗺️ خريطة السائق',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
