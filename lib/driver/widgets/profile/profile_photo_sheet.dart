import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';

/// اختيار / رفع / حذف صورة الملف الشخصي للسائق.
class ProfilePhotoActions {
  ProfilePhotoActions._();

  static final ImagePicker _picker = ImagePicker();
  static final StorageService _storage = StorageService();
  static final FirestoreService _firestore = FirestoreService();

  static Future<void> showOptions({
    required BuildContext context,
    required String uid,
    required bool hasPhoto,
    required Future<void> Function() onRefreshUser,
    required void Function(bool uploading) onUploadingChanged,
    required void Function(String message) onMessage,
  }) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'صورة الملف الشخصي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(
                  context: context,
                  source: ImageSource.gallery,
                  uid: uid,
                  onRefreshUser: onRefreshUser,
                  onUploadingChanged: onUploadingChanged,
                  onMessage: onMessage,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('التقاط صورة'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(
                  context: context,
                  source: ImageSource.camera,
                  uid: uid,
                  onRefreshUser: onRefreshUser,
                  onUploadingChanged: onUploadingChanged,
                  onMessage: onMessage,
                );
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('إزالة الصورة'),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePhoto(
                    context: context,
                    uid: uid,
                    onRefreshUser: onRefreshUser,
                    onUploadingChanged: onUploadingChanged,
                    onMessage: onMessage,
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Future<void> _pickAndUpload({
    required BuildContext context,
    required ImageSource source,
    required String uid,
    required Future<void> Function() onRefreshUser,
    required void Function(bool uploading) onUploadingChanged,
    required void Function(String message) onMessage,
  }) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (xfile == null) return;

      onUploadingChanged(true);

      final downloadUrl = await _storage.uploadProfilePhoto(
        uid: uid,
        file: File(xfile.path),
      );

      await _firestore.updateUserData(uid, {'photoUrl': downloadUrl});
      await onRefreshUser();
      onMessage('✅ تم رفع الصورة الشخصية بنجاح');
    } catch (_) {
      onMessage('❌ تعذر رفع الصورة. تأكد من الاتصال والصلاحيات.');
    } finally {
      onUploadingChanged(false);
    }
  }

  static Future<void> _removePhoto({
    required BuildContext context,
    required String uid,
    required Future<void> Function() onRefreshUser,
    required void Function(bool uploading) onUploadingChanged,
    required void Function(String message) onMessage,
  }) async {
    onUploadingChanged(true);
    try {
      await _storage.deleteProfilePhoto(uid);
      await _firestore.updateUserData(uid, {'photoUrl': null});
      await onRefreshUser();
      onMessage('تم إزالة الصورة الشخصية');
    } catch (_) {
      onMessage('❌ تعذر حذف الصورة');
    } finally {
      onUploadingChanged(false);
    }
  }
}
