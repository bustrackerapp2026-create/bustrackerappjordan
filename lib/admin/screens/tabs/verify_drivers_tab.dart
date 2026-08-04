import 'package:flutter/material.dart';
import '../../../services/firestore_service.dart';
import '../../screens/tabs/stat_details_screen.dart';

class VerifyDriversTab extends StatefulWidget {
  const VerifyDriversTab({super.key});

  @override
  State<VerifyDriversTab> createState() => _VerifyDriversTabState();
}

class _VerifyDriversTabState extends State<VerifyDriversTab> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _statsFuture = _getAllStats();
  }

  Future<void> _handleRefresh() async {
    if (!mounted) return;
    setState(() {
      _loadData();
    });
    await _statsFuture;
  }

  // ✅ دالة تحويل آمنة 100% تمنع حدوث أخطاء الـ Type Casting وقت التشغيل
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<Map<String, dynamic>> _getAllStats() async {
    try {
      final results = await Future.wait([
        _firestoreService.getAllUsersStats(),
        _firestoreService.getPickupPointsStats(),
      ]);

      final usersStats = results[0];
      final pointsStats = results[1];

      return {
        ...usersStats,
        'total': _toInt(usersStats['total']),
        'passenger': _toInt(usersStats['passenger']),
        'driver': _toInt(usersStats['driver']),
        'service': _toInt(usersStats['service']),
        'bus_company': _toInt(usersStats['bus_company']),
        'verified': _toInt(usersStats['verified']),
        'pending': _toInt(usersStats['pending']),
        'rejected': _toInt(usersStats['rejected']),
        'points_total': _toInt(pointsStats['total']),
        'points_approved': _toInt(pointsStats['approved']),
        'points_pending': _toInt(pointsStats['pending']),
        'active_buses':
            _toInt(usersStats['active_buses'] ?? usersStats['active_driver']),
        'active_passengers': _toInt(usersStats['active_passengers']),
        'active_services': _toInt(usersStats['active_services']),
        'active_others': _toInt(usersStats['active_others']),
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _statsFuture,
                  builder: (context, statsSnapshot) {
                    if (statsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const _LoadingSkeleton();
                    }

                    if (statsSnapshot.hasError) {
                      return _ErrorView(onRetry: () {
                        if (mounted) setState(() => _loadData());
                      });
                    }

                    final stats = statsSnapshot.data ?? {};
                    final totalUsers = _toInt(stats['total']);
                    final activeTotal = _toInt(stats['active_buses']) +
                        _toInt(stats['active_passengers']) +
                        _toInt(stats['active_services']) +
                        _toInt(stats['active_others']);

                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              // 1️⃣ بطاقة الملخص الهيرو
                              _HeroSummaryCard(
                                totalUsers: totalUsers,
                                activeTotal: activeTotal,
                              ),
                              const SizedBox(height: 12),

                              // 2️⃣ قسم المسجلين
                              _CompactSectionCard(
                                sectionId: 'registered',
                                title: 'إحصائيات المسجلين',
                                icon: Icons.people_alt_outlined,
                                iconColor: colorScheme.primary,
                                items: [
                                  _StatItem(
                                      'الإجمالي',
                                      _toInt(stats['total']),
                                      colorScheme.primary,
                                      Icons.group,
                                      'total'),
                                  _StatItem(
                                      'راكب',
                                      _toInt(stats['passenger']),
                                      const Color(0xFF059669),
                                      Icons.person,
                                      'passenger'),
                                  _StatItem(
                                      'باص',
                                      _toInt(stats['driver']),
                                      Colors.amber.shade900,
                                      Icons.directions_bus,
                                      'driver'),
                                  _StatItem(
                                      'سرفيس',
                                      _toInt(stats['service']),
                                      Colors.purple.shade700,
                                      Icons.alt_route,
                                      'service'),
                                  _StatItem(
                                      'باص شركة',
                                      _toInt(stats['bus_company']),
                                      Colors.teal.shade700,
                                      Icons.business,
                                      'bus_company'),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 3️⃣ قسم النشطين
                              _CompactSectionCard(
                                sectionId: 'active',
                                title: 'المستخدمين النشطين الآن',
                                icon: Icons.bolt_rounded,
                                iconColor: Colors.amber.shade800,
                                isLive: true,
                                items: [
                                  _StatItem(
                                      'الباصات',
                                      _toInt(stats['active_buses']),
                                      colorScheme.primary,
                                      Icons.directions_bus,
                                      'active_buses'),
                                  _StatItem(
                                      'الركاب',
                                      _toInt(stats['active_passengers']),
                                      const Color(0xFF059669),
                                      Icons.directions_walk,
                                      'active_passengers'),
                                  _StatItem(
                                      'السرافيس',
                                      _toInt(stats['active_services']),
                                      Colors.purple.shade700,
                                      Icons.local_taxi,
                                      'active_services'),
                                  _StatItem(
                                      'أخرى',
                                      _toInt(stats['active_others']),
                                      Colors.blueGrey,
                                      Icons.more_horiz,
                                      'active_others'),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 4️⃣ قسم السائقين
                              _CompactSectionCard(
                                sectionId: 'drivers',
                                title: 'حالة طلبات السائقين',
                                icon: Icons.verified_user_outlined,
                                iconColor: Colors.indigo.shade700,
                                items: [
                                  _StatItem(
                                      'المعلقون',
                                      _toInt(stats['pending']),
                                      Colors.amber.shade900,
                                      Icons.hourglass_top,
                                      'pending'),
                                  _StatItem(
                                      'الموثقون',
                                      _toInt(stats['verified']),
                                      const Color(0xFF059669),
                                      Icons.verified_user,
                                      'verified'),
                                  _StatItem(
                                      'المرفوضون',
                                      _toInt(stats['rejected']),
                                      colorScheme.error,
                                      Icons.gpp_bad,
                                      'rejected'),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 5️⃣ قسم مواقف التجمع
                              _CompactSectionCard(
                                sectionId: 'points',
                                title: 'مواقف ونقاط التجمع',
                                icon: Icons.place_outlined,
                                iconColor: colorScheme.error,
                                items: [
                                  _StatItem(
                                      'الإجمالي',
                                      _toInt(stats['points_total']),
                                      colorScheme.primary,
                                      Icons.map,
                                      'points_total'),
                                  _StatItem(
                                      'موثقة',
                                      _toInt(stats['points_approved']),
                                      const Color(0xFF059669),
                                      Icons.check_circle,
                                      'points_approved'),
                                  _StatItem(
                                      'قيد المراجعة',
                                      _toInt(stats['points_pending']),
                                      Colors.amber.shade900,
                                      Icons.pending,
                                      'points_pending'),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ]),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🧩 المكونات المستقلة المخصصة للأداء العالي ودعم إمكانية الوصول الكاملة
// ============================================================================

/// 🌟 Hero Summary Card
class _HeroSummaryCard extends StatelessWidget {
  final int totalUsers;
  final int activeTotal;

  const _HeroSummaryCard({
    required this.totalUsers,
    required this.activeTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            Color.alphaBlend(Colors.black.withValues(alpha: 0.2), primaryColor)
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نظرة عامة على النظام',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'إجمالي المستخدمين:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$totalUsers',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'نشط الآن: $activeTotal',
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

/// 📦 Section Card Component
class _CompactSectionCard extends StatelessWidget {
  final String sectionId;
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_StatItem> items;
  final bool isLive;

  const _CompactSectionCard({
    required this.sectionId,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
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
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'مباشر',
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
              // ✅ إنشاء وسم Hero فريد تماماً لكل عنصر ومجال
              final uniqueHeroTag =
                  'hero_${sectionId}_${items[index].queryType}_$index';
              return _UltraMiniStatCard(
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

/// 📇 Mini Stat Card with Unique Hero Tag & Accessibility Scaling
class _UltraMiniStatCard extends StatelessWidget {
  final _StatItem item;
  final String heroTag;

  const _UltraMiniStatCard({
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
        tag: heroTag, // ✅ وسم فريد لمنع التعارض الكلي
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!context.mounted) return;
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

/// ⏳ Loading Skeleton Component
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 90,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.4)),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        );
      },
    );
  }
}

/// ❌ Error View Component
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 44, color: theme.colorScheme.error),
            const SizedBox(height: 10),
            Text(
              'تعذر الاتصال بقاعدة البيانات',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة التحديث'),
            )
          ],
        ),
      ),
    );
  }
}

// ✅ Immutable Model Item
class _StatItem {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final String queryType;

  const _StatItem(
    this.label,
    this.count,
    this.color,
    this.icon,
    this.queryType,
  );
}
