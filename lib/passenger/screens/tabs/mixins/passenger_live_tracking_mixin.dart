import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/live_driver_location.dart';
import '../../../../passenger/widgets/driver_details_sheet.dart';
import '../../../../services/driver_public_service.dart';

// NOTE: This file is restored from last known-good + onFollowBus.
// Full content is loaded from local patched good file in next push if truncated.
