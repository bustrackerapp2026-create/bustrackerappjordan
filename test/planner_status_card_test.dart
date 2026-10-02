import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/passenger/presentation/planner_ui_projection.dart';
import 'package:jordan_bus_tracker_new/passenger/widgets/planner_status_card.dart';

void main() {
  Widget host({
    required PlannerUiProjectionStatus status,
    VoidCallback? onRetry,
  }) {
    final state = _stateFor(status);
    return MaterialApp(
      home: Scaffold(
        body: PlannerStatusCard(
          projection: PlannerUiProjection.fromState(state),
          onRetry: onRetry,
        ),
      ),
    );
  }

  testWidgets('idle renders no planner status', (tester) async {
    await tester.pumpWidget(host(status: PlannerUiProjectionStatus.idle));

    expect(find.text('جاري التخطيط...'), findsNothing);
    expect(find.text('لا توجد رحلة متاحة حاليًا'), findsNothing);
    expect(find.text('تعذر تخطيط الرحلة'), findsNothing);
  });

  testWidgets('loading renders planner loading only', (tester) async {
    await tester.pumpWidget(host(status: PlannerUiProjectionStatus.loading));

    expect(find.text('جاري التخطيط...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('success renders no persistent planner status', (tester) async {
    await tester.pumpWidget(host(status: PlannerUiProjectionStatus.success));

    expect(find.text('جاري التخطيط...'), findsNothing);
    expect(find.text('لا توجد رحلة متاحة حاليًا'), findsNothing);
    expect(find.text('تعذر تخطيط الرحلة'), findsNothing);
  });

  testWidgets('empty renders empty status without retry', (tester) async {
    await tester.pumpWidget(host(status: PlannerUiProjectionStatus.empty));

    expect(find.text('لا توجد رحلة متاحة حاليًا'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
  });

  testWidgets('error renders retry when orchestration provides it', (tester) async {
    var retries = 0;

    await tester.pumpWidget(
      host(
        status: PlannerUiProjectionStatus.error,
        onRetry: () => retries++,
      ),
    );

    expect(find.text('تعذر تخطيط الرحلة'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    expect(retries, 1);
  });

  testWidgets('error without retry keeps status-only presentation', (tester) async {
    await tester.pumpWidget(
      host(status: PlannerUiProjectionStatus.error),
    );

    expect(find.text('تعذر تخطيط الرحلة'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
  });
}

PassengerJourneyPresentationState _stateFor(
  PlannerUiProjectionStatus status,
) {
  final state = PassengerJourneyPresentationState();
  switch (status) {
    case PlannerUiProjectionStatus.idle:
      return state;
    case PlannerUiProjectionStatus.loading:
      state.beginLoading();
    case PlannerUiProjectionStatus.success:
      final generation = state.beginLoading();
      state.completeSuccess(generation);
    case PlannerUiProjectionStatus.empty:
      final generation = state.beginLoading();
      state.completeEmpty(generation);
    case PlannerUiProjectionStatus.error:
      final generation = state.beginLoading();
      state.completeError(generation, StateError('test'));
  }
  return state;
}
