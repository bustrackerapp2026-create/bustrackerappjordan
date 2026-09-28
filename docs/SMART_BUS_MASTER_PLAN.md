# Smart Bus Master Plan — Final v1

> المرجع الرسمي لخطة تطوير مشروع Jordan Smart Transit باتجاه منظومة Smart Bus.
>
> **الحالة التنفيذية الموثقة:** Phase 0 وPhase 1 وPhase 2 وPhase 3 — التنفيذ البرمجي مغلقة، مع تأجيل الاختبار الميداني النهائي لـPhase 3 لعدم توفر إمكانية تحريك الحافلة.
>
> **Phase 4.1-A:** استخراج `RoutePolylineProjection` المشترك مغلق بعد نجاح `flutter analyze` و`flutter test` بنتيجة **126/126**.
>
> **Phase 4.1-B.1:** عقد بيانات المحطات الثابتة المستقبلية مغلق كقرار تصميم فقط.
>
> **Phase 4.1-B.2-A:** `PlannedRouteStopModel` الحديث مغلق بعد نجاح `flutter analyze` و`flutter test` بنتيجة **132/132**، دون Firestore writer أو Rules أو Runtime integration.
>
> **الخطوة التالية:** Phase 4.1-B.2-B — فصل Reader للمحطات عن خوارزمية `Stop-to-Route Projection`.
>
> **قاعدة التنفيذ:** فحص الموجود → مشكلة مثبتة → قيد تصميم → Patch محدود → اختبار → دليل واضح → Commit → تثبيت → الانتقال للخطوة التالية.

---

## 1. الهدف النهائي

المشروع لا يهدف إلى أن يكون مجرد Bus Tracker يعرض موقع الحافلة، بل إلى بناء منظومة تشغيلية تفهم الرحلة والمسار والحركة، ثم تستخدم البيانات الحقيقية لتقديم التنبؤ والترشيح والذكاء.

التسلسل العام:

```text
بيانات تشغيل صحيحة
    ↓
فهم مكاني للحافلة على المسار
    ↓
Next Stop / ETA
    ↓
اختيار وترتيب الرحلات
    ↓
بيانات تاريخية وتحليلات
    ↓
Prediction / ML
    ↓
AI Assistant
```

الذكاء الاصطناعي ليس طبقة شكلية مستقلة؛ بل يأتي فوق البيانات والخدمات التشغيلية الحقيقية.

---

# 2. القواعد الحاكمة للمشروع

## 2.1 التنفيذ التدريجي

**One Step at a Time**:

- لا ننفذ عدة تغييرات كبيرة في وقت واحد.
- كل مرحلة لها نطاق واضح.
- كل Feature حرجة لها اختبار نجاح وفشل.
- لا ننتقل إلى المرحلة التالية قبل وجود دليل على نجاح المرحلة الحالية.

## 2.2 No Big-Bang Refactor

لا يوجد Refactor شامل لمجرد تنظيف الكود.

يسمح فقط بـ **Refactor محدود ومبرر مباشرةً بمتطلبات الـFeature الحالية**.

قاعدة العمل:

```text
تغيير صغير
→ اختبار
→ Commit
→ تثبيت
```

## 2.3 لا نعيد فتح الأجزاء المستقرة بلا Regression

خصوصًا:

- Route Drawing.
- Mapbox rendering path الذي تم تثبيته.
- GPS/Lifecycle المستقر.

لا تتم إعادة كتابة هذه الأجزاء لمجرد الرغبة في التحسين.

## 2.4 Firestore مقابل Local Runtime State

- **Firestore / VehicleTrip:** المصدر السلطوي (authoritative state) للرحلة التشغيلية.
- **DriverProvider:** Runtime State محلي للواجهة والتتبع.

لا نعكس الترتيب إلى:

```text
Local state → ثم Firestore
```

في بدء الرحلة، الترتيب المستهدف هو:

```text
VehicleTripService.startTrip()
        ↓
Firestore success
        ↓
تحديث Local Runtime State
        ↓
بدء Tracking
```

---

# 3. Phase 0 — Foundation & Stable Baseline ✅

## الهدف

تثبيت الأساس قبل إضافة طبقات Smart Bus.

## الحالة

**مكتملة.**

## ما تم تثبيته

- `main` هي الـbaseline الحالية.
- Route Drawing أصبح مستقرًا بعد معالجة مشكلة التجمّد/الرجة ومسار Mapbox.
- لا توجد حاجة لإعادة فتح هذه المشكلة دون Regression واضح.
- أسرار المشروع لا تدخل المستودع.

