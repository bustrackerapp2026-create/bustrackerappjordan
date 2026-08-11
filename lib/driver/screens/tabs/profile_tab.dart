import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/change_password_sheet.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../widgets/profile/edit_profile_sheet.dart';
import '../../widgets/profile/profile_photo_sheet.dart';
import '../../widgets/profile/profile_ui.dart';

/// تبويب حساب السائق — ينسّق الواجهة ويستدعي المكوّنات الفرعية.
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
        if (mounted) setState(() => _uploadingPhoto = v);
      },
      onMessage: _snack,
    );
  }

  Future<void> _editProfile() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.userData;
    if (user == null) return;

    setState(() => _savingProfile = true);
    try {
      final result = await EditProfileSheet.show(
        context: context,
        user: user,
        onRequestPhotoChange: _showPhotoOptions,
      );
      if (result == null || !mounted) return;

      if (result.success) {
        await auth.refreshUserData();
      }
      if (mounted) _snack(result.message);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
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
                ProfileUi.sectionCard(
                  child: Row(
                    children: [
                      ProfileUi.avatarWithCamera(
                        photoUrl: user?.photoUrl,
                        initial: initial,
                        onTap: _showPhotoOptions,
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
                                ProfileUi.chip(
                                  '🚗 ${user?.displayUserType ?? 'سائق'}',
                                  AppTheme.primaryColor,
                                ),
                                ProfileUi.chip(
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
                ProfileUi.sectionTitle('بيانات العمل'),
                ProfileUi.sectionCard(
                  child: Column(
                    children: [
                      ProfileUi.infoRow(
                        Icons.directions_bus_outlined,
                        'رقم الباص',
                        bus,
                      ),
                      const SizedBox(height: 10),
                      ProfileUi.infoRow(
                        Icons.route_outlined,
                        'المسار / الخط',
                        route,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ProfileUi.sectionTitle('الحساب'),
                ProfileUi.sectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ProfileUi.tile(
                        icon: Icons.edit_outlined,
                        title: 'تعديل الملف الشخصي',
                        subtitle: 'الاسم · الهاتف · البريد · الباص · المسار',
                        onTap: _editProfile,
                      ),
                      ProfileUi.divider(),
                      ProfileUi.tile(
                        icon: Icons.lock_outline,
                        title: 'تغيير كلمة المرور',
                        subtitle: 'تحديث كلمة المرور عبر Firebase',
                        onTap: _changePassword,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ProfileUi.sectionTitle('الإعدادات'),
                ProfileUi.sectionCard(
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
                      ProfileUi.divider(),
                      ProfileUi.tile(
                        icon: Icons.language,
                        title: 'اللغة',
                        subtitle: _language,
                        onTap: _showLanguagePicker,
                      ),
                      ProfileUi.divider(),
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
                ProfileUi.sectionTitle('الدعم والمعلومات'),
                ProfileUi.sectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ProfileUi.tile(
                        icon: Icons.help_outline,
                        title: 'المساعدة',
                        subtitle: 'أسئلة شائعة ودعم',
                        onTap: () => _snack('📬 الدعم قريباً'),
                      ),
                      ProfileUi.divider(),
                      ProfileUi.tile(
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
}
