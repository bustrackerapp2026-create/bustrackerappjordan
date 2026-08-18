import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// شريط حالة التتبع الحي أسفل خريطة الراكب.
class PassengerLiveStatusBar extends StatelessWidget {
  final String routeName;
  final int liveCount;
  final AppLocalizations l10n;
  final bool nearbyMode;
  final String? nearbyHint;
  final String? destinationName;
  final VoidCallback? onClearDestination;

  const PassengerLiveStatusBar({
    super.key,
    required this.routeName,
    required this.liveCount,
    required this.l10n,
    this.nearbyMode = false,
    this.nearbyHint,
    this.destinationName,
    this.onClearDestination,
  });

  @override
  Widget build(BuildContext context) {
    final hasLive = liveCount > 0;
    final hasDest =
        destinationName != null && destinationName!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasLive
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (hasLive)
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      ),
                    ),
                  CircleAvatar(
                    backgroundColor: hasLive
                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                        : Colors.grey.shade100,
                    radius: 18,
                    child: Icon(
                      hasDest
                          ? Icons.flag_rounded
                          : (nearbyMode
                              ? Icons.alt_route_rounded
                              : Icons.directions_bus_rounded),
                      color: hasLive ? AppTheme.primaryColor : Colors.grey,
                      size: 20,
                    ),
                  ),
                  if (hasLive)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasDest
                          ? 'باصات نحو وجهتك'
                          : (nearbyMode
                              ? 'باصات تمر من موقعك'
                              : l10n.liveTracking),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLive
                          ? l10n.liveBusesCount(liveCount)
                          : (hasDest || nearbyMode
                              ? 'لا باص حي على هذه الخطوط حالياً'
                              : l10n.noLiveBuses),
                      style: TextStyle(
                        fontSize: 12,
                        color: hasLive
                            ? const Color(0xFF16A34A)
                            : Colors.grey.shade600,
                        fontWeight:
                            hasLive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: hasDest
                        ? const Color(0xFF7C3AED)
                        : (nearbyMode
                            ? const Color(0xFF0F766E)
                            : AppTheme.primaryColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    routeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (hasDest) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_rounded,
                      size: 16, color: Color(0xFF6D28D9)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الوجهة: $destinationName',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Color(0xFF5B21B6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onClearDestination != null)
                    InkWell(
                      onTap: onClearDestination,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF7C3AED)),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (nearbyMode &&
              nearbyHint != null &&
              nearbyHint!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                nearbyHint!,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Color(0xFF065F46),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else if (!hasLive && !nearbyMode) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'جرّب «باصات من هنا» ثم «إلى أين؟» لتصفية الباصات نحو وجهتك.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
