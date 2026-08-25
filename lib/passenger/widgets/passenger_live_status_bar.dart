import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// شريط حالة التتبع الحي — بطاقة زجاجية أنيقة أسفل خريطة الراكب.
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

    final title = hasDest
        ? 'نحو $destinationName'
        : (nearbyMode ? 'خطوط قربك' : routeName);
    final subtitle =
        hasLive ? '$liveCount باص حي الآن' : 'لا يوجد باص حي حالياً';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasLive
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFF1F5F9),
                ),
                child: Icon(
                  hasDest
                      ? Icons.flag_rounded
                      : (nearbyMode
                          ? Icons.alt_route_rounded
                          : Icons.directions_bus_rounded),
                  color: hasLive
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF64748B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasLive
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasLive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF14B8A6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'مباشر',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasDest && onClearDestination != null) ...[
                const SizedBox(width: 4),
                Material(
                  color: const Color(0xFFF1F5F9),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onClearDestination,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (nearbyHint != null && nearbyHint!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                nearbyHint!,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
