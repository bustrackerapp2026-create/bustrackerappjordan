import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../core/widgets/change_password_sheet.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';

/// تبويب حساب الراكب — الملف الشخصي + الإعدادات داخل نفس الشاشة.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  static const _kNotifications = 'passenger_notifications_enabled';
  static const _kShareLocation = 'passenger_share_location_enabled';

  bool _notificationsEnabled = true;
  bool _shareLocationEnabled = false;
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
      _shareLocationEnabled = prefs.getBool(_kShareLocation) ?? false;
      _prefsLoaded = true;
    });
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
  }

  Future<void> _setShareLocation(bool value) async {
    if (!mounted) return;
    final uid = context.read<AuthProvider>().userId;

    setState(() => _shareLocationEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShareLocation, value);

    if (uid != null) {
      try {
        await _firestoreService.updateUserData(uid, {
          'isSharingLocation': value,
        });
      } catch (_) {}
    }
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
      _snack('✅ تم تغيير كلمة المرور بنجاح');
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
    final l10n = AppLocalizations.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.logout,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await auth.signOut();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$e'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? AppTheme.darkSurface : Colors.white;

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
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
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
                        color: Colors.grey.shade400,
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
                  Text(
                    'اضغط لتغيير الصورة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
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
    } catch (e) {
      if (mounted) _snack('❌ فشل التحديث');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  void _showLanguagePicker() {
    if (!mounted) return;
    final localeProvider = context.read<LocaleProvider>();
    final l10n = AppLocalizations.of(context);

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
              Text(
                l10n.chooseLanguage,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              ListTile(
                title: Text(l10n.arabic),
                trailing: localeProvider.isArabic
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await localeProvider.setArabic();
                  _snack(l10n.languageChanged);
                },
              ),
              ListTile(
                title: Text(l10n.english),
                trailing: localeProvider.isEnglish
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await localeProvider.setEnglish();
                  _snack(l10n.languageChanged);
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final localeProvider = context.watch<LocaleProvider>();
    final l10n = AppLocalizations.of(context);
    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : l10n.passenger;
    final initial = name.isNotEmpty ? name.characters.first : 'P';
    final email = user?.email ?? '';
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Scaffold(
      backgroundColor: bgColor,
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
                              border: Border.all(color: Colors.white, width: 2),
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
                              style: TextStyle(fontSize: 13, color: muted),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '👤 ${user?.displayUserType ?? l10n.passenger}',
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
              _sectionTitle(l10n.settings),
              _sectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.notifications_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(
                        l10n.notifications,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(l10n.notificationsSubtitle),
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
                      title: l10n.language,
                      subtitle: localeProvider.displayName,
                      onTap: _showLanguagePicker,
                    ),
                    _divider(),
                    SwitchListTile(
                      secondary: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(
                        l10n.darkMode,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isDark ? l10n.darkModeOn : l10n.darkModeOff,
                      ),
                      value: isDark,
                      activeThumbColor: AppTheme.primaryColor,
                      onChanged: (value) {
                        context.read<ThemeProvider>().setDarkMode(value);
                      },
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
                  label: Text(
                    l10n.logout,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          if (_savingProfile || _uploadingPhoto)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child, EdgeInsetsGeometry? padding}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: onSurface),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: onSurface.withValues(alpha: 0.6)),
            )
          : null,
      trailing: Icon(
        Icons.chevron_left,
        color: onSurface.withValues(alpha: 0.35),
      ),
      onTap: onTap,
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Theme.of(context).dividerColor);
}
