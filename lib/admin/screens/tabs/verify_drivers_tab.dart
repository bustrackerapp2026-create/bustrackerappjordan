import 'package:flutter/material.dart';

import '../../../services/firestore_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/verify_drivers/verify_drivers_models.dart';
import '../../widgets/verify_drivers/verify_drivers_widgets.dart';

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

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<Map<String, dynamic>> _getAllStats() async {
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor:
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      body: SafeArea(
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
                    return const VerifyDriversLoadingSkeleton();
                  }

                  if (statsSnapshot.hasError) {
                    return VerifyDriversErrorView(
                      onRetry: () {
                        if (mounted) setState(() => _loadData());
                      },
                      l10n: l10n,
                    );
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
                            VerifyDriversHeroSummaryCard(
                              totalUsers: totalUsers,
                              activeTotal: activeTotal,
                              l10n: l10n,
                            ),
                            const SizedBox(height: 12),
                            VerifyDriversCompactSectionCard(
                              sectionId: 'registered',
                              title: l10n.registeredStats,
                              icon: Icons.people_alt_outlined,
                              iconColor: colorScheme.primary,
                              liveLabel: l10n.live,
                              items: [
                                VerifyDriversStatItem(
                                  l10n.total,
                                  _toInt(stats['total']),
                                  colorScheme.primary,
                                  Icons.group,
                                  'total',
                                ),
                                VerifyDriversStatItem(
                                  l10n.passenger,
                                  _toInt(stats['passenger']),
                                  const Color(0xFF059669),
                                  Icons.person,
                                  'passenger',
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelBus,
                                  _toInt(stats['driver']),
                                  Colors.amber.shade900,
                                  Icons.directions_bus,
                                  'driver',
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelService,
                                  _toInt(stats['service']),
                                  Colors.purple.shade700,
                                  Icons.alt_route,
                                  'service',
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelBusCompany,
                                  _toInt(stats['bus_company']),
                                  Colors.teal.shade700,
                                  Icons.business,
                                  'bus_company',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            VerifyDriversCompactSectionCard(
                              sectionId: 'active',
                              title: l10n.activeUsersNow,
                              icon: Icons.bolt_rounded,
                              iconColor: Colors.amber.shade800,
                              isLive: true,
                              liveLabel: l10n.live,
                              items: [
                                VerifyDriversStatItem(
                                  l10n.labelBuses,
                                  _toInt(stats['active_buses']),
                                  colorScheme.primary,
                                  Icons.directions_bus,
                                  'active_buses',
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelPassengers,
                                  _toInt(stats['active_passengers']),
                                  const Color(0xFF059669),
                                  Icons.directions_walk,
                                  'active_passengers',
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelServices,
                                  _toInt(stats['active_services']),
                                  Colors.purple.shade700,
                                  Icons.local_taxi,
                                  'active_services',
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelOthers,
                                  _toInt(stats['active_others']),
                                  Colors.blueGrey,
                                  Icons.more_horiz,
                                  'active_others',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            VerifyDriversCompactSectionCard(
                              sectionId: 'drivers',
                              title: l10n.driverRequestsStatus,
                              icon: Icons.verified_user_outlined,
                              iconColor: Colors.indigo.shade700,
                              liveLabel: l10n.live,
                              items: [
                                VerifyDriversStatItem(
                                  l10n.labelPending,
                                  _toInt(stats['pending']),
                                  Colors.amber.shade900,
                                  Icons.hourglass_top,
                                  'pending',
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelVerified,
                                  _toInt(stats['verified']),
                                  const Color(0xFF059669),
                                  Icons.verified_user,
                                  'verified',
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelRejected,
                                  _toInt(stats['rejected']),
                                  colorScheme.error,
                                  Icons.gpp_bad,
                                  'rejected',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            VerifyDriversCompactSectionCard(
                              sectionId: 'points',
                              title: l10n.pickupPointsSection,
                              icon: Icons.place_outlined,
                              iconColor: colorScheme.error,
                              liveLabel: l10n.live,
                              items: [
                                VerifyDriversStatItem(
                                  l10n.total,
                                  _toInt(stats['points_total']),
                                  colorScheme.primary,
                                  Icons.map,
                                  'points_total',
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelApproved,
                                  _toInt(stats['points_approved']),
                                  const Color(0xFF059669),
                                  Icons.check_circle,
                                  'points_approved',
                                ),
                                VerifyDriversStatItem(
                                  l10n.underReview,
                                  _toInt(stats['points_pending']),
                                  Colors.amber.shade900,
                                  Icons.pending,
                                  'points_pending',
                                ),
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
    );
  }
}
