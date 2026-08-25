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

**الإصدار:** حسب `pubspec.yaml` (`1.0.0+1`)

**اسم الحزمة:** `jordan_bus_tracker_new`