---

# 4. Phase 1 — VehicleTrip + StartTrip ★ NEXT

## الهدف

تحويل رحلة السائق من حالة محلية إلى **رحلة تشغيلية حقيقية**.

## التدفق المستهدف

```text
Driver
  ↓
Online / Location Ready
  ↓
Select Line
  ↓
Select Direction
  ↓
Resolve Approved PlannedRoute
  ↓
VehicleTripService.startTrip()
  ↓
Firestore success
  ↓
Update local runtime state
  ↓
Start Tracking
```

## قرارات يجب حسمها قبل أول تعديل

### direction

- القيم: `outbound | return`.
- المصدر يجب أن يكون واضحًا في الـUI/الدفق.
- يؤثر لاحقًا على `RouteProgress`, `NextStop`, `ETA`.

### routeId

- مصدر الحقيقة: `PlannedRoute.id`.
- لا نعتمد اسم الخط النصي وحده لتحديد الرحلة التشغيلية.

### busNumber

- يحدد مصدره من البنية الحالية للمشروع قبل التنفيذ.

### Offline Behavior

يجب تحديد السلوك صراحةً:

| الحالة | السلوك المستهدف |
|---|---|
| الشبكة مقطوعة قبل StartTrip | رفض واضح وعدم إنشاء حالة محلية نصف مكتملة |
| الشبكة تنقطع أثناء StartTrip | فشل آمن/rollback وعدم تفعيل DriverProvider |
| الشبكة تنقطع بعد نجاح StartTrip | الرحلة تبقى Active على السيرفر، مع إدارة التحديثات لاحقًا |
| التطبيق أُغلق أثناء رحلة Active | يُعالج في استعادة الرحلة ضمن Lifecycle/Recovery المقصود |

## معايير القبول

### Happy Path

- `vehicleTrips/{tripId}` يتم إنشاؤها.
- `status = active`.
- `routeId` صحيح.
- `direction` صحيح.
- لا توجد رحلة Active ثانية للسائق نفسه.
- يبدأ DriverProvider/Tracking بعد نجاح Firestore.

### Failure Path

- Active trip موجودة → رفض واضح.
- PlannedRoute غير صالحة/غير موجودة → رفض.
- Firestore failure → لا تبقى رحلة محلية نصف مكتملة.
- زر Start لا يبقى عالقًا في حالة Loading.

### Evidence

- Firestore: وجود `/vehicleTrips/{id}` بالحالة `active`.
- Local state: `DriverProvider` يعكس الرحلة بعد نجاح الإنشاء.
- Logs مختصرة للعملية الحرجة: `tripId`, `routeId`, `direction`.

## الحد الأدنى من المسار الأفقي

- **Rules:** `vehicleTrips` فقط.
- **Error Handling:** `startTrip` + rollback.
- **Observability:** `tripId`, `routeId`, `direction`.
- **Data Quality:** direction صالح وrouteId صالح.

---

# 5. Phase 2 — Live GPS + Historical Capture

## الهدف

ربط GPS الفعلي بالـVehicleTrip والبدء مبكرًا في جمع البيانات التاريخية.

## البيانات الحية

- `currentLocation`
- `speed`
- `heading`
- `lastLocationAt`

## الفصل بين Live وHistorical

```text
Live GPS
   ↓
Latest Vehicle State

Historical Telemetry
   ↓
Local Buffer / Queue
   ↓
Batch Upload
   ↓
TripPings
```

لا نكتب كل تحديث GPS إلى Firestore بلا سياسة.

## TripPing — الحد الأدنى المقترح

```text
tripId
routeId
direction
location
speed
heading
timestamp
```

سيضاف `routeProgress` بعد اكتمال Phase 3.

## Sampling Policy

لا نثبت رقمًا نهائيًا قبل فحص معدل التتبع الحالي وسلوك الهاتف.

يجب اعتماد سياسة محددة قبل التنفيذ الفعلي، مثل:

- sampling زمني أثناء الحركة.
- sampling أبطأ عند التوقف.
- pings إضافية عند الأحداث المهمة.
- حد أعلى للـbuffer/queue.
- Batch upload بدل كتابة تاريخية منفصلة لكل update.

الهدف: جودة كافية للـanalytics مع ضبط Firestore writes والبطارية.

## حالات Live Tracking

```text
LIVE
STALE
LOST
```

**GPS LOST لا يعني تلقائيًا انتهاء VehicleTrip.**

