# Smart Bus Master Plan — Final v1

> المرجع الرسمي لخطة تطوير مشروع Jordan Smart Transit باتجاه منظومة Smart Bus.
>
> **الحالة التنفيذية الموثقة:** Phase 0 وPhase 1 وPhase 2 وPhase 3 — التنفيذ البرمجي مغلقة، مع تأجيل الاختبار الميداني النهائي لـPhase 3 لعدم توفر إمكانية تحريك الحافلة.
>
> **Phase 4.1-A:** استخراج `RoutePolylineProjection` المشترك مغلق بعد نجاح `flutter analyze` و`flutter test` بنتيجة **126/126**.
>
> **Phase 4.1-B.1:** عقد بيانات المحطات الثابتة المستقبلية مغلق كقرار تصميم فقط.
>
> **Phase 4.1-B.2-A:** `PlannedRouteStopModel` الحديث مغلق بعد نجاح `flutter analyze` و`flutter test` بنتيجة **132/132**، دون Firestore writer أو Runtime integration.
>
> **Phase 4.1-B.2-B:** `PlannedRouteStopService` (read-only Stop Reader) مغلق بعد نجاح `flutter analyze` و`flutter test` بنتيجة **134/134**، مع Rule قراءة للمسار الحديث `plannedRoutes/{routeId}/stops` ودون أي write API أو Runtime integration.
>
> **Phase 4.1-B.2-C:** `PlannedRouteStopProjection` مغلق بعد نجاح `flutter analyze` و`flutter test` بنتيجة **142/142**، مع focused projection tests بنتيجة **8/8**. تمت إعادة استخدام `RoutePolylineProjection` دون تعديل الـprimitive أو الـModel أو الـReader.
>
> **Phase 4.2:** `NextStopResolver` مغلق بعد نجاح `flutter analyze` و`flutter test` بنتيجة **151/151**، مع focused tests بنتيجة **9/9**. تم فصل Stop Eligibility عن قرار NextStop، دون threshold مسافة مثبت داخل الـResolver.
>
> **Phase 4.3-A:** عقد حالات المحطة مغلق كقرار تصميم فقط. تم تثبيت الحالات `upcoming`, `approaching`, `atStop`, `passed`، مع تصنيف حتمي على محور المسار وإبقاء الحدود العددية ضمن Policy غير مثبتة بعد.
>
> **Phase 4.3-B:** `Stop State Resolver` مغلق بعد نجاح `flutter analyze` بنتيجة **No issues found!**، واختبار مخصص **20/20**، و`flutter test` الكامل **171/171**. التغيير Domain-only ولا يتضمن GPS أو Projection أو NextStop أو Firestore أو Hub أو VehicleTrip أو ETA.
>
> **Phase 4 — Runtime / Domain Implementation:** مكتملة ✅. تم إغلاق 4.1-A و4.1-B.0 و4.1-B.1 و4.1-B.2-A و4.1-B.2-B و4.1-B.2-C و4.2 و4.3-A و4.3-B و4.4-A و4.4-B. لا توجد ملاحظة حالية تستدعي إعادة فتح Phase 4؛ فجوة اختبار Firestore failure تبقى فجوة Evidence فقط، والاختبار الميداني النهائي مؤجل.
>
> **Phase 5.1 — ETA Contract + Deterministic Engine:** مكتملة ✅ بعد تثبيت العقد والتنفيذ والتحقق المحلي، دون Integration أو Passenger/UI أو تعديل على EtaUtils القديم.

**Phase 5.2-D — ETA Runtime Invocation:** مكتملة ✅ بعد تنفيذ عقد `EtaResult?` والتحقق المحلي، مع بقاء Passenger/UI وDriverTrackingHub خارج النطاق.

**Phase 5.2-E — ETA Result Consumption:** مثبتة كتصميم ✅ دون Production Code أو UI/Hub integration.

**Phase 6-A — BusWatch Operational Read Model:** مكتملة ✅ — تم تنفيذ الـReader والـResult والاختبارات المركزة، مع بقاء Consumer/UI خارج نطاق 6-A.

**Phase 6-B — BusWatch Read Consistency & Refresh Contract:** ✅ DESIGN FROZEN — تم تثبيت عقد الاتساق وتنسيق القراءة، دون refresh/stream implementation.

**Phase 6-C — Passenger BusWatch Consumer Contract:** مكتملة ✅ — تم تنفيذ Consumer مستقل، مع استبدال النتيجة السابقة ومسح snapshot عند أي نتيجة non-available، مع بقاء UI integration خارج نطاق 6-C.

**Phase 6-D — Passenger BusWatch Read Lifecycle / Context Contract:** مكتملة ✅ — تم تنفيذ `BusWatchReadLifecycleCoordinator` مع حماية Context/Read Generation ضد النتائج والأخطاء المتأخرة.
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

**مكتملة — Runtime / Domain Implementation ✅**

تم إغلاق جميع نقاط Phase 4 التنفيذية حتى `4.4-B`. لا توجد Regression أو مشكلة معمارية مثبتة تستدعي إعادة فتح أي جزء من Phase 4.

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

### 4.1-B — Stop-to-Route Projection ✅

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

#### 4.1-B.2-B — PlannedRouteStopService / Read-only Stop Reader ✅

تم تنفيذ Reader حديث مستقل للمحطات الثابتة المستقبلية وفق العقد المثبت في 4.1-B.1.

الحدود:
- القراءة من `plannedRoutes/{routeId}/stops` فقط.
- استخدام `orderBy('order')` لإرجاع المحطات بترتيبها الإداري.
- `routeId` فارغ/بيضاء يعيد مصدرًا فارغًا دون محاولة الوصول إلى Firestore.
- لا توجد عمليات create/update/delete داخل الخدمة.
- تمت إضافة Rule قراءة فقط للمسار الحديث.
- لا يوجد Stop-to-Route Projection في هذه الخطوة.
- لا يوجد NextStop أو Stop State أو ETA أو VehicleTrip أو DriverTrackingHub أو Mapbox integration.
- المسار القديم `routes/{routeId}/stops` يبقى خارج Phase 4.

التحقق:
- `flutter analyze` → **No issues found!**
- الاختبار المخصص → **2/2**
- `flutter test` الكامل → **134/134**
- PR **#22** → merged إلى `stage/approved-route-line-vehicle-link-v1`.

هذه الخطوة تغلق Reader فقط. لا تعني بدء `Stop-to-Route Projection`.

#### 4.1-B.2-C — PlannedRouteStopProjection ✅

تم تنفيذ طبقة Domain/adapter صغيرة تربط `PlannedRouteStopModel.location` بهندسة `PlannedRoute.points` عبر إعادة استخدام `RoutePolylineProjection.project(...)`.

الحدود:
- لا معرفة بالمحطات داخل `RoutePolylineProjection`.
- لا منطق إسقاط هندسي جديد.
- `projection.alongMeters` هو الموضع المشتق للمحطة على محور المسار (`stopAlongMeters`) في runtime فقط.
- لا يتم تخزين `stopAlongMeters` في Firestore أو داخل `PlannedRouteStopModel`.
- Stop خارج الـpolyline قد تعيد projection مع `distanceToRouteMeters > 0`؛ صلاحية المحطة التشغيلية لا تُحسم هنا.
- route غير صالح (`points.length < 2` أو طول هندسي صفري) يعيد `null` دون exception.
- لا NextStop أو Stop State أو ETA أو VehicleTrip أو DriverTrackingHub أو Firestore persistence أو Mapbox integration.
- لا توجد سياسة خاصة لمسارات self-intersecting/ambiguity resolution في هذه الخطوة.

التحقق:
- `flutter analyze` → **No issues found!**
- اختبار Projection المخصص → **8/8**
- `flutter test` الكامل → **142/142**
- PR **#24** → merged إلى `stage/approved-route-line-vehicle-link-v1`.

هذه الخطوة تغلق Stop-to-Route Projection فقط.

#### 4.2 — NextStop Resolver / Stop Eligibility Contract ⏳ DESIGN ONLY

هذه الخطوة تبدأ بعقد `Stop Eligibility` قبل تنفيذ الـResolver.

التدفق المقصود:

```text
Fixed Route Stops
        ↓
PlannedRouteStopProjection
        ↓
Projected Stop
        ↓
Stop Eligibility
        ↓
NextStop Resolver
```

### مدخلات العقد

- `PlannedRoute.points` لنفس المسار/الاتجاه.
- `vehicleAlongMeters` مأخوذة من RouteProgress المقبولة؛ لا يُعاد حسابها من GPS داخل هذه الطبقة.
- لكل Stop: `PlannedRouteStopModel` مع Projection مشتق يحتوي على `alongMeters` و`distanceToRouteMeters` عند نجاح الإسقاط.
- `order` يبقى ترتيبًا إداريًا ولا يصبح محورًا مكانيًا.

### عقد Stop Eligibility

الـStop تدخل نطاق candidates فقط إذا تحققت الشروط التالية:
- يوجد Projection غير `null`.
- `alongMeters` و`distanceToRouteMeters` قيمتان finite.
- `alongMeters` يقع ضمن محور المسار الصالح من `0` إلى `totalRouteMeters`.
- `distanceToRouteMeters` ينجح في سياسة Eligibility مستقلة قابلة للضبط.
- لا تعتمد Eligibility على `order` ولا على ترتيب Firestore.
- لا تستخدم Eligibility مسافة GPS مباشرة إلى المحطة بدل مسافة الإسقاط على محور المسار.

**ملاحظة:** قيمة threshold الخاصة بـ`distanceToRouteMeters` لم تُثبت بعد، ولا يتم اختراع رقم داخل هذا العقد أو داخل الـgeometry primitive.

### عقد NextStop بعد Eligibility

بعد اجتياز Eligibility فقط:
- المرشح يجب أن يحقق:
  `vehicleAlongMeters < stopAlongMeters`.
- يتم اختيار المرشح ذي أصغر:
  `stopAlongMeters - vehicleAlongMeters`
  أي أقرب Stop إلى الأمام على محور المسار.
