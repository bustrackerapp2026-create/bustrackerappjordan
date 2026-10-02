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



### Phase 7 — Route Candidate Discovery Calibration Gate — status 2026-10-02

**FACTS VERIFIED**

الحالة الحالية مفصولة رسميًا إلى:

- Route Candidate Discovery implementation — **CLOSED ✅**
- Discovery contract — **FROZEN ✅**
- Discovery policy shape — **FROZEN ✅**
- Policy meaning — **FROZEN ✅**
- Policy values — **NOT DEFINED ⚠️**
- Planner Composition — **BLOCKED ⏸️**
- Production UI wiring — **BLOCKED ⏸️**
- Device verification — **PENDING ⏳**

معنى «near route» المجمد:

`Origin / Destination → route geometry projection → distanceToRouteMeters → independent threshold`

ولا يدخل في قرار المعايرة الحالي:
- walking distance / pedestrian routing
- ETA
- Vehicle location
- route progress للمركبة

**CALIBRATION RULE**

قبل اعتماد أي قيمة رقمية، يجب توثيق:

1. Meaning of "near".
2. Measurement method.
3. Operational uncertainty to tolerate.
4. Whether Origin and Destination tolerances are symmetric.
5. False-positive tolerance.
6. False-negative tolerance.
7. Initial Origin threshold.
8. Initial Destination threshold.
9. Design rationale.
10. Field validation status.

**EVIDENCE MODEL**

يجب الفصل بين:

- **Design rationale:** سبب اختيار القيمة بناءً على معنى الاستخدام والتشغيل.
- **Field evidence:** دليل التجربة الواقعية على أن القيمة مناسبة.

لذلك لا تُوصف القيمة بأنها **Field-validated** لمجرد اعتمادها تصميميًا.

الحالتان المعتمدتان لاحقًا:

- **Design-calibrated:** قيمة أولية معتمدة بناءً على قاعدة المعايرة والتبرير التصميمي.
- **Field-validated:** قيمة خضعت لاختبار واقعي وأكدت التجربة ملاءمتها، أو أثبتت الحاجة إلى تعديلها.

**DECISION**

لا يوجد Production Patch قبل إغلاق Calibration Gate.

**NEXT**

تعريف Calibration Rule عمليًا ثم اشتقاق قيم Origin/Destination منها. بعد ذلك فقط:
`Policy values → Composition → Planner wiring → focused tests → flutter analyze → flutter test → field/device validation`

### Phase 7 — Operational Uncertainty Inventory — status 2026-10-02

**FACTS VERIFIED**

بعد تثبيت معنى `near`، تم حصر مصادر عدم اليقين النوعية قبل اختيار أي threshold رقمي.

**UNCERTAINTY INVENTORY**

1. **Origin**
   - المصدر هو موقع الراكب.
   - عدم اليقين الأساسي: GPS horizontal accuracy.
   - جودة الإشارة والبيئة المحيطة قد تؤثر في الدقة.
   - هذا المصدر داخل نطاق معايرة Origin.

2. **Destination**
   - المصدر هو نتيجة البحث/الـgeocoding.
   - الإحداثية قد تمثل نقطة مكان، مركز مبنى/منطقة، أو إحداثية تقريبية للنتيجة.
   - هذا مصدر مختلف نوعيًا عن GPS الخاص بالـOrigin، ولذلك لا يُفترض التماثل مسبقًا.

3. **Route geometry**
   - `PlannedRoute.points` تمثل المسار التشغيلي بقدر دقة التسجيل والتمثيل.
   - يجب مراعاة digitization error / polyline simplification / sparse points عند الحاجة.
   - لا يُضاف هامش مستقل إذا كانت هندسة المسار نفسها ذات دقة مقبولة، لتجنب احتساب الخطأ مرتين.

