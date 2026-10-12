import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import 'pending_points_tab.dart';
import 'pending_routes_tab.dart';

/// مركز المراجعات: نقاط التوقف + مسارات الخطوط.
class AdminPendingHub extends StatefulWidget {
  final void Function({
    required double latitude,
    required double longitude,
    required String pointName,
    String? pointId,
  })? onShowOnMap;

  const AdminPendingHub({super.key, this.onShowOnMap});

  @override
  State<AdminPendingHub> createState() => _AdminPendingHubState();
}

class _AdminPendingHubState extends State<AdminPendingHub>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 1,
          child: TabBar(
            controller: _tabs,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: l10n.isArabic ? 'نقاط التوقف' : 'Pickup points'),
              Tab(text: l10n.isArabic ? 'مسارات الخطوط' : 'Line routes'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              PendingPointsTab(
                onShowOnMap: widget.onShowOnMap,
                embedded: true,
              ),
              const PendingRoutesTab(),
            ],
          ),
        ),
      ],
    );
  }
}