- إذا تساوى أكثر من مرشح في `alongMeters)، يبقى `order` tie-breaker إداريًا.
- Stop الواقعة تمامًا عند `vehicleAlongMeters` لا تعتبر NextStop في هذه الخطوة؛ هذا يمنع إعادة اختيار المحطة الحالية.
- إذا لم يوجد مرشح صالح إلى الأمام، تكون النتيجة `null`.
- PlannedRoute بدون Stops ثابتة حالة صحيحة، والنتيجة `null`.

### حالات الرفض/الغياب

يُعاد `null` دون exception عندما:
- RouteProgress الحالية غير متاحة أو غير صالحة.
- `vehicleAlongMeters` غير finite أو خارج محور المسار.
- المسار غير صالح أو طوله الهندسي صفري.
- لا توجد Stops.
- لا توجد Stops اجتازت Eligibility وتوجد أمام المركبة.

### حدود التنفيذ

في تنفيذ 4.2 لا تدخل:
- `Stop State`: `approaching`, `atStop`, `passed`.
- ETA أو dwell time.
- Firestore persistence.
- VehicleTrip / DriverTrackingHub integration.
- Mapbox أو `driver_map_tab.dart`.
- self-intersection / ambiguity resolution.
- أي تعديل على `RoutePolylineProjection` أو `PlannedRouteStopModel` أو `PlannedRouteStopService`.

هذه الخطوة تثبت العقد فقط؛ تنفيذ `NextStop Resolver` يأتي بعد تثبيت هذا العقد واختباره كـdomain policy مستقلة.

#### 4.2 — NextStop Resolver ✅

تم تنفيذ Resolver domain صغير يستهلك Stops projected الجاهزة مع `vehicleAlongMeters` القادم من RouteProgress، ويترك Stop Eligibility كسياسة صريحة يمررها المستهلك.

الحدود:
- لا يعيد الـResolver حساب GPS projection.
- لا يدخل إلى Firestore أو VehicleTrip أو DriverTrackingHub.
- لا يثبت threshold رقميًا لـ`distanceToRouteMeters` داخل الـResolver.
- المرشح يجب أن يكون Eligible وأن يحقق `vehicleAlongMeters < stopAlongMeters`.
- يتم اختيار أصغر `stopAlongMeters - vehicleAlongMeters`.
- `order` يستخدم فقط كـadministrative tie-breaker عند تعادل `alongMeters`.
- لا توجد Stop State أو ETA أو persistence في هذه الخطوة.
- لا توجد سياسة self-intersection ambiguity.

العقد المثبت:
```text
Projected Stops
      +
vehicleAlongMeters
      +
Stop Eligibility Policy
      ↓
NextStop?
```

التحقق:
- `flutter analyze` → **No issues found!**
- اختبار NextStop المخصص → **9/9**
- `flutter test` الكامل → **151/151**
- PR **#27** → merged إلى `stage/approved-route-line-vehicle-link-v1`.

هذه الخطوة تغلق NextStop Resolver domain logic فقط.

#### 4.3-A — Stop State Contract ✅ DESIGN ONLY

تم تثبيت عقد حالات المحطة قبل تنفيذ أي State Resolver.

### المدخلات

- `vehicleAlongMeters`: قيمة `RouteProgressProjection.alongMeters` المقبولة على محور المسار.
- `stopAlongMeters`: قيمة `PlannedRouteStopProjection` المشتقة للمحطة.
- Policy للحالة تحتوي على حدود عددية قابلة للضبط، ولم يتم تثبيت قيمها بعد.

لا تدخل في هذا العقد:
- GPS خام أو أي مسافة جغرافية مباشرة بين المركبة والمحطة.
- `order` كمحور مكاني.
- Firestore أو VehicleTrip أو DriverTrackingHub أو Mapbox.

### المتغير المعياري

يُعرَّف:

```text
delta = stopAlongMeters - vehicleAlongMeters
```

بحيث:
- `delta > 0`: المحطة أمام المركبة على محور المسار.
- `delta = 0`: المركبة والمحطة عند نفس الموضع على محور المسار.
- `delta < 0`: المركبة تجاوزت موضع المحطة على محور المسار.

### الحالات وحدودها

التصنيف يجب أن يكون حتميًا ومغطيًا كامل محور `delta` دون تداخل أو فجوات، بعد تثبيت Policy العددية:

```text
delta < -atStopRadius
        → passed

|delta| <= atStopRadius
        → atStop

atStopRadius < delta <= approachingDistance
        → approaching

delta > approachingDistance
        → upcoming
```

ويجب أن تحقق الـPolicy:
- `atStopRadius > 0`.
- `approachingDistance > atStopRadius`.
- لا توجد مناطق تداخل أو فجوات بين الحالات الأربع.

المعاني التشغيلية:
- `upcoming`: المحطة أمام المركبة وبعيدة أكثر من نطاق الاقتراب.
- `approaching`: المحطة أمام المركبة وداخل نطاق الاقتراب، لكنها خارج نطاق `atStop`.
- `atStop`: المركبة داخل نطاق المحطة حول موضعها على محور المسار.
- `passed`: المركبة تجاوزت نطاق المحطة من الجهة الأمامية.

### الانتقالات

لا يحتاج State Contract إلى ذاكرة حالة مستقلة؛ التصنيف حتمي من القيم الحالية. مع افتراض أن RouteProgress يحافظ على monotonicity، يكون المسار الطبيعي:

```text
upcoming
   ↓
approaching
   ↓
atStop
   ↓
passed
```

لا يجوز لطبقة Stop State أن تعيد الحالة للخلف بسبب GPS jitter؛ معالجة الرجوع الوهمي تقع في RouteProgress قبل وصول `vehicleAlongMeters` إلى هذه الطبقة.

إذا كان `vehicleAlongMeters` أو `stopAlongMeters` غير finite أو خارج محور المسار، فلا توجد حالة صالحة (`null` / unavailable).

### حدود 4.3-A

- لا يوجد كود إنتاجي.
- لا State machine تنفيذية.
- لا hysteresis إضافي قبل وجود حاجة مثبتة.
- لا threshold رقمي قبل تثبيت Policy مستقلة.
- لا تعديل على Eligibility أو NextStop Resolver.
- لا ETA أو dwell time.
- لا Firestore persistence.
- لا Hub/VehicleTrip/Mapbox.
- لا self-intersection ambiguity resolution.

الخطوة البرمجية التالية بعد تثبيت هذا العقد هي 4.3-B — `Stop State Resolver`.

#### 4.3-B — Stop State Resolver ✅

تم تنفيذ Resolver Domain-only حتمي لحالة محطة ثابتة على محور المسار.

### العقد والتنفيذ

```text
Stop State Resolver
        ↓
validate inputs
        ↓
calculate delta
        ↓
classify state
```

يعتمد التصنيف على:

```text
delta = stopAlongMeters - vehicleAlongMeters
```

والحالات المثبتة:

```text
delta < -atStopRadius
        → passed

|delta| <= atStopRadius
        → atStop

atStopRadius < delta <= approachingDistance
        → approaching

delta > approachingDistance
        → upcoming
```

### Policy

- `atStopRadius` يجب أن يكون finite و`> 0`.
- `approachingDistance` يجب أن يكون finite و`> atStopRadius`.
- لا توجد قيم افتراضية رقمية في resolver.
- صلاحية قيم المحور تُتحقق مقابل `[0, totalRouteMeters]`.
- `totalRouteMeters` نفسه يجب أن يكون finite و`> 0`.

### حدود التنفيذ

لا يعرف هذا الـResolver:
- GPS.
- Projection.
- NextStop.
- Firestore.
- VehicleTrip.
- DriverTrackingHub.
- Mapbox.
- ETA.
- persistence.

ولا يغير أي طبقة سابقة.

### الاختبارات

تمت تغطية الحدود الأساسية وقيم الإدخال والسياسة، بما في ذلك:
- `delta = -atStopRadius`.
- `delta = +atStopRadius`.
- `delta = approachingDistance`.
- `delta > approachingDistance`.
- `delta < -atStopRadius`.
- نفس موضع المركبة والمحطة.
- قيم محور غير صالحة.
- قيم route length غير صالحة.
- سياسات غير صالحة.

التحقق المحلي:
- `flutter analyze` → **No issues found!**
- focused `stop_state_resolver_test.dart` → **20/20**
- `flutter test` الكامل → **171/171**
- PR **#30** → merged squash إلى `stage/approved-route-line-vehicle-link-v1`.
- merge commit → `690c26f25f9372649f5b722802ed932bd997a66f`.

هذه الخطوة مغلقة. لا يوجد في الخطة الحالية بند رسمي باسم 4.3-C.

#### 4.4-A — Stop Runtime Integration Contract ✅ DESIGN ONLY

قبل أي ربط تنفيذي مع الـHub أو Firestore، تم تثبيت عقد التكامل بين الطبقات السابقة.

### التدفق المقصود

```text
Active VehicleTrip
      +
Approved PlannedRoute
      +
Accepted RouteProgress
      ↓
Read fixed Stops once
      ↓
Project Stops to route axis
      ↓
Stop Eligibility
      ↓
NextStopResolver
      +
StopStateResolver per projected stop
      ↓
