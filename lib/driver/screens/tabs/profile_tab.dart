import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/change_password_sheet.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';
import '../../widgets/profile/edit_profile_sheet.dart';
import '../../widgets/profile/profile_body.dart';
import '../../widgets/profile/profile_photo_sheet.dart';

/// تبويب حساب السائق — منطق خفيف + إعادة بناء انتقائية.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with AutomaticKeepAliveClientMixin {
  static const _kNotifications = 'driver_notifications_enabled';
  static const _kLanguage = 'driver_language';

  bool _notificationsEnabled = true;
  String _language = 'العربية';
  bool _prefsLoaded = false;

  /// لا يعيد بناء ListView عند الرفع/الحفظ
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  final ValueNotifier<bool> _uploading = ValueNotifier(false);

  final FirestoreService _firestoreService = FirestoreService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
  }

  @override
  void dispose() {
    _busy.dispose();
    _uploading.dispose();
    super.dispose();
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
    if (ok) _snack('✅ تم تغيير كلمة المرور. سجّل الدخول مجدداً');
  }

  Future<void> _showPhotoOptions() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null) {
      _snack('⚠️ يجب تسجيل الدخول أولاً');
      return;
    }

    await ProfilePhotoActions.showOptions(
      context: context,
      uid: uid,
      hasPhoto: auth.userData?.hasPhoto == true,
      onRefreshUser: auth.refreshUserData,
      onUploadingChanged: (v) {
        _uploading.value = v;
        _busy.value = v;
      },
      onMessage: _snack,
    );
  }

  Future<void> _editProfile() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.userData;
    if (user == null) return;

    _busy.value = true;
    try {
      final result = await EditProfileSheet.show(
        context: context,
        user: user,
        onRequestPhotoChange: _showPhotoOptions,
      );
      if (result == null || !mounted) return;
      if (result.success) await auth.refreshUserData();
      if (mounted) _snack(result.message);
    } finally {
      _busy.value = false;
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin

    // يعيد البناء فقط عند تغيّر userData (وليس أي notifyListeners آخر)
    return Selector<AuthProvider, UserModel?>(
      selector: (_, auth) => auth.userData,
      shouldRebuild: (prev, next) =>
          prev?.uid != next?.uid ||
          prev?.fullName != next?.fullName ||
          prev?.email != next?.email ||
          prev?.photoUrl != next?.photoUrl ||
          prev?.busNumber != next?.busNumber ||
          prev?.route != next?.route ||
          prev?.isVerified != next?.isVerified ||
          prev?.phoneNumber != next?.phoneNumber,
      builder: (context, user, _) {
        return ProfileBody(
          user: user,
          notificationsEnabled: _notificationsEnabled,
          prefsLoaded: _prefsLoaded,
          language: _language,
          busyNotifier: _busy,
          uploadingNotifier: _uploading,
          onPhotoTap: _showPhotoOptions,
          onEditProfile: _editProfile,
          onChangePassword: _changePassword,
          onNotificationsChanged: _setNotifications,
          onLanguageTap: _showLanguagePicker,
          onLogout: _logout,
          onSnack: _snack,
        );
      },
    );
  }
}