## الحد الأدنى من المسار الأفقي

- **Rules:** `tripPings`.
- **Error Handling:** GPS `LOST/STALE`.
- **Observability:** ping rate وgaps.
- **Data Quality:** speed/timestamp validation.

---

# 6. Phase 3 — RouteProgress

## الهدف

معرفة موقع الحافلة على المسار، وليس فقط موقعها الجغرافي.

```text
VehicleTrip
+
GPS
+
PlannedRoute
      ↓
RouteProgress
```

القيمة:

```text
0.00 → بداية المسار
0.50 → منتصف المسار
1.00 → نهاية المسار
```

## الحماية

- Projection على المسار.
- GPS noise handling.
- منع القفزات غير المنطقية.
- حماية من التراجع الوهمي في progress.

## القبول

تحرك الحافلة على مسار معروف يجب أن يعطي `progress` منطقيًا ومستقرًا.

---

# 7. Phase 4 — NextStop / Pickup

## الحالة الحالية

**قيد التنفيذ — تم إغلاق 4.1-A و4.1-B.0 و4.1-B.1 و4.1-B.2-A، ولم تبدأ خوارزمية Stop-to-Route بعد.**

### 4.1-A — RoutePolylineProjection ✅

تم استخراج primitive هندسي مشترك من إسقاط RouteProgress الحالي:

```text
RoutePolylineProjection
    ↓
alongMeters
distanceToRouteMeters
segmentIndex
segmentT
```

الـprimitive لا يعرف GPS أو Stop أو VehicleTrip أو Firestore.

تم الحفاظ على سلوك `RouteProgressCalculator` الحالي دون تغيير في:
- `100m` minimum projection distance.
- accuracy handling.
- `250m` hard cap.
- nearest projection selection.
- `alongMeters`, `segmentT`, `segmentIndex`, `distanceToRouteMeters`.
- حساب `progress`.

التحقق على جهاز التطوير:
- `flutter analyze` → **No issues found!**
- الاختبار المخصص → **7/7**
- `flutter test` الكامل → **126/126**
- لا تغييرات محلية بعد التثبيت.

### 4.1-B — Stop-to-Route Projection ⏳

#### 4.1-B.0 — Projection Primitive Contract Hardening ✅

تم تثبيت عقد هندسي صغير على `RoutePolylineProjection` عبر regression test يغطي route بالشكل `A → A → B`.

السلوك المثبت:
- يتم تجاهل المقطع الصفري الطول `A → A`.
- يتم اختيار المقطع الحقيقي `A → B` للإسقاط.
- `segmentIndex`, `segmentT`, `alongMeters`, و`distanceToRouteMeters` تبقى متوافقة مع الإسقاط المتوقع.

حدود التغيير:
- اختبار فقط؛ لا production code.
- لا Model جديد.
- لا Firestore.
- لا `RoutePlanService`.
- لا Hub.
- لا `NextStop`.

التحقق:
- `flutter analyze` → **No issues found!**
- الاختبار المخصص → **8/8**
- `flutter test` الكامل → **127/127**
- PR **#20** → merged إلى `stage/approved-route-line-vehicle-link-v1`.

هذا hardening مغلق ولا يعيد فتح 4.1-A.

#### 4.1-B.1 — Stop data contract ✅

تم تثبيت عقد بيانات المحطات الثابتة المستقبلية كقرار تصميم فقط.

العقد المستهدف:

```text
plannedRoutes/{routeId}/stops/{stopId}

Stop
├── name       : String      required
├── location   : GeoPoint    required
├── order      : int         required, >= 0
└── isMajor    : bool        optional, default false
```

الـinvariants:
- `stopId` هو Firestore Document ID.
- `routeId` هو Parent `PlannedRoute` ID، ولا يُكرر كحقل إلزامي داخل Stop.
- `direction` مصدره `PlannedRoute.direction`، ولا يُكرر داخل Stop.
- `order` هو تسلسل إداري zero-based للمحطات في اتجاه `PlannedRoute.points`، وفريد داخل Stops الخاصة بالـroute.
- `order` لا يعرّف الهندسة ولا يُستخدم كبديل عن projection.
- المصدر الهندسي هو `location + PlannedRoute.points`.
- `stopAlongMeters` قيمة مشتقة ولا تُخزن.
- `NextStop` قيمة مشتقة ولا تُخزن.
- لا توجد Stops ثابتة مفروضة على كل المسارات؛ `PlannedRoute` بدون Stops حالة Domain صحيحة، ويدعم لاحقًا `NextStop = null`.