Runtime Stop Snapshot
```

### مصدر البيانات

- المصدر الوحيد للمحطات الثابتة هو:
  `plannedRoutes/{routeId}/stops`
- القراءة تتم عبر `PlannedRouteStopService`.
- لا توجد عمليات write للمحطات في هذا التكامل.
- لا تتم إعادة استخدام `routes/{routeId}/stops` القديم أو `PickupPointModel`.

### قاعدة الأداء

- لا يُسمح بقراءة Firestore للمحطات داخل كل GPS callback.
- يتم تحميل/تحديث Stops عند ربط الرحلة التشغيلية أو استعادتها، ثم تُستخدم بياناتها المحملة محليًا.
- إسقاط المحطات، واختيار NextStop، وتصنيف StopState عمليات محلية deterministic بعد توفر المدخلات.
- لا نضيف stream/query جديدًا إلى مسار GPS الساخن قبل وجود حاجة مثبتة.

### مسؤوليات التكامل

- `PlannedRouteStopService`: قراءة Stops فقط.
- `PlannedRouteStopProjection`: تحويل موقع Stop إلى `RoutePolylineProjection`.
- `NextStopResolver`: اختيار أقرب Stop مؤهل إلى الأمام.
- `StopStateResolver`: تصنيف حالة كل Stop من `vehicleAlongMeters` وPolicy صريحة.
- `DriverTrackingHub`: يحتفظ ببيانات الرحلة التشغيلية والـderived runtime snapshot، ولا يعيد اختراع منطق الإسقاط أو resolver.

### Policy

- `StopStatePolicy` تُمرر صراحة ولا توجد قيم افتراضية رقمية.
- Stop Eligibility تبقى سياسة مستقلة يمررها المستهلك.
- لا يتم تثبيت threshold جديد لـ`distanceToRouteMeters` في 4.4-A.

### الحالة عند غياب البيانات

- لا توجد Stops → `NextStop = null` وحالات Stops فارغة.
- لا يوجد `vehicleAlongMeters` مقبول → لا يتم اشتقاق NextStop/StopState.
- Stop لا تملك Projection صالحًا أو لا تجتاز Eligibility → لا تدخل في NextStop، وتصنيفها لا يُعامل كحالة تشغيلية صالحة.
- فشل قراءة Stops لا ينهي VehicleTrip ولا يوقف GPS tracking؛ يبقى التكامل بدون Stop-derived data ويجب أن يكون الفشل observable دون كسر الرحلة.

### حدود 4.4-A

- لا Firestore write للمحطات أو Stop State.
- لا إضافة fields جديدة إلى `VehicleTrip`.
- لا تعديل على `RouteProgressTracker` أو `RoutePolylineProjection`.
- لا ETA أو dwell time.
- لا Mapbox أو `driver_map_tab.dart`.
- لا self-intersection ambiguity resolution.
- لا تغيير في GPS/Lifecycle architecture.

هذه الخطوة تثبت عقد التكامل فقط؛ التنفيذ البرمجي المحدود يأتي في 4.4-B.

### حالة 4.4-B التنفيذية النهائية ✅

تم إغلاق Runtime Integration على `stage/approved-route-line-vehicle-link-v1`.

### ما تم تثبيته

1. تحميل Fixed Stops مرة واحدة عند bind/restore من:
   `plannedRoutes/{routeId}/stops`
   عبر `PlannedRouteStopService`.
2. تخزين Stops محليًا في `DriverTrackingHub` مع حماية `tripId/routeId`.
3. إنشاء `StopRuntimePolicy` كمصدر مركزي للسياسة التشغيلية.
4. السياسة الإنتاجية الحالية:
   - `stopEligibilityDistanceMeters = 75m`.
   - `atStopRadius = 30m`.
   - `approachingDistance = 200m`.
5. حقن السياسة صراحةً عند بدء واستعادة `VehicleTrip`.
6. تحديث `StopRuntimeSnapshot` تلقائيًا بعد كل `RouteProgress` مقبول.
7. إعادة اشتقاق الـSnapshot عند اكتمال تحميل Stops إذا كان هناك `accepted RouteProgress` متاح.
8. عدم إدخال Firestore reads في GPS callback وعدم إضافة Firestore writes لـStop State.

### حدود التكامل

- `StopStateResolver` و`NextStopResolver` بقيَا policy/domain services مستقلة.
- `DriverTrackingHub` يستهلك السياسة والنتائج المشتقة ولا يعيد تنفيذ منطق Projection أو Resolution.
- لم يتم تعديل `driver_map_tab.dart`.
- لم يتم تعديل `DriverTrackingLifecycle`.
- لم يتم تعديل `RouteProgressTracker` أو `RoutePolylineProjection`.
- لم تتم إضافة fields جديدة إلى `VehicleTrip`.
- الـStop Runtime Snapshot يبقى in-memory derived data.

### دليل التحقق

- `flutter analyze` بعد Patch التنظيف → **No issues found!**
- focused Hub tests → **15/15**
- full `flutter test` → **192/192**
- PR #37 — Stop Runtime Policy → merged.
- PR #38 — automatic runtime refresh → merged.
- PR #39 — unused import cleanup → merged.
- الفرع التطويري الحالي بعد PR #41 عند merge commit:
  `08f442cedf71d4eef7e691a801c859b455c21d77`.

### فجوات Evidence المتبقية

- **Firestore failure integration test:** 🟡 غير موجود كاختبار تكاملي مستقل يحقن فشل `fetchStops()` ويثبت آليًا استمرار `VehicleTrip` وGPS. الكود الإنتاجي يعالج الفشل عبر `try/catch` دون قطع الرحلة أو التتبع، لذلك هذه فجوة Evidence وليست Bug.
- **Field acceptance:** 🟡 مؤجل لعدم توفر إمكانية تحريك الحافلة فعليًا. الاختبارات الحالية deterministic/synthetic.
- **UI presentation:** ⏭ خارج نطاق Phase 4؛ الـStop Runtime Snapshot حاليًا derived in-memory runtime data.
- قيم `75m / 30m / 200m` هي engineering baseline مركزية في `StopRuntimePolicy` وقابلة للمعايرة لاحقًا بناءً على evidence ميداني؛ ليست قيمًا ميدانية نهائية مثبتة.

### الهدف التشغيلي

```text
Active VehicleTrip
+
Approved PlannedRoute
+
Accepted RouteProgress
+
Loaded Fixed Stops
+
StopRuntimePolicy
      ↓
Local StopRuntimeSnapshot
      ↓
NextStop + StopState
```

المسار الذي لا يحتوي Stops ثابتة يبقى صالحًا؛ في هذه الحالة تكون بيانات Stop-derived فارغة أو غير متاحة، بينما تستمر VehicleTrip/GPS tracking بشكل طبيعي.

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
### 5.1 — ETA Contract + Deterministic Engine ✅

**الحالة:** DESIGN FROZEN + IMPLEMENTED + VERIFIED.

تم تنفيذ baseline حتمي مستقل يعتمد فقط على vehicleAlongMeters وtargetAlongMeters وspeedMps، مع حفظ observedAt كما ورد من المصدر. لا يستخدم المحرك DateTime.now()؛ Freshness مسؤولية Integration Layer.

Validation المثبتة:
- vehicleAlongMeters وtargetAlongMeters يجب أن يكونا finite و>= 0.
- targetAlongMeters <= vehicleAlongMeters → targetNotAhead.
- speedMps = NaN أو ±Infinity → invalidSpeed.
- speedMps <= 0 → nonPositiveSpeed.

الحساب الوحيد:
- distanceAheadMeters = targetAlongMeters - vehicleAlongMeters.
- etaSeconds = distanceAheadMeters / speedMps.

لا fallback speed، ولا buffer، ولا rounding، ولا max cap، ولا traffic factor، ولا dwell time، ولا historical correction، ولا ML.

الـEngine لا يعرف GPS أو Firestore أو Flutter UI أو Mapbox أو DriverTrackingHub أو DriverTrackingLifecycle أو VehicleTrip أو StopRuntimeSnapshot أو system clock.

الملفات المضافة:
- lib/models/eta_input.dart
- lib/models/eta_result.dart
- lib/models/eta_status.dart
- lib/models/eta_unavailable_reason.dart
- lib/services/eta_engine.dart
- test/eta_engine_test.dart

الحدود: لم يتم تعديل RouteProgressTracker أو DriverTrackingHub أو DriverTrackingLifecycle أو VehicleTrip أو Firestore أو StopRuntime أو Passenger أو driverPublic أو EtaUtils أو UI.

دليل التحقق المحلي:
- flutter analyze → **No issues found!**
- flutter test test/eta_engine_test.dart → **16/16 passed**.
- flutter test الكامل → **208/208 passed**.

هذه الخطوة مغلقة ولا يعاد فتحها إلا عند ظهور Regression أو دليل جديد.

### 5.2-A — Accepted ETA Observation Bridge ✅

**الحالة:** IMPLEMENTED + VERIFIED + CLOSED.

تم تنفيذ أول ربط محدود بين طبقة GPS/RouteProgress وطبقة ETA دون إدخال حساب ETA نفسه في الـHub.

### العقد المثبت

```text
Accepted GPS sample
        ↓
RouteProgressTracker
        ↓
Accepted RouteProgress
        +
Speed
+
ObservedAt
        ↓
AcceptedEtaObservation
```

`AcceptedEtaObservation` يحمل فقط:
- `acceptedRouteProgress`.
- `speedMps`.
- `observedAt`.

### قاعدة القبول

التكامل يميز قبول العينة من خلال تغير حالة `RouteProgressTracker.lastAccepted` بالهوية (`beforeAccepted` مقابل `afterAccepted`).

- العينة المرفوضة التي لا تنشئ Projection مقبولًا جديدًا لا تستبدل الملاحظة الحالية.
- عينة الـbackward jitter التي يقبلها `RouteProgressTracker` رغم تثبيت `alongMeters` عند الموضع المقبول السابق تنشئ Projection جديدًا، ولذلك تستبدل الملاحظة مع الاحتفاظ بـ`speedMps` و`observedAt` من العينة المقبولة الجديدة.
- عند ربط رحلة جديدة أو تغيير `routeId` أو مسح الرحلة يتم تصفير `activeEtaObservation`.

### حدود الـPatch

لم يتم تعديل:
- `RouteProgressTracker`.
- `EtaEngine`.
- `StopRuntime`.
- `Passenger`.
- `Firestore`.
- `EtaUtils`.
- `DriverTrackingLifecycle`.
- أي UI.

ولا توجد Freshness Policy رقمية في هذه الخطوة؛ تحديد freshness يبقى قرار Integration مستقلًا في خطوة لاحقة.

### التحقق

- `flutter analyze` → **No issues found!**.
- focused `driver_tracking_hub_route_progress_test.dart` → **17/17 passed**.
- `flutter test` الكامل → **210/210 passed**.

تمت إضافة حالتي اختبار أساسيتين:
1. العينة المرفوضة لا تستبدل ETA observation السابقة.
2. backward-jitter المقبول يستبدل observation بالسرعة والطابع الزمني الجديدين مع بقاء `alongMeters` monotonic.

هذه الخطوة مغلقة ولا يعاد فتحها إلا عند ظهور Regression أو دليل جديد.

الخطوة التالية: **تصميم Freshness Policy للـETA ضمن Integration Layer فقط**، دون تعديل `EtaEngine` أو إدخال Passenger/UI قبل تثبيت العقد الجديدة.

### 5.2-B — ETA Freshness Policy ✅ CLOSED

**الحالة:** DESIGN FROZEN + IMPLEMENTED + VERIFIED + CLOSED.

تم فصل مفهوم ETA freshness عن سياسات freshness الأخرى الموجودة في المشروع. لا تُعاد استخدام `HistoricalSamplingPolicy.maxPositionAge = 45s` تلقائيًا كـETA threshold؛ فهي evidence لسياسة قبول DriverTrip GPS upstream وليست عقد ETA مستقلة. كذلك لا تُعاد استخدام Heartbeat أو LocationService cache أو Public UI freshness كبديل عن ETA policy.

### العقد المثبت

```text
AcceptedEtaObservation
        ↓
EtaFreshnessPolicy
        ↓
Fresh / Unavailable
        ↓
EtaInput
        ↓
EtaEngine
```

`EtaFreshnessPolicy` مفهوم مستقل وقابل للحقن، ويُلزم المستهلك بتمرير:
- `observedAt`.
- `evaluatedAt`.
- `maxAge`.

ولا توجد قيمة رقمية افتراضية لـ`maxAge` داخل الـPolicy.

### قاعدة الزمن

- `evaluatedAt` هو وقت تقييم صلاحية observation من Integration Layer، وليس وقت وصول callback.
- لا تستخدم الـPolicy `DateTime.now()` داخليًا.
- حساب العمر مفاهيميًا: `age = evaluatedAt - observedAt`.
- `age < 0` → `future` / unavailable.
- `age >= 0 && age <= maxAge` → `fresh`.
- `age > maxAge` → `stale`.

### حدود المسؤولية

- Freshness Policy لا تحسب ETA.
- Freshness Policy لا تنشئ `EtaResult`.
- Integration Layer هي التي تمنع إنشاء `EtaInput` عندما تكون observation غير صالحة.
- `EtaEngine` يبقى مستقلًا عن clock وGPS وfreshness.
- `speedMps` و`acceptedRouteProgress` و`observedAt` تعامل كوحدة observation واحدة؛ لا يوجد فصل مصطنع بين freshness للموقع وfreshness للسرعة.

### اختبارات العقد المخططة قبل التنفيذ

يجب لاحقًا إثبات:
- `observedAt == evaluatedAt` → `fresh`.
- العمر قبل `maxAge` → `fresh`.
- العمر عند `maxAge` → `fresh`.
- العمر بعد `maxAge` → `stale`.
- `observedAt > evaluatedAt` → `future` / unavailable.
- نفس المدخلات → نفس النتيجة.

لا تثبت هذه الخطوة أي رقم لـ`maxAge`، ولا تُدخل 45 ثانية كـimplicit ETA constant.

تم تنفيذ `EtaFreshnessPolicy` واختبارها بشكل مستقل دون تعديل `AcceptedEtaObservation` أو `RouteProgressTracker` أو `DriverTrackingHub` أو `EtaEngine` أو StopRuntime أو Passenger/UI أو Firestore أو `EtaUtils`.

### التنفيذ والتحقق

- `EtaFreshnessPolicy.maxAge` مطلوب صراحةً ولا توجد قيمة افتراضية أو implicit ETA threshold.
- لا تستخدم الـPolicy `DateTime.now()`؛ `evaluatedAt` يُمرر صراحةً من المستهلك.
- حالات العقد المثبتة: `future`, `fresh`, `stale`.
- اختبارات focused: `test/eta_freshness_policy_test.dart` → **6/6 passed**.
- `flutter analyze` → **No issues found!**.
- `flutter test` الكامل → **216/216 passed**.
- لا يمثل `HistoricalSamplingPolicy.maxPositionAge = 45s` أي قيمة داخل ETA Policy.

هذه الخطوة مغلقة ولا يعاد فتحها إلا عند ظهور Regression أو دليل جديد.

الخطوة التالية: تصميم/مراجعة أول Integration لتكوين `EtaInput` من `AcceptedEtaObservation` بعد اجتياز freshness gate، دون تعديل `EtaEngine` نفسه قبل تثبيت ذلك العقد.

### 5.2-C — EtaInput Builder Integration ✅ CLOSED

**الحالة:** DESIGN FROZEN + IMPLEMENTED + VERIFIED + CLOSED.

تم تنفيذ مكوّن Integration مستقل وصغير يحوّل البيانات التشغيلية المقبولة إلى `EtaInput` فقط بعد اجتياز Freshness Gate ووجود NextStop صالح.

### العقد المثبت

```text
AcceptedEtaObservation
        +
