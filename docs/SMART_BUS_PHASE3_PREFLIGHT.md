# Smart Bus — Phase 3 Pre-flight Decisions

> مرجع قرارات وتصميم Phase 3 — RouteProgress. كانت هذه الوثيقة Pre-flight قبل بدء التنفيذ؛ تم إغلاق الملاحظة الحرجة والانتقال لاحقًا إلى التنفيذ التدريجي، لذلك تُقرأ الأقسام التنفيذية مع سجل الحالة الحالي أدناه.

## 1. الهدف

تحويل:
`VehicleTrip + accepted GPS + PlannedRoute`
إلى:
`routeProgress`

بحيث `0.00` = بداية المسار، `0.50` = منتصفه تقريبًا، و`1.00` = نهايته. القيمة هي نسبة **المسافة على طول polyline** وليست نسبة المسافة الجغرافية المباشرة بين طرفي المسار.

## 2. مصدر المسار

- المصدر التشغيلي: `VehicleTrip.routeId` → `plannedRoutes/{routeId}`.
- يجب أن يكون المسار موجودًا، معتمدًا، وبنقطتين صالحـتين على الأقل.
- لا نستخدم `lineName` لتحديد هندسة المسار أثناء التتبع.
- بعد StartTrip/Restore تُحمّل هندسة المسار مرة واحدة وتبقى محليًا مع طبقة التتبع؛ لا توجد قراءة Firestore لكل GPS event.

## 3. اتجاه وترتيب النقاط

التحقق من بيانات المشروع يثبت أن `PlannedRoute.points` في المسارات الاتجاهية مرتبة وفق حركة ذلك الاتجاه.

مثال خط 99:
- outbound: أول نقطة عند جهة متحف الأردن، وآخر نقطة عند جهة صويلح.
- return: أول نقطة عند جهة صويلح، وآخر نقطة عند جهة متحف الأردن.

إذن:
- `points.first` = البداية التشغيلية.
- `points.last` = النهاية التشغيلية.
- لا نقلب القائمة تلقائيًا بسبب `direction`.
- `direction` جزء من هوية VehicleTrip ويُستخدم للتحقق من الاتساق.

## 4. ملاحظة حرجة قبل Phase 3

الدالة الحالية `TripManagerMixin._distanceToRouteStart()` تستخدم:
- outbound → `points.first`
- return → `points.last`

وهذا لا يطابق ترتيب المسارات الاتجاهية الذي تم التحقق منه.

لذلك نحتاج **Patch مستقل صغير** لتثبيت تعريف بداية المسار في StartTrip مع regression test للـreturn، قبل تنفيذ RouteProgress. هذا ليس إعادة بناء لـGPS/Mapbox ولا يحتاج تعديل `driver_map_tab.dart`.

## 5. طريقة الحساب

RouteProgress = projection على polyline:

1. التحقق من النقاط وحساب طول كل segment.
2. حساب المسافة التراكمية قبل كل segment.
3. إسقاط GPS على كل segment مع `t ∈ [0,1]`.
4. اختيار projection المناسبة.
5. `alongMeters = cumulativeBefore + t × segmentLength`.
6. `progress = alongMeters / totalRouteMeters`.
7. حصر الناتج في `0.0..1.0`.

الحساب هندسي محلي بالمتر لكل segment؛ لا نستخدم Mapbox/API في كل تحديث.

## 6. GPS Noise

- الضوضاء الجانبية الصغيرة تُعالج بالـprojection بدل مطابقة GPS مع RoutePoint.
- أي Position مرفوضة من freshness gate لا تدخل الحساب.
- لا نعطي progress لموقع بعيد جدًا عن route.

السياسة المبدئية لحد الإسقاط:
`maxProjectionDistance = max(100m, 2 × accuracy)`
مع سقف حماية ثابت يُحسم داخل التنفيذ بالاختبار.

## 7. منع القفزات

