import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// خدمة رفع وحذف الصور على Firebase Storage.
/// إن لم يُفعَّل Storage في Console تظهر رسالة واضحة للمستخدم.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Reference _profileRef(String uid) =>
      _storage.ref().child('profile_photos').child('$uid.jpg');

  String _friendlyError(FirebaseException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();

    if (code.contains('object-not-found')) {
      return 'الصورة غير موجودة.';
    }
    if (code.contains('unauthorized') || code.contains('permission')) {
      return 'لا صلاحية لرفع/حذف الصورة. تحقق من تسجيل الدخول وقواعد Storage.';
    }
    if (msg.contains('not been set up') ||
        msg.contains('bucket') ||
        code.contains('unknown') ||
        msg.contains('404')) {
      return 'تخزين الملفات (Storage) غير مفعّل على مشروع Firebase.\n'
          'من Console → Storage → Get Started ثم أعد المحاولة.';
    }
    return 'فشل عملية التخزين: ${e.message ?? e.code}';
  }

  /// رفع صورة شخصية وإرجاع رابط التحميل (download URL).
  Future<String> uploadProfilePhoto({
    required String uid,
    required File file,
  }) async {
    try {
      final ref = _profileRef(uid);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=3600',
      );

      final task = await ref.putFile(file, metadata);
      if (task.state != TaskState.success) {
        throw Exception('فشل رفع الصورة');
      }

      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception(_friendlyError(e));
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('storage') &&
          (s.contains('not') || s.contains('bucket') || s.contains('404'))) {
        throw Exception(
          'تخزين الملفات (Storage) غير مفعّل على مشروع Firebase.\n'
          'من Console → Storage → Get Started ثم أعد المحاولة.',
        );
      }
      throw Exception('فشل رفع الصورة: $e');
    }
  }

  /// حذف صورة الملف الشخصي من Storage (إن وُجدت).
  Future<void> deleteProfilePhoto(String uid) async {
    try {
      await _profileRef(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw Exception(_friendlyError(e));
    } catch (_) {
      // تجاهل أخطاء الحذف غير الحرجة
    }
  }
}