4. **Measurement**
   - القياس الحالي هو projection على هندسة المسار وإخراج `distanceToRouteMeters`.
   - projection/distance uncertainty تُراجع كخاصية للقياس نفسه.
   - لا يوجد حاليًا مبرر لإضافة margin حسابي منفصل دون دليل أن طريقة القياس تحتاجه.

5. **Time / staleness**
   - قدم إحداثية Origin ليس خطأً هندسيًا في `distanceToRouteMeters`.
   - stale coordinate تعني أن النقطة قد لا تمثل الموقع الحالي.
   - freshness تبقى concern مستقلة ولا تُدمج ضمن distance threshold تلقائيًا.

**DESIGN CONSTRAINT**

`Threshold != sum of every conceivable error`.

الـthreshold يجب أن يتحمل فقط عدم اليقين الذي يحتاجه قرار Route Candidate هذا، مع تجنب double-counting بين مصادر الخطأ.

**RESULT**

- Meaning of "near" — **DEFINED ✅**
- Measurement — **FROZEN ✅**
- Origin GPS uncertainty — **IN SCOPE ✅**
- Destination coordinate uncertainty — **IN SCOPE ✅**
- Route geometry uncertainty — **IN SCOPE ✅**
- Projection uncertainty — **REVIEWED; no separate margin justified yet ✅**
- Staleness — **SEPARATE CONCERN ✅**
- Numeric thresholds — **NOT DEFINED ⚠️**
- Production code changes — **NONE ✅**

**NEXT**

الانتقال إلى **Origin/Destination symmetry** فقط، مع عدم افتراض تساوي الـthresholds قبل تحليل اختلاف مصادر عدم اليقين.

### Phase 7 — Origin/Destination Symmetry Decision — status 2026-10-02

**FACTS VERIFIED**

- **Origin** مصدره موقع الراكب، مع GPS uncertainty.
- **Destination** مصدره `PlaceSearchResult` / search-geocoding coordinate، مع uncertainty مختلفة نوعيًا.
- القياس الهندسي موحّد في الحالتين: projection على `PlannedRoute` ثم `distanceToRouteMeters`.
- `RouteCandidateDiscoveryPolicy` مصممة أصلًا بحدين مستقلين:
  - `originMaxDistanceMeters`
  - `destinationMaxDistanceMeters`

**PROBLEM IDENTIFIED**

لا يوجد دليل Domain/Operational حالي يبرر افتراض أن عدم اليقين في Origin وDestination متكافئ بما يكفي لفرض threshold واحد.

**DESIGN DECISION**

`Origin/Destination symmetry = NO`.

أي أن:
- `originMaxDistanceMeters` و`destinationMaxDistanceMeters` مستقلان.
- لا يُشترط تساوي القيمتين.
- يجب أن يكون **معنى near** و**طريقة القياس** متماثلين.
- اختلاف threshold لا يعني اختلاف نوع القياس أو إدخال walking distance في أحد الطرفين.

**BOUNDARY**

هذا القرار يثبت **شكل السياسة فقط** ولا يحدد أي قيمة رقمية.

**RESULT**

- Meaning of "near" — **DEFINED ✅**
- Measurement — **FROZEN ✅**
- Operational uncertainty — **FROZEN ✅**
- Origin/Destination symmetry — **NO / independent thresholds ✅**
- Origin threshold — **NOT DEFINED ⚠️**
- Destination threshold — **NOT DEFINED ⚠️**
- Production code changes — **NONE ✅**

**NEXT**

تحليل **False-positive tolerance / False-negative tolerance** بشكل نوعي، ثم اشتقاق القيم الرقمية من قواعد القبول المطلوبة، دون التخمين.

### Phase 7 — Initial Policy Values — status 2026-10-02

**DECISION**

تم اعتماد قيم أولية لـRoute Candidate Discovery Policy بعد إغلاق القواعد النوعية السابقة:

- `originMaxDistanceMeters = 100m`
- `destinationMaxDistanceMeters = 150m`
- Origin وDestination يحتفظان بحدين مستقلين.
- القياس في الحالتين يبقى `distanceToRouteMeters` الناتج من projection على `PlannedRoute` geometry.

