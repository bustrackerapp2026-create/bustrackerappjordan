import 'package:flutter/material.dart';

class OperationsTab extends StatelessWidget {
  const OperationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '📊 العمليات',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
