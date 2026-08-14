import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// ورقة خيارات صورة الملف الشخصي للراكب.
class PassengerPhotoOptionsSheet {
  PassengerPhotoOptionsSheet._();

  static Future<void> show({
    required BuildContext context,
    required bool hasPhoto,
    required VoidCallback onGallery,
    required VoidCallback onCamera,
    required VoidCallback onRemove,
  }) {
    return showModalBottomSheet(
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
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppTheme.primaryColor,
              ),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(ctx);
                onGallery();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppTheme.primaryColor,
              ),
              title: const Text('التقاط صورة'),
              onTap: () {
                Navigator.pop(ctx);
                onCamera();
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('إزالة الصورة'),
                onTap: () {
                  Navigator.pop(ctx);
                  onRemove();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
