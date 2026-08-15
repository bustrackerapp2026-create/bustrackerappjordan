# Seed data — مسارات أولية

ملفات JSON جاهزة للاستيراد مرة واحدة إلى مجموعة Firestore: `plannedRoutes`.

## خط 99 (BRT)

| ملف | الوصف |
|-----|--------|
| `route_99_outbound.json` | ذهاب: متحف الأردن → صويلح |
| `route_99_return.json` | إياب: صويلح → متحف الأردن |
| `route_99_plannedRoutes.json` | الملفان معاً + meta |

**المصدر:** بيانات مستوردة لمرة واحدة من Amman Bus (خط 99).
**لا يوجد ربط حي** مع API خارجي — البيانات مستقلة داخل مشروعك.

### الحفظ في Firebase

1. Firestore → `plannedRoutes`
2. أضف مستنداً والصق محتوى `route_99_outbound.json`
3. أضف مستنداً آخر والصق محتوى `route_99_return.json`
4. اختياري: عيّن `createdAt` / `updatedAt` كـ timestamp

بعد الحفظ يمكن البحث عن: `99`، `صويلح`، `متحف الأردن`، `الجامعة`، إلخ.
