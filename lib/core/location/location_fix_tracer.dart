import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location_service.dart';

/// سجلات قياس تحديد الموقع — تُطبع في وضع التطوير فقط.
///
/// تُستخدم لتحويل «تعذر تحديد الموقع أحياناً» إلى أرقام:
/// زمن كل مرحلة، الدقة، حالة GPS، ونتيجة المحاولة.
class LocationFixTracer {
  LocationFixTracer({
    this.tag = 'LocationFix',
    this.role = 'passenger',
  });

  final String tag;
  final String role;

  final Stopwatch _sw = Stopwatch();
  final List<String> _events = [];
  int _sessionId = 0;

  bool _active = false;
  String? _outcome;

  void start({String reason = 'goToMyLocation'}) {
    if (!kDebugMode) return;
    _sessionId++;
    _events.clear();
    _outcome = null;
    _active = true;
    _sw
      ..reset()
      ..start();
    _line('START role=$role reason=$reason session=$_sessionId');
  }

  void mark(String event, {Map<String, Object?>? data}) {
    if (!kDebugMode || !_active) return;
    final ms = _sw.elapsedMilliseconds;
    final extra = data == null || data.isEmpty
        ? ''
        : ' ${_formatData(data)}';
    _line('+${ms}ms $event$extra');
  }

  void markStage(LocationFixStage stage, Position pos) {
    if (!kDebugMode || !_active) return;
    mark(
      'stage=${stage.name}',
      data: {
        'acc_m': pos.accuracy.isFinite ? pos.accuracy.toStringAsFixed(1) : null,
        'age_s': _ageSeconds(pos),
        'lat': pos.latitude.toStringAsFixed(5),
        'lng': pos.longitude.toStringAsFixed(5),
      },
    );
  }

  Future<void> markEnvironment() async {
    if (!kDebugMode || !_active) return;
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();
      mark(
        'env',
        data: {
          'gps_on': service,
          'perm': perm.name,
        },
      );
    } catch (e) {
      mark('env_error', data: {'error': e.toString()});
    }
  }

  void markLifecycle(AppLifecycleStateLike state) {
    if (!kDebugMode) return;
    // lifecycle قد يحدث خارج جلسة نشطة
    final ms = _active ? _sw.elapsedMilliseconds : -1;
    _print(
      'lifecycle state=${state.name}'
      '${ms >= 0 ? ' +${ms}ms session=$_sessionId' : ''}'
      ' inFlight=${_active}',
    );
  }

  void finishSuccess(Position? best) {
    if (!kDebugMode || !_active) return;
    _outcome = 'success';
    mark(
      'DONE outcome=success',
      data: {
        'total_ms': _sw.elapsedMilliseconds,
        'acc_m': best != null && best.accuracy.isFinite
            ? best.accuracy.toStringAsFixed(1)
            : null,
        'events': _events.length,
      },
    );
    _sw.stop();
    _active = false;
  }

  void finishFailure(String reason, {Object? error}) {
    if (!kDebugMode || !_active) return;
    _outcome = 'fail';
    mark(
      'DONE outcome=fail',
      data: {
        'total_ms': _sw.elapsedMilliseconds,
        'reason': reason,
        'error': error?.toString(),
        'events': _events.length,
      },
    );
    _sw.stop();
    _active = false;
  }

  void finishSkipped(String reason) {
    if (!kDebugMode || !_active) return;
    mark('SKIP', data: {'reason': reason});
    _sw.stop();
    _active = false;
  }

  String _formatData(Map<String, Object?> data) {
    return data.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${e.value}')
        .join(' ');
  }

  String? _ageSeconds(Position pos) {
    try {
      final age = DateTime.now().difference(pos.timestamp).inMilliseconds / 1000.0;
      return age.toStringAsFixed(1);
    } catch (_) {
      return null;
    }
  }

  void _line(String message) {
    _events.add(message);
    _print(message);
  }

  void _print(String message) {
    debugPrint('⏱ [$tag] $message');
  }
}

/// تفادي استيراد Flutter Material في طبقة القياس فقط لدورة الحياة.
enum AppLifecycleStateLike {
  resumed,
  inactive,
  paused,
  detached,
  hidden,
}

extension AppLifecycleStateLikeX on AppLifecycleStateLike {
  static AppLifecycleStateLike fromFlutter(Object state) {
    final name = state.toString().split('.').last;
    return AppLifecycleStateLike.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AppLifecycleStateLike.resumed,
    );
  }
}
