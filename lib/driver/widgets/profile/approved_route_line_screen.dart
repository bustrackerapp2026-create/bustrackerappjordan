import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_search.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/driver_line_assignment.dart';
import '../../../models/planned_route.dart';
import '../../../models/transit_line.dart';
import '../../../services/driver_line_assignment_service.dart';
import '../../../services/route_plan_service.dart';

/// الشاشة المستقلة الخاصة بميزة "خط المسار المعتمد".
class ApprovedRouteLineScreen extends StatefulWidget {
  const ApprovedRouteLineScreen({super.key});

  @override
  State<ApprovedRouteLineScreen> createState() =>
      _ApprovedRouteLineScreenState();
}

class _ApprovedRouteLineScreenState extends State<ApprovedRouteLineScreen> {
  final DriverLineAssignmentService _assignments =
      DriverLineAssignmentService();
  final RoutePlanService _routes = RoutePlanService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = true;
  String? _error;

  DriverLineAssignment? _approved;
  TransitLine? _approvedLine;
  PlannedRoute? _approvedRoute;

  DriverLineAssignment? _pending;
  TransitLine? _pendingLine;
  PlannedRoute? _pendingRoute;

  bool _searching = false;
  String? _searchError;
  List<PlannedRoute> _searchResults = const [];
  PlannedRoute? _selectedResult;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (_searchResults.isEmpty && _searchError == null && !_searching) {
        return;
      }
      setState(() {
        _searching = false;
        _searchError = null;
        _searchResults = const [];
        _selectedResult = null;
      });
      return;
    }
    if (query.length < 2) {
      setState(() {
        _searching = false;
        _searchError = null;
        _searchResults = const [];
        _selectedResult = null;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      if (_searchController.text.trim() != query) return;
      unawaited(_runSearch(fromTyping: true));
    });
  }

  Future<TransitLine?> _loadLine(String? lineId) async {
    final id = lineId?.trim() ?? '';
    if (id.isEmpty) return null;
    final snap =
        await FirebaseFirestore.instance.collection('transitLines').doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return TransitLine.fromDoc(snap.id, snap.data()!);
  }

  Future<PlannedRoute?> _loadRoute(String routeId) async {
    final id = routeId.trim();
    if (id.isEmpty) return null;
    final snap =
        await FirebaseFirestore.instance.collection('plannedRoutes').doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return PlannedRoute.fromDoc(snap.id, snap.data()!);
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().userId?.trim();
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحديد حساب السائق.';
        _approved = null;
        _approvedLine = null;
        _approvedRoute = null;
        _pending = null;
        _pendingLine = null;
        _pendingRoute = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final approved = await _assignments.getApprovedForDriver(uid);
      final pending = await _assignments.getPendingForDriver(uid);

      TransitLine? approvedLine;
      PlannedRoute? approvedRoute;
      if (approved != null) {
        approvedLine = await _assignments.getApprovedLineForDriver(uid);
        approvedLine ??= await _loadLine(approved.lineId);
        approvedRoute = await _loadRoute(approved.routeId);
      }

      TransitLine? pendingLine;
      PlannedRoute? pendingRoute;
      if (pending != null) {
        pendingLine = await _loadLine(pending.lineId);
        pendingRoute = await _loadRoute(pending.routeId);
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _approved = approved;
        _approvedLine = approvedLine;
        _approvedRoute = approvedRoute;
        _pending = pending;
        _pendingLine = pendingLine;
        _pendingRoute = pendingRoute;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات المسار المعتمد.';
        _approved = null;
        _approvedLine = null;
        _approvedRoute = null;
        _pending = null;
        _pendingLine = null;
        _pendingRoute = null;
      });
    }
  }

  bool _strictNamePrefixMatch(PlannedRoute route, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return false;

    final name = ArabicSearch.normalize(route.lineName);
    if (name.startsWith(normalizedQuery)) return true;

    final nameTokens = ArabicSearch.tokens(route.lineName);
    if (nameTokens.isNotEmpty && nameTokens.first.startsWith(normalizedQuery)) {
      return true;
    }

    for (final alias in route.aliases) {
      final an = ArabicSearch.normalize(alias);
      if (an.startsWith(normalizedQuery)) return true;
      final aliasTokens = ArabicSearch.tokens(alias);
      if (aliasTokens.isNotEmpty &&
          aliasTokens.first.startsWith(normalizedQuery)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _runSearch({bool fromTyping = false}) async {
    final query = _searchController.text.trim();
    if (!fromTyping) {
      FocusScope.of(context).unfocus();
    }

    if (query.isEmpty) {
      setState(() {
        _searching = false;
        _searchError = null;
        _searchResults = const [];
        _selectedResult = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      if (!fromTyping) _selectedResult = null;
    });

    try {
      final raw = await _routes.searchApprovedRoutes('', limit: 80);
      final qn = ArabicSearch.normalize(query);
      final filtered = raw.where((r) => _strictNamePrefixMatch(r, qn)).toList();

      filtered.sort((a, b) {
        final an = ArabicSearch.normalize(a.lineName);
        final bn = ArabicSearch.normalize(b.lineName);
        final byLen = an.length.compareTo(bn.length);
        if (byLen != 0) return byLen;
        return a.lineName.compareTo(b.lineName);
      });

      if (!mounted) return;
      if (_searchController.text.trim() != query) return;

      setState(() {
        _searching = false;
        _searchResults = filtered.take(40).toList();
        if (filtered.isEmpty) {
          _searchError = 'لا توجد نتائج مطابقة لبحثك.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (_searchController.text.trim() != query) return;
      setState(() {
        _searching = false;
        _searchResults = const [];
        _searchError = 'تعذر البحث في المسارات المعتمدة.';
      });
    }
  }

  Future<void> _onSelectResult(PlannedRoute route) async {
    if (_requesting) return;

    final uid = context.read<AuthProvider>().userId?.trim();
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد حساب السائق.')),
      );
      return;
    }

    if (_pending != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لديك طلب تعيين قيد المراجعة بالفعل. انتظر قرار الأدمن قبل طلب مسار آخر.',
          ),
        ),
      );
      return;
    }

    if (_approved != null && _approved!.routeId.trim() == route.id.trim()) {
      setState(() => _selectedResult = route);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا المسار معيّن لك بالفعل.')),
      );
      return;
    }

    final lineId = route.lineId?.trim() ?? '';
    if (lineId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هذا المسار غير مرتبط بخط معتمد مكتمل، ولا يمكن طلب تعيينه حاليًا.',
          ),
        ),
      );
      return;
    }

    setState(() => _selectedResult = route);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد طلب التعيين'),
        content: Text(
          'هل تريد طلب تعيين المسار:\n'
          '«${route.lineName}» (${route.direction.labelAr})؟\n\n'
          'سيُرسل الطلب للأدمن للموافقة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _requesting = true);
    try {
      final assignment = await _assignments.requestAssignment(
        driverId: uid,
        routeId: route.id,
        lineId: lineId,
      );
      if (!mounted) return;

      setState(() {
        if (assignment.status == DriverLineAssignmentStatus.pending) {
          _pending = assignment;
          _pendingRoute = route;
        } else if (assignment.status == DriverLineAssignmentStatus.approved) {
          _approved = assignment;
          _approvedRoute = route;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assignment.status == DriverLineAssignmentStatus.pending
                ? 'تم إرسال طلب تعيين «${route.lineName}» (${route.direction.labelAr}) وهو قيد المراجعة.'
                : 'تم تسجيل المسار «${route.lineName}» (${route.direction.labelAr}).',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().trim().isEmpty
          ? 'تعذر إرسال طلب التعيين.'
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'خط المسار المعتمد',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _StatusSummary(
                      hasApproved: _approved != null,
                      hasPending: _pending != null,
                    ),
                    const SizedBox(height: 14),
                    if (_error != null) ...[
                      _ErrorCard(message: _error!, onRetry: _load),
                      const SizedBox(height: 14),
                    ],
                    _AssignmentBlock(
                      title: 'المسار المعتمد الحالي',
                      badge: 'نشط',
                      emptyText: 'لا يوجد مسار معتمد للعمل عليه.',
                      accent: const Color(0xFF2E7D32),
                      icon: Icons.check_circle_rounded,
                      assignment: _approved,
                      line: _approvedLine,
                      route: _approvedRoute,
                    ),
                    const SizedBox(height: 12),
                    _AssignmentBlock(
                      title: 'الطلب قيد المراجعة',
                      badge: 'بانتظار الأدمن',
                      emptyText: 'لا يوجد طلب بانتظار الموافقة.',
                      accent: const Color(0xFFEF6C00),
                      icon: Icons.hourglass_top_rounded,
                      assignment: _pending,
                      line: _pendingLine,
                      route: _pendingRoute,
                    ),
                    const SizedBox(height: 18),
                    _SearchSection(
                      controller: _searchController,
                      searching: _searching,
                      onSearch: () => _runSearch(fromTyping: false),
                    ),
                    if (_searchError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _searchError!,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'النتائج (${_searchResults.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ..._searchResults.map((route) {
                        final selected = _selectedResult?.id == route.id &&
                            _selectedResult?.direction == route.direction;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SearchResultTile(
                            route: route,
                            selected: selected,
                            enabled: !_requesting,
                            onTap: () => _onSelectResult(route),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.hasApproved,
    required this.hasPending,
  });

  final bool hasApproved;
  final bool hasPending;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          label: hasApproved ? 'مسار نشط' : 'بلا مسار نشط',
          color: hasApproved ? const Color(0xFF2E7D32) : Colors.blueGrey,
          icon: hasApproved
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked,
        ),
        _Chip(
          label: hasPending ? 'طلب معلّق' : 'بلا طلب معلّق',
          color: hasPending ? const Color(0xFFEF6C00) : Colors.blueGrey,
          icon: hasPending
              ? Icons.hourglass_top_rounded
              : Icons.radio_button_unchecked,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'تعذر التحميل',
      icon: Icons.error_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _AssignmentBlock extends StatelessWidget {
  const _AssignmentBlock({
    required this.title,
    required this.badge,
    required this.emptyText,
    required this.accent,
    required this.icon,
    required this.assignment,
    required this.line,
    required this.route,
  });

  final String title;
  final String badge;
  final String emptyText;
  final Color accent;
  final IconData icon;
  final DriverLineAssignment? assignment;
  final TransitLine? line;
  final PlannedRoute? route;

  @override
  Widget build(BuildContext context) {
    final hasData = assignment != null;
    final scheme = Theme.of(context).colorScheme;
    final lineName = line?.name.trim().isNotEmpty == true
        ? line!.name.trim()
        : (route?.lineName.trim().isNotEmpty == true
            ? route!.lineName.trim()
            : '—');
    final startName = line?.startName.trim().isNotEmpty == true
        ? line!.startName.trim()
        : '—';
    final endName = line?.endName.trim().isNotEmpty == true
        ? line!.endName.trim()
        : '—';
    final direction = route?.direction.labelAr ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (hasData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: hasData
                ? Column(
                    children: [
                      _InfoRow(
                        icon: Icons.drive_file_rename_outline_rounded,
                        label: 'اسم الخط',
                        value: lineName,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.trip_origin_rounded,
                        label: 'البداية',
                        value: startName,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.location_on_rounded,
                        label: 'النهاية',
                        value: endName,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.swap_horiz_rounded,
                        label: 'الاتجاه',
                        value: direction,
                      ),
                    ],
                  )
                : Text(
                    emptyText,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.62),
                      height: 1.45,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.controller,
    required this.searching,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool searching;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'البحث عن خط معتمد',
      icon: Icons.search_rounded,
      child: Column(
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'اكتب اسم الخط…',
              prefixIcon: const Icon(Icons.route_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: searching ? null : onSearch,
              icon: searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                searching ? 'جاري البحث…' : 'بحث',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.route,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final PlannedRoute route;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? AppTheme.primaryColor
        : scheme.outline.withValues(alpha: 0.12);

    return Material(
      color: selected
          ? AppTheme.primaryColor.withValues(alpha: 0.07)
          : scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.alt_route_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.lineName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        route.direction.labelAr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_left_rounded,
                color: selected
                    ? AppTheme.primaryColor
                    : scheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: scheme.outline.withValues(alpha: 0.10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor.withValues(alpha: 0.85)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.62),
              fontSize: 13,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
