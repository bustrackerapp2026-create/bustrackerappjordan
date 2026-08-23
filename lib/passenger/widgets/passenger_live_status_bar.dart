import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// شريط حالة التتبع الحي أسفل خريطة الراكب — مظهر أنظف.
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
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasLive
              ? AppTheme.primaryColor.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: hasLive
                        ? [
                            AppTheme.primaryColor.withValues(alpha: 0.18),
                            AppTheme.primaryColor.withValues(alpha: 0.08),
                          ]
                        : [
                            Colors.grey.shade100,
                            Colors.grey.shade50,
                          ],
                  ),
                ),
                child: Icon(
                  hasDest
                      ? Icons.flag_rounded
                      : (nearbyMode
                          ? Icons.alt_route_rounded
                          : Icons.directions_bus_rounded),
                  color: hasLive ? AppTheme.primaryColor : Colors.grey.shade600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDest
                          ? 'نحو $destinationName'
                          : (nearbyMode ? 'خطوط قربك' : routeName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLive
                          ? '$liveCount باص حي الآن'
                          : 'لا يوجد باص حي حالياً',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: hasLive
                            ? AppTheme.primaryColor
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasLive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.secondaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'مباشر',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondaryColor.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasDest && onClearDestination != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'إلغاء الوجهة',
                  onPressed: onClearDestination,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          if (nearbyHint != null && nearbyHint!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                nearbyHint!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.grey.shade800,
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