EtaFreshnessPolicy
        +
StopRuntimeSnapshot
        +
explicit evaluatedAt
        ↓
EtaInputBuilder
        ↓
EtaInput?
        ↓
EtaEngine
```

### قواعد التحويل

- يتم تقييم freshness أولًا باستخدام `observedAt` و`evaluatedAt` والـPolicy المحقونة.
- `stale` أو `future` → لا يتم إنشاء `EtaInput`.
- غياب `nextStop` → لا يتم إنشاء `EtaInput`.
- `vehicleAlongMeters` يؤخذ مباشرةً من `AcceptedEtaObservation.acceptedRouteProgress.alongMeters`.
- `targetAlongMeters` يؤخذ مباشرةً من `StopRuntimeSnapshot.nextStop.projection.alongMeters`.
- `speedMps` و`observedAt` يؤخذان مباشرةً من `AcceptedEtaObservation`.
- لا يعيد الـBuilder اشتقاق `targetNotAhead` ولا يعيد تنفيذ أي منطق من `EtaEngine`.
- لا يستخدم الـBuilder `DateTime.now()` ولا يختار قيمة لـ`maxAge`.

### حدود الـPatch

تم تعديل/إضافة:
- `lib/services/eta_input_builder.dart`.
- `test/eta_input_builder_test.dart`.

لم يتم تعديل:
- `EtaEngine`.
- `AcceptedEtaObservation`.
- `EtaFreshnessPolicy`.
- `RouteProgressTracker`.
- `DriverTrackingHub`.
- `StopRuntime`.
- `Passenger/UI`.
- `Firestore`.
- `EtaUtils`.

### دليل التحقق المحلي

- `flutter analyze` → **No issues found!**.
- focused `test/eta_input_builder_test.dart` → **9/9 passed**.
- `flutter test` الكامل → **225/225 passed**.

تمت تغطية Fresh / stale / future / no NextStop، ومطابقة كل حقل في `EtaInput` مع مصدره الصحيح، والحفاظ على `observedAt`، والحتمية عند تكرار المدخلات.

هذه الخطوة مغلقة ولا يعاد فتحها إلا عند ظهور Regression أو دليل جديد.

الخطوة التالية: تصميم طريقة استدعاء ETA في Integration Runtime بعد تكوين `EtaInput`، دون تعديل `EtaEngine` نفسه قبل تثبيت عقد الاستدعاء.

### 5.2-D — ETA Runtime Invocation ✅ CLOSED

**الحالة:** DESIGN FROZEN + IMPLEMENTED + VERIFIED + CLOSED.

تم تنفيذ مكوّن Integration Runtime صغير ومستقل ينسّق بين `AcceptedEtaObservation` و`StopRuntimeSnapshot` و`EtaFreshnessPolicy` و`EtaInputBuilder` و`EtaEngine` دون إدخال ETA في `DriverTrackingHub` أو Passenger/UI.

### العقد التنفيذي المثبت

المخرج العام للمكوّن هو:

`EtaResult?`

والسلوك محدد كالتالي:

- غياب `AcceptedEtaObservation` → `null`، ولا يتم استدعاء `EtaEngine`.
- غياب `StopRuntimeSnapshot` → `null`، ولا يتم استدعاء `EtaEngine`.
- إذا رفض `EtaInputBuilder` observation بسبب `stale` أو `future` أو غياب `nextStop` → `null`، ولا يتم استدعاء `EtaEngine`.
- إذا أعاد `EtaInputBuilder` كائن `EtaInput` → يتم استدعاء `EtaEngine.calculate()` وتُعاد نتيجة المحرك نفسها كما هي.
- يمكن أن تكون نتيجة المحرك `available` أو `unavailable` وفق عقد ETA Domain.

### التدفق التنفيذي

```text
AcceptedEtaObservation
        +
StopRuntimeSnapshot
        +
EtaFreshnessPolicy
        +
evaluatedAt
        ↓
EtaInputBuilder
        ↓
EtaInput?
   ├── null → EtaResult? = null
   │          └→ لا يُستدعى EtaEngine
   ↓
EtaEngine.calculate(EtaInput)
        ↓
EtaResult
```

### متى يتم التقييم؟

- عند وصول `AcceptedEtaObservation` جديدة مقبولة فعلًا.
- عند توفر/تغيّر `StopRuntimeSnapshot` أو `nextStop`.
- يمكن لمستهلك Integration Runtime طلب evaluation صراحةً باستخدام أحدث state.
- العينة المرفوضة التي لا تستبدل observation لا تتطلب إعادة حساب ETA من هذا المسار.

### evaluatedAt

- `evaluatedAt` يُمرر صراحةً من مستدعي Runtime.
- يمثل لحظة طلب/تنفيذ التقييم.
- لا يُستمد من `observedAt` أو وقت Firestore أو وقت استقبال callback.
- لا توجد `DateTime.now()` مخفية داخل `EtaRuntimeInvocation` أو `EtaInputBuilder` أو `EtaFreshnessPolicy` أو `EtaEngine`.

### التمييز بين حالات عدم التوفر

- `EtaInputBuilder == null` → لم تتكوّن مدخلات ETA، وبالتالي لا يبدأ الحساب أصلًا.
- `EtaEngine → EtaResult.unavailable` → تكوّنت `EtaInput` ووصلت إلى المحرك، لكن Domain validation رفضتها، مثل `targetNotAhead` أو `invalidSpeed` أو `nonPositiveSpeed`.
- لا يتم دمج الحالتين في `EtaUnavailableReason` جديدة.

### تغيّر NextStop

- كل evaluation يستخدم `StopRuntimeSnapshot` الحالي.
- تغيّر `nextStop` يؤدي إلى تكوين `EtaInput` جديد في التقييم التالي.
- لا تُعاد استخدام ETA قديمة مع target قديم.
- `nextStop == null` يؤدي إلى `EtaResult? = null` دون استدعاء المحرك.

### حدود الـPatch

تمت إضافة:
- `lib/services/eta_runtime_invocation.dart`
- `test/eta_runtime_invocation_test.dart`

لم يتم تعديل:
- `EtaEngine`
- `AcceptedEtaObservation`
- `EtaFreshnessPolicy`
- `EtaInputBuilder`
- `DriverTrackingHub`
- `RouteProgressTracker`
- `StopRuntime`
- Passenger/UI
- `Firestore`
- `EtaUtils`

### دليل التحقق المحلي النهائي

- `flutter analyze` → **No issues found!**
- focused `test/eta_runtime_invocation_test.dart` → **9/9 passed**.
- `flutter test` الكامل → **234/234 passed**.

كما أُزيلت fixture اختبارية غير مستخدمة بعد التحقق الأولي، وأُعيد تشغيل `flutter analyze` والاختبارات بعد التنظيف.

هذه الخطوة مغلقة ولا يعاد فتحها إلا عند ظهور Regression أو دليل جديد.

**الخطوة التالية:** اختيار المستهلك التنفيذي الواحد لـ`EtaResult?` وتثبيت عقده قبل أي Production Patch.


### 5.2-E — ETA Result Consumption ✅ DESIGN FROZEN

**الحالة:** DESIGN FROZEN ONLY — لا Production Code في هذه الخطوة.

تم تثبيت عقد استهلاك `EtaResult?` بعد اكتمال `EtaRuntimeInvocation`. الهدف هنا هو تحديد كيف تتعامل طبقة لاحقة مع نتيجة ETA دون إنشاء عقد بديل أو إدخال ETA في `DriverTrackingHub` أو Passenger/UI.

### العقد الأساسي

يبقى `EtaResult?` هو **العقد القياسي للمخرج** من ETA Runtime إلى المستهلك اللاحق.

لا يتم إنشاء Wrapper جديد مثل `EtaViewModel` أو `EtaRuntimeState` داخل هذه الخطوة، ولا تتم إعادة حساب ETA بعد خروج النتيجة من `EtaRuntimeInvocation`.

```text
EtaRuntimeInvocation
        ↓
EtaResult?
        ↓
