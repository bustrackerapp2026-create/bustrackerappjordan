# Smart Bus — Current Execution Plan

> مرجع المتابعة اليومية لتنفيذ النقاط الحالية في مشروع Jordan Smart Transit.
> لا يحل محل `SMART_BUS_MASTER_PLAN.md`، بل يحدد ما نفعله الآن وبأي ترتيب.

## قاعدة التنفيذ

**تغيير واحد → اختبار واحد → تحليل النتيجة → تثبيت النجاح → الخطوة التالية**

لا Big-Bang Refactor، ولا نعيد فتح أجزاء مستقرة بلا Regression واضح.

---

# 1. إصلاح بحث المسار المعتمد أثناء إنشاء حساب السائق

**الحالة: ✅ مكتملة**

## المشكلة المثبتة

كان البحث العام أثناء التسجيل يصل إلى `plannedRoutes` المحمية، ما أدى إلى:

`PERMISSION_DENIED: Missing or insufficient permissions.`

## الإصلاح

أصبحت `RoutePlanService.searchApprovedRoutes()` تقرأ metadata المعتمدة من:

`routeCatalog`

ثم تبني `PlannedRoute` خفيفًا للاختيار أثناء التسجيل، بينما تبقى `plannedRoutes` مصدر البيانات التشغيلية الكاملة بعد تسجيل الدخول.

## التحقق

- شاشة تسجيل السائق تستخدم `searchApprovedRoutes()` مباشرة.
- عند البحث عن `الجيزة` ظهرت النتيجة المطلوبة في الاختبار اليدوي:
  `الجيزة - اليادودة - دوار الشرق الأوسط`.
- تم تعديل `ArabicSearch` بحيث لا يؤدي البحث أحادي الكلمة إلى نتائج غير مرتبطة.

**هذا البند لم يعد هو العائق الحالي.**

---

# 2. تثبيت نسخة المشروع الحالية من الجهاز على GitHub

**الحالة: ✅ مثبتة ومزامنة**

- فرع التطوير الحالي:
  `stage/approved-route-line-vehicle-link-v1`.
- آخر مزامنة محلية مؤكدة تطابق GitHub عند merge commit:
  `4709bb8ff61c41708bf3b5daba5b4a4b20632377`.
- حالة الجهاز بعد المزامنة:
  **nothing to commit, working tree clean**.
- تغييرات Phase 4.4-B مدمجة عبر PRs #37 و#38 و#39، وتم توثيق الإغلاق عبر PR #40.
- **لم يتم دمج فرع التطوير في `stable/route-drawing-baseline` أو `stable/vehicle-session-route-persistence-v1`.**

## ملاحظة منهجية

نستخدم فرع التطوير كمساحة التنفيذ، ولا نعدّل الـstable baselines أثناء هذه المرحلة.

---

# 3. تصميم ذكاء المسارات الطويلة

**الحالة: 💡 متفق عليه كاتجاه تصميم، لم يبدأ التنفيذ**

## المشكلة

المسارات الطويلة مثل:

`الكرك → عمان`

تمر بمناطق كثيرة، ولا يمكن مطالبة السائق بإدخال كل أسماء المناطق يدويًا.

## التصميم المستهدف

نفصل بين:

`TransitLine`

و

`Route`

و

`GPS Track`

و

`Detected Areas`

وبذلك يكون اسم الخط شيئًا، والمسار الجغرافي شيئًا آخر، والمناطق التي عبرها الباص يتم اكتشافها تدريجيًا من الحركة الفعلية.

---

# 4. الاكتشاف التلقائي للمناطق التي يمر بها الباص

**الحالة: ⏳ لم يبدأ**

النظام لاحقًا يأخذ GPS التاريخي للرحلة ويحوّله إلى تغطية مكانية:

`GPS Track → Map Matching / Area Detection → Route Coverage`

مثال:

`الكرك → عمان`

قد يكتشف تلقائيًا مناطق مثل القطرانة، أم الرصاص، ضبعة، الجيزة، القسطل، جسر المطار وغيرها، مع درجة ثقة بدل افتراض اسم المنطقة بلا دليل.

