## Phase 8A — Second Criterion Preflight: Fastest

**Result: DEFERRED — 2026-10-02**

### FACTS VERIFIED

The project already contains a deterministic ETA path:

```text
AcceptedEtaObservation
+
StopRuntimeSnapshot
+
EtaFreshnessPolicy
    ↓
EtaInputBuilder
    ↓
EtaEngine
    ↓
EtaResult
```

The existing ETA runtime invocation is:

```text
EtaRuntimeInvocation.evaluate(...)
```

It explicitly requires:

- `AcceptedEtaObservation`
- `StopRuntimeSnapshot`
- injected `EtaFreshnessPolicy`
- caller-supplied `evaluatedAt`

The current `PassengerJourneyPlanningService` does not provide these runtime snapshots. Its production output remains the existing:

```dart
List<({
  PlannedRoute route,
  VehicleTrip vehicleTrip,
})>
```

The `DriverTrackingHub` does hold:

- latest `AcceptedEtaObservation`
- latest `StopRuntimeSnapshot`

but these are in-memory operational snapshots owned by the driver tracking runtime. They are not part of the Passenger JourneyPlanner association contract.

The Hub derives the snapshots from the active trip's accepted GPS/RouteProgress state and already-loaded route Stops. The Hub is intentionally outside the Passenger Planner boundary.

### PROBLEM IDENTIFIED

`Fastest` requires a comparable journey-time measure for each Journey Option.

The current ETA implementation can calculate time only when the accepted observation and the current StopRuntimeSnapshot are available through the existing driver runtime path.

The current Planner association gives us `PlannedRoute + VehicleTrip`, but it does not provide the exact accepted ETA observation / Stop runtime snapshot required by `EtaRuntimeInvocation`.

Using only:

- `VehicleTrip.routeProgress`
- `VehicleTrip.speed`
- `VehicleTrip.lastLocationAt`

as an implicit replacement would change the frozen ETA integration semantics and would manufacture a new time basis.

### DESIGN CONSTRAINT

For Phase 8A:

- `Fastest` may use ETA only when a valid, explicit, and deterministic comparable journey-time input exists.
- Do not make `PassengerJourneyPlanningService` depend on `DriverTrackingHub` singleton state.
- Do not reconstruct `AcceptedEtaObservation` from arbitrary `VehicleTrip` fields unless a separate contract explicitly defines that transformation.
- Do not synthesize `StopRuntimeSnapshot` inside Ranking.
- Do not add Firestore reads solely to manufacture the ETA input.
- Do not add an ETA fallback value.
- Do not use `DateTime.now()` as the missing observation timestamp.
- A route with no fixed Stops remains a valid Journey Option, but the current ETA path cannot produce a stop-based ETA for it.
- An unavailable Fastest value must not automatically invalidate the underlying Journey Option.

### CURRENT DECISION

**Fastest — DEFERRED.**

The existing ETA machinery is real and deterministic, but the required runtime data contract is not currently exposed at the Passenger JourneyPlanner boundary.

This is a data/integration-boundary gap, not a reason to rewrite ETA, DriverTrackingHub, StopRuntime, or Planner association.

### BOUNDARIES PRESERVED

No Production Code is added in this preflight.

No changes are authorized here to:

- `PassengerJourneyPlanningService`
- `JourneyRouteVehicleAssociationService`
- `DriverTrackingHub`
- `DriverTrackingLifecycle`
- `EtaRuntimeInvocation`
- `EtaInputBuilder`
- `EtaEngine`
- Stop runtime services
- Mapbox / UI
- `NearbyRoutesService`
- Firestore schema or indexes

### RESULT

**Fastest Criterion Preflight — DEFERRED ✅**

The current Phase 8A supported criterion remains:

- **Closest — SUPPORTED / CLOSED**
- **Fastest — DEFERRED**
- **Least Walking — DEFERRED**
- **Fewest Transfers — DEFERRED**

### NEXT

Do not create another criterion implementation merely to keep Phase 8A moving.

The next engineering decision should be a fresh inspect of the **Ranking Consumer Boundary** around the already-supported `Closest` criterion, asking whether an actual consumer needs deterministic ordering now. No Generic Ranking Engine is justified until that consumer requirement is concrete.
