import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../../core/constants/bus_capacity.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';
import 'profile_ui.dart';

/// نتيجة حفظ التعديلات على الملف الشخصي.
class EditProfileResult {
  final bool success;
  final String message;

  const EditProfileResult({required this.success, required this.message});
}

/// ورقة تعديل بيانات السائق.
class EditProfileSheet {
  EditProfileSheet._();

  static Future<EditProfileResult?> show({
    required BuildContext context,
    required UserModel user,
    required VoidCallback onRequestPhotoChange,
  }) async {
    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.phoneNumber ?? '');
    final emailCtrl = TextEditingController(text: user.email);
    final busCtrl = TextEditingController(text: user.busNumber ?? '');
    final routeCtrl = TextEditingController(text: user.route ?? '');
    final routeDetailCtrl =
        TextEditingController(text: user.routeDetail ?? '');
    int? selectedCapacity =
        BusCapacity.normalize(user.capacity) ?? BusCapacity.medium;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'تعديل الملف الشخصي',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ProfileUi.avatarWithCamera(
                          photoUrl: user.photoUrl,
                          initial: user.fullName.isNotEmpty
                              ? user.fullName.characters.first
                              : 'س',
                          size: 88,
                          onTap: () {
                            Navigator.pop(ctx, false);
                            onRequestPhotoChange();
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'اضغط لتغيير الصورة',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      _field(
                        controller: nameCtrl,
                        label: 'الاسم الكامل',
                        icon: Icons.person_outline,
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: phoneCtrl,
                        label: 'رقم الهاتف (يظهر للركاب)',
                        icon: Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: emailCtrl,
                        label: 'البريد الإلكتروني',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: busCtrl,
                        label: 'رقم المركبة / الباص',
                        icon: Icons.directions_bus_outlined,
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: routeCtrl,
                        label: 'اتجاه الخط العام (من → إلى)',
                        icon: Icons.route_outlined,
                        action: TextInputAction.next,
                        hint: 'مثال: الجيزة → دوار الشرق الأوسط',
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: routeDetailCtrl,
                        label: 'مسير الخط التفصيلي (المناطق)',
                        icon: Icons.alt_route_rounded,
                        action: TextInputAction.done,
                        maxLines: 3,
                        hint:
                            'مثال: الجيزة - القسطل - شارع المطار - جامعة الإسراء - ...',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedCapacity,
                        decoration: InputDecoration(
                          labelText: 'نوع الباص / عدد الركاب',
                          prefixIcon: const Icon(Icons.event_seat_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: BusCapacity.options
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c,
                                child: Text(BusCapacity.label(c)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setSheetState(() => selectedCapacity = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ملاحظة: اتجاه الخط ومسيره التفصيلي يظهران للراكب عند الضغط على أيقونتك.\n'
                        'تغيير البريد قد يتطلب تأكيداً عبر الرابط المرسل.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'حفظ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) return null;

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final bus = busCtrl.text.trim();
    final route = routeCtrl.text.trim();
    final routeDetail = routeDetailCtrl.text.trim();

    if (name.isEmpty) {
      return const EditProfileResult(
        success: false,
        message: '⚠️ الاسم مطلوب',
      );
    }
    if (email.isEmpty || !email.contains('@')) {
      return const EditProfileResult(
        success: false,
        message: '⚠️ أدخل بريداً إلكترونياً صالحاً',
      );
    }

    final firestore = FirestoreService();
    final updates = <String, dynamic>{
      'fullName': name,
      'phoneNumber': phone,
      'busNumber': bus,
      'route': route,
      'routeDetail': routeDetail,
      'email': email,
      'capacity': selectedCapacity,
    };

    String? note;
    final fbUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final emailChanged = email.toLowerCase() != user.email.toLowerCase();

    if (fbUser != null && emailChanged) {
      try {
        await fbUser.verifyBeforeUpdateEmail(email);
        note =
            '📧 تم إرسال رابط تأكيد للبريد الجديد. أكّده ثم سجّل الدخول مجدداً.';
      } on firebase_auth.FirebaseAuthException catch (e) {
        updates.remove('email');
        if (e.code == 'requires-recent-login') {
          note =
              '🔒 لتغيير البريد، سجّل الخروج ثم الدخول مجدداً وحاول مرة أخرى.';
        } else if (e.code == 'email-already-in-use') {
          note = '⚠️ هذا البريد مستخدم بالفعل';
        } else {
          note = '⚠️ تعذر تحديث البريد: ${e.message ?? e.code}';
        }
      }
    }

    try {
      await firestore.updateUserData(user.uid, updates);
      if (note != null) {
        return EditProfileResult(success: true, message: note);
      }
      return const EditProfileResult(
        success: true,
        message: '✅ تم تحديث الملف الشخصي',
      );
    } catch (_) {
      return const EditProfileResult(
        success: false,
        message: '❌ فشل التحديث',
      );
    }
  }

  static Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    TextInputAction action = TextInputAction.next,
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textInputAction: action,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}