مصادر خارج العقد:
- لا يُستخدم `routeCatalog` كمصدر Stops.
- لا يُعاد استخدام `PickupPointModel` أو `NearestStopFinder` كنظام Route Stops.
- `RouteStopModel` القديم المرتبط بـ`routes/{routeId}/stops` يبقى خارج Phase 4.

حدود الإغلاق:
- لا Model جديد.
- لا Firestore write.
- لا Firestore Rules.
- لا Hub أو VehicleTrip.
- لا NextStop Resolver.
- لا تعديل في RouteProgress أو `RoutePolylineProjection`.

تم تثبيت uniqueness لـ`order` كـinvariant منطقي؛ آلية enforcement تؤجل إلى طبقة الإدارة/الكتابة عند التنفيذ العملي.

#### 4.1-B.2-A — PlannedRouteStopModel ✅

تم تنفيذ Model حديث مستقل للمحطات الثابتة المستقبلية وفق العقد المثبت في 4.1-B.1.

الحدود:
- `PlannedRouteStopModel` يمثل: `id`, `name`, `location: GeoPoint`, `order >= 0`, `isMajor`.
- `id` هو Document ID؛ لا يتم تكرار `routeId` أو `direction`.
- القيم المشتقة (`stopAlongMeters`, `NextStop`, `distanceAhead`, `eta`) خارج النموذج.
- لا يوجد Writer أو Reader للمسارات الثابتة في هذه الخطوة.
- لا توجد Firestore Rules جديدة.
- لا تغيير في RouteProgress أو `RoutePolylineProjection` أو Hub/VehicleTrip.
- `routes/{routeId}/stops` القديم يبقى خارج Phase 4.

التحقق:
- `flutter analyze` → **No issues found!**
- الاختبار المخصص → **5/5**
- `flutter test` الكامل → **132/132**
- PR **#21** → merged إلى `stage/approved-route-line-vehicle-link-v1`.

هذه الخطوة جزء من 4.1-B.2، وليست تنفيذًا لخوارزمية `Stop-to-Route Projection` نفسها.

### الهدف النهائي للمرحلة

```text
Current Position
+
RouteProgress
+
Optional Fixed Route Stops
      ↓
NextStop
```

ويجب أن يدعم النظام أيضًا المسار الذي لا توجد له محطة ثابتة لاحقة.

# 8. Phase 5 — ETA Engine

## الهدف

بناء ETA هندسي deterministic قبل إدخال ML.

```text
Position
+
Progress
+
Speed
+
Remaining Route
+
Stop Behavior
      ↓
ETA
```

## قواعد مهمة

- `speed = 0` تتم معالجته بوضوح.
- السرعات غير الواقعية لا تنتج ETA ساذجًا.
- GPS stale/lost قد يجعل ETA غير متاح.
- **ETA unavailable أفضل من رقم وهمي.**

---

# 9. Phase 6 — BusWatch

## الهدف

تمكين الراكب من مراقبة رحلة فعلية.

```text
Passenger
   ↓
VehicleTrip
   ↓
Live Location
   ↓
Route
   ↓
ETA
```

**Read-only بالكامل.**

الراكب لا يعدّل الرحلة التشغيلية.

---

# 10. Phase 7 — JourneyPlanner

## الهدف

الانتقال من عرض الحافلات إلى اختيار رحلة مناسبة.

```text
Origin
+
Destination
+
Available Trips
+
Routes
+
ETA
      ↓
Journey Options
```

محرك JourneyPlanner يمكن بناؤه عندما تصبح البيانات الحية والمسارات وETA قابلة للاستخدام.

لا يوجد شرط هندسي جامد مبني على عدد محدد من الرحلات اليومية؛ جودة التوصيات تعتمد على الحركة المتاحة وجودة البيانات.

---

# 11. Phase 8A — Engineering Ranking

ترتيب الخيارات بالاعتماد على البيانات الحالية والحسابات المباشرة:

- Fastest.
- Closest.
- Least Walking.
- Fewest Transfers.

لا يحتاج ML ولا Historical Data كاملة.

---

# 12. Phase 9 — Historical Analytics

> **الجمع يبدأ في Phase 2، والتحليل يبدأ هنا.**

## أمثلة

- Trip duration.
- Segment speed.
- Stop dwell time.
- Delay.
- Arrival deviation.
- Route performance.
- Reliability patterns.

