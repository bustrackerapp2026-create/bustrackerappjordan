# توثيق Authorization وFirestore Rules Emulator — 2026-10-16

## الحالة التنفيذية

- الفرع: `stage/approved-route-line-vehicle-link-v1`
- العمل الحالي مستقل عن مراحل VehicleTrip / RouteProgress / DriverTrackingHub / ETA / BusWatch / Journey Planner / Ranking 8A / Trip Duration المغلقة.
- قواعد الإنتاج لم تُنشر باستخدام `firebase deploy`.
- تم تشغيل الاختبارات عبر Firestore Emulator على المشروع التجريبي `demo-jordan-bus-tracker-rules`، وليس على قاعدة بيانات الإنتاج.

## إصدارات البيئة التي أكدتها مخرجات PowerShell

| الأداة | الإصدار/القيمة المؤكدة | ملاحظة |
| --- | --- | --- |
| Node.js | `v24.18.0` | من `node --version` |
| npm | `12.0.2` | من `npm --version` |
| Firebase CLI | `15.26.0` | من `npx --yes firebase-tools --version` |
| Java runtime | Eclipse Temurin / OpenJDK `21.0.12.1` | استخدم خلال جلسة PowerShell الحالية |
| Java compiler | `javac 21.0.12.1` | تم التحقق منه |
| JAVA_HOME في جلسة الاختبار | `C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot` | تعيين مؤقت داخل PowerShell، وليس تغييرًا دائمًا للنظام |
| Java الافتراضي قبل تغيير PATH المؤقت | Java `17.0.12` | قد يظهر مجددًا في نافذة جديدة؛ أضيف مسار JDK 21 أولًا في PATH بجلسة الاختبار |
| Firestore Emulator | `cloud-firestore-emulator-v1.22.0.jar` | نُزّل عند التشغيل الأول (137 MB) وبدأ بنجاح |
| Firestore JS SDK الظاهر في سجل الاختبار | `13.0.0` | النسخة التي أظهرها سجل `@firebase/firestore` |
| Firebase Rules Unit Testing | لم يُسجل رقم الإصدار ضمن مخرجات المحادثة | تم تثبيت الحزمة محليًا، لكن لا يُذكر رقم إصدار غير متحقق منه |

إعداد Firebase في `firebase.json`:
- Firestore database: `(default)`
- Firestore location: `eur3`
- Rules file: `firestore.rules`
- Indexes file: `firestore.indexes.json`
- Storage rules: `storage.rules`

## نتائج التحقق المؤكدة

### 1. Firestore Emulator smoke test

الأمر:

```powershell
npx --yes firebase-tools emulators:exec --project demo-jordan-bus-tracker-rules --only firestore "echo FIRESTORE_EMULATOR_SMOKE_TEST_OK"
```

النتيجة:
- بدأ Firestore Emulator بنجاح.
- ظهر `FIRESTORE_EMULATOR_SMOKE_TEST_OK`.
- انتهى script برمز خروج `0`.
- أُغلق المحاكي بعد الاختبار كما هو متوقع.

### 2. VehicleOperationalSession Rules tests

ملف الاختبار:
`test/firestore_rules/vehicle_operational_session.rules.test.mjs`

Commits:
- Precheck tests: `1a9e6582af98687d2f7133f0a46b7b46dcd56f8c`
- Rules patch: `a463280fda0137d15feda78d0d0c672aea0bccf8`
- Expanded tests: `b7fcedc9d41b569a61c988171bfe59cd38189cde`

تعديل القواعد:
- إنشاء الجلسة من حساب driver يتطلب `isVerified == true`.
- تحديثات driver المسموح بها تتطلب `isVerified == true`.
- handover عبر driver يتطلب أن تكون `lastHeartbeatAt` القديمة timestamp وأن يكون قد مرّ عليها 15 دقيقة أو أكثر.
- `previousDriverId` المطلوب يطابق `resource.data.activeDriverId`، بالإضافة إلى شروط handover الحالية.

النتيجة الفعلية المرسلة من المستخدم:
- `tests 6`
- `pass 6`
- `fail 0`
- script exited successfully with code `0`.

السيناريوهات المغطاة: رفض إنشاء جلسة لسائق غير موثّق؛ قبول إنشاء السائق الموثّق المعيّن للحافلة؛ رفض الاستيلاء على جلسة حديثة؛ قبول handover بعد stale heartbeat؛ السماح لمالك الجلسة بتحديث حقول heartbeat المسموح بها؛ رفض سائق حافلة أخرى من تحديث الجلسة.

### 3. التحقق العام من Flutter بعد VehicleOperationalSession

النتائج الفعلية التي أرسلها المستخدم:
- `flutter analyze`: `No issues found! (ran in 192.0s)`.
- `flutter test`: `358/358 — All tests passed!`.

هذه النتائج تغطي تحقق تطبيق Flutter على الحالة التي اختبرها المستخدم. لا تعتبر بديلًا عن Rules Emulator tests.

### 4. driverPublic authorization

ملف القواعد الحالي:
`firestore.rules` — `match /driverPublic/{userId}`.

التعديل:
- `allow create, update` يتطلب تطابق UID مع معرف الوثيقة (owner)، وأن يكون الحساب من دور `driver`، وأن `isVerified == true`، إضافة إلى قيد المفاتيح الموجود مسبقًا.
- لم تتغير قاعدة القراءة أو الحذف في هذا الـpatch.
- لم تتغير طبقات GPS أو Mapbox أو DriverTrackingHub أو DriverTrackingLifecycle.

