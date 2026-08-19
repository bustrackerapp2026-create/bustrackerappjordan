import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/trip_model.dart';

/// شريط طلب صعود على خريطة السائق.
class DriverPendingRequestBanner extends StatelessWidget {
  final TripModel trip;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onFocusPickup;
  final VoidCallback? onDismiss;

  const DriverPendingRequestBanner({
    super.key,
    required this.trip,
    this.busy = false,
    this.onAccept,
    this.onReject,
    this.onFocusPickup,
    this.onDismiss,
  });

  String get _passengerLabel {
    final name = trip.passengerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = trip.passengerId;
    if (id.isEmpty) return 'راكب';
    return id.length > 8 ? '${id.substring(0, 8)}…' : id;
  }

  @override
  Widget build(BuildContext context) {
    final pickup =
        trip.pickupPoint.trim().isEmpty ? 'نقطة صعود' : trip.pickupPoint.trim();
    final dropoff = trip.dropoffPoint.trim().isEmpty
        ? 'على طول الخط'
        : trip.dropoffPoint.trim();
    final route = trip.route?.trim();
    final hasPickupCoords = trip.pickupLat != null && trip.pickupLng != null;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFDBA74), width: 1.4),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hail_rounded,
                    color: Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'طلب صعود جديد',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _passengerLabel,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: busy ? null : onDismiss,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _row(Icons.my_location_rounded, 'الصعود', pickup),
            const SizedBox(height: 6),
            _row(Icons.flag_rounded, 'الوجهة', dropoff),
            if (route != null && route.isNotEmpty) ...[
              const SizedBox(height: 6),
              _row(Icons.route_rounded, 'الخط', route),
            ],
            if (hasPickupCoords && onFocusPickup != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : onFocusPickup,
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                  label: const Text(
                    'عرض موقع الراكب',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'رفض',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onAccept,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      busy ? 'جاري…' : 'قبول',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
