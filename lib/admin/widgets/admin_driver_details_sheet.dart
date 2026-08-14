import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../screens/tabs/mixins/driver_manager_mixin.dart';

/// ورقة معلومات السائق عند الضغط على أيقونته في خريطة الأدمن.
class AdminDriverDetailsSheet extends StatelessWidget {
  final DriverLocationData driver;

  const AdminDriverDetailsSheet({super.key, required this.driver});

  static Future<void> show(BuildContext context, DriverLocationData driver) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminDriverDetailsSheet(driver: driver),
    );
  }

  String get _updatedLabel {
    final t = driver.lastUpdated;
    if (t == null) return '—';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'منذ ثوانٍ';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return 'منذ ${diff.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final online = driver.isOnline;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 16),
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
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: online
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
                child: Icon(
                  Icons.directions_bus_rounded,
                  color: online ? Colors.green.shade700 : Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: online ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          online ? 'متصل الآن' : 'غير متصل',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: online
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _row(Icons.confirmation_number_outlined, 'رقم الباص',
              (driver.busNumber?.trim().isNotEmpty == true)
                  ? driver.busNumber!.trim()
                  : '—'),
          _row(Icons.route_outlined, 'المسار',
              (driver.route?.trim().isNotEmpty == true)
                  ? driver.route!.trim()
                  : '—'),
          _row(Icons.phone_outlined, 'الهاتف',
              (driver.phoneNumber?.trim().isNotEmpty == true)
                  ? driver.phoneNumber!.trim()
                  : '—'),
          _row(Icons.update_rounded, 'آخر تحديث', _updatedLabel),
          _row(
            Icons.place_outlined,
            'الإحداثيات',
            '${driver.latitude.toStringAsFixed(5)}, ${driver.longitude.toStringAsFixed(5)}',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'إغلاق',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
