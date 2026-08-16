import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/route_point.dart';
import 'route_plan_service.dart';

/// استيراد عيّنة دقيقة لعمّان:
/// - مساران فقط (خط 99 ذهاب/إياب) من ملفات seed_data بعد لصقها على الشوارع عبر Mapbox
/// - 5 نقاط تجمع على نفس الخط
///
/// لا تُستورد مسارات تقريبية تقطع المباني.
class SampleAmmanDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final RoutePlanService _plan = RoutePlanService();

  /// نسخة جديدة بعد إزالة المسارات التقريبية
  static const String seedTag = 'sample_amman_v2_road';

  /// يستورد العيّنة إن لم تكن موجودة.
  /// يحذف أي عيّنة قديمة (v1) غير الدقيقة إن وُجدت.
  Future<String> importSampleIfNeeded({required String adminId}) async {
    await clearSample(tag: 'sample_amman_v1');

    final routesCol = _db.collection('plannedRoutes');
    final existing = await routesCol
        .where('seedTag', isEqualTo: seedTag)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return 'العيّنة الدقيقة موجودة مسبقاً (خط 99 ذهاب/إياب + نقاط).';
    }

    final outboundCtrl = _controlPoints(_route99OutboundDense);
    final returnCtrl = _controlPoints(_route99ReturnDense);

    if (kDebugMode) {
      debugPrint(
        '🛣️ [SampleAmman] aligning routes via Mapbox '
        '(${outboundCtrl.length} / ${returnCtrl.length} control pts)…',
      );
    }

    final outboundRoad = await _plan.buildRoadAlignedRoute(outboundCtrl);
    final returnRoad = await _plan.buildRoadAlignedRoute(returnCtrl);

    if (outboundRoad.length < 8 || returnRoad.length < 8) {
      throw StateError(
        'فشل لصق المسار على الشوارع (نقاط قليلة). '
        'تحقق من اتصال الإنترنت ومفتاح Mapbox ثم أعد المحاولة.',
      );
    }

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    void putRoute({
      required String id,
      required String direction,
      required List<RoutePoint> points,
      required String notes,
    }) {
      final ref = routesCol.doc(id);
      final dist = _plan.totalDistanceMeters(points);
      batch.set(ref, {
        'createdBy': adminId,
        'driverId': adminId,
        'lineName': 'متحف الأردن → صويلح',
        'direction': direction,
        'status': 'approved',
        'source': 'admin',
        'reRecordAllowed': false,
        'editRequestPending': false,
        'notes': notes,
        'aliases': ['99', 'BRT 99', 'خط 99', 'صويلح', 'متحف الأردن'],
        'searchKeys': ['99', 'صويلح', 'متحف', 'خط 99', 'brt 99'],
        'lineNameNormalized': 'متحف الاردن صويلح',
        'distanceMeters': dist,
        'points': points.map((p) => p.toMap()).toList(),
        'seedTag': seedTag,
        'createdAt': now,
        'updatedAt': now,
      });
    }

    putRoute(
      id: 'sample_99_outbound_v2',
      direction: 'outbound',
      points: outboundRoad,
      notes: 'عيّنة دقيقة: خط 99 ذهاب — ملصق على شبكة الطرق (Mapbox)',
    );
    putRoute(
      id: 'sample_99_return_v2',
      direction: 'return',
      points: returnRoad,
      notes: 'عيّنة دقيقة: خط 99 إياب — ملصق على شبكة الطرق (Mapbox)',
    );

    final pointsCol = _db.collection('pickupPoints');
    for (final point in _samplePickups) {
      final ref = pointsCol.doc(point['id'] as String);
      batch.set(ref, {
        ...point['data'] as Map<String, dynamic>,
        'addedBy': adminId,
        'addedByUserType': 'admin',
        'status': 'approved',
        'isApproved': true,
        'seedTag': seedTag,
        'createdAt': now,
        'updatedAt': now,
      });
    }

    await batch.commit();

    if (kDebugMode) {
      debugPrint(
        '✅ [SampleAmman] saved road-aligned 99 '
        '(${outboundRoad.length}+${returnRoad.length} pts) + 5 pickups',
      );
    }

    return 'تم استيراد خط 99 (ذهاب/إياب) ملصقاً على الشوارع + 5 نقاط تجمع.';
  }

  Future<String> clearSample({String? tag}) async {
    final t = tag ?? seedTag;
    int deleted = 0;

    final routes = await _db
        .collection('plannedRoutes')
        .where('seedTag', isEqualTo: t)
        .get();
    for (final d in routes.docs) {
      await d.reference.delete();
      deleted++;
    }

    final points = await _db
        .collection('pickupPoints')
        .where('seedTag', isEqualTo: t)
        .get();
    for (final d in points.docs) {
      await d.reference.delete();
      deleted++;
    }

    // عند المسح العام احذف أيضاً العيّنة القديمة غير الدقيقة
    if (tag == null) {
      final old = await clearSample(tag: 'sample_amman_v1');
      return 'تم حذف $deleted مستنداً من العيّنة الدقيقة. $old';
    }

    return 'تم حذف $deleted مستنداً (tag=$t).';
  }

  /// نقاط تحكم كل ~N نقطة من المسار الكثيف (مناسبة لـ Directions)
  List<RoutePoint> _controlPoints(List<List<double>> dense, {int step = 6}) {
    final out = <RoutePoint>[];
    for (var i = 0; i < dense.length; i += step) {
      out.add(RoutePoint(latitude: dense[i][0], longitude: dense[i][1]));
    }
    final last = dense.last;
    final lastPt = RoutePoint(latitude: last[0], longitude: last[1]);
    if (out.isEmpty ||
        out.last.latitude != lastPt.latitude ||
        out.last.longitude != lastPt.longitude) {
      out.add(lastPt);
    }
    return out;
  }
}