Consumer
```

### دلالات المخرج

#### `EtaResult == null`

تعني أن تقييم Runtime لم ينتج `EtaInput` صالحًا، ولذلك لم يبدأ `EtaEngine` أصلًا.

الأسباب الداخلة ضمن هذا المسار:
- غياب `AcceptedEtaObservation`.
- غياب `StopRuntimeSnapshot`.
- observation غير صالحة من ناحية Freshness: `stale` أو `future`.
- غياب `nextStop`.

المستهلك يجب ألا يحول `null` إلى `EtaUnavailableReason` جديدة، وألا يخترع ETA بديلة.

#### `EtaResult.status == available`

المستهلك يستعمل القيم كما خرجت من المحرك:
- `etaSeconds`.
- `distanceAheadMeters`.
- `observedAt`.

لا يعيد المستهلك حساب المسافة أو ETA من GPS أو Stop أو speed.

#### `EtaResult.status == unavailable`

المستهلك يحافظ على النتيجة غير المتاحة وسببها:
- `unavailableReason`.

ولا يحولها تلقائيًا إلى قيمة ETA تقديرية، ولا يستعمل fallback speed.

### Freshness عند الاستهلاك

- `observedAt` في `EtaResult` هو وقت observation الأصلية، وليس وقت استهلاك النتيجة.
- صلاحية freshness تمتلكها مرحلة Runtime أثناء التقييم.
- لا يجوز للمستهلك أن يستنتج من `observedAt` وحده أن النتيجة ما تزال fresh الآن.
- لا يستخدم Consumer `DateTime.now()` لإعادة تفسير العقد الحالية.
- إذا احتجنا Freshness عند العرض/الاستخدام الفعلي لاحقًا، فهذا عقد مستقل يجب تصميمه صراحةً ولا يُضاف ضمن هذه الخطوة.

### قواعد الاستهلاك

- النتيجة الخارجة من Runtime تُستهلك كما هي؛ لا تعديل على قيم `EtaResult`.
- لا استدعاء ثانٍ لـ`EtaEngine` من Consumer.
- لا قراءة مباشرة لـGPS أو `RouteProgressTracker` أو `StopRuntime` أو Firestore للحصول على ETA بديلة.
- لا استخدام `EtaUtils` القديم لإعادة بناء ETA عند توفر/عدم توفر `EtaResult`.
- لا تنسيق نصي للـETA داخل عقد Domain/Runtime؛ التحويل إلى دقائق أو نص عرض يخص طبقة Presentation عندما تُصمم لاحقًا.
- لا Persistence لـ`EtaResult` داخل Firestore في هذه الخطوة.

### إعادة الاستخدام وتغيّر النتيجة

- كل `EtaResult` مرتبط بالمدخلات التي أنتجته في ذلك التقييم، وبخاصة `observedAt` وtarget الحالي.
- عند تنفيذ تقييم جديد، النتيجة الجديدة هي نتيجة التقييم الحالي؛ لا يعاد استخدام ETA قديمة مع target جديد.
- إذا أعاد التقييم `null`، لا يجوز للمستهلك الاحتفاظ تلقائيًا بـETA السابقة على أنها نتيجة صالحة للتقييم الحالي.
- العينة المرفوضة التي لا تطلب evaluation جديدة لا تنشئ نتيجة جديدة؛ لذلك لا يترتب عليها تغيير في هذا العقد بحد ذاته.

### حدود 5.2-E

ممنوع في هذه الخطوة:
- تعديل `EtaRuntimeInvocation`.
- تعديل `EtaEngine`.
- تعديل `EtaInputBuilder`.
- تعديل `EtaFreshnessPolicy`.
- تعديل `AcceptedEtaObservation`.
- تعديل `DriverTrackingHub`.
- تعديل `RouteProgressTracker` أو StopRuntime.
- تعديل Passenger/UI أو `ActiveTripBanner`.
- تعديل `EtaUtils`.
- إضافة Firestore reads/writes لمسار ETA.
- إضافة cache أو persistence أو scheduler.
- تثبيت Freshness Policy ثانية للعرض.

### قرار الانتقال

العقد التالي التنفيذي، عندما يحين دوره، يجب أن يختار **مستهلكًا واحدًا واضح المسؤولية** لـ`EtaResult?` ويبني عليه Patch صغيرًا، دون إدخال طبقة العرض أو `DriverTrackingHub` إلا إذا أثبتت المتطلبات أن ذلك هو المستهلك المقصود.

هذه النقطة مغلقة كتصميم فقط حتى يتم تنفيذ المستهلك المحدد لاحقًا.

---

# 9. Phase 6 — BusWatch

## الهدف

تمكين الراكب من مراقبة رحلة فعلية عبر **Operational Read Model للقراءة فقط**، مع إبقاء ETA وStop Runtime وPresentation كطبقات مستقلة.

```text
Passenger Trip
      ↓
driverId / passenger context
      ↓
Active VehicleTrip
      +
Public Live Location
      +
Approved PlannedRoute
      ↓
BusWatch Operational Snapshot
      ↓
BusWatch Consumer لاحقًا
```

**Read-only بالكامل.** الراكب لا يعدّل `VehicleTrip` أو `PlannedRoute` أو `driverPublic`.

### 6-A — BusWatch Operational Read Model ✅ IMPLEMENTED & VERIFIED

**الحالة:** IMPLEMENTED & VERIFIED ✅ — العقد منفذ ومثبت بالاختبارات.

تم تثبيت عقد قراءة موحدة **immutable snapshot** لرحلة Passenger محددة، دون إنشاء state طويل العمر داخل Service ودون إدخال ETA/NextStop/Stop Runtime في الـRead Model.

### اختيار Passenger Context

- الـRead Model يعمل على **Passenger Trip محددة**، وليس على `passengerId` وحده، لتجنب اختيار رحلة عشوائية عند وجود أكثر من رحلة مفتوحة.
- `passengerTripId` هو معرف السياق الذي اختاره المستهلك الأعلى؛ لا يقرر الـRead Model من تلقاء نفسه أي رحلة هو الأنسب.
- `TripModel.driverId` هو الرابط الحالي بين رحلة الراكب والسائق.
- لا تتم إضافة `vehicleTripId` إلى `TripModel` في 6-A.

### تحديد Operational VehicleTrip

- بعد وجود Passenger Trip صالحة، يتم البحث عن `VehicleTrip` نشطة لنفس `driverId`.
- مصدر العملية الحالي الموجود هو `VehicleTripService.findActiveTripForDriver(driverId)`.
- العقد يفترض invariant وجود VehicleTrip تشغيلية نشطة واحدة كحد أقصى للسائق؛ لا يتم اختيار واحدة من عدة رحلات على أساس ترتيب عشوائي.
- غياب VehicleTrip نشطة لا يعني أن Passenger Trip أُلغيت أو انتهت؛ يعني فقط أنه لا توجد Operational Trip متاحة للمراقبة في هذه اللحظة.
- حالة Passenger Trip وحالة VehicleTrip تبقيان حقلي حالة مستقلين؛ لا توجد مساواة ضمنية بينهما.

### مصادر الحقول

| الحقل | المصدر السلطوي | ملاحظة |
|---|---|---|
| `passengerTripId` | Passenger Trip context | هوية السياق فقط، ولا يختار الـReader الرحلة |
| `vehicleTripId` | `VehicleTrip.id` | معرف الرحلة التشغيلية |
| `driverId` | `TripModel.driverId` مع مطابقة `VehicleTrip.driverId` | الرابط بين السياقين |
| `busNumber` | `VehicleTrip.busNumber` | هوية المركبة التشغيلية |
| `routeId` | `VehicleTrip.routeId` | المعرف السلطوي للمسار |
| `direction` | `VehicleTrip.direction` | القيمة التشغيلية outbound/return |
| `status` | `VehicleTrip.status` | يجب أن تكون `active` للنتيجة التشغيلية |
| `liveLocation` | `driverPublic` | المصدر العام للـlive position |
| `speed` | `driverPublic` | قيمة الحالة العامة الحالية |
| `heading` | `driverPublic` | قيمة الحالة العامة الحالية |
| `lastLocationAt` | `driverPublic.locationUpdatedAt` | وقت الموقع العام، وليس `Eta observedAt` |
| `routeProgress` | `VehicleTrip.routeProgress` | operational field فقط، وليس `AcceptedEtaObservation` |
| `approvedRoute` | `plannedRoutes/{routeId}` | يجب أن تكون Approved مع Geometry صالحة |

لا يتم في 6-A افتراض أن `VehicleTrip.currentLocation + speed + lastLocationAt + routeProgress` تساوي `AcceptedEtaObservation`.

### Route Reference

- يتم حل المسار من `plannedRoutes/{routeId}` باستخدام `VehicleTrip.routeId` نفسه.
- لا يستخدم 6-A `lineName + direction` كبديل عن `routeId` عندما نحتاج المسار المقابل للرحلة التشغيلية.
- لا يستخدم `routeCatalog` كمصدر للهندسة التشغيلية.
- حالة المسار المطلوبة لقراءة تشغيلية مكتملة: `status == approved` مع Geometry صالحة (`points.length >= 2`).
- عدم توفر helper حالي للقراءة exact-by-id داخل `RoutePlanService` هو **ملاحظة تنفيذية** للـReader المستقبلي، وليس سببًا لإضافة lookup بديل الآن.

### Live Location Boundary

- `driverPublic` هو المصدر العام لموقع السائق الذي سيستهلكه BusWatch.
- غياب وثيقة عامة، أو غياب إحداثيات صالحة، يعني `No Live Location`.
- لا يوجد fallback تلقائي من `VehicleTrip.currentLocation` إلى `driverPublic` داخل العقد؛ لا نخلط مصدرين عام/تشغيلي في حقل واحد.
- freshness الرقمية لموقع BusWatch ليست جزءًا من 6-A. `lastLocationAt` يمرر كما هو، وأي Freshness Policy للعرض أو المراقبة يجب أن تكون عقدًا مستقلاً لاحقًا.

### Stops Boundary

- `Stops` ليست جزءًا من `BusWatchOperationalSnapshot` في 6-A.
- `No Stops` لا يُسقط الـOperational snapshot الأساسي إذا كانت VehicleTrip وLive Location وApproved Route متوفرة.
- Fixed Stops و`StopRuntimeSnapshot` تبقيان ضمن عقود Phase 4، ويُصمم استهلاكهما لاحقًا دون دمجهما في هذا Read Model.
- لا يتم إدخال `NextStop` أو Stop State أو ETA في هذه المرحلة.

### نتيجة القراءة وحالات الغياب

تم اختيار **Result Object immutable typed** مع حالة واحدة حاسمة، بدل مجموعة booleans أو `nullable snapshot` فقط:

```text
BusWatchOperationalReadResult
   ├── status
   └── snapshot?
