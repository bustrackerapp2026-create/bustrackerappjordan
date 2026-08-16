import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// استيراد عيّنة محدودة لعمّان: 5 مسارات (plannedRoutes) + 5 نقاط تجمع.
/// مخصّص للتجربة البصرية قبل إضافة الشبكة كاملة.
class SampleAmmanDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _seedTag = 'sample_amman_v1';

  /// يستورد العيّنة إن لم تكن موجودة (لا يكرر بنفس المعرّفات الثابتة).
  Future<String> importSampleIfNeeded({required String adminId}) async {
    final routesCol = _db.collection('plannedRoutes');
    final existing = await routesCol
        .where('seedTag', isEqualTo: _seedTag)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return 'العيّنة موجودة مسبقاً (5 مسارات). أضف نقاط التجمع يدوياً إن لزم.';
    }

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    for (final route in _sampleRoutes) {
      final ref = routesCol.doc(route['id'] as String);
      batch.set(ref, {
        ...route['data'] as Map<String, dynamic>,
        'createdBy': adminId,
        'driverId': adminId,
        'seedTag': _seedTag,
        'createdAt': now,
        'updatedAt': now,
      });
    }

    final pointsCol = _db.collection('pickupPoints');
    for (final point in _samplePickups) {
      final ref = pointsCol.doc(point['id'] as String);
      batch.set(ref, {
        ...point['data'] as Map<String, dynamic>,
        'addedBy': adminId,
        'addedByUserType': 'admin',
        'status': 'approved',
        'isApproved': true,
        'seedTag': _seedTag,
        'createdAt': now,
        'updatedAt': now,
      });
    }

    await batch.commit();

    if (kDebugMode) {
      debugPrint('✅ [SampleAmman] imported 5 routes + 5 pickups');
    }
    return 'تم استيراد 5 مسارات و 5 نقاط تجمع (عيّنة عمّان).';
  }

  Future<String> clearSample() async {
    int deleted = 0;

    final routes = await _db
        .collection('plannedRoutes')
        .where('seedTag', isEqualTo: _seedTag)
        .get();
    for (final d in routes.docs) {
      await d.reference.delete();
      deleted++;
    }

    final points = await _db
        .collection('pickupPoints')
        .where('seedTag', isEqualTo: _seedTag)
        .get();
    for (final d in points.docs) {
      await d.reference.delete();
      deleted++;
    }

    return 'تم حذف $deleted مستنداً من عيّنة عمّان.';
  }
}

// ─── 5 مسارات (مبسّطة من بيانات خط 99 وممرات عمّان) ───