لا نضيف هذه الطبقة قبل أن يصبح التقاط GPS التاريخي مستقرًا.

---

# 5. الاستفادة من عمليات بحث الركاب كإشارة طلب

**الحالة: ⏳ لم يبدأ**

كل بحث مهم يمكن تحويله إلى `Demand Signal`.

نسجل لاحقًا:

- كلمة البحث.
- الشكل الموحّد للكلمة.
- الوقت.
- المنطقة المحتملة.
- المسارات المرشحة.
- عدد التكرارات.

الهدف هو معرفة أين يتركز الطلب، وليس مجرد استخدام البحث للعثور على route.

---

# 6. ربط الطلب بتغطية المسارات

**الحالة: ⏳ لم يبدأ**

بعد توفر `Detected Areas` و`Demand Signals`:

`Passenger Search → Area → Routes Passing Area → Available Buses → ETA`

وبذلك يستطيع النظام معرفة المسارات التي تغطي الطلب فعليًا.

---

# 7. اكتشاف الطلب غير المغطى

**الحالة: ⏳ لم يبدأ**

عندما توجد عمليات بحث متكررة عن منطقة ولا توجد تغطية مناسبة، يسجل النظام:

`Unserved Demand Signal`

ويصبح هذا لاحقًا مدخلًا للإدارة لمراجعة الخطوط أو اقتراح خط جديد.

---

# 8. التوصية الذكية بالمسارات والخطوط

**الحالة: ⏳ لم يبدأ**

بعد تراكم بيانات الحركة والطلب، يمكن ترتيب الخيارات هندسيًا أولًا:

- الأسرع.
- الأقرب.
- الأقل مشيًا.
- الأقل تحويلات.

ثم لاحقًا نضيف التحليل الإحصائي وML عندما تتوفر بيانات حقيقية كافية.

---

# 9. ما لن نفعله الآن

لن نبدأ الآن في:

- ML.
- AI Assistant.
- ETA معقد متعدد النماذج.
- سياسات الانحراف النهائية.
- إعادة بناء Mapbox.
- Refactor شامل.

**الأولوية الحالية:** مراجعة بوابة Phase 4 بالكامل، ثم الانتقال المنظم إلى **Phase 5 — ETA Engine**.

---

# سجل التقدم

| التاريخ | المهمة | الحالة | النتيجة |
|---|---|---|---|
| 2026-09-12 | إنشاء `routeCatalog` لمسار الجيزة | ✅ | تم الحفظ بنجاح في Firestore |
| 2026-09-12 | إضافة قواعد `routeCatalog` محليًا | ✅ | القواعد موجودة في النسخة المثبتة |
| 2026-09-12 | إصلاح البحث العام قبل تسجيل الدخول | ✅ | البحث التشغيلي يعتمد على `routeCatalog` بدل القراءة المحمية من `plannedRoutes` |
| 2026-09-28 | إغلاق Phase 4.4-B Runtime Integration | ✅ | Policy + Stop loading + local runtime snapshot + automatic refresh |
| 2026-09-28 | التحقق النهائي بعد دمج PRs #37–#40 | ✅ | `flutter analyze` نظيف، Hub **15/15**، full suite **192/192** |
| 2026-09-28 | مزامنة فرع التطوير على الجهاز | ✅ | clean + up to date عند `4709bb8` |

---

# 10. Phase 4.4-A — Stop Runtime Integration Contract

**الحالة: ✅ DESIGN ONLY**

تم تثبيت عقد التكامل قبل أي تعديل على `DriverTrackingHub` أو تدفق الرحلة.

### المبدأ

```text
Firestore Stops
      ↓
Read once at trip bind/restore
      ↓
Local projected stops
      ↓
NextStop + StopState
      ↓
Runtime snapshot
```

### القيود

