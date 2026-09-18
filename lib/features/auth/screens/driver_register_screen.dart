import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:jordan_bus_tracker_new/core/constants/bus_capacity.dart';
import 'package:jordan_bus_tracker_new/core/constants/user_roles.dart';
import 'package:jordan_bus_tracker_new/core/theme/app_theme.dart';
import 'package:jordan_bus_tracker_new/core/utils/arabic_search.dart';
import 'package:jordan_bus_tracker_new/core/utils/validators.dart';
import 'package:jordan_bus_tracker_new/features/auth/providers/auth_provider.dart';
import 'package:jordan_bus_tracker_new/l10n/app_localizations.dart';
import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/services/route_plan_service.dart';

/// تسجيل حساب سائق مع اختيار مسار معتمد من الكتالوج.
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}
