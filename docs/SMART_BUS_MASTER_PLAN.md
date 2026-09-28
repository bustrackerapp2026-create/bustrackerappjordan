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
> **الخطوة التالية:** 4.4 — Firestore / Hub Integration، وفق الخريطة التنفيذية الحالية.
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

**قيد التنفيذ — تم إغلاق 4.1-A و4.1-B.0 و4.1-B.1 و4.1-B.2-A و4.1-B.2-B و4.1-B.2-C و4.2 و4.3-B، و4.3-A مغلقة كقرار تصميم فقط، والخطوة التالية هي 4.4 Firestore / Hub Integration.**

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
⏳ IN PROGRESS
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
⏳ NEXT
        ↓
PHASE 5
ETA
⏳
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

**Phase 4.3-B مغلقة ✅.**

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
⏳ NEXT
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

**الخطوة التالية الموثقة:** 4.4 — Firestore / Hub Integration.

**المسارات الحالية لا تتطلب Stops ثابتة حتى تستمر في العمل وفق نموذج التشغيل الحالي القائم على صعود الركاب عند طلب التوقف.**

