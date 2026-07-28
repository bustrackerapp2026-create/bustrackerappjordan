import 'package:flutter/material.dart';

class BookingsTab extends StatelessWidget {
  const BookingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '📋 الطلبات',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