- لا قراءة Firestore داخل كل GPS callback.
- المحطات تقرأ من `plannedRoutes/{routeId}/stops` عبر `PlannedRouteStopService`.
- الإسقاط يستخدم `PlannedRouteStopProjection`.
- `NextStopResolver` و`StopStateResolver` يبقيان domain services مستقلة.
- `vehicleAlongMeters` مصدره RouteProgress المقبول؛ لا يعاد حسابه من GPS داخل طبقة التكامل.
- `StopStatePolicy` وStop Eligibility تُمرران صراحةً دون قيم افتراضية جديدة.
- لا Firestore write لـStop State.
- لا fields جديدة في `VehicleTrip`.
- لا تغيير في `RouteProgressTracker` أو Mapbox أو GPS/Lifecycle.

### سلوك الفشل

فشل قراءة Stops لا ينهي VehicleTrip ولا يوقف التتبع؛ فقط تكون بيانات Stop-derived غير متاحة، مع تسجيل/ملاحظة الفشل دون كسر المسار التشغيلي.

### الخطوة التالية

**4.4-B — Runtime Integration**.

تم تنفيذها وإغلاقها أدناه بعد اكتمال التكامل والتحقق.

### 4.4-B Runtime Integration ✅

تم إغلاق 4.4-B بعد تنفيذ التكامل التشغيلي المحدود والتحقق منه.

#### ما تم تنفيذه
- تحميل Fixed Stops مرة واحدة عند bind/restore من:
  `plannedRoutes/{routeId}/stops`
  عبر `PlannedRouteStopService`.
- تخزين Stops محليًا في `DriverTrackingHub` مع التحقق من `tripId/routeId`.
- إضافة `StopRuntimePolicy` كمصدر مركزي للسياسة التشغيلية، دون قيم افتراضية داخل الـResolvers.
- السياسة الإنتاجية الحالية:
  - `stopEligibilityDistanceMeters = 75m`.
  - `atStopRadius = 30m`.
  - `approachingDistance = 200m`.
- ربط السياسة صراحةً عند بدء/استعادة `VehicleTrip`.
- عند قبول `RouteProgress` جديد، يتم تحديث `StopRuntimeSnapshot` تلقائيًا داخل `DriverTrackingHub`.
- عند اكتمال تحميل Stops، يتم إعادة الاشتقاق تلقائيًا إذا كان هناك `accepted RouteProgress` موجود مسبقًا.
- لا توجد قراءة Firestore داخل GPS callback؛ البيانات المطلوبة للمحطات محملة محليًا.
- لا توجد كتابة لـStop State في Firestore.
- لا توجد fields جديدة في `VehicleTrip`.

#### الحدود التي بقيت ثابتة
- لم يتم تعديل `driver_map_tab.dart`.
- لم يتم تعديل `DriverTrackingLifecycle`.
- لم يتم تعديل `RouteProgressTracker` أو `RoutePolylineProjection`.
- لم يتم تغيير Mapbox أو بنية Firestore الخاصة بالرحلة.
- ما زال Stop Runtime in-memory derived data فقط.

#### التحقق
- `flutter analyze` → **No issues found!** على فرع التنظيف الأخير.
- focused Hub tests → **15/15**.
- full `flutter test` → **192/192**.
- PR #37 — تثبيت `StopRuntimePolicy` — merged.
- PR #38 — ربط السياسة والتحديث التلقائي — merged.
- PR #39 — إزالة import غير مستخدم — merged.

**الحالة النهائية: 4.4-B ✅ مكتملة.**

### الخطوة التالية

**Phase 4 يمكن اعتبارها مكتملة من ناحية Runtime Stop Integration.**

المرحلة التالية المخطط لها هي:

**Phase 5 — ETA Engine**

ولا يبدأ التنفيذ حتى يظل بناء ETA معتمدًا على البيانات الفعلية المتاحة من Position + RouteProgress + Speed + Remaining Route، مع اعتبار ETA غير متاح أفضل من إنتاج رقم غير موثوق.


### إغلاق 6-E.2-B — Passenger Presentation UI — 2026-10-01

**الحالة: ✅ مكتملة**