```

والحالة المسموح بها تكون قيمة واحدة فقط من:

```dart
enum BusWatchOperationalReadStatus {
  available,
  noPassengerContext,
  noActiveVehicleTrip,
  noLiveLocation,
  noApprovedRoute,
}
```

القواعد:
- `available` يتطلب Passenger Context صالحًا + Active VehicleTrip + Live Location عامة صالحة + Approved PlannedRoute صالحة، وعندها فقط يكون `snapshot != null`.
- أي حالة غير `available` يكون معها `snapshot == null`.
- `noPassengerContext` يعني عدم وجود Passenger Trip محددة/صالحة ضمن سياق BusWatch.
- `noActiveVehicleTrip` يعني وجود Passenger Context مع عدم وجود VehicleTrip تشغيلية نشطة مقابلة.
- `noLiveLocation` يعني أن VehicleTrip موجودة لكن `driverPublic` لا يوفر موقعًا عامًا صالحًا.
- `noApprovedRoute` يعني أن VehicleTrip تحمل `routeId` لكن المسار المرجعي غير موجود، غير معتمد، أو Geometry غير صالحة.
- `No Stops` ليست حالة فشل أعلى للـOperational Read Model؛ هي غياب تابع يُعالج في Stop Runtime لاحقًا.
- لا يتم تحويل أخطاء Firestore/الشبكة إلى واحدة من حالات الغياب؛ أخطاء البنية التحتية تبقى أخطاء تنفيذية منفصلة وتنتقل للمستدعي.

### حدود 6-A

ممنوع في هذه الخطوة:
- تعديل `TripModel` لإضافة `vehicleTripId`.
- تعديل `VehicleTrip` أو `VehicleTripService`.
- تعديل `driverPublic` schema.
- تعديل `DriverTrackingHub`.
- تعديل `EtaRuntimeInvocation` أو `EtaEngine` أو `EtaInputBuilder` أو `EtaFreshnessPolicy`.
- دمج Passenger/UI أو `ActiveTripBanner`.
- إضافة ETA أو `EtaResult` إلى الـsnapshot.
- إضافة `NextStop` أو `StopRuntimeSnapshot` إلى الـsnapshot.
- إضافة cache أو scheduler أو stream طويل العمر داخل الـRead Model.
- الاحتفاظ بأي mutable state بين استدعاءات `read(...)`.
- إضافة Firestore writes.

### القرار

6-A مكتملة ومثبتة. تم تنفيذ `BusWatchOperationalReader` مستقل، بلا state داخلي أو Stream lifecycle طويل العمر، ويعيد `BusWatchOperationalReadResult` بصيغة `status + snapshot?`. تم التحقق من حالات `available` والغياب الأربع، ومطابقة driverId، والقراءة exact-by-routeId، وبقاء `VehicleTrip.routeProgress` كبيانات تشغيلية فقط. لا تم تعديل الطبقات المحمية.

### Evidence

- `flutter analyze` — No issues found.
- `flutter test test/bus_watch_operational_reader_test.dart` — **14/14 passed**.
- `flutter test` — **248/248 passed**.
- `git status` — working tree clean.
- UI/Consumer integration ليست ضمن 6-A، ولا تُعد جزءًا من دليل إغلاق هذه المرحلة.

### 6-B — BusWatch Read Consistency & Refresh Contract ✅ DESIGN FROZEN

**الحالة:** DESIGN FROZEN — لا Production Code أو Reader/Consumer refresh implementation في هذه الخطوة.

### الهدف

تحديد عقد تنسيق القراءات المتعددة التي تدخل في BusWatch، بحيث تكون النتيجة المعروضة للمستهلك متسقة دلاليًا، مع عدم الادعاء بوجود transaction ذري بين Collections مختلفة.

### نطاق 6-B

- تحديد ترتيب الاعتماد بين القراءات:
  `Passenger Trip`
  ثم `Active VehicleTrip`
  ثم `driverPublic`
  ثم `plannedRoutes/{routeId}`.
- تثبيت أن الـConsumer لا يختار رحلة أخرى أثناء القراءة، ولا يغير `passengerTripId` ضمن نفس الاستدعاء.
- التحقق النهائي من تطابق الهويات قبل إرجاع نتيجة تشغيلية:
  - `TripModel.driverId == VehicleTrip.driverId`
  - `driverPublic.driverId == VehicleTrip.driverId`
  - `PlannedRoute.id == VehicleTrip.routeId`
  - `VehicleTrip.status == active`
  - `PlannedRoute.status == approved`
  - Geometry صالحة.
- تحديد أن القراءة متعددة المصادر **best-effort coordinated read** وليست Firestore transaction؛ لا يوجد ادعاء أن المصادر الأربع تم التقاطها في لحظة زمنية ذرية واحدة.
- تحديد أن الاستدعاء الواحد ينتج نتيجة واحدة فقط؛ لا يتم خلط نتائج استدعاء سابق مع الاستدعاء الحالي.
- عند اكتشاف عدم اتساق بين المصادر، لا يُعاد بناء snapshot جزئي ولا يتم اختيار مصدر بديل تلقائيًا.
- لا توجد Freshness Threshold رقمية جديدة في 6-B؛ أزمنة المصادر تمرر كما هي، وأي سياسة freshness مستقلة تأتي بعقد منفصل لاحقًا.
- Refresh frequency ليست من مسؤولية Read Model؛ المستدعي الأعلى يقرر متى يعيد `read(...)`.

### حالات الاتساق

```text
Coordinated Read
      ↓
Identity / Status / Geometry Validation
      ↓
Consistent → BusWatchOperationalReadResult.available
Inconsistent → one explicit non-available result
```

لا يتم تعريف حالة فشل جديدة إذا كان عدم الاتساق يؤدي بوضوح إلى إحدى الحالات الموجودة في 6-A؛ تتم المحافظة على الحالات الخمس نفسها.

### حدود 6-B

ممنوع في هذه الخطوة:

- تعديل `BusWatchOperationalReader` أو `BusWatchOperationalReadResult` للإضافة التشغيلية.
- إضافة Stream أو listener أو scheduler أو timer.
- إضافة cache أو retained state.
- إضافة transaction أو batch write بغرض تنسيق القراءة.
- إضافة Firestore writes.
- إضافة numerical freshness policy.
- إدخال ETA أو `EtaResult`.
- إدخال NextStop أو `StopRuntimeSnapshot`.
- دمج Passenger/UI أو `ActiveTripBanner`.
- تعديل `TripModel` أو `VehicleTrip` أو `driverPublic` schema أو `DriverTrackingHub`.

### القرار

6-B مجمدة كعقد تصميم مستقل ✅. العقد الحالي يقرر **كيفية تنسيق القراءة والاتساق فقط**؛ ولا يضيف lifecycle أو timing policy إلى BusWatch Operational Read Model. أي تنفيذ لاحق لـrefresh أو consumer behavior يحتاج نقطة تصميم/تنفيذ مستقلة ولا يعيد فتح 6-A.
 
### 6-C — Passenger BusWatch Consumer Contract ✅ IMPLEMENTED & VERIFIED

**الحالة:** IMPLEMENTED & VERIFIED ✅ — Consumer مستقل مع اختبارات focused، دون UI integration.

### الهدف

تحديد عقد استهلاك `BusWatchOperationalReadResult` داخل سياق Passenger محدد، مع الفصل الصريح بين **Passenger Trip Context** وبين **Operational Read Result**، ومنع الاحتفاظ ببيانات تشغيلية قديمة عند تغير النتيجة الحالية.

### مسار الاستهلاك

```text
Passenger Trip Context
        ↓
exact tripId
        ↓
BusWatchOperationalReader.read(tripId)
        ↓
exactly one BusWatchOperationalReadResult
        ↓
Passenger BusWatch Consumer
```

### قواعد Consumer

1. **رحلة واحدة محددة**
   - الـConsumer يستقبل `tripId` من Passenger Trip Context الأعلى.
   - لا يبحث عن Trips من تلقاء نفسه.
   - لا يستخدم ترتيبًا مثل `list.first`.
   - لا يبدل `tripId` إلى رحلة بديلة أثناء نفس السياق.

2. **نتيجة واحدة سلطوية**
   - كل قراءة مكتملة تنتج `BusWatchOperationalReadResult` واحدة.
   - النتيجة الجديدة تستبدل النتيجة السابقة في حالة الـConsumer.
   - لا يتم دمج نتائج قراءات مختلفة.

3. **قاعدة منع البيانات القديمة**
   - **New Result replaces previous Consumer state.**
   - **A non-available result must clear any previously available operational snapshot.**
   - لا يجوز استخدام snapshot سابق كـfallback عندما تصبح القراءة الحالية غير متاحة.
   - الـConsumer لا يتحول إلى cache غير معلن.

4. **عدم إعادة تفسير statuses**
   - `noActiveVehicleTrip` تعني وجود Passenger Trip ولكن لا توجد VehicleTrip تشغيلية نشطة مقابلة حاليًا.
   - لا تُفسر هذه الحالة على أنها إلغاء للرحلة، انتهاء الرحلة، أو offline للسائق.
   - `noLiveLocation` لا تتحول إلى `noActiveVehicleTrip`، ولا يُستخدم `VehicleTrip.currentLocation` كـfallback.
   - `noApprovedRoute` تعني فشل توفر المسار المرجعي التشغيلي المطلوب، ولا يعاد اختيار Route أخرى.
   - `available` فقط تسمح باستهلاك snapshot.

5. **available**
   - `status == available` و`snapshot != null`.
   - الـConsumer يستهلك الـsnapshot كما هو.
   - لا يعيد اشتقاق أو تعديل `routeProgress` أو الموقع أو السرعة أو الاتجاه أو هوية المسار.

6. **non-available**
   - جميع الحالات غير `available` يكون معها `snapshot == null`.
   - الـConsumer يمسح أي operational snapshot سابق فور اعتماد النتيجة الحالية.
   - لا يُنشئ snapshot اصطناعيًا ولا يعيد استخدام بيانات قديمة.

### معنى noPassengerContext

`noPassengerContext` هي **حالة سياق أعلى** وليست آلية للبحث عن رحلة.

- تعني عدم وجود Passenger Trip Context صالح لبدء BusWatch.
- Consumer لا يختار Trip.
- Consumer لا ينفذ lookup بديل.
- عند استدعاء `read(tripId)` بمعرف محدد وصالح، لا يكون `noPassengerContext` هو المسار الطبيعي لغياب Vehicle/Live/Route؛ تلك الحالات لها statuses مستقلة.

### أخطاء البنية التحتية

```text
Domain Result
   ≠
Infrastructure Error
```

- أخطاء Firestore أو الشبكة لا يعاد تفسيرها كـ`noActiveVehicleTrip` أو `noLiveLocation` أو `noApprovedRoute`.
- الـConsumer لا ينشئ Domain Result بديلًا لإخفاء Infrastructure Error.

### حدود 6-C

ممنوع في هذه الخطوة:

- تنفيذ Consumer أو UI integration.
- تعديل `BusWatchOperationalReader`.
- تعديل `BusWatchOperationalReadResult` أو `BusWatchOperationalSnapshot` إلا إذا ثبت تضارب عقدي لاحقًا.
- اختيار Trips تلقائيًا أو استخدام `list.first`.
- الاحتفاظ بـsnapshot سابق كـfallback.
- إضافة cache أو scheduler أو timer.
- إضافة Stream/listener lifecycle.
- إضافة freshness policy.
- إدخال ETA أو `EtaResult`.
- إدخال NextStop أو `StopRuntimeSnapshot`.
- تعديل `TripModel` أو `VehicleTrip` أو `driverPublic` schema أو `DriverTrackingHub`.
- إضافة Firestore writes.

### القرار

6-C مكتملة ومثبتة ✅. تم تنفيذ `BusWatchOperationalConsumer` مستقل يستهلك `BusWatchOperationalReadResult` كما هو، ويستبدل النتيجة السابقة بالكامل، ويمسح الـoperational snapshot السابق عند أي `non-available` result، دون اختيار Trip أو lookup أو fallback أو cache أو Stream lifecycle. لا تم تعديل 6-A أو 6-B.

### Evidence

- `flutter analyze` — No issues found.
- `flutter test test/bus_watch_operational_consumer_test.dart` — **6/6 passed**.
- `flutter test` — **254/254 passed**.
- `git status` — working tree clean.
- Consumer/UI integration الفعلية ليست ضمن 6-C، ولا تُعد جزءًا من دليل إغلاق هذه النقطة.

### 6-D — Passenger BusWatch Read Lifecycle / Context Contract ✅

**الحالة:** مكتملة ✅ — تم تنفيذ Production `BusWatchReadLifecycleCoordinator` واختبار عقده بشكل مستقل.

### المشكلة التي تحلها 6-D

6-C تملك استهلاك `BusWatchOperationalReadResult`، لكن لا يوجد فيها من يقرر:

- متى تبدأ القراءة.
- متى تتوقف دورة السياق.
- متى يعاد استدعاء `read(tripId)`.
- كيف تُرفض نتيجة أو أخطاء قراءة وصلت بعد تغيير سياق Passenger.

6-D تفصل هذه المسؤولية في Coordinator مستقل عن Reader وConsumer.

### العقد

```text
Passenger Context Owner
        ↓
