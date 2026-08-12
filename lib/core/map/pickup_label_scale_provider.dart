import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مستويات حجم نص أسماء نقاط التجمع على الخريطة.
enum PickupLabelSize {
  normal,
  large,
  xlarge,
}

/// إعداد عام لحجم نص النقاط المضافة — يُحفظ محلياً ويُطبَّق على كل الخرائط.
class PickupLabelScaleProvider extends ChangeNotifier {
  static const String _prefsKey = 'pickup_label_size';

  /// يُقرأ من رسّام العلامات دون الحاجة لـ BuildContext.
  static double currentScale = 1.0;
  static PickupLabelSize currentSize = PickupLabelSize.normal;

  PickupLabelSize _size = PickupLabelSize.normal;
  bool _loaded = false;

  PickupLabelSize get size => _size;
  bool get isLoaded => _loaded;

  double get scale => scaleOf(_size);

  static double scaleOf(PickupLabelSize size) {
    switch (size) {
      case PickupLabelSize.normal:
        return 1.0;
      case PickupLabelSize.large:
        return 1.35;
      case PickupLabelSize.xlarge:
        return 1.7;
    }
  }

  String labelAr(PickupLabelSize size) {
    switch (size) {
      case PickupLabelSize.normal:
        return 'عادي';
      case PickupLabelSize.large:
        return 'كبير';
      case PickupLabelSize.xlarge:
        return 'أكبر';
    }
  }

  String labelEn(PickupLabelSize size) {
    switch (size) {
      case PickupLabelSize.normal:
        return 'Normal';
      case PickupLabelSize.large:
        return 'Large';
      case PickupLabelSize.xlarge:
        return 'Extra large';
    }
  }

  PickupLabelScaleProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      _size = _fromStorage(stored);
      currentSize = _size;
      currentScale = scaleOf(_size);
    } catch (_) {
      _size = PickupLabelSize.normal;
      currentSize = _size;
      currentScale = 1.0;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setSize(PickupLabelSize size) async {
    if (_size == size) return;
    _size = size;
    currentSize = size;
    currentScale = scaleOf(size);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _toStorage(size));
    } catch (_) {}
  }

  static PickupLabelSize _fromStorage(String? value) {
    switch (value) {
      case 'large':
        return PickupLabelSize.large;
      case 'xlarge':
        return PickupLabelSize.xlarge;
      default:
        return PickupLabelSize.normal;
    }
  }

  static String _toStorage(PickupLabelSize size) {
    switch (size) {
      case PickupLabelSize.normal:
        return 'normal';
      case PickupLabelSize.large:
        return 'large';
      case PickupLabelSize.xlarge:
        return 'xlarge';
    }
  }
}
