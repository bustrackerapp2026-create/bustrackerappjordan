import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../providers/driver_provider.dart';
import '../../services/vehicle_trip_service.dart';
import '../widgets/driver_custom_app_bar.dart';
import '../widgets/driver_custom_bottom_nav_bar.dart';
import 'tabs/driver_map_tab.dart';
import 'tabs/operations_tab.dart';
import 'tabs/bookings_tab.dart';
import 'tabs/profile_tab.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}