BusWatchReadLifecycleCoordinator
        ↓
BusWatchOperationalReader
        ↓
BusWatchOperationalConsumer
```

الـCoordinator يملك **دورة القراءة فقط**، ولا يملك بيانات BusWatch التشغيلية كـsource of truth، ولا يختار Trip.

### واجهة دورة الحياة

```text
bind(tripId)
clear()
refresh()
```

#### bind(tripId)

- يربط Coordinator برحلة Passenger محددة.
- يـinvalidate السياق السابق أولًا.
- يمسح حالة الـConsumer القديمة قبل بدء القراءة الجديدة.
- يزيد `Context / Read Generation`.
- ينفذ قراءة أولية واحدة لـ`read(tripId)`.
- لا يبحث عن Trip بديلة ولا يستخدم `list.first`.

#### refresh()

- يعيد قراءة السياق الحالي نفسه.
- لا يغير `tripId`.
- لا يختار رحلة بديلة.
- لا ينشئ Timer أو polling loop أو Stream.

#### clear()

- يلغي صلاحية السياق الحالي بزيادة `Context / Read Generation`.
- يمسح حالة الـConsumer.
- بعد `clear()` لا يجوز تطبيق أي نتيجة أو خطأ من قراءة سابقة.

### Context / Read Generation

الـGeneration هو معرف داخلي صغير لدورة السياق، وليس Cache ولا بيانات تشغيلية.

مثال:

```text
bind(trip-A)
generation = 1
        ↓
read(A) starts with generation 1

bind(trip-B)
generation = 2
        ↓
read(B) starts with generation 2

A returns late
generation = 1
        ↓
discard
```

قاعدة الحماية:

> **A read result or read error may be applied only if it belongs to the currently active context generation.**

بالعربي:

> **لا يجوز تطبيق نتيجة أو خطأ من قراءة سابقة على سياق Passenger الحالي.**

وتنطبق الحماية نفسها على **result** وعلى **error**.

### Refresh / Lifecycle Policy

6-D لا تثبت periodic refresh.

المسموح حاليًا فقط:

- Initial bind.
- Trip context change.
- Explicit refresh.
- Lifecycle reactivation عندما يصبح Passenger Context صالحًا.

ولا يتم في 6-D إضافة:

- Timer.
- Polling loop.
- Periodic Stream.

أي احتياج لاحق لهذه الآليات يحتاج عقدًا مستقلًا ودليلًا فعليًا.

### ملكية Passenger Context

- Passenger Context Owner الأعلى هو الذي يحدد `tripId`.
- Coordinator لا يختار رحلة من مجموعة Trips.
- `MapTab` لا تنقل منطق `list.first` إلى Coordinator.
- تغيير `tripId` يعني بداية Context Generation جديدة.

### سلوك النتائج والأخطاء المتأخرة

```text
Context A
   ↓
read(A) generation 1
   ↓
context changes to B
   ↓
generation 2

late A result
→ discard

late A error
→ discard
```

لا يتم:
- تطبيق snapshot قديم.
- تحويل الخطأ القديم إلى Domain Result حالي.
- إعادة استخدام نتيجة سابقة كـfallback.

### حدود 6-D

تم الالتزام بالحدود التالية في التنفيذ:

- تعديل `BusWatchReadLifecycleCoordinator` فقط وإضافة focused tests الخاصة به.
- عدم تعديل `BusWatchOperationalReader`.
- عدم تعديل `BusWatchOperationalConsumer`.
- عدم إدخال UI integration.
- عدم إدخال `ActiveTripBanner`.
- عدم إدخال ETA أو `EtaResult`.
- عدم إدخال NextStop أو `StopRuntimeSnapshot`.
- عدم إضافة freshness policy.
- عدم إضافة cache أو persistence.
- عدم إضافة Timer أو polling أو periodic Stream.
- عدم تعديل `TripModel` أو `VehicleTrip` أو `driverPublic` schema أو `DriverTrackingHub`.
- عدم إضافة Firestore writes.

### القرار

6-D مكتملة ومثبتة ✅. الفصل أصبح:

```text
6-A = ماذا نقرأ
6-B = كيف ننسق القراءة
6-C = كيف نستهلك النتيجة
6-D = من يدير دورة القراءة ويحمي السياق
```

والتنفيذ المثبت في 6-D يغطي focused tests لـ:
- bind A → initial read.
- bind A → explicit refresh.
- A → B → late A result rejected.
- A → B → late A error rejected.
- clear → late result rejected.
- reactivate → new read.
- same tripId + explicit refresh → fresh read.

### Evidence

- `flutter test test/bus_watch_read_lifecycle_coordinator_test.dart` — **7/7 passed**.
- `flutter analyze` — **No issues found!** بعد إزالة الـunused import من اختبار 6-D.
- `flutter test` — **261/261 passed**.
- تم تثبيت التنفيذ على الفرع `stage/approved-route-line-vehicle-link-v1` في commit `bc72bff5dcf0befb844b331d0052e7802d5f1f67`، ثم patch تنظيف الاختبار `735695459bcee44cd3d8824865c97d9a45c997ae`.
- لم تتغير عقود 6-A أو 6-B أو 6-C ضمن 6-D.

ولا تعيد 6-D فتح 6-A أو 6-B أو 6-C.
 
### 6-E.1 — Passenger Context Binding ✅

**الحالة:** مكتملة ✅ — تم تنفيذ وربط عقد `Passenger Context Binding` بشكل مستقل، دون إدخال UI integration الفعلية أو تغيير مسؤوليات BusWatch السابقة.

### العقد

```text
Passenger Context Owner
        ↓
Passenger-selected TripModel?
        ↓
BusWatchPassengerContextBinder
        ↓
exact TripModel.id
        ↓
BusWatchReadLifecycleCoordinator
```

`BusWatchPassengerContextBinder` مسؤول فقط عن تحويل الـ`TripModel` الذي يختاره المستهلك الأعلى إلى `TripModel.id` وربط هذا المعرف بدورة قراءة BusWatch.

### السلوك المثبت

- `sync(selectedTrip)` يربط `TripModel.id` المحدد فقط.
- نفس `tripId` لا يبدأ `bind` أو قراءة أولية جديدة.
- تغيير `tripId` يبدأ سياقًا جديدًا عبر الـCoordinator.
- غياب الرحلة أو وجود `id` فارغ يؤدي إلى عدم إنشاء سياق BusWatch صالح.
- `refresh()` يعيد قراءة نفس الرحلة المرتبطة فقط.
- لا يقوم الـBinder باختيار الرحلة، ولا يستخدم `list.first`، ولا ينفذ Firestore reads بنفسه.

### حدود 6-E.1

لم تتضمن هذه الخطوة:

- UI presentation integration.
- تعديل `MapTab`.
- استبدال `ActiveTripBanner`.
- تعديل `PassengerLiveTrackingMixin`.
- إدخال ETA أو `EtaResult`.
- إدخال NextStop أو `StopRuntimeSnapshot`.
- إضافة Timer أو polling أو Stream.
- تعديل `TripModel` أو `VehicleTrip` أو `driverPublic`.
- تعديل `BusWatchOperationalReader` أو `BusWatchOperationalConsumer` أو `BusWatchReadLifecycleCoordinator`.
- إضافة Firestore writes.

### Evidence

- `flutter test test/bus_watch_passenger_context_binder_test.dart` — **7/7 passed**.
- `flutter analyze` — **No issues found!**.
- `flutter test` — **268/268 passed**.
- تم التحقق من أن التغيير البرمجي في 6-E.1 محصور في `BusWatchPassengerContextBinder` واختباراته، وهذه النقطة لا تضيف أي تعديل إلى طبقات BusWatch المغلقة.

### القرار

6-E.1 مغلقة ✅.

الفصل الحالي يصبح:

`6-A` = ماذا نقرأ  
`6-B` = كيف ننسق القراءة  
`6-C` = كيف نستهلك النتيجة  
`6-D` = من يدير دورة القراءة ويحمي السياق  
`6-E.1` = كيف يرتبط Passenger Context المحدد بدورة BusWatch

والخطوة التالية هي **6-E.2 — Passenger Presentation Consumption**، وتبدأ بـInspect مستقل قبل أي Production Code.


### 6-E.2-A — Passenger Presentation Consumption Contract ✅

**الحالة:** مكتملة ✅ — تم تنفيذ جسر العرض في `MapTab` فوق طبقات BusWatch المغلقة، مع إبقاء Domain Result منفصلًا عن Infrastructure Error وحماية Presentation State من النتائج المتأخرة.

### العقد المثبت

```text
Passenger Context
        ↓
BusWatchPassengerContextBinder
        ↓
BusWatchReadLifecycleCoordinator
        ↓
BusWatchOperationalConsumer
        ↓
Passenger Presentation Bridge
        ↓