نحتاج:
- **Continuity:** بعد أول projection نحتفظ بالموضع السابق على المسار، ونفضّل candidate المتسقة معه حتى لا نقفز إلى جزء متوازٍ أو قريب جغرافيًا.
- **Physical plausibility:** حد التقدم يعتمد على `Position.timestamp` والسرعة الصالحة وهامش حماية. لا نستخدم وقت وصول callback.
- جميع الثوابت تكون داخل خدمة RouteProgress، وليست موزعة في الـUI/Hub.

## 8. منع التراجع الوهمي

خلال VehicleTrip واحدة:
`storedProgress` = monotonic non-decreasing.

إذا كان `rawProgress < previousProgress` بسبب jitter أو projection غير مستقر، نحتفظ بالقيمة السابقة ولا نخفضها.

## 9. موضع التنفيذ

التصميم المستهدف:
`RouteProgress calculator/service (pure geometry)`
ثم:
`DriverTrackingHub`

الـHub يربط النتيجة بنفس مسار تحديث VehicleTrip الحي، مع بقاء الحساب مستقلًا عن واجهة الخريطة وقابلًا لاختبارات unit مستقلة.

لا نضع هندسة RouteProgress داخل:
- `driver_map_tab.dart`
- Mapbox UI
- `DriverTrackingLifecycle`

## 10. Firestore وLifecycle

Phase 3 يحدّث:
`vehicleTrips/{tripId}.routeProgress`

ولا يضيف `routeProgress` إلى TripPing في هذه المرحلة.

عند إنشاء VehicleTrip يبقى progress = null.
لا نجعل EndTrip يكتب `1.0` تلقائيًا؛ 1.0 يجب أن ينتج من GPS المقبول عندما يصل إسقاطه إلى نهاية المسار.

عند فشل Firestore، لا نعتبر القيمة persisted؛ أحدث قيمة محلية يمكن أن تُكتب مع أول update ناجح لاحق.

## 11. اختبارات مطلوبة

### Geometry
- start ≈ 0.00
- midpoint ≈ 0.50
- end ≈ 1.00
- مسار متعدد segments
- segment بطول صفر لا يسبب division-by-zero
- المسافة التراكمية على طول polyline صحيحة

### Noise / Jump
- انحراف جانبي صغير لا يسبب قفزة كبيرة
- موقع بعيد عن route لا ينتج progress
- انتقال طبيعي بين segments
- مسار متوازٍ/متقاطع لا يسبب branch jump واضح
- قفزة مكانية غير معقولة لا ترفع progress بشكل غير منطقي

### Monotonic
- jitter خلفي لا يخفض progress
- raw أقل من السابق → الاحتفاظ بالسابق
- التقدم اللاحق يستأنف الزيادة

### Direction / Integrity
- outbound: first → last
- return: first → last داخل route الخاص بالإياب
- لا reverse تلقائي للقائمة
- routeId هو مفتاح هندسة المسار

## 12. Acceptance Gate

لا تُغلق Phase 3 قبل:
1. Unit tests كاملة للـprojection والحماية.
2. `flutter analyze` نظيف.
3. `flutter test` بلا regression.
4. اختبار ميداني لمسار معروف يبيّن progress متدرجًا ومستقرًا.
5. اختبار outbound وreturn على هندسة كل منهما.
6. لا توجد قراءة Firestore لكل GPS update.
7. لا يوجد progress تخميني عند غياب هندسة/إشارة صالحة.

## الحالة الحالية

**Phase 3 Preflight: مغلق ✅.** تم تنفيذ القرارات الأساسية تدريجيًا عبر وحدات مستقلة، وآخرها دمج `RouteProgressPhysicalPlausibilityPolicy` داخل `RouteProgressTracker`.

حالة التحقق المحلي على الفرع الأساسي بتاريخ 2026-09-28:
- `flutter analyze` → **No issues found!**
- `flutter test` → **119/119 All tests passed!**

لا تزال بنود القبول الميداني في القسم 12 غير مُثبتة داخل هذا السجل؛ لذلك لا يُفهم من إغلاق الـPreflight أن الاختبار الميداني النهائي لـPhase 3 قد أُغلق.

لا يتم تعديل `driver_map_tab.dart` لهذا الغرض.
