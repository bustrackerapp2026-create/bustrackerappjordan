import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/change_password_sheet.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';

/// تبويب حساب السائق — ملف شخصي + بيانات الباص + إعدادات.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  static const _kNotifications = 'driver_notifications_enabled';
  static const _kLanguage = 'driver_language';

  bool _notificationsEnabled = true;
  String _language = 'العربية';
  bool _prefsLoaded = false;
  bool _savingProfile = false;
  bool _uploadingPhoto = false;

  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
  }

  Future<void> _loadPrefs() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _notificationsEnabled = prefs.getBool(_kNotifications) ?? true;
      _language = prefs.getString(_kLanguage) ?? 'العربية';
      _prefsLoaded = true;
    });
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
  }

  Future<void> _setLanguage(String value) async {
    setState(() => _language = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, value);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _changePassword() async {
    if (!mounted) return;
    final ok = await ChangePasswordSheet.show(context);
    if (!mounted) return;
    if (ok) {
      _snack('✅ تم تغيير كلمة المرور. سجّل الدخول مجدداً');
    }
  }

  Future<void> _removeProfilePhoto() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      await _storageService.deleteProfilePhoto(uid);
      await _firestoreService.updateUserData(uid, {'photoUrl': null});
      await auth.refreshUserData();
      if (!mounted) return;
      _snack('تم إزالة الصورة الشخصية');
    } catch (e) {
      if (mounted) _snack('❌ تعذر حذف الصورة');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _showPhotoOptions() async {
    if (!mounted) return;
    final hasPhoto =
        context.read<AuthProvider>().userData?.hasPhoto == true;

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
                _pickFrom(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('التقاط صورة'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFrom(ImageSource.camera);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('إزالة الصورة'),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeProfilePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFrom(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (xfile == null || !mounted) return;

      final auth = context.read<AuthProvider>();
      final uid = auth.userId;
      if (uid == null) {
        _snack('⚠️ يجب تسجيل الدخول أولاً');
        return;
      }

      setState(() => _uploadingPhoto = true);

      final file = File(xfile.path);
      final downloadUrl = await _storageService.uploadProfilePhoto(
        uid: uid,
        file: file,
      );

      await _firestoreService.updateUserData(uid, {'photoUrl': downloadUrl});
      await auth.refreshUserData();

      if (!mounted) return;
      _snack('✅ تم رفع الصورة الشخصية بنجاح');
    } catch (e) {
      if (!mounted) return;
      _snack('❌ تعذر رفع الصورة. تأكد من الاتصال والصلاحيات.');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الخروج'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uid = auth.userId;
      if (uid != null) {
        try {
          await _firestoreService.updateUserData(uid, {'isOnline': false});
        } catch (_) {}
      }
      await auth.signOut();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تسجيل الخروج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editProfile() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.userData;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.phoneNumber ?? '');
    final emailCtrl = TextEditingController(text: user.email);
    final busCtrl = TextEditingController(text: user.busNumber ?? '');
    final routeCtrl = TextEditingController(text: user.route ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx, false);
                        _showPhotoOptions();
                      },
                      child: Stack(
                        alignment: Alignment.bottomLeft,
                        children: [
                          _buildAvatar(
                            photoUrl: user.photoUrl,
                            initial: user.fullName.isNotEmpty
                                ? user.fullName.characters.first
                                : 'س',
                            size: 88,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'اضغط لتغيير الصورة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'الاسم الكامل',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: busCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'رقم الباص',
                      prefixIcon: const Icon(Icons.directions_bus_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: routeCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'المسار / الخط',
                      prefixIcon: const Icon(Icons.route_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ملاحظة: تغيير البريد قد يتطلب تأكيداً عبر الرابط المرسل.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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

    if (saved != true || !mounted) return;

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final bus = busCtrl.text.trim();
    final route = routeCtrl.text.trim();

    if (name.isEmpty) {
      _snack('⚠️ الاسم مطلوب');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _snack('⚠️ أدخل بريداً إلكترونياً صالحاً');
      return;
    }

    setState(() => _savingProfile = true);
    try {
      final updates = <String, dynamic>{
        'fullName': name,
        'phoneNumber': phone,
        'busNumber': bus,
        'route': route,
        'email': email,
      };

      final fbUser = firebase_auth.FirebaseAuth.instance.currentUser;
      final emailChanged = email.toLowerCase() != user.email.toLowerCase();

      if (fbUser != null && emailChanged) {
        try {
          await fbUser.verifyBeforeUpdateEmail(email);
          if (!mounted) return;
          _snack(
            '📧 تم إرسال رابط تأكيد للبريد الجديد. أكّده ثم سجّل الدخول مجدداً.',
          );
        } on firebase_auth.FirebaseAuthException catch (e) {
          if (!mounted) return;
          if (e.code == 'requires-recent-login') {
            _snack(
              '🔒 لتغيير البريد، سجّل الخروج ثم الدخول مجدداً وحاول مرة أخرى.',
            );
            updates.remove('email');
          } else if (e.code == 'email-already-in-use') {
            _snack('⚠️ هذا البريد مستخدم بالفعل');
            updates.remove('email');
          } else {
            _snack('⚠️ تعذر تحديث البريد: ${e.message ?? e.code}');
            updates.remove('email');
          }
        }
      }

      await _firestoreService.updateUserData(user.uid, updates);
      await auth.refreshUserData();

      if (!mounted) return;

      final emailStillInUpdates = updates.containsKey('email');
      if (!emailChanged || !emailStillInUpdates) {
        _snack('✅ تم تحديث الملف الشخصي');
      }
    } catch (_) {
      if (mounted) _snack('❌ فشل التحديث');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  void _showLanguagePicker() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'اختر اللغة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              ListTile(
                title: const Text('العربية'),
                trailing: _language == 'العربية'
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  _setLanguage('العربية');
                  Navigator.pop(ctx);
                  _snack('🌐 اللغة: العربية');
                },
              ),
              ListTile(
                title: const Text('English'),
                trailing: _language == 'English'
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  _setLanguage('English');
                  Navigator.pop(ctx);
                  _snack('🌐 Language: English');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar({
    String? photoUrl,
    required String initial,
    double size = 64,
  }) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasPhoto
            ? null
            : LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.75),
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userData;
    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'سائق';
    final initial = name.isNotEmpty ? name.characters.first : 'س';
    final email = user?.email ?? '';
    final bus = user?.busNumber?.trim().isNotEmpty == true
        ? user!.busNumber!.trim()
        : 'غير محدد';
    final route = user?.route?.trim().isNotEmpty == true
        ? user!.route!.trim()
        : 'غير محدد';
    final verified = user?.isVerified == true;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _sectionCard(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _showPhotoOptions,
                        child: Stack(
                          alignment: Alignment.bottomLeft,
                          children: [
                            _buildAvatar(
                              photoUrl: user?.photoUrl,
                              initial: initial,
                              size: 64,
                            ),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _chip(
                                  '🚗 ${user?.displayUserType ?? 'سائق'}',
                                  AppTheme.primaryColor,
                                ),
                                _chip(
                                  verified ? '✅ معتمد' : '⏳ بانتظار الاعتماد',
                                  verified
                                      ? Colors.green.shade700
                                      : Colors.orange.shade800,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionTitle('بيانات العمل'),
                _sectionCard(
                  child: Column(
                    children: [
                      _infoRow(Icons.directions_bus_outlined, 'رقم الباص', bus),
                      const SizedBox(height: 10),
                      _infoRow(Icons.route_outlined, 'المسار / الخط', route),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionTitle('الحساب'),
                _sectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _tile(
                        icon: Icons.edit_outlined,
                        title: 'تعديل الملف الشخصي',
                        subtitle: 'الاسم · الهاتف · البريد · الباص · المسار',
                        onTap: _editProfile,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.lock_outline,
                        title: 'تغيير كلمة المرور',
                        subtitle: 'تحديث كلمة المرور عبر Firebase',
                        onTap: _changePassword,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionTitle('الإعدادات'),
                _sectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(
                          Icons.notifications_outlined,
                          color: AppTheme.primaryColor,
                        ),
                        title: const Text(
                          'الإشعارات',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('تنبيهات الرحلات والطلبات'),
                        value: _prefsLoaded ? _notificationsEnabled : true,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: _setNotifications,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.language,
                        title: 'اللغة',
                        subtitle: _language,
                        onTap: _showLanguagePicker,
                      ),
                      _divider(),
                      SwitchListTile(
                        secondary: const Icon(
                          Icons.dark_mode_outlined,
                          color: AppTheme.primaryColor,
                        ),
                        title: const Text(
                          'الوضع الليلي',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('قريباً'),
                        value: false,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: (_) => _snack('🔜 الوضع الليلي قريباً'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionTitle('الدعم والمعلومات'),
                _sectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _tile(
                        icon: Icons.help_outline,
                        title: 'المساعدة',
                        subtitle: 'أسئلة شائعة ودعم',
                        onTap: () => _snack('📬 الدعم قريباً'),
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.info_outline,
                        title: 'عن التطبيق',
                        subtitle: 'الإصدار 1.0.0+1',
                        onTap: () =>
                            _snack('📱 Bus Tracker Jordan — 1.0.0+1'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'تسجيل الخروج',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '© 2026 Bus Tracker Jordan',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
            if (_savingProfile || _uploadingPhoto)
              Container(
                color: Colors.black26,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (_uploadingPhoto) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'جاري رفع الصورة...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Icon(Icons.chevron_left, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade200);
}