تم إغلاق Production Patch لطبقة عرض BusWatch للمسافر بعد إصلاح ملاحظة التحليل التي ظهرت بعد التنفيذ الأول.

#### التنفيذ المثبت

- أضيفت بطاقة عرض مستقلة:
  `lib/passenger/widgets/bus_watch_operational_card.dart`
- البطاقة تستهلك Presentation State فقط:
  `loading`, `result`, `error`, `onRetry`.
- تم ربطها داخل `MapTab` دون استبدال `ActiveTripBanner` أو إعادة بناء مسار GPS/Live Tracking.
- حالات BusWatch غير المتاحة تُعرض كحالات تشغيلية واضحة، بينما خطأ البنية التحتية لا يُعرض خامًا للمستخدم.
- عند وجود نتيجة سابقة يمكن إظهارها أثناء التحديث مع مؤشر تحميل.
- لا يتم إدخال ETA أو `NextStop` أو `StopRuntimeSnapshot` إلى `BusWatchOperationalSnapshot`.
- لم يتم تعديل `DriverTrackingLifecycle` أو Mapbox أو `driver_map_tab.dart` خارج الربط المحدود المطلوب للعرض.

#### الإصلاح اللاحق

تم اكتشاف خطأ صياغة في نهاية `MapTab` بعد أول تنفيذ:
`Expected to find ']'`.

تم إصلاحه بتغيير سطري واحد فقط، كما أزيل importان غير مستخدمين من بطاقة العرض.

#### Evidence

على الجهاز المحلي بعد سحب آخر commits:

- `flutter analyze` → **No issues found!**
- `flutter test test/bus_watch_operational_card_test.dart` → **8/8 All tests passed!**
- `flutter test test/bus_watch_passenger_presentation_state_test.dart` → **7/7 All tests passed!**
- `flutter test` → **283/283 All tests passed!**
- `git status` → **working tree clean**
- الفرع `stage/approved-route-line-vehicle-link-v1` متزامن مع `origin`.

ظهور سجلات اختبارات stale GPS أثناء الاختبار الكامل كان تشخيصًا متوقعًا، ثم اكتملت المجموعة بالكامل دون failures.

**نتيجة البوابة:** **6-E.2-B مغلقة وناجحة ✅**

**قاعدة الانتقال:** لا يوجد Patch برمجي جديد مطلوب لهذه النقطة. قبل فتح Feature جديدة، يجب تنفيذ Preflight قصير لتثبيت نقطة المرحلة التالية وتحديد ما إذا كان المسار التالي هو إكمال ETA Result Consumption أو فتح Phase 7، دون استنتاج ذلك من نجاح الاختبارات وحده.


### قرار ما بعد إغلاق 6-E.2-B — 2026-10-01

**FACTS VERIFIED**

- `EtaRuntimeInvocation` موجود ويعيد `EtaResult?` بصورة صحيحة.
- `DriverTrackingHub` يحتفظ بـ`activeEtaObservation` و`activeStopRuntimeSnapshot`، لكنه لا يستدعي `EtaRuntimeInvocation`.
- `BusWatchOperationalSnapshot` لا يحتوي ETA، وفق العقد المثبت.
- `BusWatchOperationalCard` تستهلك Presentation State الخاص بـBusWatch ولا تستهلك ETA.
- `ActiveTripBanner` هو المستهلك الحالي الفعلي للـETA في الواجهة، لكنه يستخدم `EtaUtils` القديم، وتعديلُه خارج حدود 5.2-E المثبتة.

**PROBLEM IDENTIFIED**

لا يوجد حاليًا Production Consumer مناسب لـ`EtaResult?` يمكن تنفيذه داخل حدود 5.2-E دون إدخال ETA إلى Passenger/UI أو `DriverTrackingHub` أو إعادة بناء `ActiveTripBanner`.

**DESIGN CONSTRAINT**

لا ننشئ Consumer اصطناعيًا أو Wrapper/state/cache/scheduler لمجرد إغلاق البند برمجيًا، ولا نكسر الحدود المعمارية المثبتة.

