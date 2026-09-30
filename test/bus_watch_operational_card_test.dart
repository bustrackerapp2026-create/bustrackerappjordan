import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/live_driver_location.dart';
import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_operational_read_result.dart';
import 'package:jordan_bus_tracker_new/passenger/widgets/bus_watch_operational_card.dart';

void main() {
  BusWatchOperationalSnapshot snapshot() {
    return BusWatchOperationalSnapshot(
      passengerTripId: 'trip-1',
      vehicleTripId: 'vehicle-1',
      driverId: 'driver-1',
      busNumber: '12',
      routeId: 'route-1',
      direction: 'outbound',
      status: VehicleTripStatus.active,
      liveLocation: const LiveDriverLocation(
        driverId: 'driver-1',
        fullName: 'أحمد',
        latitude: 31.95,
        longitude: 35.91,
      ),
      speed: 7,
      heading: 90,
      routeProgress: 0.4,
      lastLocationAt: DateTime(2026, 9, 30, 18),
      approvedRoute: const PlannedRoute(
        id: 'route-1',
        createdBy: 'admin-1',
        lineName: 'عمان - الزرقاء',
        direction: RouteDirection.outbound,
        points: [
          RoutePoint(latitude: 31.95, longitude: 35.91),
          RoutePoint(latitude: 31.96, longitude: 35.92),
        ],
      ),
    );
  }

  Widget host({
    bool loading = false,
    BusWatchOperationalReadResult? result,
    Object? error,
    VoidCallback? onRetry,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: BusWatchOperationalCard(
            loading: loading,
            result: result,
            error: error,
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }

  testWidgets('shows loading state', (tester) async {
    await tester.pumpWidget(host(loading: true));

    expect(find.text('جارٍ تحميل معلومات الحافلة...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows available operational data', (tester) async {
    await tester.pumpWidget(
      host(
        result: BusWatchOperationalReadResult.available(snapshot()),
      ),
    );

    expect(find.text('الحافلة في رحلة نشطة'), findsOneWidget);
    expect(find.text('باص 12'), findsOneWidget);
    expect(find.text('عمان - الزرقاء'), findsOneWidget);
    expect(find.text('ذهاب'), findsOneWidget);
    expect(find.text('أحمد'), findsOneWidget);
  });

  testWidgets('shows no active vehicle trip', (tester) async {
    await tester.pumpWidget(
      host(
        result: BusWatchOperationalReadResult.unavailable(
          BusWatchOperationalReadStatus.noActiveVehicleTrip,
        ),
      ),
    );

    expect(
      find.text('لا توجد رحلة تشغيلية نشطة للحافلة حاليًا'),
      findsOneWidget,
    );
  });

  testWidgets('shows no live location', (tester) async {
    await tester.pumpWidget(
      host(
        result: BusWatchOperationalReadResult.unavailable(
          BusWatchOperationalReadStatus.noLiveLocation,
        ),
      ),
    );

    expect(
      find.text('الرحلة التشغيلية موجودة، لكن موقع الحافلة غير متاح حاليًا'),
      findsOneWidget,
    );
  });

  testWidgets('shows no approved route', (tester) async {
    await tester.pumpWidget(
      host(
        result: BusWatchOperationalReadResult.unavailable(
          BusWatchOperationalReadStatus.noApprovedRoute,
        ),
      ),
    );

    expect(
      find.text('تعذر تحميل المسار المعتمد للحافلة حاليًا'),
      findsOneWidget,
    );
  });

  testWidgets('shows retry for infrastructure error', (tester) async {
    var retries = 0;

    await tester.pumpWidget(
      host(
        error: StateError('read failed'),
        onRetry: () => retries++,
      ),
    );

    expect(find.text('تعذر تحديث معلومات الحافلة'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    expect(retries, 1);
  });

  testWidgets('disables retry while loading after an error', (tester) async {
    var retries = 0;

    await tester.pumpWidget(
      host(
        loading: true,
        error: StateError('read failed'),
        onRetry: () => retries++,
      ),
    );

    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
    expect(retries, 0);
  });

  testWidgets('does not render no-passenger-context', (tester) async {
    await tester.pumpWidget(
      host(
        result: BusWatchOperationalReadResult.unavailable(
          BusWatchOperationalReadStatus.noPassengerContext,
        ),
      ),
    );

    expect(find.text('جارٍ تحميل معلومات الحافلة...'), findsNothing);
    expect(find.text('إعادة المحاولة'), findsNothing);
  });
}
