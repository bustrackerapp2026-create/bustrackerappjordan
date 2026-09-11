import 'package:flutter/material.dart';

import '../../../core/constants/user_roles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/map_landmark_service.dart';
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
      MapLandmarkService().getStats(useFallback: true),
    ]);

    final usersStats = results[0] as Map;
    final pointsStats = results[1] as Map;
    final landmarksStats = results[2] as Map;

    return {
      ...usersStats,
      'total': _toInt(usersStats['total']),
      UserRoles.passenger: _toInt(usersStats[UserRoles.passenger]),
      UserRoles.driver: _toInt(usersStats[UserRoles.driver]),
      UserRoles.service: _toInt(usersStats[UserRoles.service]),
      UserRoles.busCompany: _toInt(usersStats[UserRoles.busCompany]),
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
      'landmarks_total': _toInt(landmarksStats['total']),
      'landmarks_from_admin': _toInt(landmarksStats['fromAdmin']),
      'landmarks_from_users': _toInt(landmarksStats['fromUsers']),
      'landmarks_approved': _toInt(landmarksStats['approved']),
      'landmarks_pending': _toInt(landmarksStats['pending']),
      'landmarks_text_labels': _toInt(landmarksStats['textLabels']),
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
                          horizontal: 12,
                          vertical: 10,
                        ),
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
                                  _toInt(stats[UserRoles.passenger]),
                                  const Color(0xFF059669),
                                  Icons.person,
                                  UserRoles.passenger,
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelBus,
                                  _toInt(stats[UserRoles.driver]),
                                  Colors.amber.shade900,
                                  Icons.directions_bus,
                                  UserRoles.driver,
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelService,
                                  _toInt(stats[UserRoles.service]),
                                  Colors.purple.shade700,
                                  Icons.alt_route,
                                  UserRoles.service,
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelBusCompany,
                                  _toInt(stats[UserRoles.busCompany]),
                                  Colors.teal.shade700,
                                  Icons.business,
                                  UserRoles.busCompany,
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
                                  Icons.alt_route,
                                  'active_services',
                                ),
                                VerifyDriversStatItem(
                                  l10n.labelOthers,
                                  _toInt(stats['active_others']),
                                  Colors.blueGrey.shade700,
                                  Icons.people_outline,
                                  'active_others',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            VerifyDriversCompactSectionCard(
                              sectionId: 'drivers',
                              title: l10n.driverRequestsStatus,
                              icon: Icons.verified_user_outlined,
                              iconColor: const Color(0xFF059669),
                              liveLabel: l10n.live,
                              items: [
                                VerifyDriversStatItem(
                                  l10n.labelPending,
                                  _toInt(stats['pending']),
                                  Colors.amber.shade900,
                                  Icons.pending_actions,
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
                              sectionId: 'landmarks',
                              title: 'إحصائيات المعالم',
                              icon: Icons.location_city_outlined,
                              iconColor: Colors.deepPurple,
                              liveLabel: l10n.live,
                              items: [
                                VerifyDriversStatItem(
                                  'إجمالي المعالم',
                                  _toInt(stats['landmarks_total']),
                                  Colors.deepPurple,
                                  Icons.place,
                                  'landmarks_total',
                                ),
                                VerifyDriversStatItem(
                                  'من الأدمن',
                                  _toInt(stats['landmarks_from_admin']),
                                  Colors.indigo,
                                  Icons.admin_panel_settings_outlined,
                                  'landmarks_from_admin',
                                ),
                                VerifyDriversStatItem(
                                  'من المستخدمين',
                                  _toInt(stats['landmarks_from_users']),
                                  Colors.cyan.shade700,
                                  Icons.person_pin_circle_outlined,
                                  'landmarks_from_users',
                                ),
                                VerifyDriversStatItem(
                                  'معتمدة',
                                  _toInt(stats['landmarks_approved']),
                                  const Color(0xFF059669),
                                  Icons.check_circle_outline,
                                  'landmarks_approved',
                                ),
                                VerifyDriversStatItem(
                                  'قيد المراجعة',
                                  _toInt(stats['landmarks_pending']),
                                  Colors.amber.shade900,
                                  Icons.hourglass_top_rounded,
                                  'landmarks_pending',
                                ),
                                VerifyDriversStatItem(
                                  'أسماء شوارع / تسميات',
                                  _toInt(stats['landmarks_text_labels']),
                                  Colors.brown,
                                  Icons.label_outline,
                                  'landmarks_text_labels',
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
