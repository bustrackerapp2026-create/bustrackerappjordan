## First Criterion Preflight — Closest

**Result: DEFERRED ✅ — 2026-10-02**

Inspect أثبت أن `Closest` لديه مدخلات أولية حقيقية: `VehicleTrip.currentLocation` + `lastLocationAt` + Passenger Origin.

لكن لا يوجد بعد `Vehicle Location Freshness Policy` حتمي ومحقون خاص بـRanking. لذلك لا نعلن `Closest` Supported اعتمادًا على موقع مخزن قديم.

العقد المؤقت المثبت:

- المرجع: vehicle location → passenger Origin.
- المصدر: `VehicleTrip.currentLocation`.
- أهلية الموقع: تعتمد لاحقًا على `VehicleTrip.lastLocationAt` + freshness policy محقونة.
- لا `DateTime.now()` داخل criterion.
- لا inference من `routeProgress` أو speed أو heading.
- الموقع المفقود/غير المؤهل يجعل الـoption **not rankable for Closest** مع إبقائه في candidate set.
- المقارنة عند الدعم: أقل مسافة بالمتر.
- tie-break: `route.id + route.direction.firestoreValue + vehicleTrip.id`.

`Fastest` ما يزال Deferred لأن ETA runtime الحالي يحتاج `StopRuntimeSnapshot` غير موجود في Planner association contract.

التفاصيل الكاملة: `docs/SMART_BUS_PHASE8A_CLOSEST_CRITERION_PREFLIGHT.md`.

**NEXT:** تجميد `Vehicle Location Freshness Policy` الصغيرة والمحقونة، ثم تنفيذ `Closest` فقط باختبارات مركزة.

