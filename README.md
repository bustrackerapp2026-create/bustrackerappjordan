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

---

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

**`firestore.indexes.json`**

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
|---------------------|--------|---------------------|
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

- **الفرع الحالي:** `stage/driver-route-assignment-model`
- **المرجع المستقر الذي استخدمناه للاستعادة:** `stable/route-drawing-baseline`
- **آخر commit معروف وقت توثيق هذا السجل:** `4b470f30a6be4636d02889e75609e31653b41253`
- **آخر commit قبل تحديث GPS الحديث:** `41851d0a99a2cb358417eefa800d8921c612f090`
- **commit تحديث GPS الحديث:** `ce8844dc1349a077978c7cea15693434715303e7`

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

**طلبات الركاب التي يستقبلها السائق يجب أن تبقى قسمًا مستقلًا خاصًا بها.**

لذلك:

- لا ندمج طلبات تعيين المسار مع طلبات الركاب.
- لا نستبدل `BookingsTab` بوظيفة تعيين المسار؛ `BookingsTab` حاليًا مخصص لطلبات الرحلات التي يرسلها الركاب. 
- لن نضع اختيار المسار يدويًا داخل تعديل الملف الشخصي باعتباره الحل الأساسي.
- التصميم النهائي لواجهة تعيين المسار سيُحدد بعد أن يقدّم صاحب المشروع التصور الكامل للقسم المطلوب.

### الحالة الحالية: ما هو مؤجل

1. تصميم وتنفيذ واجهة مستقلة لطلبات/تعيين المسارات للسائق.
2. فصلها بصريًا ووظيفيًا عن قسم طلبات الركاب.
3. استخدام نفس البحث عن المسارات المعتمدة الموجود أصلًا في التسجيل.
4. اختبار إرسال طلب تعيين مسار ومتابعة حالته حتى مراجعة الأدمن.

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
