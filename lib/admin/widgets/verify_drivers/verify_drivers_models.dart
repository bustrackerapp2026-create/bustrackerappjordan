import 'package:flutter/material.dart';

/// عنصر إحصائية في تبويب التحقق / نظرة عامة.
class VerifyDriversStatItem {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final String queryType;

  const VerifyDriversStatItem(
    this.label,
    this.count,
    this.color,
    this.icon,
    this.queryType,
  );
}
