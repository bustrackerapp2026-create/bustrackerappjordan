# Phase 8A — Engineering Ranking Contract v1

## Status
**DESIGN FROZEN — 2026-10-02**

This document freezes the planning contract for the first deterministic Engineering Ranking layer.

It defines the boundary only. It does not add a production Ranking Engine, a new JourneyOption model, an ETA consumer, a walking model, a transfer model, or UI behavior.

---

## FACTS VERIFIED

The current JourneyPlanner path provides Route Candidate Discovery, Active Vehicle Discovery, and Route + Vehicle Association.

The current production association remains the original PlannedRoute + VehicleTrip pair; no JourneyOption domain model is required by this contract.

Deterministic ETA primitives exist, but ETA Result Consumption is not a production consumer and remains design-frozen/deferred.

---

## PROBLEM IDENTIFIED

Engineering Ranking needs a contract before an engine because the roadmap names several ranking ideas whose required data and missing-data semantics are not yet equivalent.

The Ranking layer must not manufacture missing information through ETA fallback, currentLocation inference, speed inference, guessed walking distance, or guessed transfer count.

---

## DESIGN CONSTRAINT

### 1. Ranking input

The minimum semantic input is:

Planning Context + Candidate Associations + One Defined Criterion

Candidate Associations are valid route-vehicle associations from JourneyPlanner.

Planning context is explicit whenever a criterion needs it. Ranking does not infer missing context from unrelated fields.

No copied DTO, wrapper, or new JourneyOption model is required.

### 2. Criterion taxonomy

**Defined criterion:** meaning and required data can be stated clearly; this does not mean production-supported.

**Supported criterion:** required data, missing-data semantics, comparison rule, tie-break, focused tests, and non-synthetic implementation are all frozen and implemented.

**Deferred criterion:** defined, but required data/model/comparison semantics are not yet sufficiently established for production.

### 3. Current criteria classification

| Criterion | Meaning | Current status |
| --- | --- | --- |
| **Fastest** | Smallest explicitly valid journey-time measure for the planning context. | **DEFERRED** |
| **Closest** | Smallest explicitly defined distance measure with frozen reference points and units. | **DEFERRED** |
| **Least Walking** | Smallest explicitly defined walking/access distance in the planning context. | **DEFERRED** |
| **Fewest Transfers** | Smallest transfer count within an explicit multi-leg journey representation. | **DEFERRED** |

**Supported production criteria: none.**

### 4. Data requirements

Each criterion must declare its required data before implementation.

- Fastest requires an explicit comparable journey-time/ETA value; no fallback ETA.
- Closest requires an explicit distance metric with defined references and units.
- Least Walking requires an explicit walking/access model; route distance or straight-line distance is not silently substituted.
- Fewest Transfers requires an explicit multi-leg journey model and transfer-count semantics.

### 5. Missing-data semantics

Unsupported criterion ≠ Journey Option invalid.

Criterion unavailable for an option ≠ Option invalid.

The generic Ranking layer has no implicit invalidation rule for missing criterion data.

Before a criterion becomes Supported, its own semantics must explicitly choose one of:

- skip the criterion while preserving the option;
- mark the option not rankable for that criterion while preserving the option;
- criterion-specific rejection only when a documented requirement proves exclusion is semantically correct.

Ranking never invents a fallback value to force comparability.

For the four current criteria, these semantics are not frozen; therefore all four remain Deferred.

### 6. Comparison rule

A Supported criterion must declare a deterministic comparison direction: lower-is-better or higher-is-better, using an explicitly defined comparable value.

For compound ranking, criteria are applied only in the explicit order supplied by the caller. No implicit global priority among the four roadmap criteria is created here.

### 7. Tie-break

Ties after the requested Supported criterion/criteria are resolved deterministically from the existing association identity:

route.id + route.direction.firestoreValue + vehicleTrip.id

The tuple is compared lexicographically after the normalization rules already used by the underlying model values.

This is a determinism rule only, not a quality score.

### 8. No data synthesis inside Ranking

Ranking must not contain ETA fallback values, DateTime.now() as a substitute for observation time, current-location inference, speed inference without a frozen time basis, guessed walking distance, guessed transfer count, or new Firestore reads used to manufacture missing ranking inputs.

### 9. Boundary

This contract does not authorize changes to PassengerJourneyPresentationState, PlannerUiProjection, PlannerStatusCard, PassengerPlannedRoutesMixin, NearbyRoutesService, ETA Result Consumption, Mapbox, GPS/Tracking, or Firestore schema/indexes.

It does not require a new JourneyOption model.

---

## RESULT

**Engineering Ranking Contract v1 — DESIGN FROZEN ✅**

Frozen: minimum ranking input, Defined/Supported/Deferred taxonomy, data requirements, missing-data semantics, deterministic comparison, deterministic tie-break, and the prohibition of fallback/inference.

**Current production-supported criteria: none.** This is intentional.

---

## NEXT

Inspect the current data available for the first concrete criterion.

Implement one criterion only once its data requirement and missing-data semantics are demonstrably satisfiable.

Do not build a generic Ranking framework first.
