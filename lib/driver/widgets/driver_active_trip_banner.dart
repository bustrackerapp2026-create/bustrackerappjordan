import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/trip_model.dart';

/// شريط مختصر لرحلة راكب مقبولة على خريطة السائق.
class DriverActiveTripBanner extends StatelessWidget {
  final TripModel trip;
  final VoidCallback? onFocusPickup;
  final VoidCallback? onComplete;
  final bool busy;

  const DriverActiveTripBanner({
    super.key,
    required this.trip,
    this.onFocusPickup,
    this.onComplete,
    this.busy = false,
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
    final hasCoords = trip.pickupLat != null && trip.pickupLng != null;

    return Material(
      elevation: 7,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_pin_circle_rounded,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رحلة نشطة · $_passengerLabel',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'صعود: $pickup',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'وجهة: $dropoff',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (hasCoords && onFocusPickup != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onFocusPickup,
                      icon: const Icon(Icons.center_focus_strong_rounded,
                          size: 18),
                      label: const Text(
                        'موقع الراكب',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF99F6E4)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (hasCoords && onFocusPickup != null && onComplete != null)
                  const SizedBox(width: 8),
                if (onComplete != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: busy ? null : onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'تم الصعود',
                              style: TextStyle(fontWeight: FontWeight.w800),
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
}
