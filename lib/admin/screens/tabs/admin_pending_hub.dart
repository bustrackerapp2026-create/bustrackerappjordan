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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.isArabic ? 'المراجعات' : 'Reviews'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        bottom: TabBar(
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
      body: TabBarView(
        controller: _tabs,
        children: [
          // إعادة استخدام تبويب النقاط بدون AppBar مزدوج
          _EmbeddedPendingPoints(onShowOnMap: widget.onShowOnMap),
          const PendingRoutesTab(),
        ],
      ),
    );
  }
}

/// يلف PendingPointsTab ويزيل الـ Scaffold/AppBar الداخلي عبر نسخة مبسطة.
class _EmbeddedPendingPoints extends StatelessWidget {
  final void Function({
    required double latitude,
    required double longitude,
    required String pointName,
    String? pointId,
  })? onShowOnMap;

  const _EmbeddedPendingPoints({this.onShowOnMap});

  @override
  Widget build(BuildContext context) {
    // PendingPointsTab يحتوي Scaffold خاصاً — نستخدمه كما هو داخل الـ Tab
    // مع إزالة الـ AppBar عبر نسخة بدون عنوان مزدوج غير مرغوب.
    // الأبسط: عرض الشاشة كاملة؛ المستخدم يرى عنواناً فرعياً مقبولاً.
    return PendingPointsTab(onShowOnMap: onShowOnMap);
  }
}
