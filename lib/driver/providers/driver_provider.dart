import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Provider مسؤول عن إدارة حالة السائق (التوفر، الموقع الحالي، والرحلة النشطة)
class DriverProvider extends ChangeNotifier {
  // --- الحالات الداخلية (Private State) ---
  bool _isOnline = false;
  bool _isTripActive = false;
  Position? _currentPosition;
  String _selectedRoute = '';

  // --- القائمات العامة (Getters) ---
  /// هل السائق متصل ومتاح لاستقبال الطلبات؟
  bool get isOnline => _isOnline;

  /// هل هناك رحلة جارية حالياً؟
  bool get isTripActive => _isTripActive;

  /// الموقع الحالي للسائق من الـ GPS
  Position? get currentPosition => _currentPosition;

  /// الخط الحالي المحدد للسائق
  String get selectedRoute => _selectedRoute;

  // --- الدوال والعمليات (Methods) ---

  /// تغيير حالة الاتصال (متاح / غير متاح)
  void toggleOnlineStatus() {
    _isOnline = !_isOnline;

    // إذا أوقف السائق الاتصال أثناء رحلة نشطة، ننهي حالة الرحلة تلقائياً
    if (!_isOnline && _isTripActive) {
      _isTripActive = false;
    }

    notifyListeners();
  }

  /// تعيين حالة الاتصال مباشرة (true أو false)
  void setOnlineStatus(bool status) {
    if (_isOnline != status) {
      _isOnline = status;
      notifyListeners();
    }
  }

  /// تحديث الموقع الحالي للسائق (تُستدعى عند استقبال إشارة GPS جديدة)
  void updatePosition(Position newPosition) {
    _currentPosition = newPosition;
    notifyListeners();
  }

  /// تحديد الخط الحالي للسائق
  void setSelectedRoute(String route) {
    _selectedRoute = route;
    notifyListeners();
  }

  /// بدء رحلة جديدة
  void startTrip() {
    if (!_isOnline) return;
    _isTripActive = true;
    notifyListeners();
  }

  /// إنهاء الرحلة الحالية
  void endTrip() {
    _isTripActive = false;
    notifyListeners();
  }

  /// إعادة تعيين جميع بيانات السائق (عند تسجيل الخروج)
  void resetDriverState() {
    _isOnline = false;
    _isTripActive = false;
    _currentPosition = null;
    _selectedRoute = '';
    notifyListeners();
  }
}
