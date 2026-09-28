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
