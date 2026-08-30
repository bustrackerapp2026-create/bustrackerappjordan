/// صلاحيات الموقع + تفعيل GPS.
/// مسار السائق عند «اتصال»: فحص مرة واحدة، Dialog واحد عند الحاجة، بدون ترقية whileInUse→always عبر requestPermission.
class LocationPermissionSheet {
  LocationPermissionSheet._();

  static const MethodChannel _locationChannel =
      MethodChannel('com.example.jordan_bus_tracker/location_service');

  static const int _servicePollAttempts = 12;
  static const Duration _servicePollInterval = Duration(milliseconds: 400);

  static Future<bool>? _servicePromptInFlight;

  static DateTime? _lastServicePromptAt;
  static const Duration _servicePromptCooldown = Duration(seconds: 12);

  static Future<bool> ensurePermission(
    BuildContext context, {
    bool forcePrompt = false,
  }) async {
    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        if (!context.mounted) return false;
        final open = await _confirmAction(
          context,
          title: 'صلاحية الموقع مرفوضة',
          message:
              'تم رفض صلاحية الموقع بشكل دائم.\nافتح إعدادات التطبيق وفعّل الموقع يدوياً.',
          confirmLabel: 'فتح الإعدادات',
          cancelLabel: 'لاحقاً',
        );
        if (open) await Geolocator.openAppSettings();
        return false;
      }

      final alreadyGranted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (!alreadyGranted || forcePrompt) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('LocationPermissionSheet.ensurePermission: $e');
      return false;
    }
  }

  /// بوابة اتصال السائق (مسار واحد):
  /// - always / whileInUse → نجاح بدون Dialog (خيار whileInUse المسموح)
  /// - denied → Dialog واحد ثم requestPermission مرة واحدة فقط
  /// - deniedForever → Dialog واحد → الإعدادات
  /// - لا يُستدعى requestPermission لترقية whileInUse → always
  static Future<bool> ensureDriverBackgroundAccess(BuildContext context) async {
    try {
      if (!await ensureLocationService(context)) return false;
      if (!context.mounted) return false;

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        return true;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!context.mounted) return false;
        final open = await _confirmAction(
          context,
          title: 'صلاحية الموقع مطلوبة',
          message:
              'تم رفض صلاحية الموقع بشكل دائم.\n'
              'من إعدادات التطبيق → الأذونات → الموقع، فعّل الموقع ثم ارجع واضغط «اتصال».',
          confirmLabel: 'فتح الإعدادات',
          cancelLabel: 'لاحقاً',
        );
        if (open) await Geolocator.openAppSettings();
        return false;
      }

      // denied (أو غير معروف): حوار واحد ثم طلب النظام مرة واحدة فقط
      if (!context.mounted) return false;
      final accept = await _confirmAction(
        context,
        title: 'السماح بالوصول للموقع',
        message:
            'لمشاركة موقعك مع الركاب أثناء الاتصال، يحتاج التطبيق إلى صلاحية الموقع.',
        confirmLabel: 'متابعة',
        cancelLabel: 'لاحقاً',
      );
      if (!accept || !context.mounted) return false;

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        return true;
      }

      if (permission == LocationPermission.deniedForever && context.mounted) {
        final open = await _confirmAction(
          context,
          title: 'صلاحية الموقع مرفوضة',
          message:
              'افتح إعدادات التطبيق وفعّل الموقع، ثم ارجع واضغط «اتصال».',
          confirmLabel: 'فتح الإعدادات',
          cancelLabel: 'لاحقاً',
        );
        if (open) await Geolocator.openAppSettings();
      }
      return false;
    } catch (e) {
      debugPrint('ensureDriverBackgroundAccess: $e');
      return false;
    }
  }

  static Future<bool> ensureLocationService(BuildContext context) async {
    final existing = _servicePromptInFlight;
    if (existing != null) {
      return existing;
    }

    final future = _ensureLocationServiceImpl(context);
    _servicePromptInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_servicePromptInFlight, future)) {
        _servicePromptInFlight = null;
      }
    }
  }

  static Future<bool> _ensureLocationServiceImpl(BuildContext context) async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        return true;
      }

      final now = DateTime.now();
      if (_lastServicePromptAt != null &&
          now.difference(_lastServicePromptAt!) < _servicePromptCooldown) {
        debugPrint('LocationPermissionSheet: skip GPS prompt (cooldown)');
        return Geolocator.isLocationServiceEnabled();
      }
      _lastServicePromptAt = now;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          final enabled =
              await _locationChannel.invokeMethod<bool>('enableLocationService');
          if (enabled == true) {
            if (await _waitForLocationServiceEnabled()) return true;
          } else if (enabled == false) {
            debugPrint(
              'LocationPermissionSheet: system GPS dialog dismissed',
            );
            return false;
          }
        } on PlatformException catch (e) {
          if (e.code == 'BUSY') {
            debugPrint('enableLocationService BUSY');
            if (await _waitForLocationServiceEnabled()) return true;
            return false;
          }
          debugPrint('enableLocationService: ${e.code} ${e.message}');
        } catch (e) {
          debugPrint('enableLocationService channel: $e');
        }
      }

      if (!context.mounted) return false;
      final open = await _confirmAction(
        context,
        title: 'فعّل خدمة الموقع',
        message:
            'الموقع (GPS) مغلق على الجهاز.\n'
            'اضغط «تفعيل» لفتح الإعدادات وتشغيله، ثم ارجع للتطبيق.',
        confirmLabel: 'تفعيل',
        cancelLabel: 'لاحقاً',
      );
      if (open) {
        await Geolocator.openLocationSettings();
        if (await _waitForLocationServiceEnabled()) return true;
      }
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationPermissionSheet.ensureLocationService: $e');
      return false;
    }
  }

  static Future<bool> _waitForLocationServiceEnabled() async {
    for (var i = 0; i < _servicePollAttempts; i++) {
      if (await Geolocator.isLocationServiceEnabled()) {
        return true;
      }
      await Future<void>.delayed(_servicePollInterval);
    }
    return Geolocator.isLocationServiceEnabled();
  }

  static Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'إلغاء',
  }) async {
    if (!context.mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }
}