**DECISION**

تبقى **Phase 5.2-E — ETA Result Consumption** في حالة **DESIGN FROZEN / DEFERRED ✅** حتى يظهر مستهلك إنتاجي محدد بمتطلب واضح. لا يوجد Patch برمجي مطلوب الآن.

وبعد إغلاق **6-E.2-B** تصبح **Phase 6 — BusWatch** مكتملة من نطاقها الحالي.

### الخطوة التالية

**Phase 7 — JourneyPlanner Preflight** فقط، دون Production Code.

الـPreflight سيحدد:
- مصدر Origin وDestination في الواجهة الحالية.
- ما هي الرحلات التشغيلية التي يمكن اعتبارها Candidates.
- كيف يرتبط Candidate بالـroute/VehicleTrip.
- كيف يُستخدم ETA عندما يصبح له Consumer صالح.
- حدود عدم توفر البيانات، دون اختراع ETA أو fallback غير مثبت.

لا يبدأ تنفيذ JourneyPlanner قبل تثبيت هذا العقد واختبار أول وحدة مستقلة.



### Phase 7 — Route Candidate Discovery Contract v1 — 2026-10-01

**FACTS VERIFIED**

- PlannedRoute هو مصدر بيانات المسار المعتمد، ويحمل الهوية id + direction.
- NearbyRoutesService الحالي يستخدم lineName في _dedupeBestByLine()، لذلك لا يمكن اعتماد ناتجه الحالي كما هو كمجموعة Route Candidates نهائية للـJourneyPlanner.
- NearbyRoutesService.progressAlongRoute() يعتمد تقريب segmentIndex / numberOfSegments، وليس محور alongMeters الدقيق.
- RoutePolylineProjection.project() يعيد alongMeters وdistanceToRouteMeters على هندسة المسار نفسها، وهو primitive هندسي مستقل قابل لإعادة الاستخدام.
- لا يوجد بعد Production Route Candidate Discovery Consumer يبرر تعديل NearbyRoutesService أو إنشاء RouteCandidate Model.

**PROBLEM IDENTIFIED**

قبل ربط أي VehicleTrip بالمسار، يجب أن تنتج Route Discovery مجموعة Candidates تحتفظ بكامل هوية كل مسار.

المشكلة الحالية هي أن Discovery القديم يمكن أن:
- يدمج مسارات مختلفة تحت lineName.
- يستخدم اتجاهًا تقريبيًا مبنيًا على segmentIndex.
- يحمل thresholds داخل الخدمة بدل Policy معلنة ومحقونة.

**DESIGN CONSTRAINT**

العقد المجمد دلاليًا:

```text
Input:
  origin   = latitude + longitude
  destination = latitude + longitude

Source:
  approved PlannedRoute(s)

Output:
  List<PlannedRoute>

Identity:
  route.id + route.direction

Qualifying:
  origin is sufficiently close to route
  AND
  destination is sufficiently close to route
  AND
  destination lies ahead of origin on the route axis

Direction relation:
  project origin and destination onto the same route geometry
  using RoutePolylineProjection
  then require:
    destinationProjection.alongMeters > originProjection.alongMeters
```

**DECISIONS**

1. **Input**
   - Origin وDestination هما إحداثيات فقط.
   - لا PassengerTrip ولا VehicleTrip ضمن هذا العقد.

2. **Source**
   - المصدر الدلالي هو المسارات المعتمدة PlannedRoute.
   - لا يعتمد العقد على routeCatalog كمصدر geometry.
   - لا يعتمد على NearbyRoutesService كـfinal planner discovery API.

3. **Output**
   - الناتج هو List<PlannedRoute>.
   - كل Route مؤهل تبقى هويته الأصلية محفوظة.
   - لا يتم إسقاط Route بسبب تشابه lineName.
   - لا يتم دمج outbound وreturn أو مسارين مختلفين لهما نفس الاسم.

4. **Route identity**
   - الهوية التشغيلية للـRoute Candidate هي PlannedRoute.id + PlannedRoute.direction.
   - lineName metadata للعرض/البحث، وليس مفتاحًا للتفريد أو الربط.

