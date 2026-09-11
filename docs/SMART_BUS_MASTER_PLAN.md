# Smart Bus Master Plan — Final v1

> المرجع الرسمي لخطة تطوير مشروع Jordan Smart Transit باتجاه منظومة Smart Bus.
>
> **الحالة الحالية:** Phase 0 مكتملة.
>
> **المرحلة التالية:** Phase 1 — VehicleTrip + StartTrip.
>
> **قاعدة التنفيذ:** فحص الموجود → تغيير محدود → اختبار نجاح وفشل → دليل واضح → Commit → تثبيت → الانتقال للمرحلة التالية.

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

## الهدف

تحديد المحطة أو نقطة الالتقاط التالية.

```text
Current Position
+
RouteProgress
+
Stops
      ↓
NextStop
```

يجب أن نعرف:

- `nextStopId`.
- المسافة إلى المحطة.
- approaching / at stop / passed.

ويجب التعامل مع:

- تجاوز المحطة.
- GPS غير دقيق.
- عدم وجود محطة لاحقة.

---

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

**لا نبدأ الآن بـ RouteProgress أو ETA أو AI.**

نبدأ فقط بـ:

> **Phase 1 — VehicleTrip + StartTrip**

وأول مهمة تنفيذية قبل تعديل الكود:

### Phase 1 Pre-flight Decisions

```text
1. direction source: يتم تحديده من تدفق UI الحالي بعد فحص الكود.
2. routeId source: PlannedRoute.id.
3. busNumber source: يُحسم من البنية الحالية قبل التنفيذ.
4. offline behavior at startTrip: رفض واضح قبل الإنشاء أو فشل آمن دون تفعيل Local Trip.
```

بعد حسم هذه النقاط:

```text
فحص الكود الحالي
→ Patch صغير
→ flutter analyze
→ flutter run
→ اختبار Phase 1
→ Evidence
→ Commit
```

---

# 20. ملاحظات مرجعية للمستقبل

- Route Drawing تم تثبيته قبل اعتماد هذه الخطة، ولا يُعاد فتحه دون Regression.
- `VehicleTrip` و`VehicleTripService` موجودان في المشروع، والخدمة تتضمن آلية لمنع الرحلات النشطة المتعارضة للسائق نفسه.
- `VehicleTrip` مصمم ليحمل `currentLocation`, `speed`, `heading`, `routeProgress`, و`lastLocationAt`.
- Historical Capture مقصود أن يبدأ مبكرًا في Phase 2، بينما التحليل والاستخدام المتقدم للبيانات يأتي لاحقًا.
- الهدف النهائي هو Smart Bus مبني على بيانات تشغيل حقيقية.
