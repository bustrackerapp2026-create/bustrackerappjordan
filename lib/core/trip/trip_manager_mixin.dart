import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../map/map_core_mixin.dart';
import '../../models/trip.dart';
import '../../models/vehicle_trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../services/trip_service.dart';
import '../../services/vehicle_trip_service.dart';
import '../../utils/map_utils.dart';

mixin TripManagerMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final TripService _tripService = TripService();
  final VehicleTripService _vehicleTripService = VehicleTripService();

  String? _currentTripId;
  String? _currentVehicleTripId;
  bool _isProcessingTrip = false;

  PolylineAnnotationManager? _polylineAnnotationManager;
  PolylineAnnotation? _polylineAnnotation;

  String? get currentTripId => _currentTripId;
  String? get currentVehicleTripId => _currentVehicleTripId;
  bool get isProcessingTrip => _isProcessingTrip;

  // ... (content truncated for this simulation - use real full content)