**RATIONALE — ORIGIN 100m**

`100m` نقطة تشغيل أولية مبنية على حد دقة GPS المقبول في تطبيق الراكب:

- `passengerBrowse.maxAcceptableAccuracyMeters = 55m`
- القيمة لا تُعد مشتقة رياضيًا من 55m.
- تمثل 100m هامشًا هندسيًا/تشغيليًا إضافيًا فوق حد الدقة المقبول.
- القيمة **Initial Design-calibrated** وليست **Field-validated**.

**RATIONALE — DESTINATION 150m**

`150m` قيمة تشغيلية أولية أكثر تسامحًا من Origin بسبب طبيعة إحداثيات نتائج البحث/geocoding:

- `PlaceSearchResult` يحتفظ حاليًا بـ`name + latitude + longitude` فقط ولا يحمل accuracy رقمية موحدة.
- نتائج البحث قد تمثل أنواعًا مكانية مختلفة (مثل address أو POI أو منطقة/مدينة).
- القيمة ليست قياسًا لخطأ geocoder محددًا، ولا تمثل walking-access radius.
- القيمة **Initial Design-calibrated** وليست **Field-validated**.

**SUPPORTED SEMANTICS**

هذه المعايرة لا تعني أن `150m` حد عالمي صالح لكل أنواع Destination semantics إلى الأبد. اختلاف نوع feature قد يستدعي إعادة معايرة مستقبلية إذا ظهر سلوك ميداني أو متطلب Domain يبرر ذلك.

**EVIDENCE STATUS**

- Design rationale — **DOCUMENTED ✅**
- Initial Origin value — **100m / Design-calibrated ✅**
- Initial Destination value — **150m / Design-calibrated ✅**
- Field validation — **NOT DONE ⚠️**
- Calibration adjustment remains possible after field evidence.
- Calibration adjustment لا يعني تلقائيًا أن `RouteCandidateDiscoveryService` نفسه كان خاطئًا.

**BOUNDARY**

لا يدخل في اختيار هذه القيم:
- walking distance/access
- pickup stop availability
- Vehicle location
- freshness/staleness
- speed
- ETA
- ranking

**RESULT**

بوابة Policy Values — **CLOSED FOR INITIAL IMPLEMENTATION ✅**

القيم المعتمدة الآن هي:
`Origin = 100m`
`Destination = 150m`

والتصنيف الرسمي:
**Initial Design-calibrated / NOT Field-validated**

**NEXT**

الانتقال إلى **Policy Composition** ثم Production wiring فقط. لا يتم تعديل Route Candidate Discovery implementation نفسه، ولا إعادة فتح NearbyRoutesService.

### Phase 7 — Policy Composition v1 — implemented 2026-10-02

**FACTS VERIFIED**

تم فتح Composition بعد اعتماد قيم Policy الأولية:

- `originMaxDistanceMeters = 100m`
- `destinationMaxDistanceMeters = 150m`
- `Origin/Destination symmetry = NO`
- القياس = `distanceToRouteMeters`

تم استخدام آلية الحقن الموجودة أصلًا في التطبيق: `MultiProvider` / `Provider`.
لا توجد DI framework جديدة في المشروع، ولم تتم إضافة واحدة.

**COMPOSITION**

```text
Passenger Journey Planning Composition
  ├── RouteCandidateDiscoveryPolicy
  │     ├── originMaxDistanceMeters = 100
  │     └── destinationMaxDistanceMeters = 150
  ├── RouteCandidateDiscoveryService
  │     └── approvedRoutesReader → RoutePlanService.listApprovedRoutes(limit: 200)
  ├── JourneyRouteVehicleAssociationService
  │     └── VehicleTripService
  └── PassengerJourneyPlanningService
```

**PRODUCTION PATCH**

