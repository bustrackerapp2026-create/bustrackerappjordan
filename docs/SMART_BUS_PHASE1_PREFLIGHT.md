# Smart Bus — Phase 1 Pre-flight Decisions

> المرجع التنفيذي قبل أول Patch في Phase 1.
> هذه الوثيقة لا تغيّر الكود؛ تثبت القرارات التي يجب أن يلتزم بها التنفيذ.

## 1. direction

- القيم المعتمدة: `outbound | return`.
- المصدر التشغيلي النهائي: `PlannedRoute.direction`.
- واجهة السائق هي التي تختار الاتجاه عندما يكون للخط أكثر من مسار معتمد.
- عند وجود مسار معتمد واحد فقط للخط، يمكن استخدام اتجاهه مباشرة دون حوار إضافي.
- `VehicleTrip.direction` يُخزّن القيمة المطبّعة من `PlannedRoute.direction.firestoreValue`.
- يؤثر الاتجاه لاحقًا على `RouteProgress`, `NextStop`, و`ETA`.

## 2. routeId

- مصدر الحقيقة: `PlannedRoute.id`.
- لا يعتمد التشغيل على اسم الخط النصي وحده.
- لا يبدأ `VehicleTrip` إلا بعد العثور على PlannedRoute صالحة ومعتمدة وبها نقاط كافية للمسار.

## 3. busNumber

- المصدر الحالي المعتمد في تدفق StartTrip: `AuthProvider.userData.busNumber`.
- إذا لم توجد قيمة صالحة، يُستخدم fallback الحالي (`—`) مؤقتًا بدل اختراع مصدر ثانٍ.
- لا نغيّر مصدر `busNumber` في هذه المرحلة إلا إذا كشف التدقيق داخل الكود حاجة تقنية مباشرة.

## 4. Firestore vs Local Runtime State

- `vehicleTrips/{tripId}` هو المصدر السلطوي للرحلة التشغيلية على الخادم.
- `DriverProvider` هو Runtime State محلي للواجهة والتتبع.
- الترتيب الإلزامي عند البدء:

```text
VehicleTripService.startTrip()
        ↓
Firestore success
        ↓
DriverProvider.startTrip()
        ↓
Tracking
```

- لا نفعّل `DriverProvider.isTripActive` قبل نجاح إنشاء VehicleTrip.

## 5. Offline Behavior

### قبل StartTrip

- إذا تعذر الاتصال/الوصول إلى Firestore: رفض واضح للبدء.
- لا تُنشأ رحلة تشغيلية محلية وهمية.
- لا يتم تفعيل `DriverProvider.isTripActive`.

### أثناء StartTrip

- فشل transaction أو timeout: العملية تفشل بأمان ولا يتم تفعيل الحالة المحلية.
- retry الحالي في `VehicleTripService` يبقى كما هو ما لم يثبت الاختبار ضرورة تغييره.

### بعد نجاح StartTrip

- إذا انقطعت الشبكة بعد إنشاء VehicleTrip: الرحلة تبقى Active على الخادم.
- معالجة تراكم GPS التاريخي/Queue التفصيلية تخص Phase 2 وليست جزءًا من Patch Phase 1.

### إغلاق التطبيق أثناء رحلة Active

- لا نفترض الإنهاء التلقائي للرحلة.
- الاستعادة من VehicleTrip/lock تُنفّذ ضمن Recovery/Lifecycle عندما تدخل هذه الحالة نطاق التنفيذ.

## 6. trips القديمة

- `vehicleTrips` هي سجل الرحلة التشغيلية للحافلة.
- `trips` تبقى مخصصة لتدفق طلبات/رحلات الراكب القديم في المرحلة الانتقالية.
- لا ننشئ `TripModel` اصطناعية تمثل "رحلة بدأها السائق" داخل `trips` كبديل عن VehicleTrip.
- أي إزالة نهائية لاعتماد Passenger flow على `trips` تتم فقط بعد التحقق من استخداماته وعدم كسر تجربة الراكب.

## 7. الحد الأدنى من Rules / Observability / Data Quality

- Rules: يجب أن تدعم `vehicleTrips` و`vehicleTripDriverLocks` وفق نموذج الملكية والـtransaction المستخدم في الخدمة.
- Error Handling: فشل StartTrip يجب ألا يترك Local Trip Active بدون VehicleTrip ناجحة.
- Observability: تسجيل `tripId`, `routeId`, `direction` للعملية الحرجة دون أسرار.
- Data Quality: التحقق من `driverId`, `routeId`, `direction` والقيم الجغرافية عند إدخالها.

## 8. Schema Evolution

- الحقول الجديدة يجب أن تكون nullable أو ذات default متوافق.
- لا حذف لحقول قائمة بدون migration واضحة.
- لا نضيف versioning إلى VehicleTrip إلا عند ظهور حاجة فعلية؛ ليس شرطًا لـ Phase 1.

## 9. Acceptance Gate for Phase 1

### Happy Path

1. السائق Online والموقع جاهز.
2. يختار الخط.
3. النظام يحل PlannedRoute المعتمدة والاتجاه.
4. `VehicleTripService.startTrip()` ينشئ VehicleTrip Active مع lock.
5. فقط بعد نجاح Firestore يبدأ DriverProvider الرحلة المحلية والتتبع.

### Failure Path

- لا PlannedRoute معتمدة → لا Start.
- Active VehicleTrip موجودة → لا Start جديدة.
- Firestore unavailable/timeout/permission denied → لا Local Trip Active.
- إلغاء/فشل UI أثناء المعالجة → يعاد الزر إلى حالته التفاعلية.

### Evidence

- Firestore: `/vehicleTrips/{id}` بالحالة `active`.
- Firestore: lock للسائق يشير إلى `tripId`.
- Local: `DriverProvider.isTripActive == true` بعد نجاح الخادم فقط.
- Logcat: العملية الحرجة قابلة للتتبع عبر `tripId`, `routeId`, `direction`.

## Current Status

**Phase 1 Pre-flight: DECIDED**

**Next action:** تنفيذ أول Patch ضيق في StartTrip، مع عدم إعادة تصميم GPS/Lifecycle/Passenger أو فتح Refactor شامل.
