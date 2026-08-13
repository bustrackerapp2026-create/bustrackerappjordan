import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_utils.dart';
import '../../../core/pickup/pickup_point_mixin.dart';
import '../../../core/trip/trip_manager_mixin.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../driver/providers/driver_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/live_tracking_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/planned_route.dart';
import 'mixins/driver_location_mixin.dart';
import 'mixins/route_plan_recording_mixin.dart';

/// خريطة السائق: تتبع حي + رحلات + تسجيل مسار خطة الخط — كل العمليات مربوطة بـ uid السائق الحالي فقط.
class DriverMapTab extends StatefulWidget {
  const DriverMapTab({super.key});

  @override
  State<DriverMapTab> createState() => _DriverMapTabState();
}