// ─── خط 99 ذهاب — كامل من seed_data/route_99_outbound.json ───
const List<List<double>> _route99OutboundDense = [
  [31.945475, 35.928783], [31.945649, 35.928818], [31.945712, 35.928798],
  [31.945842, 35.928563], [31.946167, 35.927883], [31.946363, 35.92684],
  [31.946423, 35.926068], [31.946246, 35.924465], [31.94551, 35.922139],
  [31.945469, 35.921676], [31.945956, 35.919074], [31.946533, 35.917991],
  [31.947667, 35.916133], [31.948082, 35.915407], [31.948232, 35.914735],
  [31.948199, 35.914133], [31.94808, 35.913502], [31.947845, 35.912619],
  [31.94588, 35.907799], [31.945651, 35.907394], [31.945378, 35.907067],
  [31.945338, 35.90704], [31.946053, 35.905901], [31.946415, 35.905384],
  [31.947059, 35.904593], [31.947375, 35.904312], [31.948499, 35.903433],
  [31.949439, 35.902569], [31.949886, 35.902136], [31.95077, 35.900891],
  [31.951132, 35.900101], [31.951328, 35.89973], [31.951415, 35.899458],
  [31.951605, 35.898715], [31.951756, 35.897932], [31.951777, 35.896955],
  [31.951658, 35.89442], [31.951648, 35.893641], [31.952153, 35.892291],
  [31.953009, 35.890173], [31.953725, 35.888498], [31.954271, 35.886977],
  [31.955067, 35.884639], [31.955305, 35.884043], [31.958028, 35.879096],
  [31.959269, 35.879941], [31.960877, 35.881176], [31.961956, 35.881926],
  [31.962804, 35.882609], [31.964345, 35.883909], [31.965816, 35.885414],
  [31.966271, 35.886022], [31.966561, 35.886594], [31.966638, 35.886912],
  [31.966671, 35.886955], [31.968224, 35.886679], [31.969698, 35.886452],
  [31.97111, 35.886323], [31.971509, 35.886254], [31.97198, 35.886203],
  [31.972424, 35.886269], [31.973405, 35.8865], [31.973938, 35.886676],
  [31.974659, 35.886845], [31.97675, 35.888103], [31.978244, 35.889229],
  [31.980213, 35.891429], [31.981795, 35.89325], [31.98447, 35.89658],
  [31.985173, 35.897579], [31.985219, 35.89781], [31.985265, 35.898201],
  [31.98532, 35.898327], [31.9854, 35.89841], [31.985472, 35.89843],
  [31.985864, 35.897999], [31.986041, 35.897759], [31.988938, 35.894455],
  [31.991647, 35.891514], [31.992307, 35.8905], [31.998243, 35.881143],
  [31.999843, 35.878659], [32.000808, 35.877219], [32.001589, 35.876296],
  [32.002739, 35.875109], [32.003876, 35.874089], [32.0045, 35.8737],
  [32.005964, 35.872832], [32.006605, 35.87241], [32.009903, 35.871198],
  [32.011381, 35.870696], [32.012064, 35.870382], [32.013812, 35.869306],
  [32.014211, 35.869028], [32.018118, 35.86545], [32.019332, 35.864138],
  [32.020178, 35.863148], [32.022091, 35.860829], [32.023333, 35.859358],
  [32.023793, 35.858663], [32.024253, 35.857568], [32.024408, 35.857061],
  [32.024697, 35.855746], [32.024723, 35.855245], [32.024717, 35.854839],
  [32.024639, 35.853916], [32.024389, 35.852991], [32.023458, 35.849726],
  [32.022602, 35.846343], [32.022131, 35.844527], [32.022049, 35.844061],
  [32.021981, 35.843823], [32.021858, 35.843763], [32.021562, 35.843781],
  [32.021042, 35.843756], [32.02071, 35.843721], [32.020687, 35.843338],
  [32.020737, 35.842858],
];

