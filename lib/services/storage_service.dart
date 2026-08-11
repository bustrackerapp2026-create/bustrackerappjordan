import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// خدمة رفع وحذف الصور على Firebase Storage.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// مسار صورة الملف الشخصي للمستخدم.
  Reference _profileRef(String uid) =>
      _storage.ref().child('profile_photos').child('$uid.jpg');

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
      throw Exception('فشل رفع الصورة: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('فشل رفع الصورة: $e');
    }
  }

  /// حذف صورة الملف الشخصي من Storage (إن وُجدت).
  Future<void> deleteProfilePhoto(String uid) async {
    try {
      await _profileRef(uid).delete();
    } on FirebaseException catch (e) {
      // object-not-found = لا توجد صورة مسبقاً — نتجاهل
      if (e.code != 'object-not-found') {
        throw Exception('فشل حذف الصورة: ${e.message ?? e.code}');
      }
    } catch (_) {
      // تجاهل أخطاء الحذف غير الحرجة
    }
  }
}
