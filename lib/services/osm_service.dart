import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'location_service.dart';

/// خدمة OpenStreetMap عبر Nominatim (بحث + عكس جيوكود).
///
/// تلتزم بسياسة الاستخدام العامة:
/// - طلب واحد كحد أقصى لكل ثانية تقريباً
/// - User-Agent واضح يعرّف التطبيق
/// - للاستخدام عند تفاعل المستخدم فقط (بحث يدوي)
///
/// المصدر: https://nominatim.openstreetmap.org
/// الترخيص: ODbL — © OpenStreetMap contributors
class OsmService {
  OsmService._();
  static final OsmService instance = OsmService._();
  factory OsmService() => instance;

  static const String _base = 'https://nominatim.openstreetmap.org';
  static const String _userAgent =
      'JordanBusTracker/1.0 (Flutter; contact: bustrackerapp2026@gmail.com)';

  DateTime? _lastRequestAt;

  Future<void> _throttle() async {
    final last = _lastRequestAt;
    if (last != null) {
      final wait = const Duration(milliseconds: 1100) -
          DateTime.now().difference(last);
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
    }
    _lastRequestAt = DateTime.now();
  }

  Future<String?> _get(Uri uri) async {
    await _throttle();
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'ar,en');
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != HttpStatus.ok) {
        debugPrint('OSM HTTP ${res.statusCode}');
        return null;
      }
      return await res.transform(utf8.decoder).join();
    } catch (e) {
      debugPrint('OSM request: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// بحث أماكن داخل الأردن بأسماء عربية قدر الإمكان.
  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    int limit = 5,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final uri = Uri.parse('$_base/search').replace(queryParameters: {
      'q': q,
      'format': 'json',
      'addressdetails': '1',
      'namedetails': '1',
      'countrycodes': 'jo',
      'limit': '$limit',
      'accept-language': 'ar',
    });

    final body = await _get(uri);
    if (body == null) return const [];

    try {
      final list = jsonDecode(body) as List<dynamic>;
      final out = <PlaceSearchResult>[];
      for (final item in list) {
        if (item is! Map) continue;
        final map = item.map((k, v) => MapEntry(k.toString(), v));
        final lat = double.tryParse(map['lat']?.toString() ?? '');
        final lon = double.tryParse(map['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final name = _bestArabicName(map);
        if (name.isEmpty) continue;

        out.add(PlaceSearchResult(
          name: name,
          latitude: lat,
          longitude: lon,
        ));
      }
      return out;
    } catch (e) {
      debugPrint('OSM parse search: $e');
      return const [];
    }
  }

  /// أول نتيجة بحث (للتوافق مع LocationService.searchPlace).
  Future<PlaceSearchResult?> searchPlace(String query) async {
    final list = await searchPlaces(query, limit: 1);
    return list.isEmpty ? null : list.first;
  }

  /// عكس الجيوكود: إحداثيات → اسم عربي من OSM.
  Future<PlaceSearchResult?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$_base/reverse').replace(queryParameters: {
      'lat': latitude.toStringAsFixed(6),
      'lon': longitude.toStringAsFixed(6),
      'format': 'json',
      'addressdetails': '1',
      'namedetails': '1',
      'accept-language': 'ar',
      'zoom': '18',
    });

    final body = await _get(uri);
    if (body == null) return null;

    try {
      final map = (jsonDecode(body) as Map).map(
        (k, v) => MapEntry(k.toString(), v),
      );
      if (map['error'] != null) return null;

      final lat = double.tryParse(map['lat']?.toString() ?? '') ?? latitude;
      final lon = double.tryParse(map['lon']?.toString() ?? '') ?? longitude;
      final name = _bestArabicName(map);
      if (name.isEmpty) return null;

      return PlaceSearchResult(
        name: name,
        latitude: lat,
        longitude: lon,
      );
    } catch (e) {
      debugPrint('OSM reverse: $e');
      return null;
    }
  }

  /// يختار أفضل اسم عربي من namedetails / display_name.
  String _bestArabicName(Map<String, dynamic> map) {
    final namedetails = map['namedetails'];
    if (namedetails is Map) {
      final nd = namedetails.map((k, v) => MapEntry(k.toString(), v));
      for (final key in ['name:ar', 'name_ar', 'name']) {
        final v = nd[key]?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
    }

    final address = map['address'];
    if (address is Map) {
      final ad = address.map((k, v) => MapEntry(k.toString(), v));
      for (final key in [
        'amenity',
        'shop',
        'tourism',
        'building',
        'road',
        'neighbourhood',
        'suburb',
        'city',
        'town',
        'village',
        'state',
      ]) {
        final v = ad[key]?.toString().trim();
        if (v != null && v.isNotEmpty) {
          // إن وُجدت مدينة/شارع ابنِ اسماً مختصراً
          final city = ad['city'] ?? ad['town'] ?? ad['state'];
          if (city != null &&
              key != 'city' &&
              key != 'town' &&
              key != 'state') {
            return '$v، ${city.toString()}';
          }
          return v;
        }
      }
    }

    final display = map['display_name']?.toString().trim();
    if (display != null && display.isNotEmpty) {
      // اختصر العرض الطويل: أول جزئين عادةً كافيان
      final parts = display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      return parts.take(3).join('، ');
    }
    return '';
  }
}
