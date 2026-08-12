import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../core/widgets/change_password_sheet.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
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

  bool _notificationsEnabled = true;
  bool _prefsLoaded = false;
  bool _disposed = false;

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
    _disposed = true;
    // إزالة المستمعين قبل dispose لمنع "used after being disposed"
    _busy.dispose();
    _uploading.dispose();
    super.dispose();
  }

  void _setBusy(bool value) {
    if (_disposed) return;
    try {
      _busy.value = value;
    } catch (_) {}
  }

  void _setUploading(bool value) {
    if (_disposed) return;
    try {
      _uploading.value = value;
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    if (!mounted || _disposed) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _disposed) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(_kNotifications) ?? true;
      _prefsLoaded = true;
    });
  }

  Future<void> _setNotifications(bool value) async {
    if (!mounted || _disposed) return;
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
  }

  void _snack(String message) {
    if (!mounted || _disposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _changePassword() async {
    if (!mounted || _disposed) return;
    final ok = await ChangePasswordSheet.show(context);
    if (!mounted || _disposed) return;
    if (ok) _snack('✅ تم تغيير كلمة المرور. سجّل الدخول مجدداً');
  }

  Future<void> _showPhotoOptions() async {
    if (!mounted || _disposed) return;
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
        _setUploading(v);
        _setBusy(v);
      },
      onMessage: _snack,
    );
  }

  Future<void> _editProfile() async {
    if (!mounted || _disposed) return;
    final auth = context.read<AuthProvider>();
    final user = auth.userData;
    if (user == null) return;

    _setBusy(true);
    try {
      final result = await EditProfileSheet.show(
        context: context,
        user: user,
        onRequestPhotoChange: _showPhotoOptions,
      );
      if (result == null || !mounted || _disposed) return;
      if (result.success) await auth.refreshUserData();
      if (mounted && !_disposed) _snack(result.message);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _logout() async {
    if (!mounted || _disposed) return;
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
          content: Text('$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLanguagePicker() {
    if (!mounted || _disposed) return;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final language = context.watch<LocaleProvider>().displayName;

    return Selector<AuthProvider, UserModel?>(
      selector: (_, auth) => auth.userData,
      shouldRebuild: (prev, next) =>
          prev?.uid != next?.uid ||
          prev?.fullName != next?.fullName ||
          prev?.email != next?.email ||
          prev?.photoUrl != next?.photoUrl ||
          prev?.busNumber != next?.busNumber ||
          prev?.route != next?.route ||
          prev?.capacity != next?.capacity ||
          prev?.isVerified != next?.isVerified ||
          prev?.phoneNumber != next?.phoneNumber,
      builder: (context, user, _) {
        return ProfileBody(
          user: user,
          notificationsEnabled: _notificationsEnabled,
          prefsLoaded: _prefsLoaded,
          language: language,
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