تمت إضافة `Provider<PassengerJourneyPlanningService>` إلى `lib/main.dart` فقط.

لم يتم:
- تعديل `RouteCandidateDiscoveryService`.
- تعديل `NearbyRoutesService`.
- تعديل `MapTab`.
- ربط Planner بواجهة الراكب بعد.
- إضافة ETA أو ranking أو UI behavior.
- إضافة أي Firestore write أو schema/index.
- إنشاء DI framework جديدة.

**SOURCE BOUNDARY**

Composition الحالية تستخدم `RoutePlanService.listApprovedRoutes(limit: 200)` كمصدر approved-route reader، لأن الخدمة الحالية تدعم حدًا أقصى قدره 200 في هذا الـAPI.

هذا ليس تغييرًا في دلالة Route Candidate Discovery، بل قرار Composition للمصدر الحالي، ويجب إعادة مراجعته فقط إذا أصبح عدد المسارات المعتمدة يتجاوز هذا الحد أو ظهر متطلب completeness مختلف.

**STATUS**

- Policy Values — **CLOSED FOR INITIAL IMPLEMENTATION ✅**
- Policy Composition v1 — **IMPLEMENTED ✅**
- Planner UI wiring — **NOT STARTED ⏸️**
- Field validation — **PENDING ⏳**
- Production code beyond composition — **UNCHANGED ✅**

**NEXT**

تشغيل focused tests الخاصة بـRoute Candidate Discovery وPassenger Journey Planning، ثم `flutter analyze` و`flutter test`. بعد نجاحها فقط نراجع أول نقطة Production UI wiring لزر/تدفق الوجهة دون ربط `MapTab` عشوائيًا أو إزالة `NearbyRoutesService` قبل إثبات الاستبدال.

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
### Phase 7 — Route Candidate Discovery API v1 — 2026-10-01

**FACTS VERIFIED**

- لا يوجد في الفرع domain abstraction مستقلة باسم Origin أو Destination.
- `PlaceSearchResult` يمثل نتيجة بحث مكان في طبقة Location/UI، ويحتوي `name + latitude + longitude`؛ لا توجد حاجة لتحويله إلى planner input abstraction في هذه الخطوة.
- `PassengerLocationMixin` يحتفظ بـ`lastPassengerLat + lastPassengerLng` كموقع أصل حالي للراكب.
- لذلك لا يوجد type قائم يمكن إعادة استخدامه دون إدخال مسؤولية UI/location إلى Domain/Planner.

**PROBLEM IDENTIFIED**

نحتاج API صغيرًا لحدود Route Candidate Discovery يستقبل نقطتي التخطيط دون إنشاء value objects جديدة لمجرد الأناقة.

**DESIGN DECISION**

يُجمّد API بالشكل التالي:

```dart
Future<List<PlannedRoute>> discover({
  required double originLatitude,
  required double originLongitude,
  required double destinationLatitude,
  required double destinationLongitude,
});
```

**RATIONALE**

- الإحداثيات هي الحد الأدنى الذي يحتاجه Discovery.
- لا يتم تمرير `PlaceSearchResult` لأن `name` metadata واجهة وليس جزءًا من qualification الهندسي.
- لا يتم إنشاء `Origin` أو `Destination` model الآن.
- لا يتم ربط API مباشرةً بـ`PassengerLocationMixin` أو `MapTab`.
- لا يوجد `DateTime.now()` أو GPS/Firestore/UI dependency ضمن العقد نفسه.

**CONTRACT BOUNDARY**

الـAPI:
- يقرأ/يحصل على approved `PlannedRoute` candidates من المصدر المخصص لذلك.
- يعيد `List<PlannedRoute>` مع الحفاظ على `id + direction`.
- يطبق qualification المثبتة في Route Candidate Discovery Contract.
- يستخدم `RoutePolylineProjection` للـroute-axis relation عند التنفيذ.
- يستقبل Policy injected لأي proximity thresholds لازمة.

