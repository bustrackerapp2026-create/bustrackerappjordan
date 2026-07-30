import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// ✅ التحقق من الصلاحيات وتجهيز الخدمة
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('⚠️ خدمة الموقع الجغرافي غير مفعّلة في الجهاز.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ تم رفض صلاحية الموقع.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('⚠️ تم رفض صلاحية الموقع نهائياً من إعدادات النظام.');
      return false;
    }

    return true;
  }

  /// ✅ جلب الموقع الحالي الحالي للمستخدم
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('❌ خطأ أثناء جلب الموقع الحالي: $e');
      return null;
    }
  }

  /// ✅ البث المباشر لإحداثيات الموقع (مفيد للملاحة المباشرة وبث موقع السائق)
  Stream<Position> getPositionStream({
    int distanceFilter = 5,
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