const List<Map<String, dynamic>> _sampleRoutes = [
  {
    'id': 'sample_99_outbound',
    'data': {
      'lineName': 'متحف الأردن → صويلح',
      'direction': 'outbound',
      'status': 'approved',
      'source': 'admin',
      'reRecordAllowed': false,
      'editRequestPending': false,
      'notes': 'عيّنة: خط 99 ذهاب (مختصر)',
      'aliases': ['99', 'BRT 99', 'خط 99', 'صويلح', 'متحف الأردن'],
      'searchKeys': ['99', 'صويلح', 'متحف', 'خط 99', 'brt 99'],
      'lineNameNormalized': 'متحف الاردن صويلح',
      'distanceMeters': 16632.0,
      'points': [
        {'latitude': 31.945475, 'longitude': 35.928783},
        {'latitude': 31.946363, 'longitude': 35.92684},
        {'latitude': 31.94551, 'longitude': 35.922139},
        {'latitude': 31.946533, 'longitude': 35.917991},
        {'latitude': 31.94808, 'longitude': 35.913502},
        {'latitude': 31.945378, 'longitude': 35.907067},
        {'latitude': 31.949439, 'longitude': 35.902569},
        {'latitude': 31.951756, 'longitude': 35.897932},
        {'latitude': 31.953725, 'longitude': 35.888498},
        {'latitude': 31.958028, 'longitude': 35.879096},
        {'latitude': 31.964345, 'longitude': 35.883909},
        {'latitude': 31.97111, 'longitude': 35.886323},
        {'latitude': 31.978244, 'longitude': 35.889229},
        {'latitude': 31.985173, 'longitude': 35.897579},
        {'latitude': 31.991647, 'longitude': 35.891514},
        {'latitude': 32.000808, 'longitude': 35.877219},
        {'latitude': 32.006605, 'longitude': 35.87241},
        {'latitude': 32.012064, 'longitude': 35.870382},
        {'latitude': 32.019332, 'longitude': 35.864138},
        {'latitude': 32.024253, 'longitude': 35.857568},
        {'latitude': 32.022602, 'longitude': 35.846343},
        {'latitude': 32.020737, 'longitude': 35.842858},
      ],
    },
  },
  {
    'id': 'sample_99_return',
    'data': {
      'lineName': 'متحف الأردن → صويلح',
      'direction': 'return',
      'status': 'approved',
      'source': 'admin',
      'reRecordAllowed': false,
      'editRequestPending': false,
      'notes': 'عيّنة: خط 99 إياب (مختصر)',
      'aliases': ['99', 'BRT 99', 'خط 99', 'صويلح', 'متحف الأردن'],
      'searchKeys': ['99', 'صويلح', 'متحف', 'خط 99', 'brt 99'],
      'lineNameNormalized': 'متحف الاردن صويلح',
      'distanceMeters': 16645.0,
      'points': [
        {'latitude': 32.021302, 'longitude': 35.842828},
        {'latitude': 32.022856, 'longitude': 35.847501},
        {'latitude': 32.024635, 'longitude': 35.853855},
        {'latitude': 32.023374, 'longitude': 35.859319},
        {'latitude': 32.018097, 'longitude': 35.865488},
        {'latitude': 32.012099, 'longitude': 35.870357},
        {'latitude': 32.00654, 'longitude': 35.87246},
        {'latitude': 32.000797, 'longitude': 35.877181},
        {'latitude': 31.991666, 'longitude': 35.89147},
        {'latitude': 31.985246, 'longitude': 35.8981},
        {'latitude': 31.978239, 'longitude': 35.889253},
        {'latitude': 31.969119, 'longitude': 35.886517},
        {'latitude': 31.961947, 'longitude': 35.88193},
        {'latitude': 31.955012, 'longitude': 35.884806},
        {'latitude': 31.951641, 'longitude': 35.893644},
        {'latitude': 31.949851, 'longitude': 35.902145},
        {'latitude': 31.945484, 'longitude': 35.906831},
        {'latitude': 31.947562, 'longitude': 35.911787},
        {'latitude': 31.945447, 'longitude': 35.921815},
        {'latitude': 31.946311, 'longitude': 35.926323},
        {'latitude': 31.945174, 'longitude': 35.928773},
      ],
    },
  },
  {
    'id': 'sample_uni_city',
    'data': {
      'lineName': 'الجامعة — وسط البلد',
      'direction': 'outbound',
      'status': 'approved',
      'source': 'admin',
      'reRecordAllowed': false,
      'editRequestPending': false,
      'notes': 'عيّنة: ممر جامعي مبسّط',
      'aliases': ['الجامعة', 'وسط البلد', 'البلد'],
      'searchKeys': ['الجامعه', 'وسط البلد', 'البلد'],
      'lineNameNormalized': 'الجامعه وسط البلد',
      'distanceMeters': 12000.0,
      'points': [
        {'latitude': 32.0120, 'longitude': 35.8720},
        {'latitude': 32.0050, 'longitude': 35.8800},
        {'latitude': 31.9950, 'longitude': 35.9000},
        {'latitude': 31.9800, 'longitude': 35.9200},
        {'latitude': 31.9600, 'longitude': 35.9300},
        {'latitude': 31.9530, 'longitude': 35.9320},
      ],
    },
  },
  {
    'id': 'sample_north_terminal',
    'data': {
      'lineName': 'مجمع الشمال — الجبيهة',
      'direction': 'outbound',
      'status': 'approved',
      'source': 'admin',
      'reRecordAllowed': false,
      'editRequestPending': false,
      'notes': 'عيّنة: شمال عمّان',
      'aliases': ['مجمع الشمال', 'الجبيهة', 'صويلح'],
      'searchKeys': ['مجمع الشمال', 'الجبيهه', 'صويلح'],
      'lineNameNormalized': 'مجمع الشمال الجبيهه',
      'distanceMeters': 8000.0,
      'points': [
        {'latitude': 32.0120, 'longitude': 35.8720},
        {'latitude': 32.0200, 'longitude': 35.8680},
        {'latitude': 32.0280, 'longitude': 35.8600},
        {'latitude': 32.0350, 'longitude': 35.8450},
        {'latitude': 32.0400, 'longitude': 35.8400},
      ],
    },
  },
  {
    'id': 'sample_sports_city',
    'data': {
      'lineName': 'المدينة الرياضية — الجامعة',
      'direction': 'outbound',
      'status': 'approved',
      'source': 'admin',
      'reRecordAllowed': false,
      'editRequestPending': false,
      'notes': 'عيّنة: مدينة رياضية',
      'aliases': ['المدينة الرياضية', 'الجامعة', 'الصويفية'],
      'searchKeys': ['مدينه رياضيه', 'الجامعه', 'الصويفيه'],
      'lineNameNormalized': 'المدينه الرياضيه الجامعه',
      'distanceMeters': 9000.0,
      'points': [
        {'latitude': 31.9850, 'longitude': 35.8980},
        {'latitude': 31.9950, 'longitude': 35.8850},
        {'latitude': 32.0020, 'longitude': 35.8780},
        {'latitude': 32.0080, 'longitude': 35.8730},
        {'latitude': 32.0120, 'longitude': 35.8700},
      ],
    },
  },
];

// ─── 5 نقاط تجمع ───

const List<Map<String, dynamic>> _samplePickups = [
  {
    'id': 'sample_pickup_museum',
    'data': {
      'id': 'sample_pickup_museum',
      'name': 'متحف الأردن',
      'latitude': 31.9455,
      'longitude': 35.9288,
      'pointType': 'bus',
      'confirmations': <String>[],
      'confirmationCount': 0,
    },
  },
  {
    'id': 'sample_pickup_sports',
    'data': {
      'id': 'sample_pickup_sports',
      'name': 'المدينة الرياضية',
      'latitude': 31.9852,
      'longitude': 35.8976,
      'pointType': 'bus',
      'confirmations': <String>[],
      'confirmationCount': 0,
    },
  },
  {
    'id': 'sample_pickup_uni',
    'data': {
      'id': 'sample_pickup_uni',
      'name': 'الجامعة الأردنية',
      'latitude': 32.0121,
      'longitude': 35.8704,
      'pointType': 'bus',
      'confirmations': <String>[],
      'confirmationCount': 0,
    },
  },
  {
    'id': 'sample_pickup_swaileh',
    'data': {
      'id': 'sample_pickup_swaileh',
      'name': 'محطة صويلح',
      'latitude': 32.0207,
      'longitude': 35.8429,
      'pointType': 'bus',
      'confirmations': <String>[],
      'confirmationCount': 0,
    },
  },
  {
    'id': 'sample_pickup_north',
    'data': {
      'id': 'sample_pickup_north',
      'name': 'مجمع الشمال',
      'latitude': 32.0120,
      'longitude': 35.8720,
      'pointType': 'bus',
      'confirmations': <String>[],
      'confirmationCount': 0,
    },
  },
];