ولا يملك:
- `VehicleTrip` access.
- ETA.
- ranking.
- UI.
- cache.
- polling.
- fallback.
- `JourneyCandidate` model.
- `NearbyRoutesService` mutation لمجرد توفير هذا API.

**API NON-GOALS**

- لا نثبت هنا أسماء أو قيم الـDiscovery Policy.
- لا نثبت هنا كيفية قراءة approved routes من `RoutePlanService`؛ هذا قرار Implementation Boundary منفصل.
- لا نضيف overload يستقبل `Origin`/`Destination` objects.
- لا نضيف factory أو DTO خاص بالطلب.

**RESULT**

**Route Candidate Discovery API v1 — DESIGN FROZEN ✅**

تم حسم شكل الـAPI بأصغر تمثيل يطابق الكود الحالي:
`originLatitude + originLongitude + destinationLatitude + destinationLongitude`.

إنشاء abstraction مستقلة لـOrigin/Destination يبقى مؤجلًا حتى يظهر سلوك مشترك حقيقي يحتاجها خارج هذا الـConsumer.

**NEXT**

الخطوة التالية هي **Route Candidate Discovery Implementation** فقط: خدمة مستقلة صغيرة أو boundary مماثلة، مع dependency على approved-route source وPolicy injected، ثم focused tests. لا تعديل مسبق لـ`NearbyRoutesService` أو `MapTab`.


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


### Phase 7 — JourneyPlanner First Association Operation Contract v1 — 2026-10-01

**FACTS VERIFIED**

- لا يوجد حاليًا Production `JourneyPlanner` أو `JourneyCandidate` model يفرض تمثيلًا خاصًا للناتج.
- `RouteCandidateDiscoveryService.discover()` يعيد `List<PlannedRoute>` مع الحفاظ على هوية المسار `id + direction`.
- `VehicleTripService.findActiveTripsForRoute({routeId, direction})` يعيد `List<VehicleTrip>` للمركبات النشطة المطابقة.
- المشروع يستخدم Dart SDK `^3.5.0`، وبالتالي named records متاحة في لغة Dart الحالية للمشروع.

**PROBLEM IDENTIFIED**

العقد الدلالي السابق ثبت علاقة Route Candidate بالمركبات والتعدد، لكنه لم يثبت بعد الشكل البرمجي للناتج. لا يجوز اختراع `JourneyCandidate` أو DTO جديد فقط لسد هذه الفجوة.

**DESIGN CONSTRAINT**

يُجمّد أول Consumer Operation بالشكل التالي:

```text
Input:
  List<PlannedRoute> routeCandidates

Dependency:
  VehicleTripService.findActiveTripsForRoute({
    routeId,
    direction,
  })

Matching:
  route.id == vehicleTrip.routeId
  AND
  route.direction.firestoreValue == vehicleTrip.direction

Multiplicity:
  one association per valid (PlannedRoute, VehicleTrip) pair

Output:
  Future<List<({
    PlannedRoute route,
    VehicleTrip vehicleTrip,
  })>>
```

**OUTPUT SHAPE DECISION**

- الناتج هو **Dart named record** وليس Model أو DTO أو `JourneyCandidate`.
- حقلا السجل هما بالاسم: `route` و`vehicleTrip`.
- يحتفظ `route` بكائن `PlannedRoute` الأصلي كاملًا.
- يحتفظ `vehicleTrip` بكائن `VehicleTrip` الأصلي كاملًا.
- لا يتم نسخ الحقول إلى structure جديد.
- لا يتم إنشاء typedef مسمى في هذه الخطوة؛ type الـrecord يبقى مباشرًا حتى يثبت Consumer لاحق حاجة حقيقية إلى abstraction مستقلة.

**OPERATION SEMANTICS**

