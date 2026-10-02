# Jordan Bus Tracker

تطبيق Flutter لتتبع الحافلات في الأردن — مع أدوار **راكب** و**سائق** و**مسؤول (Admin)** (إضافةً إلى سرفيس وباص شركة)، خرائط Mapbox، وتتبع حي عبر Firebase.

---

## المحتويات

1. [المتطلبات](#المتطلبات)
2. [الإعداد السريع](#الإعداد-السريع)
3. [متغيرات البيئة](#متغيرات-البيئة)
4. [Firebase](#firebase)
5. [فهارس Firestore](#فهارس-firestore)
6. [تشغيل التطبيق](#تشغيل-التطبيق)
7. [أدوار المستخدمين](#أدوار-المستخدمين)
8. [هيكل المشروع](#هيكل-المشروع)
9. [الاختبارات](#الاختبارات)
10. [قائمة ما قبل الإطلاق التجريبي](#قائمة-ما-قبل-الإطلاق-التجريبي)
11. [أوامر مفيدة](#أوامر-مفيدة)
12. [استكشاف الأخطاء](#استكشاف-الأخطاء)
13. [مرجع التقدم والإصلاحات](#مرجع-التقدم-والإصلاحات)
14. [الحالة الحالية](#الحالة-الحالية)

---

## الحالة الحالية

### آخر حالة موثقة — 2026-10-02

- الفرع المرجعي: `stage/approved-route-line-vehicle-link-v1`
- أحدث commit تقني: `21869cc1c36fad3be71704ab7cf9dcde365fec1e` — **fix(ranking): restore GeoPoint test import**
- أحدث commit توثيقي: `120e6cbef0e45d2eb94c2fea1204703102b6ae4e` — **docs(ranking): update closest criterion status**
- baseline السابق: `6d217c5` — **Document planner UI projection contract**
- `PassengerJourneyPresentationState` يملك فقط: `status` و`generation` و`error`.
- `PlannerUiProjection` تبقى pure projection لحالة Planner فقط.
- route snapshot والرسم الفعلي يبقيان مملوكين لـ`PassengerPlannedRoutesMixin`.
- تم تنفيذ **Planner UI Projection Wiring** داخل `MapTab` بأصغر نطاق ممكن.
- الاختبار المركّز: `flutter test test/planner_status_card_test.dart` → **6/6 passed**.
- `flutter analyze` → **No issues found!**
- `flutter test` → **335/335 passed**.
- الزيادة من **329 → 335** تعود إلى اختبارات `PlannerStatusCard` الستة.
- لا يوجد fallback من Planner إلى `NearbyRoutesService` في مسار الوجهة.

### Phase 7 — JourneyPlanner

الوحدات والعقود التالية **مغلقة ومثبتة**:
- **Active Vehicle Discovery Read Contract v1** ✅
- **Route Candidate Discovery Contract/API v1** ✅
- **Journey Candidate Consumer Contract v1** — مجمد تصميميًا ✅
- **JourneyRouteVehicleAssociationService / First Association Operation v1** ✅
- **Passenger Journey Planning Service** ✅
- **Planner Presentation State Ownership Cleanup** ✅
- **Planner UI Projection Contract** ✅
- **Planner UI Projection Wiring** ✅
- **Engineering Ranking Contract v1** — مجمد تصميميًا ✅

### Phase 8A — Engineering Ranking

تم إغلاق أول معيار إنتاجي مستقل ضمن العقد المجمد:

- **Closest** → **SUPPORTED / CLOSED ✅**.
- المرجع: `VehicleTrip.currentLocation` → Passenger Origin.
- freshness تعتمد على `VehicleTrip.lastLocationAt` عبر `VehicleLocationFreshnessPolicy` محقونة.
- missing / stale / future location → `unavailable` للـcriterion فقط، ولا يبطل `Journey Option`.
- لا `DateTime.now()`، ولا inference من `routeProgress` أو speed أو heading، ولا ETA fallback.
- الاختبارات المركزة: **15/15 passed**.
- التحقق الكامل: `flutter analyze` بلا مشاكل و`flutter test` → **350/350 passed**.
- التفاصيل: `docs/SMART_BUS_PHASE8A_CLOSEST_CRITERION_PREFLIGHT.md`.

### Engineering Ranking Contract v1

التصنيف الحالي:

- **Fastest** — Defined / Deferred.
- **Closest** — **Supported / Closed**.
- **Least Walking** — Defined / Deferred.
- **Fewest Transfers** — Defined / Deferred.

**Supported production criteria: Closest.**

القواعد المثبتة:

- غياب Criterion data لا يبطل `Journey Option` تلقائيًا.
- لا ETA fallback.
- لا current-location inference.
- لا speed inference.
- لا walking-distance guess.
- لا transfer-count guess.
- Tie-break deterministic مبني على `route.id + route.direction.firestoreValue + vehicleTrip.id`.

لا يوجد Generic Ranking Engine في هذه الخطوة؛ تم تنفيذ `Closest` فقط ضمن حدوده.

### Planner Presentation State Ownership

التقسيم المعماري المثبت:

```text
PassengerJourneyPlanningService
        ↓
PassengerJourneyPresentationState
        ↓
PlannerUiProjection
        ↓
PlannerStatusCard
```

ويملك `PassengerJourneyPresentationState` فقط:

```text
status
generation
error
```

ولا يملك:

```text
PlannedRoute
Journey Options
route snapshot
Mapbox objects
rendering result
```

أما route snapshot والرسم الفعلي فهما مملوكان لـ:

```text
Journey Options
        ↓
distinct PlannedRoute
        ↓
PassengerPlannedRoutesMixin
        ↓
Mapbox
```

### Planner UI Projection Contract

`PlannerUiProjection` هي pure projection لحالة آخر Planner request فقط.

الحالات:

| State | UI meaning | Route ownership |
| --- | --- | --- |
| `idle` | لا توجد نتيجة Planner حالية لعرضها | لا تغيير |
| `loading` | طلب Planner حالي قيد التنفيذ | لا clear تلقائي |
| `success` | الطلب انتهى بخيارات Journey Options غير فارغة | الرسم يبقى مملوكًا للـMixin |
| `empty` | الطلب انتهى بلا Journey Options | لا fallback ولا clear ضمني |
| `error` | الطلب فشل | لا fallback ولا clear ضمني |

القاعدة الأساسية:

```text
Planner UI Projection
        ≠
Route Rendering
```

وكذلك:

```text
Planner Success
        ≠
Mapbox Draw Success
```

### Planner UI Projection Wiring — التنفيذ المثبت

تم ربط الـProjection بالواجهة دون نقل أي ملكية للـroute lifecycle:

- أضيف `PlannerStatusCard` كـpresentation-only consumer لـ`PlannerUiProjection`.
- الودجت لا يعرف `PlannedRoute` أو `Journey Options` أو `VehicleTrip` أو Mapbox أو `NearbyRoutesService`.
- داخل `MapTab` يتم إنشاء:
  `PlannerUiProjection.fromState(_journeyPresentation)`.
- حالات `loading / empty / error` فقط هي التي تُظهر بطاقة حالة Planner؛ `idle / success` لا تفرضان بطاقة دائمة.
- زر **إعادة المحاولة** في حالة الخطأ اختياري ويأتي من orchestration؛ الودجت نفسه لا يبدأ Planner.
- تم فصل `_findingNearby` عن مسار الوجهة؛ أصبح تمثيلًا لتفاعل **Nearby** فقط.
- `PassengerNearbyChip` لا يعكس حالة Planner.
- لا يتم مسح Mapbox بسبب تغيير Projection بحد ذاته.
- لا يتم الرسم من `PlannerStatusCard`؛ الرسم يبقى في `PassengerPlannedRoutesMixin`.
- عند وجود رحلة مفتوحة لا تُضاف بطاقة Planner فوق عرض الرحلة النشط.
- في حالات Planner المعروضة، تم تجنب تداخلها البصري مع `PassengerLiveStatusBar` دون إعادة استخدام live status لتمثيل Planner.

### Async / transition semantics

إذا حدث:

```text
Success A
   ↓
Request B
   ↓
Loading
```

فإن:

```text
PresentationState = Loading
Route snapshot     = آخر رسم يملكه Mixin
```

ولا تستنتج الـProjection أن `Loading` يعني مسح Mapbox أو أن الرسم الحالي هو نتيجة الطلب B.

كما أن:

```text
Request A
Request B
→ B authoritative
→ A stale → ignored
```

و:

```text
clear()
→ invalidate generation
→ Idle
→ stale completion rejected
```

### Planner UI Wiring — Validation Evidence

تم تنفيذ التحقق محليًا على الجهاز بعد سحب التعديلات:

- `flutter test test/planner_status_card_test.dart` → **6/6 All tests passed!** ✅
- `flutter analyze` → **No issues found!** ✅
- `flutter test` → **335/335 All tests passed!** ✅
- `git status` → **nothing to commit, working tree clean** ✅
- آخر commit تقني قبل التوثيق: `aa765b1eba1fe52b276c4e4b1008b50e54ae6d29`.

أثناء الاختبارات الكاملة ظهرت سجلات تشغيل متوقعة في اختبارات stale GPS، وانتهت المجموعة كاملة بنجاح **335/335**؛ لم ينتج عنها failure.

### Boundaries preserved

- لا تعديل على `PassengerJourneyPlanningService` ضمن Wiring.
- لا تعديل على `PassengerPlannedRoutesMixin` ضمن Wiring.
- لا تعديل على Mapbox core.
- لا تعديل على GPS أو Tracking.
- لا تعديل على `NearbyRoutesService`.
- لا ETA consumer.
- لا route snapshot داخل Presentation State.
- لا استخدام لـ`_findingNearby` لتمثيل destination Planner loading.

**الحالة:**

**Phase 7 — Planner UI Projection Wiring → CLOSED ✅**

**الخطوة التالية:**

الانتقال إلى **مراجعة ما بعد الربط وتحديد عقدة Planner التالية** فقط بعد إبقاء هذه البوابة مستقرة، ودون إدخال ranking أو ETA أو Mapbox changes في نفس الـPatch.

## المتطلبات

- **[Flutter](https://docs.flutter.dev/get-started/install)** — SDK `^3.5.0` (راجع `pubspec.yaml`)
- **حساب [Firebase](https://console.firebase.google.com/)** — Auth + Firestore + Storage
- **حساب [Mapbox](https://account.mapbox.com/)** — Access Token للخرائط
- **Android Studio / Xcode** — حسب المنصة
- **[Firebase CLI](https://firebase.google.com/docs/cli)** (اختياري) — لنشر القواعد والفهارس

تأكد من عمل Flutter:

```bash
flutter doctor
```

---

## الإعداد السريع

```bash
# 1) استنساخ المشروع
git clone https://github.com/bustrackerapp2026-create/bustrackerappjordan.git
cd bustrackerappjordan

# 2) تثبيت الاعتماديات
flutter pub get

# 3) ملف البيئة (لا ترفعه إلى Git)
cp .env.example .env
# ثم افتح .env وضع مفتاح Mapbox الحقيقي

# 4) تشغيل التطبيق
flutter run
```

> ملف `.env` مُستثنى في `.gitignore`. لا تشارك المفاتيح في المستودع.

---

## متغيرات البيئة

انسخ `.env.example` إلى `.env`:

```env
MAPBOX_ACCESS_TOKEN=pk.your_real_mapbox_token_here
```

- **`MAPBOX_ACCESS_TOKEN`** — تهيئة Mapbox في `main.dart` عبر `flutter_dotenv`

بدون هذا المفتاح تظهر الخريطة فارغة أو يظهر تحذير في سجل التشغيل.

**أمان Mapbox:** من لوحة Mapbox قيّد التوكن بنطاق URL / Bundle ID للتطبيق قدر الإمكان.

---

## Firebase

المشروع مضبوط على:

- **Firestore** — قواعد: `firestore.rules` — فهارس: `firestore.indexes.json`
- **Storage** — قواعد: `storage.rules`
- **Auth** — البريد وكلمة المرور
- **Analytics** — مفعّل في الاعتماديات (`firebase_analytics`)

الإعدادات المحلية للمنصة موجودة في `lib/firebase_options.dart`.

> **ملاحظة:** `firebase_options.dart` حالياً مضبوط لـ **Android فقط**. لإضافة iOS/Web استخدم FlutterFire CLI على جهازك.

### نشر القواعد والفهارس (من جهازك)

```bash
# تسجيل الدخول مرة واحدة
firebase login

# التأكد من المشروع (راجع .firebaserc)
firebase use

# نشر القواعد + الفهارس + التخزين
firebase deploy --only firestore:rules,firestore:indexes,storage
```

`firebase.json` يربط الملفات كالتالي:

- `firestore.rules` → قواعد قاعدة البيانات
- `firestore.indexes.json` → الفهارس المركّبة
- `storage.rules` → قواعد الملفات (صور الملف الشخصي)

---

## فهارس Firestore

الاستعلامات المركّبة (مثل `where` + `orderBy`) تحتاج فهارس. الملف الرسمي:

### `firestore.indexes.json`

الفهارس المعرّفة حالياً:

- **`users`** — `userType` + `isVerified` + `isOnline` — فلترة السائقين / المتصلين
- **`trips`** — `driverId` + `status` + `createdAt` (تنازلي) — طلبات ورحلات السائق
- **`trips`** — `passengerId` + `createdAt` (تنازلي) — سجل رحلات الراكب
- **`trips`** — `passengerId` + `status` — رحلات الراكب المفتوحة (pending/active)
- **`routeCoordinates`** — `routeId` + `chunkIndex` — تحميل أجزاء مسار الخط
- **`plannedRoutes`** — فهارس الخطوط المخططة (اسم/اتجاه/حالة)

### نشر الفهارس فقط

```bash
firebase deploy --only firestore:indexes
```

إذا ظهر خطأ من التطبيق يشبه:

> The query requires an index…

افتح الرابط الذي يظهر في الرسالة، أو أضف الفهرس إلى `firestore.indexes.json` ثم أعد النشر.

---

## تشغيل التطبيق

```bash
# جهاز/محاكي افتراضي
flutter run

# جهاز محدد
flutter devices
flutter run -d <device_id>

# بناء Android
flutter build apk

# تحليل الكود
flutter analyze
```

---

## أدوار المستخدمين

مصدر الحقيقة في الكود: `lib/core/constants/user_roles.dart` (`UserRoles`).

| القيمة في Firestore | المعنى | يحتاج موافقة أدمن؟ |
| --- | --- | --- |
| `passenger` | راكب | لا |
| `driver` | سائق | نعم |
| `service` | سرفيس | نعم |
| `bus_company` | باص شركة | نعم |
| `admin` | مسؤول | يُعيَّن يدوياً فقط |

ملاحظات:

- عند التسجيل الذاتي يُنشأ الحساب بـ `isVerified: false` (لا يمكن رفعها من التطبيق حسب قواعد Firestore).
- الأدمن فقط يوافق على الأدوار التي تحتاج تحققاً ويعدّل الحالات الحساسة.
- قراءة مستند `users/{uid}` مسموحة لـ **صاحب المستند أو الأدمن فقط** (ليست عامة لكل مستخدم مسجّل).
- المواقع العامة للسائقين تُعرض عبر مجموعة `driverPublic` (قراءة لأي مستخدم مسجّل).

### إنشاء حساب أدمن يدوياً (مرة واحدة)

1. سجّل مستخدماً عادياً من التطبيق أو من Firebase Console → Authentication.
2. من Firebase Console → Firestore → مستند `users/{uid}`:
   - `userType`: `"admin"`
   - `isVerified`: `true`
3. أعد تسجيل الدخول في التطبيق.

---

## هيكل المشروع

```text
lib/
  main.dart                 # نقطة الدخول، الثيم، اللغة، AuthWrapper
  firebase_options.dart
  admin/                    # لوحة المسؤول وتبويباتها
  driver/                   # لوحة السائق، الخريطة، العمليات
  passenger/                # لوحة الراكب
  features/auth/            # تسجيل الدخول، التسجيل، AuthProvider
  core/                     # ثيم، لغة، خريطة مشتركة، أدوات، UserRoles
  services/                 # Firestore، رحلات، موقع، تخزين، خطوط
  models/                   # نماذج البيانات
  l10n/                     # الترجمة (عربي / إنجليزي)
  map/                      # ويدجتات الخريطة المشتركة

test/                       # اختبارات الوحدات
firestore.rules             # قواعد الأمان
firestore.indexes.json      # الفهارس المركّبة
storage.rules               # قواعد الملفات
.env.example                # نموذج المفاتيح (بدون أسرار)
```

---

## الاختبارات

اختبارات وحدات في مجلد `test/`:

- `trip_status_test.dart` — تحويل حالات الرحلة
- `trip_model_test.dart` — التحقق من المدخلات وحالات `TripModel`
- `trip_acceptance_test.dart` — قبول الرحلة وتعيين السائق وانتقال الحالات
- `trip_cancel_rules_test.dart` — إلغاء الراكب ورفض السائق
- `user_model_test.dart` — تحليل `UserModel` ودوال العرض
- `user_roles_test.dart` — ثوابت الأدوار والمساعدات
- `pickup_point_model_test.dart` — ملاحظات مراجعة نقاط التجمع
- `historical_sampling_policy_test.dart` — اختبار حداثة Position التاريخية ورفض المواقع القديمة
- `route_progress_calculator_test.dart` — اختبار الإسقاط الهندسي لـRouteProgress
- `route_progress_tracker_test.dart` — اختبار الاستمرارية والتقدم الأحادي والـPhysical Plausibility
- `driver_tracking_hub_route_progress_test.dart` — اختبار تكامل RouteProgress مع DriverTrackingHub
- `vehicle_trip_live_location_payload_test.dart` — اختبار حفظ RouteProgress مع تحديث VehicleTrip الحي
- `route_progress_physical_plausibility_policy_test.dart` — اختبار سياسة الحد الفيزيائي المستقلة

تشغيل كل الاختبارات:

```bash
flutter test
```

تشغيل ملف واحد:

```bash
flutter test test/trip_cancel_rules_test.dart
```

---

## قائمة ما قبل الإطلاق التجريبي

استخدمها قبل إعطاء التطبيق لمختبرين حقيقيين:

1. **أسرار**
   - تأكد أن `.env` غير مرفوع إلى Git (`git status` لا يظهره)
   - قيّد توكن Mapbox في لوحة Mapbox (تطبيق / URL إن أمكن)
2. **Firebase**
   - `firebase deploy --only firestore:rules,firestore:indexes,storage`
   - تحقق من مشروع `.firebaserc` الصحيح (ليس مشروع تجريبي بالخطأ)
3. **جودة**
   - `flutter analyze` بدون أخطاء جديدة
   - `flutter test` ينجح
4. **سيناريو يدوي قصير**
   - راكب يطلب صعوداً → سائق يرى الطلب → يقبل / يرفض → راكب يلغي إن كان pending/active
   - أدمن يوافق على سائق معلّق
5. **نسخة التطبيق**
   - راجع `version` في `pubspec.yaml` قبل توزيع APK/IPA
6. **مراقبة (اختياري لاحقاً)**
   - Analytics مفعّل جزئياً
   - Crashlytics يمكن إضافته عند الحاجة دون إعادة بناء البنية

---

## أوامر مفيدة

```bash
flutter pub get
flutter analyze
flutter test
flutter clean && flutter pub get

firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```

---

## استكشاف الأخطاء

- **الخريطة لا تظهر** — تحقق من ملف `.env` ووجود `MAPBOX_ACCESS_TOKEN` صحيح
- **خطأ «requires an index»** — انشر `firestore.indexes.json` أو أنشئ الفهرس من رابط الخطأ
- **Permission denied** — انشر `firestore.rules` / `storage.rules`، وتحقق من نوع المستخدم في المستند
- **السائق عالق في شاشة الانتظار** — يجب أن يكون `isVerified: true` من حساب أدمن أو Console
- **فشل رفع الصورة** — قواعد Storage وحجم/نوع الملف (صورة، أقل من 5MB)
- **تعارض Git على pack files** — أغلق IDE، نفّذ `git gc --prune=now` أو استنسخ المستودع من جديد

---

## الترخيص والخصوصية

- لا ترفع ملفات `.env` أو مفاتيح Firebase/Mapbox إلى Git.
- راجع قواعد Firestore قبل أي إطلاق عام.
- قراءة `users/{uid}`: صاحب المستند أو الأدمن فقط.
- قراءة مواقع السائقين العامة: عبر `driverPublic` لأي مستخدم مسجّل.

---

## مرجع التقدم والإصلاحات

> هذا القسم هو المرجع العملي لحالة المشروع أثناء جلسات التطوير. لا يُفترض أن يحل محل الكود نفسه؛ عند التعارض، الكود والـGit commits هما مصدر الحقيقة.

### الفرع والحالة المرجعية

- **الفرع التطويري المرجعي:** `stage/approved-route-line-vehicle-link-v1`
- **الحالة التقنية الحالية:** وحدات Phase 3 — RouteProgress حتى دمج Physical Plausibility داخل `RouteProgressTracker` مغلقة ومثبتة على الفرع `stage/approved-route-line-vehicle-link-v1`.
- **آخر commit تقني مغلق:** `283009bcaeb8168b438609f7ba9466e46c8379c7` — `feat(route-progress): integrate physical plausibility into tracker`
- **آخر commit تقني سابق لمسار Failure Path 1:** `5e820c8da9dbf171ddbaca156dba52d95e56e25c`
- **آخر commit توثيقي سابق لـFailure Path 1:** `311a0aafb5bc88493757f4501e5c5a838779546c`
- **آخر commit تقني لـ Buffer Isolation:** `c058b26ccdf62ed9abc2ad325522f8403a7fa81e`
- **نسخة الاستقرار السابقة لرسم المسار:** `stable/route-drawing-baseline` عند `46c3ac430b193434eb886eaedee2ad2dd0e05183`
- **نسخة الاستقرار المستقلة لمرحلة Vehicle Session:** `stable/vehicle-session-route-persistence-v1` عند `054a8feaf58e6b41400dbde4a55da3bfe853e625`
- **لم يتم دمج فرع التطوير الحالي في أي من فروع الاستقرار أعلاه.**

### منهج العمل المتفق عليه

نعمل بطريقة حذرة: **تغيير واحد → اختبار واحد → تحليل النتيجة → تثبيت نجاح التغيير → الانتقال إلى الخطوة التالية**.

لا نبدأ تغييرات واجهة كبيرة أو إعادة كتابة للمنطق الموجود قبل فحص الملفات المرتبطة بالتدفق كاملًا.

### الإصلاحات التي أُنجزت واختُبرت

1. **توحيد واعتماد إصدارات Firebase**
   - تمت مواءمة `cloud_firestore` و`firebase_core` و`firebase_auth`.
   - تم تنفيذ `flutter pub get` وتشغيل التطبيق واختبار تسجيل الدخول/الخروج وبدء/إنهاء الرحلات.

2. **فرض حد القرب 750 متر عند بدء رحلة السائق**
   - أضيف التحقق في `lib/core/trip/trip_manager_mixin.dart`.
   - الاختبار البعيد (أكثر من 100 كم) رُفض بنجاح.
   - الاختبار القريب ضمن 750 متر سُمِح له بالمتابعة.

3. **تمييز أسباب فشل بدء الرحلة**
   - عدم وجود تعيينات.
   - وجود تعيينات غير صالحة.
   - وجود تعيين صحيح مع كون السائق أبعد من 750 متر.

4. **منع بدء الرحلة عندما يكون السائق Offline**
   - أضيف Online gate.
   - اختُبرت حالة Offline وحالة Online مع القرب المطلوب.

5. **حماية إنشاء/بدء `VehicleTrip` من الحالات اليتيمة**
   - تمت إضافة تحقق بعد `startTrip()`.
   - تمت إضافة rollback لحالة إنشاء `VehicleTrip` إذا فشل التفعيل المحلي بعد الإنشاء.

6. **منع تغيير المسار أثناء كون السائق Online**
   - تم تطبيق المنع في `driver_map_tab.dart`.

7. **توحيد منطق القرب من بداية المسار**
   - تم استخدام المنطق المشترك `isNearAssignedRouteStart()` بدل تكرار حساب Haversine/assignment داخل واجهة الخريطة.

8. **GPS حديث قبل تحويل السائق إلى Online**
   - استخدام `Geolocator.getCurrentPosition()` بدقة `high` وبمهلة 8 ثوانٍ قبل إتمام فحص القرب.
   - في حال فشل الحصول على GPS حديث لا يتم تحويل السائق إلى Online.
   - `flutter analyze` لم يُظهر أخطاء.
   - تم بناء Release APK بنجاح.
   - commit: `ce8844dc1349a077978c7cea15693434715303e7`.

9. **تقوية Firestore لطلبات تعيين المسار**
   - أصبح إنشاء `driverLineAssignments` المعلّق يتطلب `routeId` نصيًا وغير فارغ.
   - تم تشغيل `firebase deploy --only firestore:rules --dry-run` ونجح تجميع القواعد.
   - commit: `4b470f30a6be4636d02889e75609e31653b41253`.

10. **تقوية منظومة تعيين السائق للمسار**
    - `DriverLineAssignment` و`DriverLineAssignmentService` يدعمان `pending / approved / rejected / revoked`.
    - التعيين يعتمد على `driverId + routeId + lineId`.
    - طلب التعيين يتحقق من اعتماد المسار، اكتماله، ارتباطه بالخط، واعتماد الخط، ويمنع التكرار لنفس المسار.

11. **ربط موافقة الأدمن بحساب السائق وتعيين المسار المعتمد**
    - إذا وجد طلب `DriverLineAssignment` معلّق، فمسار موافقة الأدمن يستخدم `approveDriverAndAssignment()` لموافقة ذرية على الحساب والتعيين.

12. **ربط تعيين المسار التشغيلي بالمركبة**
    - أصبح `busNumber` هو الهوية التشغيلية للمركبة في `DriverLineAssignment` و`DriverLineAssignmentService`.
    - يمكن لعدة سائقين مرتبطين بنفس رقم المركبة استخدام نفس التعيين المعتمد للمركبة.
    - بقي `driverId` محفوظًا لأغراض الهوية والأمان والتدقيق، وليس كمرجع تشغيلي وحيد للمسار.

13. **إنشاء جلسة تشغيل واحدة لكل مركبة**
    - أضيفت `VehicleOperationalSessionService` ومجموعة `vehicleOperationalSessions`.
    - المركبة لا تسمح إلا بجلسة تشغيل نشطة واحدة في الوقت نفسه.
    - الرحلة النشطة تمنع الاستحواذ التلقائي على المركبة.
    - تم دعم انتهاء الجلسة القديمة والتحقق من الموقع والمسافة قبل الاستحواذ في الحالات المسموح بها.

14. **إصلاح القراءة والملكية لجلسة المركبة**
    - تم تقوية قواعد Firestore لقراءة وتحديث جلسة المركبة بما يتوافق مع السائق المالك للجلسة ورقم المركبة.
    - تم التعامل مع `permission-denied` أثناء محاولة اتصال السائق بالمركبة بدل تحويله إلى فشل غير معالج.

15. **منع تحديد الموقع من التسبب بفقدان جلسة المركبة**
    - أصبح تحديث موقع السائق مستقلًا عن heartbeat جلسة المركبة عندما يكون السائق Offline.
    - زر «تحديد موقعي» لا يحاول تجديد جلسة تشغيل لم يتم امتلاكها أصلًا.

16. **عرض اسم الخط التشغيلي الحقيقي للمركبة**
    - عند الاتصال يتم جلب اسم الخط من التعيين المعتمد للمركبة بدل الاعتماد على الخط الافتراضي في واجهة الخريطة.
    - لا يتم عرض `AppConstants.jordanRoutes.first` باعتباره الخط التشغيلي للمركبة بعد نجاح الاتصال.

17. **استمرار الحالة التشغيلية عند تسجيل الخروج أثناء رحلة نشطة**
    - إذا كانت هناك `VehicleTrip` نشطة، لا يتم تحويل السائق إلى Offline عند تسجيل الخروج.
    - تبقى حالة الرحلة والمركبة محفوظة حتى يمكن استكمالها بعد تسجيل الدخول من جديد.

18. **استعادة الرحلة والمسار بعد إعادة الدخول**
    - عند فتح خريطة السائق من جديد يتم البحث عن `VehicleTrip` النشطة من Firestore.
    - يتم تحميل `PlannedRoute` المرتبط بـ `routeId` والتحقق من اعتماده واتجاهه.
    - تتم استعادة معرف الرحلة التشغيلي وإعادة رسم خط المسار على الخريطة.

19. **اختبار واستقرار المرحلة الحالية**
    - نجح `flutter analyze` بعد إصلاح أخطاء الترجمة التي ظهرت أثناء استعادة المسار.
    - تم اختبار سيناريوهات الاتصال، تعدد السائقين على نفس المركبة، بدء الرحلة، منع السائق الثاني أثناء رحلة نشطة، تسجيل الخروج/الدخول، استمرار الرحلة، وإعادة ظهور المسار.
    - تم إنشاء فرع استقرار مستقل مطابق تمامًا للفرع المختبَر: `stable/vehicle-session-route-persistence-v1`.
    - فرع الاستقرار وفرع التطوير متطابقان عند نقطة التثبيت الحالية ولا توجد فروقات بينهما وقت توثيق هذا السجل.

20. **Phase 2 — الخطوة الثانية: ربط GPS الحي بـ VehicleTrip**
    - تم تنفيذ ربط موقع GPS الحي بالرحلة التشغيلية النشطة `VehicleTrip` دون إنشاء نظام GPS جديد أو إعادة بناء `DriverTrackingLifecycle`.
    - تم إضافة `VehicleTripService.updateLiveLocation()` لتحديث: `currentLocation` و`speed` و`heading` و`lastLocationAt`، مع التحقق من صحة الموقع والبيانات.
    - تم تنفيذ الربط داخل `DriverTrackingHub` حتى يستمر تحديث `VehicleTrip` مستقلًا عن وجود واجهة الخريطة.
    - تم وضع حد تحديث للحالة الحية بحد أدنى كل 5 ثوانٍ مع الاحتفاظ بآخر Position، بدل الكتابة مع كل حدث GPS.
    - عند `Start Trip` يتم ربط معرف `VehicleTrip` بالـHub، وعند استعادة الرحلة بعد إعادة فتح التطبيق يتم إعادة الربط، وعند `End Trip` يتم فك الربط.
    - لم يتم استخدام `routeProgress` في هذه الخطوة؛ يبقى مؤجلًا إلى Phase 3.
    - تم تثبيت التنفيذ في commit: `dec2aea9a9e034cff81deef23815c90c17cc1401`.
    - تم إصلاح ملاحظة `control_flow_in_finally` في commit مستقل: `3d84bd30e31ba119a0a66b326882e38b144c6c17`.
    - التحقق البرمجي على نسخة الجهاز بعد التحديث: `flutter analyze` → **No issues found!** و`flutter test` → **50/50 All tests passed!**
    - **الاختبار الميداني مكتمل:** أثناء رحلة فعلية تم التأكد من تغير `vehicleTrips/{tripId}` في Firestore (`currentLocation` و`lastLocationAt` وبيانات السرعة/الاتجاه)، ثم توقف التحديث بعد `End Trip`.
    - **الحالة:** التنفيذ البرمجي ✅ — اختبار الهاتف ✅ — تم اعتماد الانتقال إلى التسجيل التاريخي `TripPing + Buffer`.

### إغلاق Phase 2.4 — Batch Upload → Firestore — 2026-09-26

تم إغلاق بوابة **Phase 2.4** رسميًا بعد نجاح الاختبار الميداني وتأكيد مستند Firestore الفعلي للرحلة التجريبية.

- **الرحلة التجريبية:** `OCSPvGY2EiYsp9hf8N6s`
- **المستند:** `vehicleTrips/OCSPvGY2EiYsp9hf8N6s`
- **الحالة المؤكدة:** `status = "completed"`
- **بدأت الرحلة:** 8:20:01 PM (UTC+3)
- **انتهت الرحلة:** 8:22:24 PM (UTC+3)
- **آخر تحديث GPS:** `lastLocationAt = 8:22:07 PM` (UTC+3)
- **المسار:** `Z7aCAGVFjJlOpfktUSdE`
- **الاتجاه:** `outbound`
- **عدد نقاط TripPing التي ظهرت أثناء الاختبار:** 6 نقاط، مع استمرار ظهور بيانات الرحلة بعد الرفع الدفعي ثم توقف النقاط الجديدة بعد `End Trip`.
- **`routeProgress`:** `null` حاليًا، وهو متعمد ومؤجل إلى **Phase 3**.
- **HEAD المثبت وقت الإغلاق:** `a9eb4c4aa96173963c9ab8f426980f0504b4886b`.

**نتيجة البوابة:** Phase 2.4 مكتملة: GPS → Buffer → Batch Upload → Final Flush → End Trip → `VehicleTrip.status=completed`.

**الحالة المرجعية الحالية:** تم إغلاق Failure Paths الخاصة بـPhase 1 وCheckpoint الخاص بـPhase 2. أي انتقال لاحق إلى Phase 3 يبدأ من القسم **Final Checkpoint — Phase 1 + Phase 2**، ولا يبدأ `routeProgress` تلقائيًا.

### Final Checkpoint — Phase 1 + Phase 2 — 2026-09-27

هذا القسم هو **المرجع التشغيلي الحالي** بعد اكتمال اختبارات Failure Paths على الجهاز. السجلات الأقدم في هذا الملف تبقى كتاريخ للتنفيذ، لكن حالة هذا القسم هي المعتمدة عند تحديد ما إذا كان العمل قد أُغلق.

#### Phase 1 — الحالة النهائية

- **Active VehicleTrip موجودة مسبقًا:** مغلق ✅
- **PlannedRoute مفقودة / غير موجودة:** مغلق ✅
- **PlannedRoute موجودة ولكن غير معتمدة/غير صالحة:** مغلق ✅
- **Firestore failure أثناء StartTrip:** مغلق ✅
- **حماية Start من الضغط المتكرر (`isProcessingTrip`):** مغلق ✅

#### Phase 2 — الحالة النهائية الحالية

- **Live GPS → VehicleTrip:** مغلق ✅
- **Historical TripPing → Buffer → Batch Upload:** مغلق ✅
- **TripPingBuffer Isolation:** مغلق ✅
- **Batch Retry باستخدام WriteBatch جديد لكل محاولة:** مغلق ✅
- **عدم حذف Buffer قبل نجاح الرفع:** مغلق ✅
- **Final Flush قبل `completeTrip`:** مغلق ✅
- **Recovery بعد انقطاع الشبكة:** مغلق ✅
- **Historical GPS freshness gate:** مغلق ✅
- **Live GPS freshness gate — stream + heartbeat:** مغلق ✅

#### التحقق المحلي النهائي — جهاز التطوير

- `flutter analyze` → **No issues found!** ✅
- `flutter test` → **66/66 All tests passed!** ✅
- `git status` → **working tree clean** ✅
- الفرع المحلي `stage/approved-route-line-vehicle-link-v1` متزامن مع `origin` ✅

#### ما لم يبدأ بعد

- `routeProgress` لا يزال `null` عند إنشاء `VehicleTrip`، ولم يبدأ حساب التقدم على المسار. ⏸️
- ETA وML وأي منطق متقدم مبني على التقدم مؤجل إلى ما بعد Phase 3.
- لا توجد إضافة `LIVE/STALE/LOST` إلى Firestore.

#### قواعد عدم العودة إلى ما أُغلق

- لا تعاد اختبارات Failure Paths المغلقة إلا عند ظهور Regression أو تغيير معماري يمسها.
- لا يعاد بناء GPS أو `DriverTrackingLifecycle` أو Mapbox بلا دليل تقني جديد.
- لا يُستخدم `driver_map_tab.dart` للتعديلات الجانبية بسبب حادثة الاستعادة السابقة.
- لا يبدأ Phase 3 تلقائيًا؛ فتحها يكون بتغيير مستقل مع Preflight واختبار قبل التنفيذ.

**الحالة المعتمدة:** Phase 1 Failure Paths وPhase 2 Checkpoint الحاليان مغلقان بحسب الأدلة المتاحة، والخطوة التالية الوحيدة المسموح بفتحها من الخطة هي **Phase 3 Preflight لتصميم `routeProgress`**.

### إغلاق Failure Path 4 — حماية Start من الضغط المتكرر / isProcessingTrip — 2026-09-27

تم إغلاق التحقق من حماية Start Trip من التشغيل المتزامن أو الضغط المتكرر بعد مراجعة الكود واختبار ميداني على جهاز الاختبار.

- `startTrip()` يرفض أي استدعاء جديد عندما تكون `_isProcessingTrip` مفعلة.
- واجهة زر الرحلة تستخدم `isProcessingTrip` لتعطيل الزر أثناء المعالجة، مع بقاء النص المعروض وفق حالة الرحلة.
- تم تنفيذ ضغط سريع متكرر أثناء بدء الرحلة على الجهاز.
- ظهرت `VehicleTrip` واحدة فقط مرتبطة بمحاولة الاختبار، ولم تُنشأ رحلة ثانية.
- تم الانتقال إلى حالة الرحلة التشغيلية مرة واحدة فقط، واستمر التتبع على `VehicleTrip` واحدة.
- لا يوجد Patch برمجي مطلوب لهذه الحالة؛ الحماية الحالية تعمل كما هو مطلوب.

**نتيجة البوابة:** Failure Path — **حماية Start من الضغط المتكرر / isProcessingTrip** — مغلق وناجح ✅. لا توجد حاجة لإعادة فتحه ما لم يظهر Regression جديد.

### إغلاق Failure Path 3 — فشل Firestore أثناء StartTrip — 2026-09-27

تم إغلاق حالة فشل Firestore أثناء محاولة Start Trip بعد اختبار ميداني على جهاز الاختبار، دون تعديل برمجي.

- تم إبقاء السائق Online مع وجود تعيين ومسار صالحين.
- تم قطع الاتصال بالشبكة ثم تنفيذ محاولة Start Trip واحدة.
- ظهر في Logcat فشل Firestore من نوع `UNAVAILABLE` مع `UnknownHostException`.
- سجّل التطبيق في `TripManager`: `فشل بدء الرحلة` بسبب `cloud_firestore/unavailable`.
- لم يتم إنشاء `VehicleTrip` جديدة في Firestore.
- زر Start لم يدخل حالة Loading أصلًا، وبقي في حالته الطبيعية.
- لم يظهر في السجل المرسل `FATAL EXCEPTION` أو `Unhandled Exception` أو مؤشر على Crash متعلق بهذه المحاولة.
- بعد إعادة الإنترنت ظهرت إشارات لاستعادة عمل فحص الموقع (`heartbeat: location probe healthy`) مع استمرار LocationService في تقديم موقع صالح.
- لم يتم إجراء أي Patch على الكود؛ معالجة الاستثناء الحالية نجحت في منع إنشاء الرحلة عند فشل Firestore.

**نتيجة البوابة:** Failure Path — **Firestore failure أثناء StartTrip** — مغلق وناجح ✅. لا توجد حاجة لإعادة فتحه ما لم يظهر Regression جديد.

### إغلاق Failure Path 2 — PlannedRoute مفقودة / غير صالحة — 2026-09-27

تم إغلاق حالة PlannedRoute مفقودة أو غير صالحة/غير معتمدة بعد اختبارها على جهاز الاختبار دون تعديل برمجي.

- تم اختبار driverLineAssignments.routeId بقيمة تشير إلى مسار غير موجود.
- عند محاولة Start Trip ظهر رفض واضح: المسار المخصص لك غير صالح أو غير مرتبط بالخط التشغيلي المعتمد.
- لم يتم إنشاء VehicleTrip جديدة نتيجة المحاولة الفاشلة.
- تم اختبار الحالة الثانية مع وجود PlannedRoute ولكن جعل حالتها مؤقتًا rejected.
- عند محاولة Start Trip تم رفض الرحلة باعتبار المسار غير صالح/غير معتمد.
- لم يتم إنشاء VehicleTrip جديدة في هذه الحالة أيضًا.
- لم يتم إجراء أي Patch على الكود؛ حماية _getApprovedRouteForAssignment() الحالية كانت كافية وثبت سلوكها ميدانيًا.

**نتيجة البوابة:** Failure Path — PlannedRoute مفقودة / غير صالحة — مغلق وناجح ✅. لا توجد حاجة لإعادة فتحه ما لم يظهر Regression جديد.

### إغلاق Failure Path 1 — وجود رحلة تشغيلية نشطة مسبقًا — 2026-09-27

تم إغلاق حالة **Active VehicleTrip موجودة مسبقًا** بعد التحقق من السلوك على الجهاز.

- عند وجود `DriverProvider.isTripActive` يتم رفض محاولة Start ثانية من واجهة السائق.
- على مستوى الخدمة، `VehicleTripService.startTrip()` يستخدم transaction مع `vehicleTripDriverLocks/{driverId}`؛ وجود lock فعال يوقف إنشاء رحلة جديدة ويرجع الخطأ `active-trip-exists`.
- بعد إعادة فتح التطبيق، يتم استعادة الرحلة النشطة من Firestore عبر `findActiveTripForDriver()` ثم مزامنة `DriverProvider`.
- تم اختبار محاولة بدء رحلة ثانية أثناء الرحلة الحالية، وكذلك بعد إعادة فتح التطبيق، ولم يتم إنشاء `VehicleTrip` ثانية.
- لم يتم إجراء أي Patch برمجي جديد لهذا Failure Path لأن الحماية الموجودة كانت كافية وثبت نجاحها ميدانيًا.

**نتيجة البوابة:** Failure Path — **Active VehicleTrip موجودة مسبقًا** — مغلق وناجح ✅. لا توجد حاجة لإعادة فتحه ما لم يظهر Regression جديد.

### قاعدة ملكية المسار التشغيلي للمركبة — 2026-09-26 / إغلاق 2026-09-27

تم تثبيت القرار المعماري التالي وأصبح هو السلوك التنفيذي:

- **المركبة هي مصدر الحقيقة للمسار التشغيلي المعتمد.**
- `busNumber` يحدد المركبة التشغيلية، بينما `routeId` يحدد المسار المعتمد الذي تعمل عليه المركبة.
- `driverId` يحدد السائق الحالي لأغراض الهوية والأمان والتدقيق، وليس مصدرًا لملكية المسار.
- تغيير السائق الذي يقود نفس المركبة لا يغيّر المسار التشغيلي المرتبط بالمركبة.
- **تمت إزالة fallback في `startTrip()` الذي كان يبحث عن تعيين مرتبط بالسائق عند غياب تعيين للمركبة.** أصبح حل المسار التشغيلي يعتمد على `getApprovedAssignmentsForVehicle(busNumber)` فقط.
- **تم تشديد الاعتماد:** `DriverLineAssignmentService` يرفض اعتماد تعيين بلا `busNumber`.
- **تم تشديد Firestore Rules:** لا يمكن إنشاء/اعتماد تعيين تشغيلي بلا `busNumber` غير فارغ، كما لا يمكن إنشاء `vehicleTrip` بلا رقم مركبة.
- **تم إغلاق fallback في VehicleTripService:** لا يتم تحويل `busNumber` الفارغ إلى قيمة وهمية؛ الرحلة التشغيلية ترفض الرقم الفارغ صراحة.
- السجلات القديمة غير الصالحة لا تُحذف تلقائيًا؛ عند الحاجة تُحوّل إلى `rejected` أو `revoked` للحفاظ على سجل التدقيق.

### تحقق وإغلاق القاعدة

- فرع الاختبار: `test/vehicle-route-source-of-truth`
- تم تثبيت التغيير على `stage/approved-route-line-vehicle-link-v1`.
- `flutter analyze` → **No issues found!**
- `flutter test` → **66/66 All tests passed!**
- `git diff --check` → **نظيف**
- النتيجة: **Vehicle → busNumber → approved assignment → route هو المسار الوحيد المعتمد لبدء الرحلة التشغيلية ✅**

### إغلاق عزل TripPingBuffer بين الرحلات — 2026-09-26

تم إغلاق خطوة **Buffer Isolation** بعد تطبيق حماية أحادية الرحلة على `TripPingBuffer` والتحقق منها على جهاز التطوير.

- **السلوك المثبت:** لا يقبل الـBuffer `TripPing` من `tripId` مختلف طالما يحتوي نقاطًا من رحلة أخرى.
- **الاستثناء المقصود:** بعد إفراغ الـBuffer بالكامل يمكن استقبال نقاط رحلة جديدة.
- **الكود:** `lib/services/trip_ping_buffer.dart`
- **الاختبارات:** `test/trip_ping_buffer_test.dart`
- **اختبارات المستخدم على الجهاز:** `flutter test test/trip_ping_buffer_test.dart` → **8/8 All tests passed!**
- **التحليل:** `flutter analyze` → **No issues found!**
- **commit التنفيذ:** `c058b26ccdf62ed9abc2ad325522f8403a7fa81e`

**نتيجة البوابة:** عزل نقاط الرحلات داخل الـBuffer مثبت ✅. لم يتم لمس أي فرع `stable`، ولم يتم تغيير منظومة GPS أو واجهة الخريطة.

**الخطوة التالية:** فحص **Failure Path — فشل رفع دفعة TripPing**: التأكد من أن النقاط تبقى في الـBuffer عند فشل `batch.commit()`/الرفع وعدم فقدانها، مع الحفاظ على نفس قاعدة التغيير الصغير → اختبار → تحليل → تثبيت.

### إغلاق Failure Path — فشل رفع دفعة TripPing وإعادة المحاولة — 2026-09-26

تم اختبار إصلاح إعادة استخدام Firestore WriteBatch ميدانيًا على الهاتف بعد تثبيت commit:

- **commit الإصلاح:** `5e820c8da9dbf171ddbaca156dba52d95e56e25c`
- **الرحلة التجريبية:** `PLXYEbRfBR9mhXkjcUe1`
- **سيناريو الاختبار:** تم قطع الإنترنت أثناء رحلة نشطة، ثم الانتظار، ثم إعادة الإنترنت مع إبقاء الرحلة فعالة.
- أثناء الانقطاع ظهرت أخطاء الشبكة/Firestore من نوع `ERR_INTERNET_DISCONNECTED` و`UNAVAILABLE` و`UnknownHostException`.
- استمر التقاط GPS وإضافة `TripPing` إلى الـbuffer أثناء الانقطاع.
- لم يظهر الخطأ السابق: `This batch has already been committed and can no longer be changed.`
- بعد إعادة الإنترنت ظهرت مستندات الرحلة `PLXY...` داخل مجموعة `tripPings` في Firestore، ما يثبت وصول التسجيل التاريخي بعد استعادة الاتصال.
- بعد ذلك تم إنهاء الرحلة، وأصبح `vehicleTrips/PLXYEbRfBR9mhXkjcUe1` بالحالة `completed`.
- `routeProgress = null` بقي كما هو متوقع، لأنه مؤجل إلى **Phase 3**.

**نتيجة البوابة:** مسار الفشل والاستعادة لا يفقد نقاط TripPing عند انقطاع الشبكة، وإعادة المحاولة تستخدم دفعة Firestore جديدة مع نفس المعرّفات deterministic. الاختبار الميداني للحالة الحالية ناجح ✅.

**الخطوة التالية:** الانتقال إلى Failure Path مستقل آخر أو إلى تضييق مصدر المسار التشغيلي ليكون معتمدًا على المركبة فقط، دون خلط التغييرات في نفس checkpoint.

### إغلاق Failure Path 2 — End Trip أثناء انقطاع الإنترنت ثم Recovery — 2026-09-26

تم اختبار مسار الفشل الخاص بإنهاء الرحلة أثناء انقطاع الإنترنت ميدانيًا بعد تثبيت الإصلاح `d1ae474fc1fc1a5a36c565dc7aeef359773f8d47`.

- **الرحلة التجريبية:** `SoObQxt2lXYpYgtlSvFV`
- أثناء الرحلة تم تسجيل عدة `TripPing` في الـbuffer.
- تم قطع الإنترنت، وظهر فعليًا في Logcat/Firestore:
  - `UNAVAILABLE`
  - `UnknownHostException: Unable to resolve host firestore.googleapis.com`
  - `TimeoutException after 0:00:12.000000`
- عند محاولة `End Trip` أثناء الانقطاع ظهر:
  - `🧭 Historical TripPing batch upload failed: TimeoutException...`
  - `📌 [TripManager] ❌ فشل إنهاء الرحلة...`
- لم يظهر في السجل المرسل أي `Unhandled Exception` أو `FATAL EXCEPTION` أو علامة واضحة على `App isn't responding`/ANR.
- استمر تسجيل `TripPing buffered` بعد فشل الإنهاء، ما ينسجم مع عدم اعتبار المحاولة الأولى ناجحة.
- بعد إعادة الإنترنت وإعادة محاولة `End Trip` أصبحت وثيقة:
  `vehicleTrips/SoObQxt2lXYpYgtlSvFV`
  بالحالة:
  - `status = "completed"`
  - `endedAt != null`
  - `routeProgress = null`
- **قيم الرحلة المؤكدة:** `routeId = Z7aCAGVFjJlOpfktUSdE`، `busNumber = 5638524`، `driverId = mQHUS84ReQVxzxv7DbNuNZrpBZ33`.
- بعد الاسترداد ظهرت **20 وثيقة** مرتبطة بالرحلة `SoObQxt2lXYpYgtlSvFV` داخل مجموعة `tripPings`. هذا يثبت وجود التسجيل التاريخي النهائي في Firestore؛ ولا يُستخدم وحده كإثبات عددي بأن كل نقطة كانت موجودة تحديدًا قبل لحظة قطع الإنترنت.

**نتيجة البوابة:** Failure Path 2 — **End Trip مع انقطاع الشبكة + Recovery بعد عودة الشبكة** — مغلق وناجح ميدانيًا ✅ من حيث:

1. فشل الـflush عند انقطاع الشبكة.
2. عدم إغلاق الرحلة عبر محاولة End Trip الفاشلة.
3. عدم ظهور Unhandled Exception/ANR في السجل المرسل.
4. نجاح إعادة المحاولة بعد عودة الشبكة.
5. وصول الرحلة إلى `completed` مع `endedAt`.
6. وجود Historical TripPings في Firestore بعد الاسترداد.

**حالة Phase 2 بعد هذا الإغلاق:** مسارات Live GPS، Buffer، Batch Upload، Failure أثناء الرفع، وFailure أثناء End Trip أصبحت مثبتة ميدانيًا. لا يبدأ Phase 3 بعد؛ الخطوة التالية هي **Phase 2 Checkpoint + مراجعة Sampling Policy (LIVE/STALE/LOST) وأي Failure Paths متبقية** قبل إدخال `routeProgress`.

### سياسة Sampling — LIVE / STALE / LOST — 2026-09-26

تم تثبيت سياسة Sampling مبدئية لمرحلة Phase 2 قبل إدخال `routeProgress`. هذه الخطوة توثيقية فقط ولا تغيّر سلوك التطبيق التنفيذي.

#### 1. الفصل بين GPS Health وFirestore Health

- **GPS Health:** تُحدد من زمن آخر GPS fix مقبول (`Position.timestamp`) وليس من وقت آخر نجاح لكتابة Firestore.
- **Firestore Health:** فشل الكتابة (`UNAVAILABLE`/`TimeoutException`) لا يعني أن GPS مفقود؛ وقد يستمر التقاط الـGPS والـbuffer أثناء انقطاع الشبكة.
- **GPS LOST:** لا يعني إنهاء `VehicleTrip` ولا تحويلها تلقائيًا إلى `completed` أو `cancelled`.

#### 2. الحالات التشغيلية المقترحة

- **LIVE:** آخر GPS fix مقبول حديث، بحيث يكون عمره **≤ 45 ثانية** أثناء `driverTrip`. هذا يتماشى مع حد heartbeat الحالي الذي يبدأ عند 45 ثانية.
- **STALE:** لا يوجد GPS fix حديث ضمن 45 ثانية، لكن آخر fix لا يزال ضمن نافذة احتفاظ قصيرة **>45 إلى ≤90 ثانية**؛ تتم محاولة probe/استعادة ولا يُنهى `VehicleTrip`.
- **LOST:** لم يصل GPS fix مقبول خلال **>90 ثانية**، أو لا يوجد fix صالح يمكن الاعتماد عليه. تستمر الرحلة كحالة تشغيلية ما لم يطلب المستخدم/المنطق التشغيلي إنهاءها.

> هذه الحدود هي سياسة تشغيلية للمشروع وليست معيارًا عالميًا. يجب مراجعتها بعد القياس الميداني، خصوصًا للمركبة المتوقفة أو عند قيود Android/البطارية.

#### 3. Sampling Historical TripPing

- لا نرفع كل GPS event إلى Firestore.
- المعدل التاريخي الحالي يبقى **حوالي نقطة كل 5 ثوانٍ** حتى يثبت البديل بالقياس.
- الرفع الدفعي الحالي: **5 نقاط** أو مؤقت **20 ثانية**.
- عند فشل الرفع تبقى النقاط في الـBuffer.
- لا يتم إنشاء TripPing اصطناعية من موقع cached قديم فقط لملء الفجوة.
- أي Position تُستخدم لتسجيل Historical يجب أن تمر ببوابة freshness تعتمد على `Position.timestamp`.

#### 4. مبدأ التعافي

`LIVE → STALE → محاولة probe → LIVE` عند عودة GPS.

`LIVE/STALE/LOST` مستقلة عن:
`Firestore reachable/unreachable`.

ولا يجوز أن يؤدي فقد الاتصال بالخادم وحده إلى إنهاء `VehicleTrip`.

#### 5. قاعدة التنفيذ المرحلي

تم تنفيذ **freshness gate صغير** عند إدخال `TripPing` إلى الـBuffer، مع الإبقاء على سياسة المرحلة محدودة النطاق:

- لا يوجد حاليًا حقل Firestore جديد باسم `LIVE/STALE/LOST`.
- لا يتم إنشاء `TripPing` من Position قديم لمجرد وصول callback جديد.
- لا يوجد أي استخدام لـ`routeProgress` في هذه الخطوة؛ يبقى مؤجلًا إلى **Phase 3**.
- يعتمد gate على `Position.timestamp` وليس على وقت وصول الـcallback.

### إغلاق freshness gate للتسجيل التاريخي — 2026-09-27

تم إغلاق نقطة **Sampling freshness gate** رسميًا بعد اكتمال التنفيذ البرمجي والاختبار الميداني على الهاتف.

#### التنفيذ المثبت — RouteProgress Continuity

- **الملف الجديد:** `lib/services/historical_sampling_policy.dart`
- **التكامل:** `lib/driver/services/driver_tracking_hub.dart`
- **اختبار الوحدة:** `test/historical_sampling_policy_test.dart`
- يعتمد التحقق على `Position.timestamp`.
- الحد التشغيلي الحالي لقبول Historical GPS أثناء `driverTrip` هو **≤ 45 ثانية**.
- Position الأقدم من 45 ثانية تُرفض ولا تدخل `TripPingBuffer`.
- Position المستقبلية تُرفض كذلك.
- لم يتم تغيير مخطط `vehicleTrips`، ولم تتم إضافة حقل `LIVE/STALE/LOST`.
- `routeProgress` بقي `null` ولم يبدأ Phase 3.

#### التحقق البرمجي

على نسخة المشروع المحلية بعد سحب commit التنفيذ:

- `flutter analyze` → **No issues found!**
- `flutter test` → **65/65 All tests passed!**
- الـcommit البرمجي: `0126459fcd8b6f910c586f42fe978d728775672d`

#### الاختبار الميداني

- **الرحلة التجريبية:** `4oaA3NdEm5vq5Gj10qep`
- تم تشغيل رحلة فعلية لمدة تقارب 5 دقائق دون قطع الإنترنت أو إدخال Failure Path مقصود.
- ظهر `TripPing buffered` بشكل طبيعي واستمر التسجيل خلال الرحلة.
- ظهر التسلسل `count=1 → 2 → 3 → 4` ثم استمر buffering في الدفعة التالية.
- **لم يظهر** `🧭 TripPing rejected: stale GPS fix` أثناء التشغيل الطبيعي.
- عند إنهاء الرحلة توقفت تحديثات Geolocator وعادت المنظومة إلى `driverIdle` كما هو متوقع.
- لم يظهر في السجل المرسل `Unhandled Exception` أو `FATAL EXCEPTION` متعلق بهذه النقطة.

> عدم ظهور `stale GPS fix` أثناء الاختبار الطبيعي لا يعني أن حالة GPS القديم حُقنت عمدًا؛ منطق الرفض نفسه مغطى باختبارات الوحدة، بينما الاختبار الميداني أثبت عدم منع النقاط الحديثة وعدم إحداث regression في التسجيل الطبيعي.

**نتيجة البوابة:** **Sampling freshness gate مغلق وناجح ✅** من حيث التنفيذ، اختبارات الوحدة، والتحقق الميداني للحالة الطبيعية.

**حدود هذه النقطة:** لم تتم إضافة مراقبة مستقلة لـ`LIVE/STALE/LOST` إلى Firestore، ولم يتم تغيير سياسة lifecycle أو إعادة بناء منظومة GPS. أي توسيع لحالات الصحة أو تغيير عتبات 45/90 ثانية يُعامل كتغيير مستقل بعد توفر قياس ميداني إضافي.

**الحالة الحالية:** Phase 1 Failure Paths وPhase 2 Checkpoint مغلقان وفق القسم المرجعي النهائي أعلاه. `routeProgress` مؤجل إلى Phase 3.

### حادثة الاستعادة التي يجب تذكرها

حدثت سابقًا عملية فساد لملف:

`lib/driver/screens/tabs/driver_map_tab.dart`

ووصل الملف في إحدى المحاولات إلى نسخة ناقصة احتوت على `RESTORE_MARKER_INCOMPLETE`.
تمت استعادة الفرع إلى المرجع:

`41851d0a99a2cb358417eefa800d8921c612f090`

ثم تم تطبيق إصلاح GPS الحديث يدويًا وإيداعه في commit منفصل. لذلك يجب التعامل مع `driver_map_tab.dart` بحذر وعدم إجراء تعديلات غير ضرورية عليه.

### ما تم فحصه بخصوص تعيين المسارات ولم يُنفذ بعد

- تسجيل السائق يحتوي بالفعل على بحث في المسارات المعتمدة عبر `RoutePlanService.searchApprovedRoutes()`.
- البحث يعتمد على `routeCatalog` ويعيد `lineName` و`lineId` والاتجاه.
- `DriverLineAssignmentService.requestAssignment()` جاهز لإنشاء طلب تعيين بحالة `pending`.
- البنية الخلفية وموافقة الأدمن موجودتان.
- **المفقود حاليًا هو واجهة السائق بعد تسجيل الدخول لاختيار مسار معتمد وإرسال طلب تعيينه.**

### قرار UX مهم تم اعتماده

### فصل طلبات الركاب عن تعيين المسار

لذلك:

- لا ندمج طلبات تعيين المسار مع طلبات الركاب.
- لا نستبدل `BookingsTab` بوظيفة تعيين المسار؛ `BookingsTab` حاليًا مخصص لطلبات الرحلات التي يرسلها الركاب.
- لن نضع اختيار المسار يدويًا داخل تعديل الملف الشخصي باعتباره الحل الأساسي.
- التصميم النهائي لواجهة تعيين المسار سيُحدد بعد أن يقدّم صاحب المشروع التصور الكامل للقسم المطلوب.

### الحالة الحالية: ما هو مؤجل

1. فتح **Phase 3 Preflight** لتصميم `routeProgress` فقط، دون تنفيذ الكود قبل اعتماد التصميم والاختبار.
2. تصميم وتنفيذ واجهة مستقلة بعد تسجيل الدخول لطلبات/تعيين المسارات للسائق.
3. فصل واجهة تعيين المسار بصريًا ووظيفيًا عن قسم طلبات الركاب.
4. اختبار دورة طلب التعيين من السائق حتى مراجعة الأدمن.
5. بعد تثبيت بوابة Phase 1 الأساسية بدأنا التنفيذ المرحلي لـ Phase 2؛ تم تنفيذ واختبار مكونات Phase 2 الحالية ميدانيًا حتى إغلاق freshness gates في 2026-09-27.

### تثبيت Phase 1 كمرجع استقرار — 2026-09-25

تم تثبيت الحالة التشغيلية المختبرة لـ **Phase 1 — VehicleTrip + StartTrip** في فرع استقرار مستقل:

- **فرع الاستقرار:** `stable/vehicle-trip-phase1-v1`
- **الـcommit المثبت:** `4a18526104ffc893e9963865aa95a0a18cd3f6de`
- **الهدف:** حفظ نسخة موثوقة ومختبرة من Phase 1 كنقطة رجوع قبل بدء Phase 2، مع إبقاء فروع الاستقرار الأقدم دون تغيير.
- **ما تم إثباته:** StartTrip/EndTrip، منع الرحلات المتعارضة، Vehicle Session، التحقق من التعيين والمسار، حد القرب 750م، استعادة الرحلة والمسار بعد إعادة فتح التطبيق، GPS/heartbeat، ونجاح `flutter analyze` و`flutter test` بنتيجة 50/50.
- **قاعدة العمل التالية:** نواصل التطوير على `stage/approved-route-line-vehicle-link-v1`، ولا نغيّر فرع الاستقرار الجديد إلا عند وجود سبب موثق.
- **المرحلة التالية المخططة:** Phase 2 — **Live GPS + Historical Capture**، بعد فحص الموجود حاليًا وعدم إعادة بناء أجزاء مستقرة بلا Regression واضح.

### إغلاق أول وحدة هندسية لـRouteProgress — 2026-09-27

تم تنفيذ أول وحدة مستقلة من **Phase 3 — RouteProgress** دون ربطها بعد بـDriverTrackingHub أو Firestore.

- الملف: `lib/services/route_progress_calculator.dart`
- الاختبار: `test/route_progress_calculator_test.dart`
- الحساب يعتمد على Projection على polyline والمسافة التراكمية على طول المسار.
- يدعم start/midpoint/end.
- يعالج الانحراف الجانبي ضمن tolerance.
- يرفض الموقع البعيد جدًا عن المسار.
- يرفض الإحداثيات غير الصالحة والمسار ذي الطول الصفري.
- حد الإسقاط يتأثر بدقة GPS مع سقف ثابت للحماية.
- لا توجد أي قراءة شبكة لكل GPS event.
- لم يتم تعديل `DriverTrackingHub` أو `DriverTrackingLifecycle` أو `driver_map_tab.dart`.

#### Evidence — Route Start Consistency

على الجهاز المحلي بعد سحب التحديث:

- `flutter test test/route_progress_calculator_test.dart` → **8/8 All tests passed!**
- `flutter analyze` → **No issues found!**
- `flutter test` → **77/77 All tests passed!**
- `git status` → **working tree clean**
- الفرع متزامن مع `origin`.

**نتيجة البوابة:** أول وحدة Projection لـRouteProgress — **مغلقة وناجحة ✅**

**الخطوة التالية:** إضافة طبقة حماية مستقلة لـ**Continuity + Monotonic Progress** واختبارها كحالة stateful قبل ربط النتيجة بالـDriverTrackingHub.

### إغلاق Route Start Consistency Gate — 2026-09-27

تم إغلاق بوابة اتساق **بداية PlannedRoute** قبل بدء Phase 3.

- تم تثبيت قاعدة أن بداية كل مسار اتجاهي هي `PlannedRoute.points.first`.
- تم إصلاح `TripManagerMixin._distanceToRouteStart()` بحيث لا يعكس قائمة نقاط مسار الإياب.
- تم فصل القرار في `RouteStartResolver` ليكون صغيرًا وقابلًا لاختبار وحدة مستقل.
- أضيف `test/route_start_resolver_test.dart` ويغطي outbound وreturn والمسار الفارغ.
- لم يتم تعديل `driver_map_tab.dart` أو DriverTrackingLifecycle أو Mapbox.

#### Evidence — RouteProgress Continuity

على الجهاز المحلي بعد سحب commit الإصلاح:

- `flutter test test/route_start_resolver_test.dart` → **3/3 All tests passed!**
- `flutter analyze` → **No issues found!**
- `flutter test` → **69/69 All tests passed!**
- `git status` → **working tree clean**
- الفرع `stage/approved-route-line-vehicle-link-v1` متزامن مع `origin`.

**نتيجة البوابة:** Route Start Consistency — **مغلقة وناجحة ✅**

**الخطوة التالية المسموح بها:** أول Patch هندسي صغير لـ **RouteProgress** وفق `docs/SMART_BUS_PHASE3_PREFLIGHT.md`، مع إبقاء الحساب مستقلًا عن UI وGPS/Lifecycle.

### لقطة التحقق الحالية — 2026-09-27

- `flutter analyze` → **No issues found!**
- `flutter test` → **66/66 All tests passed!**
- `git diff --check` → **نظيف**.
- الـcommit الحالي الذي ثبّت حلّ الاعتماديات هو `43e3545`، ويغيّر `pubspec.lock` فقط.
- التحقق الوظيفي اليدوي غطّى: تسجيل السائق، موافقة الأدمن، تسجيل الدخول، GPS/Online، StartTrip، ظهور المسار، EndTrip، إغلاق/إعادة فتح التطبيق واستعادة الرحلة والمسار، واستمرار heartbeat، ثم بدء/إنهاء رحلة لاحقة.
- بحث المسار أثناء التسجيل أصبح يمر عبر `RoutePlanService.searchApprovedRoutes()` ويقرأ من `routeCatalog`، بينما قراءة `plannedRoutes` تبقى للبيانات التشغيلية بعد تسجيل الدخول.
- **Phase 1:** جميع Failure Paths المطلوبة ضمن بوابة Phase 1 أُغلقت ووُثقت في الأقسام اللاحقة من هذا المرجع ✅.
- **Sampling freshness gate:** التنفيذ `0126459fcd8b6f910c586f42fe978d728775672d` + اختبار ميداني للرحلة `4oaA3NdEm5vq5Gj10qep` — **مغلق ✅**.
- **توثيق freshness gate:** مثبت في هذا الـREADME بعد اكتمال التنفيذ والاختبار الميداني.

### Live GPS freshness gate — stream + heartbeat — 2026-09-27

تم إغلاق بوابة حداثة GPS الحي داخل DriverTrackingLifecycle بعد إثبات مسارين مستقلين كان يمكن أن يعيدا Position قديمة كموقع حي:

1. GPS stream بعد خطأ: كان LocationService يعيد آخر Position مخزنة، وكان lifecycle يعاملها كحدث جديد.
2. Heartbeat probe: كان getCurrentPosition() قد يعيد Position قديمة عبر fallback، وكان heartbeat يحدّث lastPositionAt ويمررها إلى onPosition.

### الإصلاح المثبت

- عند LocationTrackingProfile.driverTrip يتم فحص Position.timestamp قبل تحديث lastPosition وlastPositionAt وقبل استدعاء onPosition.
- الموقع الأقدم من 45 ثانية يُرفض في مسار stream وفي مسار heartbeat.
- تم توحيد قبول Position الحية عبر نقطة واحدة داخل DriverTrackingLifecycle.
- لم يتم تعديل LocationService أو driver_map_tab.dart في إصلاح بوابة freshness.
- لا يتم تغيير مخطط vehicleTrips ولا إضافة LIVE/STALE/LOST إلى Firestore.

### الاختبارات — Live GPS freshness gate

- test/driver_tracking_stale_position_test.dart — يثبت رفض cached Position القديمة بعد stream error وقبول Position حديثة.
- test/driver_tracking_heartbeat_stale_probe_test.dart — يثبت رفض Position القديمة القادمة من heartbeat probe.
- على فرع التطوير نفسه:
  - flutter analyze → **No issues found!**
  - flutter test → **66/66 All tests passed!**
  - git diff --check → **نظيف**
- commits التنفيذ:
  - 60531ea904c3fbe3457dcca06d5e0cd0db070fe8 — stream stale-position guard + الاختبار الأول.
  - 0bc29617057f91c7eb26a93aa5d686f825081090 — توحيد بوابة freshness مع heartbeat.
  - 921e4f1d4b955e16633df185dfcacddbc8c23041 — اختبار heartbeat.
- تم التحقق محليًا من الإصلاحين قبل تثبيتهما على فرع التطوير.

**نتيجة البوابة:** **Live GPS freshness gate مغلق وناجح ✅** من حيث stream + heartbeat، مع اختبار regression كامل دون تغيير منظومة GPS أو بدء Phase 3.

### إغلاق RouteProgress Continuity + Monotonic Progress — 2026-09-28

تم إغلاق الوحدة الثانية من **Phase 3 — RouteProgress** بعد فصل حماية الاستمرارية والتقدم الأحادي عن `DriverTrackingHub` وFirestore.

#### التنفيذ المثبت — RouteProgress Hub Integration

- **الملف الجديد:** `lib/services/route_progress_tracker.dart`
- يحتفظ الـtracker بآخر إسقاط مقبول على المسار.
- التقدم الطبيعي للأمام يُقبل.
- الانحراف الخلفي البسيط بسبب jitter في GPS لا يُنقص `routeProgress`؛ يُحافظ على آخر تقدم مقبول.
- القفزة الأمامية التي تتجاوز **300 متر** في عينة واحدة تُرفض ويُحافظ على الحالة السابقة كحماية أولية من القفزات غير المنطقية.
- العينات غير الصالحة أو البعيدة عن المسار لا تغيّر الحالة الحالية.
- يدعم `seedFromProgress()` لتهيئة الحالة من `routeProgress` المحفوظ عند استعادة الرحلة.
- يدعم `reset()` لفصل حالة كل `VehicleTrip` عن الرحلة التالية.
- لم يتم تعديل `DriverTrackingHub` أو `DriverTrackingLifecycle` أو `driver_map_tab.dart` أو Firestore.

#### الاختبارات — RouteProgress Continuity

- **الاختبار:** `test/route_progress_tracker_test.dart`
- يغطي: أول projection صالح، منع التراجع بسبب GPS jitter، استمرار التقدم للأمام بعد jitter، رفض القفزة الأمامية غير المنطقية، تجاهل الموقع غير الصالح/البعيد، seed من `routeProgress`، رفض القيم غير الصالحة، وreset بين الرحلات.

#### Evidence

على الجهاز المحلي بعد سحب commit التنفيذ:

- `flutter test test/route_progress_tracker_test.dart` → **8/8 All tests passed!**
- `flutter analyze` → **No issues found!**
- `flutter test` → **85/85 All tests passed!**
- الفرع بعد السحب متزامن مع `origin` عند commit `dfa67862604c48028c7c085b51a536d1c2d2469f`.

**نتيجة البوابة:** **Continuity + Monotonic Progress — مغلقة وناجحة ✅**

تم لاحقًا إغلاق تكامل الـtracker مع `DriverTrackingHub` في الوحدة التالية، مع إبقاء الكتابة إلى Firestore خارج هذا المسار.

### إغلاق RouteProgress Hub Integration — 2026-09-28

تم ربط RouteProgressTracker مع DriverTrackingHub تدريجيًا، مع إبقاء الحساب محليًا وفصل الكتابة إلى Firestore عن هذه الوحدة.

#### التنفيذ المثبت — RouteProgress Firestore Persistence

- DriverTrackingHub يستقبل routePoints وrouteId وdirection وsavedRouteProgress عند ربط VehicleTrip.
- الرحلة الجديدة: reset ثم bind للمسار ثم seed اختياري ثم استقبال GPS.
- Restore: reset ثم bind ثم seed من VehicleTrip.routeProgress المحفوظ إن وُجد.
- إعادة الربط لنفس tripId + routeId تحافظ على حالة الـtracker؛ وجود routePoints جديدة لا يسبب reset تلقائيًا.
- إذا تغيّر routeId مع بقاء tripId نفسه، تتم إعادة تهيئة الـtracker وربط هندسة المسار الجديدة.
- clearActiveVehicleTrip() يمسح معرف الرحلة، هندسة المسار، ويعمل reset() للـtracker لمنع انتقال الحالة إلى رحلة لاحقة.
- _dispatchPosition() يمرر GPS إلى نقطة الربط المحلية updateRouteProgress() قبل مسارات التسجيل التاريخي والتحديث الحي.
- تم تأخير إنشاء خدمات Firestore داخل الـHub (VehicleTripService وTripPingService) إلى وقت استخدامها حتى يبقى اختبار RouteProgress المحلي مستقلًا عن Firebase.initializeApp()، دون تغيير واجهات هذه الخدمات أو مخطط Firestore.
- بقي guard القفزة الأمامية 300 متر كما هو دون تغيير.
- لم تتم إضافة أي كتابة لـrouteProgress إلى Firestore في هذه الوحدة.

#### الاختبار

- الاختبار: test/driver_tracking_hub_route_progress_test.dart
- يغطي: أول projection، التقدم الأمامي الأحادي، GPS jitter، عزل الرحلة الجديدة، Restore مع saved progress، إعادة الربط لنفس الرحلة، تغيير routeId، وclear/reset.
- على الجهاز المحلي:
  - flutter analyze → No issues found!
  - flutter test test/driver_tracking_hub_route_progress_test.dart → 8/8 All tests passed!
  - flutter test → 93/93 All tests passed!

**نتيجة البوابة:** **RouteProgress Hub Integration — مغلقة وناجحة ✅**

تم لاحقًا إغلاق Persistence إلى Firestore في الوحدة التالية، مع إبقاء physical plausibility كمسار مستقل.

### إغلاق RouteProgress Firestore Persistence — 2026-09-28

تم تفعيل حفظ routeProgress المقبول مع نفس live VehicleTrip flush الحالي، دون إنشاء cadence أو writer جديد.

#### التنفيذ المثبت — Physical Plausibility Integration

- DriverTrackingHub يأخذ snapshot متزامنًا من tripId وPosition وآخر routeProgress مقبول في بداية live flush.
- VehicleTripService.updateLiveLocation() يستقبل routeProgress اختياريًا.
- قيمة routeProgress الصحيحة بين 0.0 و1.0 تُضاف إلى نفس payload الخاص بتحديث VehicleTrip الحي.
- عندما تكون routeProgress = null لا يُضاف حقل routeProgress إلى payload أصلًا، وبذلك لا تُمسح قيمة محفوظة مسبقًا.
- القيم غير finite أو خارج المجال 0.0..1.0 تُرفض دفاعيًا داخل VehicleTripService.
- لم تتم إضافة cadence أو Firestore writer مستقل لـRouteProgress.
- بقي guard القفزة الأمامية 300 متر كما هو، ولم تتم إضافة physical plausibility.
- لم يتم تعديل DriverTrackingLifecycle أو LocationService أو Mapbox أو driver_map_tab.dart.

#### الاختبارات — RouteProgress Firestore Persistence

- الاختبار: test/vehicle_trip_live_location_payload_test.dart
- يغطي: تمرير routeProgress الصحيحة، غياب الحقل عند null، قبول 0 و1، ورفض القيم السالبة، الأكبر من 1، وNaN/Infinity.
- على الجهاز المحلي:
  - flutter analyze → No issues found!
  - flutter test test/vehicle_trip_live_location_payload_test.dart → 6/6 All tests passed!
  - flutter test → 99/99 All tests passed!

**نتيجة البوابة:** **RouteProgress Firestore Persistence — مغلقة وناجحة ✅**

تم لاحقًا إغلاق وحدة Physical Plausibility Policy كطبقة مستقلة قابلة للاختبار، مع إبقاء دمجها داخل RouteProgressTracker كـPatch مستقل لاحق.

### إغلاق RouteProgress Physical Plausibility Policy — 2026-09-28

تم تثبيت سياسة مستقلة لتقييد القفزات الأمامية في RouteProgress وفق timestamp وسرعة GPS، دون دمجها داخل RouteProgressTracker في هذه الوحدة.

#### Policy

- ناتج السياسة يميز بين `constrained(maxAllowedForwardDistanceMeters)` و`unavailable`.
- `currentTimestamp == previousTimestamp` ينتج `constrained(0m)`؛ لا توجد حركة أمامية مسموحة عندما لا يوجد زمن فعلي بين العينتين.
- timestamp المفقود أو غير الصالح، timestamp المتراجع، وفجوة زمنية أكبر من 30 ثانية تجعل القيد الفيزيائي `unavailable`، دون reset ودون fallback permissive إلى 300m.
- السرعة الحالية الصالحة تُستخدم أولًا، ثم سرعة العينة المقبولة السابقة عند غياب السرعة الحالية الصالحة.
- سرعة `0 m/s` صالحة وتمثل التوقف؛ الوقت وحده لا يولد RouteProgress.
- القيم المبدئية للسياسة: `safetyFactor = 1.5` و`safetyMargin = 20m` مع `300m` كـabsolute hard cap.
- هذه القيم Policy parameters قابلة للمعايرة والاختبار وليست ثوابت فيزيائية مطلقة.
- لم تدخل `speedAccuracy` في هذه النسخة.

#### الاختبارات — Physical Plausibility Policy

- **الاختبار:** `test/route_progress_physical_plausibility_policy_test.dart`
- يغطي: الحركة الطبيعية، same timestamp، timestamp regression، timestamps المفقودة، long gap، أولوية السرعة الحالية، fallback للسرعة السابقة، غياب السرعة الصالحة، التوقف بسرعة صفر، 300m hard cap، وحدود 30 ثانية.
- على الجهاز المحلي:
  - `flutter analyze` → **No issues found!**
  - `flutter test test/route_progress_physical_plausibility_policy_test.dart` → **12/12 All tests passed!**
  - `flutter test` → **111/111 All tests passed!**

**نتيجة البوابة:** **RouteProgress Physical Plausibility Policy — مغلقة وناجحة ✅**

**الخطوة التالية آنذاك:** دمج الـPolicy داخل `RouteProgressTracker` في Patch مستقل. تم تنفيذ هذا الدمج لاحقًا وإغلاقه في القسم التالي.

### إغلاق RouteProgress Physical Plausibility Integration — 2026-09-28

تم دمج `RouteProgressPhysicalPlausibilityPolicy` داخل `RouteProgressTracker` في Patch مستقل، مع تمرير `Position.timestamp` و`Position.speed` من `DriverTrackingHub` عبر نقطة الربط الحالية فقط.

#### التنفيذ المثبت

- يقيّد الـPhysical Plausibility الحركة الأمامية الموجبة فقط.
- يحتفظ الـTracker بـtimestamp آخر عينة مقبولة، وبآخر سرعة صالحة من عينة مقبولة لاستخدامها كـfallback.
- السرعة الحالية الصالحة لها الأولوية، وإذا كانت غير صالحة يمكن استخدام آخر سرعة صالحة مقبولة.
- عند `same timestamp` يكون السماح الفيزيائي `0m`، فتُرفض الحركة الأمامية الموجبة.
- عند الفجوة الزمنية الأطول من حد الـPolicy يصبح القيد الفيزيائي `unavailable` دون reset أو fallback permissive؛ يبقى guard الـ300m القائم كما هو.
- العينات المرفوضة لا تقدّم حالة المرجع الفيزيائي.
- `seedFromProgress()` يمسح metadata الفيزيائي حتى تبدأ الاستعادة بدون مرجع GPS قديم.
- لم يتم تعديل `DriverTrackingLifecycle` أو `RouteProgressCalculator` أو Mapbox/UI أو مسار Firestore.

#### الاختبارات — Physical Plausibility Integration

- `test/route_progress_tracker_test.dart` — حالات السماح/الرفض، أولوية السرعة، fallback، same timestamp، long gap، backward reference، وعدم تقدم المرجع بعد الرفض.
- `test/driver_tracking_hub_route_progress_test.dart` — تمرير timestamp/speed واقعيين في سيناريوهات التكامل.

على الجهاز المحلي:

- `flutter analyze` → **No issues found!**
- `flutter test` → **119/119 All tests passed!**

**نتيجة البوابة:** **RouteProgress Physical Plausibility Integration — مغلقة وناجحة ✅**

### ملاحظات تشغيلية

- لا نحذف الملفات الناتجة محليًا أو ملفات lock/generated دون سبب موثق.
- كانت هناك تغييرات محلية غير مرتبطة سابقًا في:
  - `linux/flutter/generated_plugins.cmake`
  - `pubspec.lock`
  - `windows/flutter/generated_plugins.cmake`
  ولا ينبغي حذفها تلقائيًا أثناء التنظيف.
- المرجع الأساسي لأي حالة تقنية هو الـcommit الفعلي، بينما هذا القسم يلخص قرارات العمل وحالة التنفيذ لتجنب فقدان السياق بين جلسات التطوير.

---

**الإصدار:** حسب `pubspec.yaml` (`1.0.0+1`)