Commits:
- Rules patch: `4a1d69d263e564ebd3bb1b92ed270f830092cdad`
- Test file: `166be10f655edc8826078203b857951a45bd6967`

ملف الاختبار:
`test/firestore_rules/driver_public.rules.test.mjs`.

النتيجة الفعلية المرسلة من المستخدم لتشغيل المجموعتين معًا:
- `tests 12`
- `pass 12`
- `fail 0`
- `cancelled 0`, `skipped 0`, `todo 0`
- `duration_ms 21957.9925`
- `Script exited successfully (code 0)`.

اختبارات `driverPublic`: **6/6 passed**. اختبارات `VehicleOperationalSession`: **6/6 passed**. ظهرت سجلات `PERMISSION_DENIED` في المحاكي للعمليات التي تتوقع الاختبارات رفضها؛ ونجحت الاختبارات المقابلة لأن الرفض كان هو السلوك المطلوب.

المجموعة تغطي: منع driver غير موثّق من الإنشاء والتحديث؛ منع passenger من النشر؛ السماح للسائق الموثّق بنشر وتحديث وثيقته؛ منع السائق من الكتابة تحت UID شخص آخر.

## أوامر التحقق

تشغيل مجموعة VehicleOperationalSession وحدها:

```powershell
npx --yes firebase-tools emulators:exec --project demo-jordan-bus-tracker-rules --only firestore "node --test test/firestore_rules/vehicle_operational_session.rules.test.mjs"
```

تشغيل مجموعتي قواعد الصلاحيات:

```powershell
npx --yes firebase-tools emulators:exec --project demo-jordan-bus-tracker-rules --only firestore "node --test test/firestore_rules/vehicle_operational_session.rules.test.mjs test/firestore_rules/driver_public.rules.test.mjs"
```

الأمر التالي تم تشغيله فعليًا بعد سحب تغييرات القواعد والاختبارات:

```powershell
npx --yes firebase-tools emulators:exec --project demo-jordan-bus-tracker-rules --only firestore "node --test test/firestore_rules/vehicle_operational_session.rules.test.mjs test/firestore_rules/driver_public.rules.test.mjs"
```

النتيجة: **12/12 passed, 0 failed**. آخر مخرجات `flutter analyze` و`flutter test` التي أبلغ عنها المستخدم كانت بعد إصلاح `VehicleOperationalSession` وقبل إضافة patch `driverPublic` (تعديل Rules فقط دون تغيير Dart): `flutter analyze` — `No issues found! (192.0s)` و`flutter test` — `358/358 All tests passed`. لم تصل مخرجات إعادة تشغيل Flutter بعد patch `driverPublic`، لذلك لا نضع علامة على أنها أُعيدت بعد آخر تعديل Rules.

## ملاحظات npm والملفات المحلية

جرى تنفيذ:

```powershell
npm install --no-save --package-lock=false @firebase/rules-unit-testing firebase
```

المخرجات التي أبلغ عنها المستخدم:
- `added 87 packages`, `audited 90 packages`.
- npm عرض `5 high severity vulnerabilities`.
- حُجبت install scripts لكل من `@firebase/util@1.15.3` و`protobufjs@7.6.6` لعدم موافقتهما على سياسة السماح المحلية.
- لم يتم تشغيل `npm audit fix`، ولم يتم اعتماد أي تحديث شامل للحزم.
- هذه ملاحظة عن شجرة الحزم المحلية أثناء تجهيز أدوات الاختبار، وليست دليلًا كافيًا على أن اعتماديات تطبيق Flutter نفسها تحتوي على خمس ثغرات. يجب فحص تفاصيل `npm audit` بصورة مستقلة قبل أي معالجة.

في `git status --short` ظهرت آثار محلية تحت `node_modules/` بعد تثبيت أدوات الاختبار. وظهر أيضًا الملف المحلي غير المتعقب `field_test_01_log.txt`.
- لا تستخدم `git add -A` لهذه المرحلة.
- لا ترفع ملفات `node_modules` إلى المستودع.
- حافظ على `field_test_01_log.txt`؛ لا تحذفه أو تستبدله.
- لا تغيّر `package.json` أو `package-lock.json` لهذا الاختبار المؤقت إلا بقرار منفصل موثق.

## حدود الإثبات والخطوة التالية

- التعديلات موجودة في الفرع التجريبي، ولكن **لم يتم نشر `firestore.rules` إلى Firebase الإنتاجي**.
- الاختبارات تستعمل مشروع Emulator يبدأ بـ`demo-`، ولا تثبت سلوك قاعدة بيانات الإنتاج أو صحة/موثوقية إحداثيات GPS المقدمة من العميل.
- قواعد handover تحمي نافذة الزمن والهوية والحقول المختبرة؛ التحقق من موقع GPS الجغرافي ضد عميل خبيث لم يثبت بهذه الاختبارات ويحتاج تصميمًا مستقلًا.
- مجموعة `driverPublic` ومجموعة `VehicleOperationalSession` تعملان الآن بنتيجة **12/12** موثقة من مخرجات المستخدم.
- الخطوة الأمنية التالية المنفصلة هي Inspect لـ`plannedRoutes` approval. لا تُعد فتح المراحل التشغيلية المغلقة ولا تخلط هذا المسار مع Follow Camera أو فجوة تسجيل المسار أثناء Screen Lock.
- لا تُعد فتح المراحل التشغيلية المغلقة، ولا تخلط هذه الإصلاحات مع Follow Camera أو فجوة تسجيل المسار أثناء Screen Lock.