// ─── خط 99 إياب — كامل من seed_data/route_99_return.json ───
const List<List<double>> _route99ReturnDense = [
  [32.021302, 35.842828], [32.021406, 35.843091], [32.021779, 35.843582],
  [32.021939, 35.844021], [32.022095, 35.844695], [32.022399, 35.84586],
  [32.022856, 35.847501], [32.022996, 35.848064], [32.023421, 35.849538],
  [32.024321, 35.852794], [32.024635, 35.853855], [32.024698, 35.854632],
  [32.024725, 35.855736], [32.024424, 35.857008], [32.023865, 35.858517],
  [32.023374, 35.859319], [32.022422, 35.860453], [32.021864, 35.861171],
  [32.019477, 35.863951], [32.018097, 35.865488], [32.014232, 35.869005],
  [32.012099, 35.870357], [32.010157, 35.871126], [32.007747, 35.871984],
  [32.00654, 35.87246], [32.005428, 35.873122], [32.004371, 35.873793],
  [32.002975, 35.874861], [32.002486, 35.875294], [32.000797, 35.877181],
  [31.998088, 35.881388], [31.996291, 35.884216], [31.995733, 35.885126],
  [31.992792, 35.889756], [31.991666, 35.89147], [31.990785, 35.892475],
  [31.989216, 35.894176], [31.986455, 35.896848], [31.985842, 35.897474],
  [31.985675, 35.897595], [31.985489, 35.897776], [31.985246, 35.8981],
  [31.985348, 35.898353], [31.98542, 35.898416], [31.985495, 35.898391],
  [31.985634, 35.898271], [31.985885, 35.897907], [31.985849, 35.897721],
  [31.98571, 35.897513], [31.985066, 35.896893], [31.982276, 35.893841],
  [31.980227, 35.891447], [31.978239, 35.889253], [31.976786, 35.888118],
  [31.975015, 35.887019], [31.973435, 35.886512], [31.972068, 35.88621],
  [31.969119, 35.886517], [31.96694, 35.886904], [31.96664, 35.886919],
  [31.966566, 35.886631], [31.966264, 35.886019], [31.96586, 35.885492],
  [31.965475, 35.885039], [31.964901, 35.884497], [31.964488, 35.88404],
  [31.961947, 35.88193], [31.960942, 35.881235], [31.959339, 35.879991],
  [31.958192, 35.879169], [31.958031, 35.87908], [31.955295, 35.884053],
  [31.955012, 35.884806], [31.953827, 35.888234], [31.952632, 35.891091],
  [31.951641, 35.893644], [31.951681, 35.895283], [31.951768, 35.896721],
  [31.951793, 35.897979], [31.951374, 35.899598], [31.950729, 35.90093],
  [31.949851, 35.902145], [31.948811, 35.903163], [31.947351, 35.904318],
  [31.946389, 35.905359], [31.945484, 35.906831], [31.945332, 35.907055],
  [31.94558, 35.907326], [31.94597, 35.908051], [31.946436, 35.909218],
  [31.947081, 35.910716], [31.947562, 35.911787], [31.947991, 35.913097],
  [31.948166, 35.913939], [31.948242, 35.914798], [31.948206, 35.915021],
  [31.947849, 35.915864], [31.94718, 35.916915], [31.94596, 35.919052],
  [31.945447, 35.921815], [31.946242, 35.924536], [31.946311, 35.926323],
  [31.946013, 35.928031], [31.945772, 35.928552], [31.94557, 35.928856],
  [31.945174, 35.928773],
];

const List<Map<String, dynamic>> _samplePickups = [
  {
    'id': 'sample_pickup_museum_v2',
    'data': {
      'id': 'sample_pickup_museum_v2',
      'name': 'متحف الأردن',
      'latitude': 31.9455,
      'longitude': 35.9288,
      'pointType': 'bus',
      'confirmations': <String>[],
      'confirmationCount': 0,
    },
  },
  {
    'id': 'sample_pickup_sports_v2',
    'data': {
      'id': 'sample_pickup_sports_v2',
      'name': 'المدينة الرياضية',
      'latitude': 31.9852,
      'longitude': 35.8976,
      'pointType': 'bus',
      'confirmations': <String>[],
      'confirmationCount': 0,
    },
  },
  {
    'id': 'sample_pickup_uni_v2',
    'data': {
      'id': 'sample_pickup_uni_v2',
      'name': 'الجامعة الأردنية',
      'latitude': 32.0121,
      'longitude': 35.8704,
      'pointType': 'bus',
      'confirmations': <String>[],
      'confirmationCount': 0,
    },
  },
  {
    'id': 'sample_pickup_swaileh_v2',
    'data': {
      'id': 'sample_pickup_swaileh_v2',
      'name': 'محطة صويلح',
      'latitude': 32.0207,
      'longitude': 35.8429,
      'pointType': 'bus',
      'confirmations': <String>[],
      'confirmationCount': 0,
    },
  },
  {
    'id': 'sample_pickup_north_v2',
    'data': {
      'id': 'sample_pickup_north_v2',
      'name': 'مجمع الشمال',
      'latitude': 32.0120,
      'longitude': 35.8720,
      'pointType': 'bus',
      'confirmations': <String>[],
      'confirmationCount': 0,
    },
  },
];
