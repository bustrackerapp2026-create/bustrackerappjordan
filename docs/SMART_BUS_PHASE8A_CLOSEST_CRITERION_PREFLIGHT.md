## First Criterion — Closest

**Result: SUPPORTED / CLOSED ✅ — 2026-10-02**

### FACTS VERIFIED

Inspect أثبت أن `Closest` لديه مدخلات تشغيلية حقيقية: `VehicleTrip.currentLocation` + `lastLocationAt` + Passenger Origin.

العائق الذي ظهر في الـpreflight كان غياب `Vehicle Location Freshness Policy` حتمية ومحقونة خاصة بـRanking. تم الآن تنفيذها، وأصبح `Closest` قابلًا للدعم الإنتاجي ضمن العقد المجمد.

- المرجع: vehicle location → passenger Origin.
- المصدر: `VehicleTrip.currentLocation`.
- أهلية الموقع: تعتمد على `VehicleTrip.lastLocationAt` + freshness policy محقونة.
- لا `DateTime.now()` داخل criterion.
- لا inference من `routeProgress` أو speed أو heading.
- الموقع المفقود/غير المؤهل يجعل الـoption **not rankable for Closest** مع إبقائه في candidate set.
- المقارنة: أقل مسافة بالمتر.
- tie-break: `route.id + route.direction.firestoreValue + vehicleTrip.id`.

### PROBLEM IDENTIFIED

المعيار يجب أن يقارن بُعد المركبة عن Origin فقط عندما يكون الموقع الحالي صالحًا وحديثًا، وألا يحول غياب قيمة Closest إلى إلغاء الـJourney Option.

### DESIGN CONSTRAINT

العقد المثبت:

- المرجع: `VehicleTrip.currentLocation` → Passenger Origin.
- الوحدة: meters.
- حداثة الموقع تعتمد على `VehicleTrip.lastLocationAt` + `VehicleLocationFreshnessPolicy` محقونة.
- `evaluatedAt` يأتي من المستهلك؛ لا `DateTime.now()` داخل criterion.
- missing / stale / future location => `unavailable` فقط.
- لا inference من `routeProgress` أو speed أو heading.
- لا ETA fallback أو ETA dependency.
- لا Firestore reads جديدة.
- أقل مسافة هي الأفضل.
- عند التعادل: `route.id + route.direction.firestoreValue + vehicleTrip.id` lexicographically.
- عدم توفر Closest لا يبطل الـassociation؛ يجعلها فقط غير قابلة للترتيب بهذا المعيار.

### IMPLEMENTATION

تم تنفيذ وحدتين صغيرتين فقط:

- `VehicleLocationFreshnessPolicy`: حالات `fresh`, `stale`, `future`, `missing`، مع `maxAge` محقون دون default رقمي في تكامل Planner.
- `ClosestCriterion`: تحقق من الإحداثيات، شرط freshness، حساب Haversine بالمتر، وtie-break حتمي.

لا يحتوي التنفيذ على clock access أو Firestore أو ETA أو inference أو mutation.

### VALIDATION

- `flutter test test/vehicle_location_freshness_policy_test.dart test/closest_criterion_test.dart` → **15/15 passed**.
- `flutter analyze` → **No issues found!**
- `flutter test` → **350/350 passed**.
- `git status` → **working tree clean** والمتزامن مع `origin`.

ظهرت أثناء الاختبار الكامل سجلات stale-GPS متوقعة من اختبارات Tracking القائمة، لكن المجموعة اكتملت بنجاح دون failures.

### BOUNDARIES PRESERVED

لم يتم تعديل JourneyPlanner orchestration أو Presentation/UI أو ETA consumer أو NearbyRoutesService أو DriverTrackingLifecycle/GPS أو Mapbox أو Firestore schema/indexes.

**RESULT:** **Closest Engineering Ranking Criterion v1 — SUPPORTED / CLOSED ✅**

`Fastest` ما يزال **Deferred** لأن ETA runtime الحالي يحتاج `StopRuntimeSnapshot` غير موجود في Planner association contract.

### NEXT

الانتقال إلى criterion التالي يكون بعد inspect/preflight مستقل. لا يتم إنشاء Generic Ranking Engine ولا إدخال Ranking أو ETA أو UI أو Tracking changes ضمن نفس الـpatch.