5. **Origin proximity**
   - يتم تقييم قرب Origin من هندسة Route.
   - الحد العددي لا يُثبت داخل العقد.
   - يجب أن يكون هذا الحد جزءًا من Discovery Policy معلنة/محقونة عند التنفيذ.
   - لا يُسمح بإضافة رقم مخفي داخل Planner لمجرد تقليد NearbyRoutesService.

6. **Destination proximity**
   - يتم تقييم قرب Destination من هندسة Route.
   - الحد العددي كذلك Policy محقونة وليس قيمة ثابتة جديدة داخل Planner.

7. **Same-direction relation**
   - يتم إسقاط Origin وDestination على نفس هندسة Route بواسطة RoutePolylineProjection.
   - الاتجاه لا يُستنتج من segmentIndex / numberOfSegments.
   - العلاقة المؤهلة هي destinationProjection.alongMeters > originProjection.alongMeters.
   - استخدام علاقة strict يمنع اعتبار نقطة تقع على نفس الموضع المحوري للRoute كرحلة forward.
   - لا يتم تثبيت minimum forward distance أو epsilon إضافي في هذه الخطوة؛ إن احتاجت سياسة لاحقة ذلك يُضاف صراحةً عبر Policy.

8. **Projection failure / invalid route**
   - إذا تعذر إسقاط أحد الإحداثيين، أو كانت هندسة Route غير صالحة، فلا يكون Route مؤهلًا.
   - لا يتم اختراع نتيجة أو fallback.
   - هذه الحالة لا تجعل VehicleTrip جزءًا من Discovery.

9. **Multiplicity**
   - يمكن أن ينتج Discovery عدة PlannedRoute مختلفة لها نفس lineName.
   - كل id + direction يبقى Candidate مستقلًا.
   - لا توجد عملية Cartesian Product ولا أي association مع المركبات هنا.

10. **Policy boundary**
    - يمكن أن تتولى Policy لاحقًا originMaxDistanceMeters وdestinationMaxDistanceMeters وأي قواعد إضافية صريحة لمعالجة ambiguity أو minimum forward separation.
    - لا يتم تثبيت أسماء أو قيم تنفيذية لهذه Policy ما دام أول Consumer لم يثبت الحاجة إليها.

11. **Out of scope**
    - VehicleTrips.
    - ETA.
    - Ranking.
    - UI.
    - JourneyCandidate model.
    - تعديل NearbyRoutesService.
    - Firestore writes.
    - Firestore schema/index changes.

**RESULT**

**Route Candidate Discovery Contract v1 — DESIGN FROZEN ✅**

تم تثبيت معنى Route Candidate qualifying، مع الحفاظ على:
- الهوية id + direction.
- كل المسارات المؤهلة دون lineName dedupe.
- اتجاه route المبني على alongMeters من RoutePolylineProjection.
- thresholds كـPolicy injected ولم تُثبت أرقام جديدة.

لم يتم إنشاء RouteCandidate Model ولم يتم تعديل أي Production Code.

**NEXT**

الخطوة التالية فقط هي تحديد **First Route Discovery Implementation Boundary**: هل تنفذ Discovery كخدمة مستقلة صغيرة أم تُوسّع خدمة موجودة، ويُحسم ذلك بعد Inspect للاعتماد الفعلي الأول على العقد، دون تعديل NearbyRoutesService مسبقًا.

### Phase 7 — Journey Candidate Consumer Contract v1 — 2026-10-01

**FACTS VERIFIED**

