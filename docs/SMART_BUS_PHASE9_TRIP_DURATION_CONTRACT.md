# Phase 9 — Trip Duration Contract v1

**Status: CONTRACT FROZEN — IMPLEMENTATION CLOSED**  
**Date: 2026-10-03**

## Purpose

Define the minimum domain contract for calculating the elapsed duration of a completed operational vehicle trip.

This contract is intentionally consumer-neutral and does not define a presentation format, storage schema, batch analytics service, or Historical Analytics framework.

## FACTS VERIFIED

The current operational trip entity is:

`VehicleTrip`

Its lifecycle timestamps are:

- `startedAt`
- `endedAt`

Observed Firestore test data contains completed VehicleTrips with both timestamps present and `endedAt > startedAt`.

Historical `TripPing` telemetry is associated with VehicleTrips through `tripId`, but it is not required to calculate Trip Duration.

## Contract

### Input

A `VehicleTrip` record.

### Eligibility

A record participates in Trip Duration analytics only when all of the following are true:

1. `status == completed`
2. `startedAt != null`
3. `endedAt != null`
4. `endedAt >= startedAt`

### Calculation

```text
duration = endedAt - startedAt
```

The result represents **elapsed time between the operational trip start and terminal trip timestamp**.

### Output

The domain meaning of the output is:

`elapsed trip duration`

The contract intentionally does **not** freeze a numeric unit such as seconds or milliseconds.

A future consumer may choose an appropriate serialization or presentation unit at its own integration boundary.

### Invalid / incomplete records

A VehicleTrip that fails any eligibility rule is **excluded from Trip Duration analytics**.

An invalid record must not cause the analytics operation for other valid records to fail.

Conceptually:

```text
Trip A → valid → duration
Trip B → invalid → excluded
Trip C → valid → duration
```

This exclusion rule does not modify the underlying VehicleTrip record.

## Implementation Slice

The frozen contract was implemented as one focused production slice with no unrelated production changes.

### Production file

`lib/services/trip_duration_calculator.dart`

The calculator is a pure deterministic domain helper:

```text
VehicleTrip
→ completed
→ timestamps present
→ endedAt >= startedAt
→ endedAt.difference(startedAt)
→ Duration?
```

Invalid or incomplete input returns `null`.

The implementation does not access the clock, Firestore, GPS, TripPing, ETA, RouteProgress, UI, or any tracking lifecycle.

### Focused test file

`test/trip_duration_calculator_test.dart`

The focused suite covers:

1. valid completed trip;
2. zero duration;
3. active trip excluded;
4. cancelled trip excluded;
5. missing `startedAt`;
6. missing `endedAt`;
7. `endedAt < startedAt`;
8. input `VehicleTrip` remains unchanged.

### Implementation commits

Production slice:

`bfc1e4f6517a068c8d05768689f3b62d777e61a2`

Test correction:

`24f04612453b163cac05687bdc6ac5aeec20c4b7`

Final test fix:

`27730133abd5feced3cda3f805ce7fd101ed5265`

Documentation closeout:

This document update is committed separately after verification.

## Verification Evidence

Verification was performed from the local project after pulling the final implementation commit.

Focused test:

```text
flutter test test/trip_duration_calculator_test.dart
→ 8/8 tests passed
```

Static analysis:

```text
flutter analyze
→ No issues found
```

Full test suite:

```text
flutter test
→ 358/358 tests passed
```

The full-suite output included existing DriverTracking-related test logging, but the suite completed successfully.

These results verify the current implementation against the observed test population. They do not establish historical-dataset completeness or production-scale statistical quality.

## Explicit Non-Goals

This contract does not:

- reconstruct duration from `TripPing` timestamps;
- infer missing `startedAt` or `endedAt`;
- use `DateTime.now()`;
- use GPS distance, `routeProgress`, speed, heading, or ETA;
- modify `TripPing`;
- modify `DriverTrackingHub`;
- modify `DriverTrackingLifecycle`;
- modify `shutdown()`;
- modify Firestore Rules or schema;
- create a generic `HistoricalAnalyticsService`;
- create an `AnalyticsRepository`;
- create a generic metric engine;
- require a Firestore reader as part of the domain calculation.

## Data Quality Boundary

This contract establishes **contractual support** for Trip Duration.

Current Firestore evidence demonstrates the contract on the observed test population.

It does **not** establish historical-dataset completeness or production-scale statistical quality.

Therefore:

- **Contractually Supported:** ✅
- **Demonstrated on observed test data:** ✅
- **Production-scale validation:** ⏳

## Consumer Boundary

The contract remains independent of any specific downstream consumer.

Unit conversion, formatting, aggregation, filtering UI, persistence of derived metrics, or reporting semantics must be defined only when an actual consumer requires them.

## Closure

The Trip Duration production slice is **closed within the current Phase 9 scope**.

No downstream Consumer, Firestore analytics reader, dashboard, aggregation framework, or additional Historical Analytics abstraction is introduced by this slice.

Future Phase 9 work must begin from a newly established Consumer or Requirement rather than expanding this closed slice by assumption.
