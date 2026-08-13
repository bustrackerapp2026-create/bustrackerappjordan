import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// غلاف آمن لـ Firebase Analytics — لا يرمي استثناءات على واجهة المستخدم.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();
  factory AnalyticsService() => instance;

  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;
  bool _enabled = true;

  /// تفعيل/تعطيل محلياً (مثلاً للاختبارات)
  void setEnabled(bool value) => _enabled = value;

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_enabled) return;
    try {
      await _fa.logEvent(name: name, parameters: params);
      if (kDebugMode) {
        debugPrint('📊 analytics: $name ${params ?? {}}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📊 analytics skip ($name): $e');
      }
    }
  }

  Future<void> setUserRole(String? role) async {
    if (!_enabled) return;
    try {
      await _fa.setUserProperty(name: 'user_role', value: role);
    } catch (_) {}
  }

  // ── أحداث عامة ──────────────────────────────────────────

  Future<void> screenView(String screenName) => _log('screen_view', {
        'screen_name': screenName,
      });

  Future<void> loginSuccess(String role) => _log('login_success', {
        'role': role,
      });

  // ── راكب ────────────────────────────────────────────────

  Future<void> passengerMapOpened() => _log('passenger_map_opened');

  Future<void> driverMarkerTapped({String? capacity}) => _log(
        'driver_marker_tapped',
        {
          if (capacity != null) 'capacity': capacity,
        },
      );

  Future<void> pickupMarkerTapped() => _log('pickup_marker_tapped');

  Future<void> routeFilterChanged(String route) => _log(
        'route_filter_changed',
        {'route': route},
      );

  Future<void> noLiveBusesViewed({String? route}) => _log(
        'no_live_buses_viewed',
        {
          if (route != null) 'route': route,
        },
      );

  Future<void> liveBusesViewed(int count, {String? route}) => _log(
        'live_buses_viewed',
        {
          'count': count,
          if (route != null) 'route': route,
        },
      );

  // ── سائق ────────────────────────────────────────────────

  Future<void> driverMapOpened() => _log('driver_map_opened');

  Future<void> goOnline() => _log('driver_go_online');

  Future<void> goOffline() => _log('driver_go_offline');

  Future<void> startTrip() => _log('driver_start_trip');

  Future<void> endTrip() => _log('driver_end_trip');

  Future<void> staleLocationBannerShown() =>
      _log('driver_stale_location_banner');

  Future<void> staleLocationRefreshed() =>
      _log('driver_stale_location_refresh');

  // ── أدمن ────────────────────────────────────────────────

  Future<void> adminDashboardOpened({int pendingDrivers = 0}) => _log(
        'admin_dashboard_opened',
        {'pending_drivers': pendingDrivers},
      );

  Future<void> adminPendingBannerTapped(int count) => _log(
        'admin_pending_banner_tapped',
        {'pending_drivers': count},
      );

  Future<void> adminDriverApproved() => _log('admin_driver_approved');

  Future<void> adminDriverRejected() => _log('admin_driver_rejected');
}
