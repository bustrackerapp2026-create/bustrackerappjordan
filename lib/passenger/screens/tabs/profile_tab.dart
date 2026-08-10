import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/firestore_service.dart';

/// تبويب حساب الراكب — الملف الشخصي + الإعدادات داخل نفس الشاشة.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  static const _kNotifications = 'passenger_notifications_enabled';
  static const _kShareLocation = 'passenger_share_location_enabled';
  static const _kLanguage = 'passenger_language';
  static const _kPhotoPathPrefix = 'passenger_photo_path_';

  bool _notificationsEnabled = true;
  bool _shareLocationEnabled = false;
  String _language = 'العربية';
  bool _prefsLoaded = false;
  String? _localPhotoPath;
  bool _savingProfile = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  String _photoKeyFor(String? uid) => '$_kPhotoPathPrefix${uid ?? 'guest'}';

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = context.read<AuthProvider>().userId;
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(_kNotifications) ?? true;
      _shareLocationEnabled = prefs.getBool(_kShareLocation) ?? false;
      _language = prefs.getString(_kLanguage) ?? 'العربية';
      final path = prefs.getString(_photoKeyFor(uid));
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        _localPhotoPath = path;
      }
      _prefsLoaded = true;
    });
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
  }

  Future<void> _setShareLocation(bool value) async {
    setState(() => _shareLocationEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShareLocation, value);

    final uid = context.read<AuthProvider>().userId;
    if (uid != null) {
      try {
        await FirestoreService().updateUserData(uid, {
          'isSharingLocation': value,
        });
      } catch (_) {}
    }
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

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (_localPhotoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('إزالة الصورة'),
                onTap: () => Navigator.pop(ctx, null),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    // إزالة الصورة
    if (source == null && _localPhotoPath != null) {
      // إذا أغلق المستخدم الورقة بدون اختيار — لا نحذف
      // نميّز الحذف عبر قائمة «إزالة» التي ترجع null مع وجود صورة:
      // نعيد فتح منطق الحذف فقط عند الضغط على إزالة (source null من ListTile).
      // لتبسيط: إن أُغلقت الورقة بدون اختيار لا نفعل شيئاً.
      // لذلك نستخدم قيمة خاصة عبر showModal — هنا نتحقق عبر dialog منفصل.
      return;
    }

    if (source == null) return;

    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (xfile == null || !mounted) return;

      final uid = context.read<AuthProvider>().userId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_photoKeyFor(uid), xfile.path);

      if (!mounted) return;
      setState(() => _localPhotoPath = xfile.path);
      _snack('✅ تم تحديث الصورة الشخصية');
    } catch (e) {
      _snack('❌ تعذر اختيار الصورة');
    }
  }

  Future<void> _removeProfilePhoto() async {
    final uid = context.read<AuthProvider>().userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_photoKeyFor(uid));
    if (!mounted) return;
    setState(() => _localPhotoPath = null);
    _snack('تم إزالة الصورة الشخصية');
  }

  Future<void> _showPhotoOptions() async {
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
              onTap: () async {
                Navigator.pop(ctx);
                await _pickFrom(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('التقاط صورة'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickFrom(ImageSource.camera);
              },
            ),
            if (_localPhotoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('إزالة الصورة'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _removeProfilePhoto();
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

      final uid = context.read<AuthProvider>().userId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_photoKeyFor(uid), xfile.path);

      if (!mounted) return;
      setState(() => _localPhotoPath = xfile.path);
      _snack('✅ تم تحديث الصورة الشخصية');
    } catch (e) {
      _snack('❌ تعذر اختيار الصورة. تأكد من صلاحيات الكاميرا/المعرض.');
    }
  }

  Future<void> _logout() async {
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

    if (confirm == true) {
      try {
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
  }

  Future<void> _editProfile() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userData;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.phoneNumber ?? '');
    final emailCtrl = TextEditingController(text: user.email);

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
                  const SizedBox(height: 20),
                  // صورة داخل ورقة التعديل
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx, false);
                        await _showPhotoOptions();
                      },
                      child: Stack(
                        alignment: Alignment.bottomLeft,
                        children: [
                          _buildAvatar(
                            initial: user.fullName.isNotEmpty
                                ? user.fullName.characters.first
                                : 'ر',
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
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ملاحظة: تغيير البريد قد يتطلب إعادة تسجيل الدخول لأسباب أمنية.',
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
        'email': email,
      };

      // تحديث البريد في Firebase Auth إن تغيّر
      final fbUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (fbUser != null &&
          email.toLowerCase() != (user.email).toLowerCase()) {
        try {
          await fbUser.verifyBeforeUpdateEmail(email);
          _snack(
            '📧 تم إرسال رابط تأكيد للبريد الجديد. أكّده ثم سجّل الدخول مجدداً.',
          );
        } on firebase_auth.FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            _snack(
              '🔒 لتغيير البريد، سجّل الخروج ثم الدخول مجدداً وحاول مرة أخرى.',
            );
            // نحفظ الاسم والهاتف فقط
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

      await FirestoreService().updateUserData(user.uid, updates);
      await auth.refreshUserData();
      if (mounted && updates.containsKey('email') == false ||
          email.toLowerCase() == user.email.toLowerCase()) {
        _snack('✅ تم تحديث الملف الشخصي');
      } else if (mounted && updates.containsKey('email')) {
        // تم إرسال التحقق مسبقاً
      } else if (mounted) {
        _snack('✅ تم تحديث البيانات');
      }
    } catch (e) {
      if (mounted) _snack('❌ فشل التحديث');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  void _showLanguagePicker() {
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

  Widget _buildAvatar({required String initial, double size = 64}) {
    final hasPhoto = _localPhotoPath != null &&
        File(_localPhotoPath!).existsSync();

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
                image: FileImage(File(_localPhotoPath!)),
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
        : 'راكب';
    final initial = name.isNotEmpty ? name.characters.first : 'ر';
    final email = user?.email ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                // ── رأس الملف ───────────────────────────────────
                _sectionCard(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _showPhotoOptions,
                        child: Stack(
                          alignment: Alignment.bottomLeft,
                          children: [
                            _buildAvatar(initial: initial, size: 64),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '👤 ${user?.displayUserType ?? 'راكب'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── الحساب ──────────────────────────────────────
                _sectionTitle('الحساب'),
                _sectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _tile(
                        icon: Icons.edit_outlined,
                        title: 'تعديل الملف الشخصي',
                        subtitle: 'الاسم · الهاتف · البريد · الصورة',
                        onTap: _editProfile,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.lock_outline,
                        title: 'تغيير كلمة المرور',
                        subtitle: 'قريباً',
                        onTap: () =>
                            _snack('🔜 سيتم تفعيل تغيير كلمة المرور قريباً'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── الرحلات ─────────────────────────────────────
                _sectionTitle('الرحلات والاستخدام'),
                _sectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _tile(
                        icon: Icons.history,
                        title: 'رحلاتي',
                        subtitle: 'عرض سجل الرحلات والحجوزات',
                        onTap: () {
                          _snack('افتح تبويب «رحلاتي» من الشريط السفلي');
                        },
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.place_outlined,
                        title: 'نقاط التجمع المفضلة',
                        subtitle: 'قريباً',
                        onTap: () => _snack('🔜 المفضلة قريباً'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── الإعدادات ───────────────────────────────────
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
                        subtitle: const Text('تنبيهات الرحلات والتحديثات'),
                        value: _prefsLoaded ? _notificationsEnabled : true,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: _setNotifications,
                      ),
                      _divider(),
                      SwitchListTile(
                        secondary: const Icon(
                          Icons.my_location_outlined,
                          color: AppTheme.primaryColor,
                        ),
                        title: const Text(
                          'مشاركة موقعي',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'إظهار موقعي للإدارة أثناء انتظار الباص',
                        ),
                        value: _prefsLoaded ? _shareLocationEnabled : false,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: _setShareLocation,
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

                // ── الدعم ───────────────────────────────────────
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
                      _divider(),
                      _tile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'سياسة الخصوصية',
                        subtitle: 'كيف نستخدم بياناتك',
                        onTap: () => _snack('🔒 سياسة الخصوصية قريباً'),
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
            if (_savingProfile)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
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
