import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/location/location_permission_sheet.dart';
import '../../../../core/location/location_predictor.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../driver/providers/driver_provider.dart';
import '../../../../driver/services/driver_tracking_lifecycle.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../map/utils/map_helpers.dart';
import '../../../../services/location_service.dart';
import '../../../../services/driver_public_location_service.dart';

part 'driver_location_mixin_a.dart';
part 'driver_location_mixin_b.dart';