- لا يوجد حاليًا `JourneyPlanner` أو `JourneyCandidate` كـProduction abstraction في الفرع.
- `MapTab` يستخدم `NearbyRoutesService` لاكتشاف الخطوط القريبة/المتجهة نحو الوجهة ثم يطبق line filters على العرض؛ هذا مسار Discovery/Presentation وليس Consumer لعقد Journey Candidate.
- `NearbyRoutesService` يعيد `NearbyLineMatch` مع `PlannedRoute`، لكنه لا يقرأ `vehicleTrips` ولا يبني Journey Candidates.
- `VehicleTripService.findActiveTripsForRoute({routeId, direction})` هو Read Contract التشغيلي المغلق للمركبات النشطة.
- لذلك لا يوجد Consumer إنتاجي حالي يمكنه إثبات أن `JourneyCandidate` Model أو `JourneyCandidateRef` مطلوب.

**PROBLEM IDENTIFIED**

السؤال الحالي ليس كيفية تمثيل Candidate، بل ما أول عملية فعلية سيجريها Consumer على مجموعة المسارات والمركبات.

حتى هذه اللحظة لا يوجد Consumer إنتاجي يثبت هل المطلوب:
- مجرد enumerate/associate للمركبات مع المسارات،
- أو فحص هندسة المسار بالنسبة إلى Origin/Destination،
- أو فحص الحالة المكانية للمركبة (`currentLocation` / `routeProgress`)،
- أو مجموعة مركبات كاملة لكل Route قبل التقييم.

**DESIGN CONSTRAINT**

المستهلك المفاهيمي هو **JourneyPlanner Consumer v1** في طبقة الـDomain/Planner المستقبلية، وليس `MapTab` ولا `NearbyRoutesService` ولا `VehicleTripService` نفسها.

العقد المجمد دلاليًا:

```text
Input:
  Route Candidate(s)
  +
  Active Vehicle Candidate(s)

Relationship:
  route.id == vehicleTrip.routeId
  &&
  route.direction.firestoreValue == vehicleTrip.direction

Multiplicity:
  one Route Candidate
      →
  zero or more matching Active VehicleTrips

Candidate semantics:
  one valid association per
  (PlannedRoute, VehicleTrip)

Important:
  this is association by matching identity,
  not a Cartesian product between independent sets.
```

**DECISIONS**

1. **Receiver**
   - المستقبل المقصود هو JourneyPlanner Consumer المستقبلي.
   - لا يتم إنشاء Class باسم `JourneyPlanner` في هذه الخطوة لمجرد تثبيت الاسم.

2. **Route Candidate input**
   - المسار المعتمد هو `PlannedRoute`.
   - هويته التشغيلية: `id + direction`.
   - `lineName` ليس مفتاح الربط.

3. **Active Vehicle input**
   - المصدر هو `List<VehicleTrip>` الناتج من Read Contract المغلق.
   - هويته: `vehicleTrip.id`.
   - ربطه بالمسار يتم فقط عبر `routeId + direction`.

4. **Route without Vehicle**
   - يبقى Route Candidate صالحًا upstream.
   - ينتج عنه **zero Journey Candidates**.
   - لا يتم إنشاء Candidate وهمي ولا fallback.

5. **Vehicle with unusable location**
   - لا تُستخدم `currentLocation` كجزء من هوية Candidate.
   - لا يقوم Consumer الحالي بتحويل "لا يوجد موقع صالح" إلى "لا توجد مركبة".
   - تبقى association ممكنة ما دام `Route + VehicleTrip` متطابقين؛ صلاحية الموقع تُحسم عند طبقة التقييم التي تحتاجه.

6. **PlannedRoute completeness**
   - لا يوجد بعد Consumer إنتاجي يفرض تمثيلًا مختصرًا للمسار.
   - لذلك لا يُنشأ wrapper أو ref بديل الآن.
   - عند ظهور أول تقييم فعلي يحتاج geometry، يمكن تمرير `PlannedRoute` الأصلي مباشرة.

7. **VehicleTrip completeness**
   - لا يوجد بعد Consumer إنتاجي يبرر نسخ حقول `VehicleTrip` إلى Model جديد.
   - الحقول التشغيلية الموجودة أصلًا (`currentLocation`، `speed`، `heading`، `routeProgress`، `lastLocationAt`) تبقى على `VehicleTrip`.
   - عند ظهور أول تقييم يحتاجها، يستخدم الـConsumer الكائن الأصلي.