- Route Candidate بلا VehicleTrip مطابق → لا association لهذا المسار.
- عدة VehicleTrips مطابقة لنفس Route → association مستقلة لكل VehicleTrip.
- لا يوجد Cartesian Product بين Routes ومركبات غير مطابقة.
- `currentLocation` ليس شرطًا للـassociation ولا تتم تصفية المركبة بسببه.
- لا ranking، ولا scoring، ولا ETA، ولا freshness evaluation في هذه العملية.
- لا dedupe إضافي حسب `lineName` أو أي metadata أخرى.
- ترتيب الناتج ليس Ranking؛ عند التنفيذ يحافظ على ترتيب Route Candidates المدخل، وداخل كل Route يحافظ على ترتيب `findActiveTripsForRoute()` كما يعيده المصدر.
- نتيجة فارغة من Read Contract تعني zero associations لذلك Route.
- استثناء من Read Contract لا يتحول إلى قائمة فارغة؛ يُمرَّر إلى المستهلك الأعلى كما هو، لأن فشل البنية التحتية مختلف دلاليًا عن عدم وجود مركبات نشطة.

**NON-GOALS**

- لا إنشاء `JourneyPlanner` class لمجرد تثبيت الاسم.
- لا إنشاء `JourneyCandidate` model أو DTO أو wrapper جديد.
- لا تعديل `NearbyRoutesService`.
- لا تعديل `MapTab`.
- لا ETA.
- لا UI.
- لا Mapbox.
- لا DriverTrackingHub.
- لا Firestore writes أو indexes جديدة.

**RESULT**

**JourneyPlanner First Association Operation Contract v1 — DESIGN FROZEN ✅**

تم الآن تجميد **Input + Dependency + Matching + Multiplicity + Output Shape + Error/Ordering Semantics** قبل كتابة أي Production Code.

**NEXT**

تنفيذ أصغر orchestration boundary ممكنة فقط لتطبيق هذا العقد، مع focused tests تثبت على الأقل:
- Route بلا مركبات → zero associations.
- Route مع عدة مركبات مطابقة → association لكل مركبة.
- Route + Vehicle غير متطابقين → لا association.
- أكثر من Route → لا Cartesian Product.
- فشل قراءة المركبات → error propagated.
- الحفاظ على `route + vehicleTrip` الأصليين داخل الناتج.

لا يتجاوز التنفيذ هذه الحدود.
### Phase 7 — Journey Option Domain Preflight / Contract v1 — 2026-10-02

**FACTS VERIFIED**

- تم إغلاق Route Candidate Discovery وActive Vehicle Read وFirst Association Operation.
- لا يوجد Production Consumer يفرض `JourneyOption` model أو Evaluation layer.
- البيانات التشغيلية في `VehicleTrip` لا تُعتبر متطلبات لوجود الـOption دون Consumer يثبت ذلك.

**DOMAIN DEFINITION — FROZEN**

```text
Journey Option
=
a route-vehicle association
that qualifies within a specific passenger planning context
```

أي:

**خيار الرحلة هو Association بين مسار مؤهل ومركبة نشطة مطابقة، ضمن سياق تخطيط محدد للراكب.**

**IDENTITY**

```text
route.id + route.direction + vehicleTrip.id
```

ولا تدخل Origin/Destination في الهوية.

**PLANNING CONTEXT**

```text
origin + destination
```

هو سياق التخطيط الذي يجعل الـAssociation خيارًا لهذا الطلب.

**MINIMUM EXISTENCE**

```text
Qualified PlannedRoute
+
Matching Active VehicleTrip
+
Planning Context
```

ولا توجد حاليًا متطلبات إضافية مثبتة من:
```text
currentLocation
routeProgress
lastLocationAt
speed
ETA
```

**DATA BOUNDARY**

- `currentLocation`, `routeProgress`, `lastLocationAt`, و`speed` تبقى بيانات تشغيلية على `VehicleTrip` أو مدخلات لطبقات لاحقة.
- ETA يبقى derived data لاحقًا، وليس شرطًا لوجود Journey Option.
- غياب أي من هذه البيانات لا يعني تلقائيًا عدم وجود Option.

