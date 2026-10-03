# Phase 9 — Trip Duration Contract v1

**Status: DESIGN FROZEN — Contract only**  
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

## Next Step

The next step is a review of the smallest production implementation slice.

No Production Code is authorized by this document alone.