8. **Planning inputs vs candidate data**
   - `Origin` و`Destination` inputs للتخطيط وليسا جزءًا من هوية Candidate.
   - ETA ليس Candidate identity/data في هذه المرحلة.
   - Ranking/UI/fallback خارج هذا العقد.
   - Discovery metadata مثل مسافات `NearbyLineMatch` لا تصبح Candidate identity تلقائيًا.

9. **Minimum output**
   - الحد الأدنى المجمد حاليًا هو **مجموعة associations صالحة بين Route Candidate وActive VehicleTrip**.
   - شكل التمثيل البرمجي لهذا الناتج **غير مجمد عمدًا** حتى يظهر Consumer التالي الفعلي.
   - لذلك لا يتم إنشاء `JourneyCandidate` أو `JourneyCandidateRef` أو map/DTO بديل في هذه الخطوة.

10. **Boundary**
   - هذا العقد لا يختار Route.
   - لا يرتب المركبات.
   - لا يحسب ETA.
   - لا يقرر صلاحية GPS بمعايير جديدة.
   - لا يغير `NearbyRoutesService`.
   - لا يغير `MapTab`.
   - لا يضيف Firestore reads أو indexes أو writes.

**RESULT**

**Journey Candidate Consumer Contract v1 — DESIGN FROZEN ✅**

المثبت الآن هو **Consumer Semantics + Association Semantics** فقط.

أما قرار:
`PlannedRoute + VehicleTrip` مباشرةً مقابل association model صغير،
فيبقى مؤجلًا حتى يظهر أول Consumer/evaluation behavior يثبت حاجة حقيقية إلى abstraction مستقلة.

**NEXT**

أول Patch في JourneyPlanner يجب أن يثبت **أول عملية فعلية على هذه associations** فقط، مع إبقاء `JourneyCandidate` Model مؤجلًا ما لم يثبت Consumer أنه ضروري.


### إغلاق Phase 7 — Active Vehicle Discovery Read Contract v1 — 2026-10-01

**FACTS VERIFIED**

- تم تجميد عقد قراءة المركبات النشطة على:
  `findActiveTripsForRoute({routeId, direction}) → Future<List<VehicleTrip>>`.
- مصدر القراءة هو `vehicleTrips` فقط.
- الاستعلام يعتمد `routeId + direction + status = active`.
- لا تدخل `currentLocation` أو freshness في Query أو filtering.
- بعد القراءة تتم إعادة مطابقة `status` و`routeId` و`direction` قبل الإرجاع.
- يتم إعادة استخدام `VehicleTrip.parseDirection()` عبر validation الموجودة في الخدمة بدل إنشاء قواعد اتجاه مكررة.
- لم يتم إنشاء `ActiveVehicleCandidate` أو `JourneyCandidate`.
- لم يتم تعديل `NearbyRoutesService` أو `MapTab` أو `DriverTrackingHub` أو ETA أو Firestore Rules/Indexes.

**PROBLEM IDENTIFIED**

لم تعد هناك مشكلة تصميمية مفتوحة في Read Contract v1. بقيت صلاحية الموقع ومعنى Candidate مسؤولية الطبقة الأعلى، لا خدمة القراءة نفسها.

**VALIDATION**

- focused test: **7/7 passed**.
- `flutter analyze`: **No issues found**.
- full `flutter test`: **290/290 passed**.
- working tree: **clean**.
- branch: **up to date with origin**.

**INDEX DECISION**

لم تتم إضافة Composite Index. الحاجة إليه لم تثبت بعد عبر تشغيل الاستعلام على Firestore الفعلي، ولذلك يبقى Deferred إلى أن يظهر دليل مباشر.

**RESULT**

**Active Vehicle Discovery Read Contract v1 — CLOSED ✅**

### الخطوة التالية

**Journey Candidate Contract Preflight** فقط، دون Production Code جديد، لتحديد أقل بيانات تربط Route Candidate بالمركبة التشغيلية دون إدخال ETA أو Ranking أو UI.
