import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../screens/tabs/stat_details_screen.dart';
import '../../screens/tabs/landmark_stats_details_screen.dart';
import 'verify_drivers_models.dart';

class VerifyDriversHeroSummaryCard extends StatelessWidget {
  final int totalUsers;
  final int activeTotal;
  final AppLocalizations l10n;

  const VerifyDriversHeroSummaryCard({
    super.key,
    required this.totalUsers,
    required this.activeTotal,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.registeredStats,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalUsers',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.activeNow(activeTotal),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class VerifyDriversCompactSectionCard extends StatelessWidget {
  final String sectionId;
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<VerifyDriversStatItem> items;
  final bool isLive;
  final String liveLabel;

  const VerifyDriversCompactSectionCard({
    super.key,
    required this.sectionId,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.liveLabel,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLive) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        liveLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 135,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 58,
            ),
            itemBuilder: (context, index) {
              final uniqueHeroTag =
                  'hero_${sectionId}_${items[index].queryType}_$index';
              return VerifyDriversUltraMiniStatCard(
                item: items[index],
                heroTag: uniqueHeroTag,
              );
            },
          ),
        ],
      ),
    );
  }
}

class VerifyDriversUltraMiniStatCard extends StatelessWidget {
  final VerifyDriversStatItem item;
  final String heroTag;

  const VerifyDriversUltraMiniStatCard({
    super.key,
    required this.item,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${item.label}: ${item.count}',
      button: true,
      child: Hero(
        tag: heroTag,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!context.mounted) return;
              final q = item.queryType;
              // إحصائيات المعالم → قائمة معالم (وليس مستخدمين)
              if (q.startsWith('landmarks_')) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LandmarkStatsDetailsScreen(
                      title: item.label,
                      queryType: q,
                    ),
                  ),
                );
                return;
              }
              // نقاط التجمع: لا تُعرض كقائمة مستخدمين
              if (q.startsWith('points_')) {
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatDetailsScreen(
                    title: item.label,
                    queryType: item.queryType,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.color.withValues(alpha: 0.14),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: item.color, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.count.toString(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: item.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerifyDriversLoadingSkeleton extends StatelessWidget {
  const VerifyDriversLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class VerifyDriversErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final AppLocalizations l10n;

  const VerifyDriversErrorView({
    super.key,
    required this.onRetry,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(l10n.retry, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