الهدف هو تحويل البيانات التاريخية الخام إلى features وتحليلات مفيدة للمراحل اللاحقة.

---

# 13. Phase 8B — Statistical Ranking

بعد توفر Historical Analytics نضيف خصائص مثل:

- More Reliable.
- Less Delay-Prone.
- More Consistent.

هذه المرحلة تعتمد على الإحصاء والبيانات التاريخية، وليست مجرد قواعد مباشرة.

---

# 14. Phase 10 — Prediction / ML

## الاستخدامات المحتملة

- ETA prediction.
- Delay prediction.
- Segment travel-time prediction.
- Reliability prediction.
- Demand prediction لاحقًا.

## القاعدة

لا نستخدم ML لمجرد وجود ML.

يبدأ فقط عندما:

- البيانات كافية للهدف.
- جودة البيانات مناسبة.
- الـbaseline deterministic موجود للمقارنة.

---

# 15. Phase 11 — AI Assistant

الـAI يكون طبقة فوق خدمات النظام:

```text
AI Assistant
   ↓
Live Data Tools
Trip Tools
Journey Planner
Historical Analytics
Prediction Engine
```

أمثلة:

- «أين أقرب باص؟» → Live Data.
- «أي رحلة أكثر موثوقية؟» → Historical/Ranking.
- «لماذا تأخر الباص؟» → Trip History + Prediction.
- «ما أفضل رحلة الآن؟» → JourneyPlanner + Ranking.

الهدف: AI يفهم بيانات النظام ويستدعي أدواته، وليس chatbot منفصلًا يعتمد على التخمين.

---

# 16. المسار الأفقي الإلزامي

هذه الضوابط تعمل في كل مرحلة ولا تشكل مراحل مستقلة.

## Security / Firestore Rules

كل Model/Collection جديد يرافقه الحد الأدنى من Rules اللازمة.

## Error Handling

لكل Feature حرجة:

```text
Success
Failure
Recovery
```

## Observability

يجب وجود دليل واضح على العمليات الحرجة بدون إغراق Logcat.

## Data Quality

خصوصًا:

- GPS.
- speed.
- timestamps.
- routeProgress.
- trip state.

## Schema Evolution

- كل field جديد nullable أو له default.
- لا إزالة لـfield بدون migration.
- نحافظ على backward compatibility.
- يمكن إضافة version field عند الحاجة، وليس كشرط مبكر.

---

# 17. بوابة الانتقال بين المراحل

لا تعتبر المرحلة مكتملة لمجرد أن التطبيق لم ينهَر.

يجب تحقق:

```text
Code
 ✅

Happy Path
 ✅

Failure Path
 ✅

Firestore / State Consistency
 ✅

No Regression
 ✅

Evidence Documented
 ✅
```

---

# 18. الخريطة التنفيذية النهائية

```text
PHASE 0
Foundation / Stable Baseline
✅
        ↓
PHASE 1
VehicleTrip + StartTrip
★ NEXT
        ↓
PHASE 2
Live GPS + Historical Capture
        ↓
PHASE 3
RouteProgress
        ↓
PHASE 4
NextStop / Pickup
        ↓
PHASE 5
ETA
        ↓
PHASE 6
BusWatch (Read Only)
        ↓
PHASE 7
JourneyPlanner
        ↓
PHASE 8A
Engineering Ranking
        ↓
PHASE 9
Historical Analytics
        ↓
PHASE 8B
Statistical Ranking
        ↓
PHASE 10
ML / Prediction
        ↓
PHASE 11
AI Assistant
```

وبالتوازي من Phase 2:

```text
Historical Capture
        ↓
Historical Data
        ↓
Analytics
        ↓
ML / Prediction
```

---

# 19. نقطة البداية الحالية

**Phase 4.1-A مغلقة ✅.**

الحالة التنفيذية الحالية:

```text
Phase 4.1-A
RoutePolylineProjection
✅
        ↓
Phase 4.1-B
Stop-to-Route Projection
⏳ NEXT
        ↓
Phase 4.2
NextStop Resolver
        ↓
Phase 4.3
Stop State
        ↓
Phase 4.4
Firestore / Hub Integration
```

ولا يتم الانتقال إلى 4.1-B قبل تثبيت تصميم المحطات الثابتة الاختيارية وتحديد مصدر بياناتها المستقبلي.

**المسارات الحالية لا تتطلب Stops ثابتة حتى تستمر في العمل وفق نموذج التشغيل الحالي القائم على صعود الركاب عند طلب التوقف.**

