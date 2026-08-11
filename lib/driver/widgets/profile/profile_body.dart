import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import 'profile_ui.dart';

/// جسم شاشة ملف السائق — مُقسَّم لتقليل إعادة البناء.
class ProfileBody extends StatelessWidget {
  final UserModel? user;
  final bool notificationsEnabled;
  final bool prefsLoaded;
  final String language;
  final ValueNotifier<bool> busyNotifier;
  final ValueNotifier<bool> uploadingNotifier;
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
    required this.busyNotifier,
    required this.uploadingNotifier,
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
    final photoUrl = user?.photoUrl;
    final userType = user?.displayUserType ?? 'سائق';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Stack(
          children: [
            // القائمة لا تُعاد بناؤها عند تغيّر حالة الرفع فقط
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              cacheExtent: 400,
              children: [
                RepaintBoundary(
                  child: _HeaderCard(
                    name: name,
                    initial: initial,
                    email: email,
                    verified: verified,
                    photoUrl: photoUrl,
                    userType: userType,
                    onPhotoTap: onPhotoTap,
                  ),
                ),
                const SizedBox(height: 14),
                const _SectionLabel('بيانات العمل'),
                RepaintBoundary(
                  child: ProfileUi.sectionCard(
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
                ),
                const SizedBox(height: 14),
                const _SectionLabel('الحساب'),
                RepaintBoundary(
                  child: ProfileUi.sectionCard(
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
                ),
                const SizedBox(height: 14),
                const _SectionLabel('الإعدادات'),
                RepaintBoundary(
                  child: _SettingsCard(
                    notificationsEnabled: notificationsEnabled,
                    prefsLoaded: prefsLoaded,
                    language: language,
                    onNotificationsChanged: onNotificationsChanged,
                    onLanguageTap: onLanguageTap,
                    onSnack: onSnack,
                  ),
                ),
                const SizedBox(height: 14),
                const _SectionLabel('الدعم والمعلومات'),
                RepaintBoundary(
                  child: ProfileUi.sectionCard(
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

            // طبقة التحميل فقط — لا تعيد بناء ListView
            ValueListenableBuilder<bool>(
              valueListenable: busyNotifier,
              builder: (context, busy, _) {
                if (!busy) return const SizedBox.shrink();
                return ValueListenableBuilder<bool>(
                  valueListenable: uploadingNotifier,
                  builder: (context, uploading, _) {
                    return const _BusyOverlay(uploading: true);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => ProfileUi.sectionTitle(text);
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String initial;
  final String email;
  final bool verified;
  final String? photoUrl;
  final String userType;
  final VoidCallback onPhotoTap;

  const _HeaderCard({
    required this.name,
    required this.initial,
    required this.email,
    required this.verified,
    required this.photoUrl,
    required this.userType,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileUi.sectionCard(
      child: Row(
        children: [
          ProfileUi.avatarWithCamera(
            photoUrl: photoUrl,
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
                    ProfileUi.chip('🚗 $userType', AppTheme.primaryColor),
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

class _SettingsCard extends StatelessWidget {
  final bool notificationsEnabled;
  final bool prefsLoaded;
  final String language;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onLanguageTap;
  final void Function(String message) onSnack;

  const _SettingsCard({
    required this.notificationsEnabled,
    required this.prefsLoaded,
    required this.language,
    required this.onNotificationsChanged,
    required this.onLanguageTap,
    required this.onSnack,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileUi.sectionCard(
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
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  final bool uploading;
  const _BusyOverlay({required this.uploading});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black26,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (uploading) ...[
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
    );
  }
}