**RANKING / EVALUATION BOUNDARY**

- Ranking خارج تعريف الـOption.
- لا يتم إنشاء `JourneyOptionEvaluator` أو `JourneyOptionStatus` أو `VehicleAvailabilityPolicy` أو `FreshnessPolicy` لمجرد سد فراغ معماري.
- لا تبدأ Evaluation مستقلة إلا بعد ظهور Consumer محدد يطلب قرارًا واضحًا.

**RESULT**

**Journey Option Domain Contract v1 — FROZEN ✅**

**NEXT**

نبحث فقط عن **أول Consumer فعلي لـJourney Option**. عند ظهور Consumer، نحدد هل يحتاج Enrichment أو ETA أو Evaluation أو Ranking، وبأي عقد محدد.

لا يوجد Production Patch مطلوب لهذه النقطة.
### Phase 7 — Passenger Journey Planning Use Case / Consumer Contract v1 — 2026-10-02

**FACTS VERIFIED**

- Use Case الراكب موجود حاليًا في الواجهة: تحديد موقع الراكب، الضغط على **«إلى أين؟»**، اختيار وجهة، ثم محاولة إظهار الباصات التي تمر من الموقع وتتجه نحو الوجهة.
- `DestinationSearchSheet` يوفر إحداثيات الوجهة.
- `PassengerLocationMixin` يوفر إحداثيات Origin الحالية.
- التنفيذ الحالي يستخدم `NearbyRoutesService` للـroute display/discovery في `MapTab`، وليس Journey Option Consumer.
- لا يوجد Production `JourneyPlanner` أو `JourneyOption` model.

**USE CASE**

```text
Passenger
  ↓
Origin + Destination
  ↓
"Show bus journey options"
  ↓
Journey Option Consumer
```

**CONTRACT**

Input:

```text
originLatitude
originLongitude
destinationLatitude
destinationLongitude
```

Dependencies:

```text
RouteCandidateDiscoveryService
+
JourneyRouteVehicleAssociationService
```

Output:

```dart
Future<List<({
  PlannedRoute route,
  VehicleTrip vehicleTrip,
})>>
```

Semantics:

- كل عنصر = Journey Option ضمن Planning Context الحالي.
- Route Candidate مؤهل + matching active VehicleTrip = Option.
- Route بلا مركبة مطابقة = zero options.
- عدة مركبات مطابقة = option لكل مركبة.
- لا ranking أو scoring أو ETA أو freshness أثناء إنشاء الخيارات.
- لا يشترط وجود `currentLocation` أو `routeProgress` أو `speed` أو `lastLocationAt`.
- نفس `route + vehicleTrip` يمكن أن يظهر في أكثر من Planning Context مختلف.
- لا يدخل Origin/Destination في Option identity.
- لا ينتج اختيار Option كتابة Firestore أو Board Request تلقائيًا.

**IDENTITY**

```text
route.id + route.direction + vehicleTrip.id
```

Planning Context:

```text
origin + destination
```

**ERROR / EMPTY**

- عدم وجود Route Candidates → zero options.
- عدم وجود Vehicles مطابقة → zero options.
- أخطاء القراءة تُمرر كما هي.
- لا fallback إلى `NearbyRoutesService` أو Live Tracking.

**BOUNDARY**

لا نضيف:
- `JourneyOption` model.
- `JourneyOptionEvaluator`.
- `JourneyOptionStatus`.
- ETA integration.
- Ranking.
- UI.
- Firestore writes/indexes.

**RESULT**

**Passenger Journey Planning Consumer Contract v1 — DESIGN FROZEN ✅**

لا يوجد Production Patch في هذه النقطة.

**NEXT**

تنفيذ أصغر Consumer Orchestration Boundary فقط، مع focused tests، إذا بقي هذا العقد ثابتًا أثناء مراجعة التنفيذ.