BusWatchPassengerPresentationState
```

Presentation State محدود إلى:

```text
contextTripId : String?
loading       : bool
result        : BusWatchOperationalReadResult?
error         : Object?
```

`loading` يعني وجود operation نشطة بدأت من السياق الحالي ولم تكتمل بعد، وليس مجرد غياب `result`.

### السلوك المثبت

- `MapTab` يملك Presentation State ولا تتم إضافة `ChangeNotifier` أو `ValueNotifier` أو Stream جديدة.
- الهوية التشغيلية للسياق هي `TripModel.id` / `passengerTripId` فقط.
- `BusWatchOperationalReadResult` يبقى كما هو؛ حالات `noLiveLocation` و`noApprovedRoute` وغيرها تبقى Domain results وليست أخطاء بنية تحتية.
- الخطأ القادم من القراءة يبقى منفصلًا في `error` من النوع `Object?` ولا يتحول إلى رسالة UI في هذه الخطوة.
- كل Presentation operation تحمل generation/token داخليًا؛ completion أو error المتأخر لا يستطيع تعديل `contextTripId` أو `loading` أو `result` أو `error` للسياق الحالي.
- `clear()` يبطل generation الحالي ويمسح `contextTripId` و`loading` و`result` و`error`.
- عند إعادة القراءة لنفس الرحلة، يبقى `result` السابق أثناء `loading` إلى أن تكتمل العملية؛ عرض هذه الحالة للمستخدم يؤجل إلى 6-E.2-B.
- تغيّر `AuthProvider.userId` داخل `MapTab` يبطل Passenger BusWatch context السابق، ويعاد إنشاء الـwatch فقط للـuid الحالي.
- callback متأخر من Passenger Trip stream لuid سابق يُرفض.
- `resumed` لا يضيف `binder.refresh()`؛ إعادة إنشاء الـPassenger Trip stream الحالية بقيت كما هي.
- `dispose()` يمسح Binder وPresentation State.

### حدود 6-E.2-A

لم تتضمن هذه الخطوة:

- تعديل `BusWatchPassengerContextBinder`.
- تعديل `BusWatchReadLifecycleCoordinator`.
- تعديل `BusWatchOperationalConsumer`.
- تعديل `BusWatchOperationalReader`.
- استبدال `ActiveTripBanner`.
- تعديل `PassengerLiveTrackingMixin`.
- إدخال ETA أو NextStop أو StopRuntime.
- إضافة Timer أو polling أو Stream جديد.
- تعديل Firestore schema أو writes.
- تعديل `TripModel` أو `VehicleTrip` أو `driverPublic`.
- إعادة تصميم واجهة BusWatch المرئية؛ ذلك مؤجل إلى 6-E.2-B.

### Correction بعد التكامل

أثناء Inspect 6-E.2-B ظهر تعارض تكاملي محدود في `MapTab`: تغيّر `TripModel.status` أو `driverId` مع بقاء `tripId` نفسه كان لا يعيد قراءة BusWatch، كما أن إلغاء الرحلة كان يمسح `_openTrip` مباشرة دون المرور بمسار BusWatch context clear.

تم تصحيح ذلك داخل `MapTab` فقط:
- تغيّر `status` أو `driverId` لنفس `tripId` يؤدي إلى `binder.refresh()` مع Presentation `beginRefresh()`.
- إلغاء الرحلة يمر عبر `_setOpenTrip(null)` ليؤدي إلى `Presentation clear` و`Binder clear`.
- لم يتم تعديل Binder أو Coordinator أو Consumer أو Reader.
### Evidence

- `flutter test test/bus_watch_passenger_presentation_state_test.dart` — **7/7 passed**.
- `flutter analyze` — **No issues found! (ran in 17.8s)**.
- `flutter test` — **275/275 passed**.
- ظهر أثناء الـfull test تشغيل اختبارات stale driver tracking مع سجلات تشخيصية متوقعة، ثم اكتملت المجموعة بالكامل بـ **275/275 passed**؛ لم تُسجّل failures.

### الملفات

- `lib/passenger/screens/tabs/map_tab.dart`
- `lib/services/bus_watch_passenger_presentation_state.dart`
- `test/bus_watch_passenger_presentation_state_test.dart`

### القرار

6-E.2-A مغلقة ✅.

يبقى **6-E.2-B — Presentation State → Passenger UI** كخطوة مستقلة، ولا تبدأ إلا بعد Inspect منفصل لتحديد كيف تُعرض حالات `loading` و`available` و`noLiveLocation` و`noApprovedRoute` وغيرها داخل الواجهة الحالية.

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
✅
        ↓
PHASE 2
Live GPS + Historical Capture
✅
        ↓
PHASE 3
RouteProgress
✅
        ↓
PHASE 4
NextStop / Pickup
✅ COMPLETE
        ↓
4.1-A
RoutePolylineProjection
✅
        ↓
4.1-B
Stop-to-Route Projection
✅
        ↓
4.2
NextStop Resolver
✅
        ↓
4.3
Stop State
✅
        ↓
4.3-A
State Contract
✅ DESIGN
        ↓
4.3-B
Stop State Resolver
✅
        ↓
4.4
Firestore / Hub Integration
✅
        ↓
4.4-A
Stop Runtime Integration Contract
✅ DESIGN
        ↓
4.4-B
Runtime Integration
✅
        ↓
PHASE 5
ETA
⏳ IN PROGRESS
        ↓
5.1
Deterministic ETA Engine
✅
        ↓
5.2-A
Accepted ETA Observation Bridge
✅
        ↓
5.2-B
ETA Freshness Policy
✅ CLOSED
        ↓
5.2-C
EtaInput Builder Integration
✅ CLOSED
        ↓
5.2-D
ETA Runtime Invocation
✅ CLOSED
        ↓
5.2-E
ETA Result Consumption
✅ DESIGN FROZEN
        ↓
PHASE 6
BusWatch (Read Only)
⏳ IN PROGRESS
        ↓
6-A
Operational Read Model
✅ CLOSED
        ↓
6-B
Read Consistency & Refresh Contract
✅ DESIGN FROZEN
        ↓
6-C
Passenger Consumer Contract
✅ CLOSED
        ↓
6-D
Read Lifecycle / Context Contract
✅ CLOSED
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

**Phase 6-A مغلقة تنفيذياً ✅.**

**Phase 6-B مثبتة كتصميم ✅.**

**Phase 6-C مغلقة تنفيذياً ✅.**

**Phase 6-D مغلقة تنفيذياً ✅.**

**Phase 5.2-D مغلقة ✅.**

**Phase 4.3-B مغلقة ✅.**

**Phase 4.4-A مغلقة كقرار تصميم فقط ✅.**

الحالة التنفيذية الحالية:

```text
4.1-A
RoutePolylineProjection
✅
        ↓
4.1-B.0
Projection Edge Contract
✅
        ↓
4.1-B.1
Stop Data Contract
✅
        ↓
4.1-B.2-A
PlannedRouteStopModel
✅
        ↓
4.1-B.2-B
Read-only Stop Reader
✅
        ↓
4.1-B.2-C
Stop-to-Route Projection
✅
        ↓
4.2
NextStop Resolver
✅
        ↓
4.3
Stop State
✅
        ↓
4.3-A
State Contract
✅ DESIGN
        ↓
4.3-B
Stop State Resolver
✅
        ↓
4.4
Firestore / Hub Integration
✅
```

**4.2 مغلقة ✅.**
- Resolver domain logic ينشأ من Stops projected الجاهزة + `vehicleAlongMeters` + Eligibility policy صريحة.
- Projection وEligibility وResolution مسؤوليات منفصلة.
- لا يوجد threshold رقمي لـ`distanceToRouteMeters` داخل Resolver.
- NextStop يتطلب `vehicleAlongMeters < stopAlongMeters`، ثم أصغر مسافة أمامية على محور المسار.
- `order` ترتيب إداري وtie-breaker فقط عند تعادل `alongMeters`.
- Stop عند نفس `alongMeters` ليست NextStop.
- عند عدم وجود مرشح صالح إلى الأمام تكون النتيجة `null`.

**4.3-A — Stop State Contract ✅ DESIGN ONLY.**
- الحالات: `upcoming`, `approaching`, `atStop`, `passed`.
- التصنيف يعتمد على `delta = stopAlongMeters - vehicleAlongMeters`.
- `atStopRadius` و`approachingDistance` قيم Policy قابلة للضبط ولم تُثبت رقميًا في العقد.
- التقسيم حتمي بلا تداخل أو فجوات.
- الحركة الطبيعية: `upcoming → approaching → atStop → passed`.
- القيم غير الصالحة لا تنتج State.

**4.3-B — Stop State Resolver ✅.**
- Resolver Domain-only وحتمي.
- Policy validation بدون default numeric thresholds.
- صلاحية `vehicleAlongMeters` و`stopAlongMeters` على محور `[0, totalRouteMeters]`.
- التصنيف يعتمد على `delta` فقط بعد validation.
- لا GPS أو Projection أو NextStop أو Firestore أو Hub أو VehicleTrip أو ETA أو persistence.
- التحقق: `flutter analyze` بدون مشاكل، focused **20/20**، full suite **171/171**.
- PR **#30** merged squash، merge commit `690c26f25f9372649f5b722802ed932bd997a66f`.

**Phase 5.1 — ETA Contract + Deterministic Engine مغلقة ✅.**

**Phase 5.2-A — Accepted ETA Observation Bridge مغلقة ✅.**
- `AcceptedEtaObservation` يحمل `acceptedRouteProgress` و`speedMps` و`observedAt` فقط.
- العينة المرفوضة لا تستبدل observation الحالية.
- backward-jitter المقبول يحدّث observation دون خرق monotonic route-axis progress.
- لم يتم تعديل `RouteProgressTracker` أو `EtaEngine` أو StopRuntime أو Passenger/UI أو Firestore.
- لا توجد Freshness Policy رقمية مثبتة بعد.
- الدليل النهائي: analyze بلا مشاكل، focused **17/17**، full **210/210**.

**Phase 5.2-B — ETA Freshness Policy مغلقة ✅.**
- `EtaFreshnessPolicy` منفصلة وحتمية؛ `maxAge` مطلوب صراحةً بلا default رقمي.
- `evaluatedAt` يمرره المستهلك، ولا تستخدم الـPolicy `DateTime.now()`.
- `age < 0` future، `0 <= age <= maxAge` fresh، `age > maxAge` stale.
- `45s` من `HistoricalSamplingPolicy` لا تُعاد استخدامها كـETA freshness threshold.
- التنفيذ اقتصر على Policy واختبارها المستقل؛ لم يتغير `EtaEngine` أو `AcceptedEtaObservation` أو `DriverTrackingHub` أو أي طبقة أخرى محمية.
- الدليل النهائي: analyze بلا مشاكل، focused **6/6**، full **216/216**.

**Phase 5.2-C — EtaInput Builder Integration مغلقة ✅.**
- `EtaInputBuilder` مستقل ويُنشئ `EtaInput` فقط بعد Freshness Gate ووجود NextStop.
- مصادر الحقول مثبتة: vehicle position/speed/time من `AcceptedEtaObservation`، والهدف من `StopRuntimeSnapshot.nextStop.projection`.
- لا يعيد الـBuilder منطق `EtaEngine` ولا يختار `maxAge` ولا يستخدم clock داخليًا.
- الدليل النهائي: analyze بلا مشاكل، focused **9/9**، full **225/225**.

**Phase 5.2-D — ETA Runtime Invocation مغلقة كعقد تصميم ✅.**
- المستهلك المقصود Integration Runtime مستقل، وليس `DriverTrackingHub` أو Passenger/UI.
- التقييم يحدث عند تغيّر accepted observation أو stop snapshot/NextStop، مع إمكانية طلب evaluation صراحةً من أحدث state.
- `evaluatedAt` يُمرر صراحةً من المستدعي ولا يوجد clock مخفي.
- `Eta Runtime Invocation` يعيد `EtaResult?`.
- إذا أعاد `EtaInputBuilder` قيمة `null`، يعيد Runtime قيمة `null` ولا يستدعي `EtaEngine`.
- إذا أعاد الـBuilder `EtaInput`، يستدعي Runtime `EtaEngine.calculate()` ويعيد نفس `EtaResult` كما هو، بما في ذلك `available` أو `unavailable`.
- `Builder == null` و`EtaResult.unavailable` حالتان منفصلتان في عقد runtime.
- لا إعادة استخدام ETA عند تغيّر NextStop، ولا استدعاء Engine عند غياب observation أو NextStop أو عند فشل freshness.
- لا Production Code في 5.2-D.

**الخطوة التالية الموثقة:** تنفيذ Runtime invocation component صغير واختبار عقده بشكل مستقل، دون تعديل `EtaEngine` أو مصادر runtime الحالية.

**Phase 4 Closure Notes:** الكود والتكامل والحدود المعمارية والتحقق الآلي موثقة كمكتملة. لا تعاد فتح Phase 4 إلا عند ظهور Regression أو دليل جديد يستوجب ذلك.

**المسارات الحالية لا تتطلب Stops ثابتة حتى تستمر في العمل وفق نموذج التشغيل الحالي القائم على صعود الركاب عند طلب التوقف.**



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
