import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import 'profile_ui.dart';

/// جسم شاشة ملف السائق (الواجهة فقط).
class ProfileBody extends StatelessWidget {
  final UserModel? user;
  final bool notificationsEnabled;
  final bool prefsLoaded;
  final String language;
  final bool savingProfile;
  final bool uploadingPhoto;
  final VoidCallback onPhotoTap;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onLanguageTap;
  final VoidCallback onLogout;
  final void Function(String message) onSnack;

  const ProfileBody({
    super.key,
    required this.user,
    required this.notificationsEnabled,
    required this.prefsLoaded,
    required this.language,
    required this.savingProfile,
    required this.uploadingPhoto,
    required this.onPhotoTap,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onNotificationsChanged,
    required this.onLanguageTap,
    required this.onLogout,
    required this.onSnack,
  });

  @override
  Widget build(BuildContext context) {
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
                _headerCard(
                  name: name,
                  initial: initial,
                  email: email,
                  verified: verified,
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
                        onTap: onEditProfile,
                      ),
                      ProfileUi.divider(),
                      ProfileUi.tile(
                        icon: Icons.lock_outline,
                        title: 'تغيير كلمة المرور',
                        subtitle: 'تحديث كلمة المرور عبر Firebase',
                        onTap: onChangePassword,
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
                        value: prefsLoaded ? notificationsEnabled : true,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: onNotificationsChanged,
                      ),
                      ProfileUi.divider(),
                      ProfileUi.tile(
                        icon: Icons.language,
                        title: 'اللغة',
                        subtitle: language,
                        onTap: onLanguageTap,
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
                        onChanged: (_) => onSnack('🔜 الوضع الليلي قريباً'),
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
                        onTap: () => onSnack('📬 الدعم قريباً'),
                      ),
                      ProfileUi.divider(),
                      ProfileUi.tile(
                        icon: Icons.info_outline,
                        title: 'عن التطبيق',
                        subtitle: 'الإصدار 1.0.0+1',
                        onTap: () =>
                            onSnack('📱 Bus Tracker Jordan — 1.0.0+1'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onLogout,
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
            if (savingProfile || uploadingPhoto)
              Container(
                color: Colors.black26,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (uploadingPhoto) ...[
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

  Widget _headerCard({
    required String name,
    required String initial,
    required String email,
    required bool verified,
  }) {
    return ProfileUi.sectionCard(
      child: Row(
        children: [
          ProfileUi.avatarWithCamera(
            photoUrl: user?.photoUrl,
            initial: initial,
            onTap: onPhotoTap,
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
    );
  }
}
