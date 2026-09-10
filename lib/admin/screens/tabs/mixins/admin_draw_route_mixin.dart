import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/models/route_point.dart';
import '../../../core/services/mapbox_service.dart';
import '../../../core/utils/route_plan_geometry.dart';
import '../models/admin_route_point.dart';
import '../services/admin_route_service.dart';

mixin AdminDrawRouteMixin<T extends StatefulWidget> on State<T> {
  final List<RoutePoint> _drawPoints = <RoutePoint>[];
  final List<List<RoutePoint>> _roadSegments = <List<RoutePoint>>[];
  LineAnnotation? _drawLine;
  int _drawSession = 0;
  int _drawMutationSeq = 0;
  int _lineRedrawSeq = 0;
  int _visualClearGen = 0;
  bool _lineRedrawBusy = false;
  bool _lineRedrawQueued = false;
  Timer? _lineRedrawDone;
  Timer? _tempLineCoalesce;
  Timer? _finalLineCoalesce;
  int _tapSeq = 0;
  bool _tapLocked = false;
  bool isDrawingRoute = false;
  bool isSnappingSegment = false;

  static const bool _liveDirectionsEnabled = true;
  static const bool _livePolylineEnabled = true;
  static const String _liveRouteSourceId = 'admin_draw_route_source';
  static const String _liveRouteLayerId = 'admin_draw_route_layer';

  int _segmentOpSeq = 0;
  bool _segmentOpBusy = false;
  Completer<void>? _segmentOpDone;
  int _directionsOpSeq = 0;
  bool _directionsBusy = false;
  Completer<void>? _directionsDone;

  MapboxMap? _map;

  int get drawPointCount => _drawPoints.length;

  void setDrawRouteMap(MapboxMap map) {
    _map = map;
  }

  Future<void> _ensureLiveRouteLayer() async {
    final map = _map;
    if (map == null) return;

    final style = map.style;
    if (!await style.styleSourceExists(_liveRouteSourceId)) {
      await style.addSource(
        GeoJsonSource(
          id: _liveRouteSourceId,
          data: jsonEncode({
            'type': 'FeatureCollection',
            'features': const [],
          }),
        ),
      );
    }

    if (!await style.styleLayerExists(_liveRouteLayerId)) {
      await style.addLayer(
        LineLayer(
          id: _liveRouteLayerId,
          sourceId: _liveRouteSourceId,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          lineColor: 0xFF7C3AED,
          lineWidth: 5.0,
        ),
      );
    }
  }

  Map<String, dynamic> _liveRouteGeoJson(List<RoutePoint> path) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': <String, dynamic>{
            'type': 'LineString',
            'coordinates': path
                .map((p) => <double>[p.longitude, p.latitude])
                .toList(growable: false),
          },
        },
      ],
    };
  }

  Future<void> _beginDirectionsOp() async {
    while (_directionsBusy) {
      final done = _directionsDone;
      if (done == null) break;
      await done.future;
    }
    _directionsBusy = true;
    _directionsDone = Completer<void>();
    _directionsOpSeq++;
  }

  void _endDirectionsOp() {
    _directionsBusy = false;
    final done = _directionsDone;
    _directionsDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> _beginSegmentOp() async {
    while (_segmentOpBusy) {
      final done = _segmentOpDone;
      if (done == null) break;
      await done.future;
    }
    _segmentOpBusy = true;
    _segmentOpDone = Completer<void>();
    _segmentOpSeq++;
  }

  void _endSegmentOp() {
    _segmentOpBusy = false;
    final done = _segmentOpDone;
    _segmentOpDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  void _invalidateFinalCoalesce() {
    _finalLineCoalesce?.cancel();
    _finalLineCoalesce = null;
  }

  void _invalidateTempCoalesce() {
    _tempLineCoalesce?.cancel();
    _tempLineCoalesce = null;
  }

  Future<void> _redrawDrawLine({
    required List<RoutePoint> path,
    required int session,
    required int mutation,
    required int clearGen,
    bool temporary = false,
  }) async {
    if (!_livePolylineEnabled) return;
    if (!mounted || session != _drawSession || mutation != _drawMutationSeq || clearGen != _visualClearGen) {
      return;
    }

    final map = _map;
    if (map == null) return;

    final geoJson = _liveRouteGeoJson(path);
    try {
      await _ensureLiveRouteLayer();
      if (!mounted || session != _drawSession || mutation != _drawMutationSeq || clearGen != _visualClearGen) {
        return;
      }
      await map.style.setStyleSourceProperty(
        _liveRouteSourceId,
        'data',
        jsonEncode(geoJson),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Live route redraw failed: $e');
      }
    }
  }

  List<RoutePoint> _flattenedRoadPath() {
    final points = <RoutePoint>[];
    for (final segment in _roadSegments) {
      if (segment.isEmpty) continue;
      points.addAll(segment);
    }
    if (points.length <= 400) return points;
    return RoutePlanGeometry.sampleByDistance(
      points,
      stepMeters: 12,
      maxPoints: 400,
    );
  }

  void _scheduleTempLineRedraw(List<RoutePoint> path, int session, int mutation, int clearGen) {
    _tempLineCoalesce?.cancel();
    _tempLineCoalesce = Timer(const Duration(milliseconds: 40), () {
      _redrawDrawLine(
        path: path,
        session: session,
        mutation: mutation,
        clearGen: clearGen,
        temporary: true,
      );
    });
  }

  void _scheduleFinalLineRedraw(List<RoutePoint> path, int session, int mutation, int clearGen) {
    _finalLineCoalesce?.cancel();
    _finalLineCoalesce = Timer(const Duration(milliseconds: 40), () {
      _redrawDrawLine(
        path: path,
        session: session,
        mutation: mutation,
        clearGen: clearGen,
      );
    });
  }

  Future<void> onDrawRouteMapTap(MapboxMap map, Point<double> point) async {
    if (!mounted) return;
    _map = map;

    final rawPoint = RoutePoint(
      latitude: point.coordinates.lat.toDouble(),
      longitude: point.coordinates.lng.toDouble(),
    );

    final session = _drawSession;
    final tapSeq = ++_tapSeq;
    final mutation = ++_drawMutationSeq;
    final clearGen = _visualClearGen;

    _drawPoints.add(rawPoint);
    if (_drawPoints.length >= 2) {
      _roadSegments.add(<RoutePoint>[_drawPoints[_drawPoints.length - 2], rawPoint]);
    }
    if (mounted) setState(() {});

    if (_drawPoints.length >= 2) {
      _scheduleTempLineRedraw(
        _flattenedRoadPath(),
        session,
        mutation,
        clearGen,
      );
    }

    if (_liveDirectionsEnabled && _drawPoints.length >= 2) {
      final previous = _drawPoints[_drawPoints.length - 2];
      final currentIndex = _drawPoints.length - 1;
      final snapped = await MapboxService.snapPointToRoad(
        previous,
        rawPoint,
      );
      if (!mounted || session != _drawSession || tapSeq != _tapSeq || currentIndex >= _drawPoints.length) {
        return;
      }

      _drawPoints[currentIndex] = snapped.last;
      if (_roadSegments.isNotEmpty) {
        _roadSegments[_roadSegments.length - 1] = snapped;
      }
      ++_drawMutationSeq;
      if (mounted) setState(() {});
      _scheduleFinalLineRedraw(
        _flattenedRoadPath(),
        session,
        _drawMutationSeq,
        clearGen,
      );
    }
  }

  void _clearDrawVisuals() {
    _visualClearGen++;
    _invalidateFinalCoalesce();
    _invalidateTempCoalesce();
    final map = _map;
    if (map == null) return;
    map.style.setStyleSourceProperty(
      _liveRouteSourceId,
      'data',
      jsonEncode({
        'type': 'FeatureCollection',
        'features': const [],
      }),
    );
  }

  void disposeAdminDrawRoute() {
    _drawSession++;
    _drawMutationSeq++;
    _lineRedrawSeq++;
    _visualClearGen++;
    _lineRedrawQueued = false;
    _invalidateFinalCoalesce();
    _invalidateTempCoalesce();
    _tapLocked = false;
    _drawPoints.clear();
    _roadSegments.clear();
    _drawLine = null;
    _segmentOpBusy = false;
    _segmentOpDone = null;
    _directionsBusy = false;
    _directionsDone = null;
    isDrawingRoute = false;
    isSnappingSegment = false;
  }
}
