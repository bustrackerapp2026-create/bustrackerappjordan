# Jordan Bus Tracker

تطبيق Flutter لتتبع الحافلات في الأردن — مع أدوار **راكب** و**سائق** و**مسؤول (Admin)**، خرائط Mapbox، وتتبع حي عبر Firebase.

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
9. [أوامر مفيدة](#أوامر-مفيدة)
10. [استكشاف الأخطاء](#استكشاف-الأخطاء)

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

---

## Firebase

المشروع مضبوط على:

- **Firestore** — قواعد: `firestore.rules` — فهارس: `firestore.indexes.json`
- **Storage** — قواعد: `storage.rules`
- **Auth** — البريد وكلمة المرور

الإعدادات المحلية للمنصة موجودة في `lib/firebase_options.dart`.

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
- **`routeCoordinates`** — `routeId` + `chunkIndex` — تحميل أجزاء مسار الخط

### نشر الفهارس فقط

```bash
firebase deploy --only firestore:indexes
```

إذا ظهر خطأ من التطبيق يشبه:

> The query requires an index…

افتح الرابط الذي يظهر في الرسالة، أو أضف الفهرس إلى `firestore.indexes.json` ثم أعد النشر.

> تفاصيل أوفى ومراجعة الفهارس الناقصة تُنجز في الخطوة التالية من خطة التحسين.

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

- **passenger** — لوحة الراكب (خريطة، رحلات، حساب)
- **driver** — إن لم يُوافق عليه → شاشة انتظار؛ بعد الموافقة → لوحة السائق
- **admin** — لوحة المسؤول (إحصائيات، التحقق من السائقين، نقاط التجمع)

ملاحظات:

- عند التسجيل يُنشأ الحساب بـ `isVerified: false` (لا يمكن رفعها من التطبيق حسب قواعد Firestore).
- المسؤول فقط يوافق على السائقين ويعدّل الحالات الحساسة.

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
  core/                     # ثيم، لغة، خريطة مشتركة، أدوات
  services/                 # Firestore، رحلات، موقع، تخزين، خطوط
  models/                   # نماذج البيانات
  l10n/                     # الترجمة (عربي / إنجليزي)
  map/                      # ويدجتات الخريطة المشتركة

firestore.rules             # قواعد الأمان
firestore.indexes.json      # الفهارس المركّبة
storage.rules               # قواعد الملفات
.env.example                # نموذج المفاتيح (بدون أسرار)
```

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
- راجع قواعد Firestore قبل أي إطلاق عام؛ حقل قراءة `users` حالياً متاح لأي مستخدم مسجّل.

---

**الإصدار:** حسب `pubspec.yaml` (`1.0.0+1`)

**اسم الحزمة:** `jordan_bus_tracker_new`
