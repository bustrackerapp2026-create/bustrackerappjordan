import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_search.dart';
import '../../models/planned_route.dart';
import '../../services/route_plan_service.dart';

/// بحث وإدارة المسارات المعتمدة من شاشة الأدمن.
class AdminRoutesSearchSheet extends StatefulWidget {
  final void Function(PlannedRoute route)? onFocusRoute;

  const AdminRoutesSearchSheet({super.key, this.onFocusRoute});

  static Future<void> show(
    BuildContext context, {
    void Function(PlannedRoute route)? onFocusRoute,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AdminRoutesSearchSheet(onFocusRoute: onFocusRoute),
    );
  }

  @override
  State<AdminRoutesSearchSheet> createState() => _AdminRoutesSearchSheetState();
}

class _AdminRoutesSearchSheetState extends State<AdminRoutesSearchSheet> {
  final _service = RoutePlanService();
  final _queryCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<PlannedRoute> _filter(List<PlannedRoute> all) {
    final q = _query.trim();
    if (q.isEmpty) {
      final sorted = List<PlannedRoute>.from(all)
        ..sort((a, b) => a.lineName.compareTo(b.lineName));
      return sorted;
    }
    return all.where((r) {
      return ArabicSearch.matches(
        query: q,
        lineName: r.lineName,
        searchKeys: r.searchKeys,
        aliases: r.aliases,
      );
    }).toList()
      ..sort((a, b) => a.lineName.compareTo(b.lineName));
  }

  Future<void> _openDetails(PlannedRoute route) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RouteDetailsPane(
        route: route,
        service: _service,
        onFocus: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
          widget.onFocusRoute?.call(route);
        },
        onChanged: () {
          Navigator.pop(ctx);
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.85;
    return SizedBox(
      height: h,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'المسارات المضافة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _queryCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث باسم الخط أو اسم بديل…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<PlannedRoute>>(
              stream: _service.watchAllApprovedRoutes(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('خطأ: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = _filter(snap.data!);
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'لا توجد مسارات معتمدة بعد'
                          : 'لا نتائج لـ «$_query»',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    final km = r.distanceMeters == null
                        ? '—'
                        : '${(r.distanceMeters! / 1000).toStringAsFixed(1)} كم';
                    return Material(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: r.direction == RouteDirection.outbound
                              ? const Color(0xFF0E9F5D).withValues(alpha: 0.15)
                              : const Color(0xFF2563EB).withValues(alpha: 0.15),
                          child: Icon(
                            r.direction == RouteDirection.outbound
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: r.direction == RouteDirection.outbound
                                ? const Color(0xFF0E9F5D)
                                : const Color(0xFF2563EB),
                          ),
                        ),
                        title: Text(
                          r.lineName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${r.direction.labelAr} · $km · ${r.points.length} نقطة'
                          '${r.notes != null && r.notes!.isNotEmpty ? '\n${r.notes}' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine:
                            r.notes != null && r.notes!.trim().isNotEmpty,
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => _openDetails(r),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDetailsPane extends StatefulWidget {
  final PlannedRoute route;
  final RoutePlanService service;
  final VoidCallback onFocus;
  final VoidCallback onChanged;

  const _RouteDetailsPane({
    required this.route,
    required this.service,
    required this.onFocus,
    required this.onChanged,
  });

  @override
  State<_RouteDetailsPane> createState() => _RouteDetailsPaneState();
}

class _RouteDetailsPaneState extends State<_RouteDetailsPane> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _aliasCtrl;
  late RouteDirection _dir;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final r = widget.route;
    _nameCtrl = TextEditingController(text: r.lineName);
    _notesCtrl = TextEditingController(text: r.notes ?? '');
    _aliasCtrl = TextEditingController(text: r.aliases.join('، '));
    _dir = r.direction;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final aliases = _aliasCtrl.text
          .split(RegExp(r'[,،]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await widget.service.updateRouteMetadata(
        routeId: widget.route.id,
        lineName: name,
        direction: _dir,
        aliases: aliases,
        notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حفظ التعديلات')),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المسار؟'),
        content: Text(
          'سيتم حذف «${widget.route.lineName}» (${widget.route.direction.labelAr}) نهائياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await widget.service.deleteRoute(widget.route.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المسار')),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحذف: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    final km = r.distanceMeters == null
        ? '—'
        : '${(r.distanceMeters! / 1000).toStringAsFixed(1)} كم';
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'تفاصيل المسار',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'المعرّف: ${r.id}\nالمصدر: ${r.source == RouteSource.admin ? 'أدمن' : 'سائق'} · $km · ${r.points.length} نقطة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الخط *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('الاتجاه', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SegmentedButton<RouteDirection>(
              segments: const [
                ButtonSegment(
                  value: RouteDirection.outbound,
                  label: Text('ذهاب'),
                ),
                ButtonSegment(
                  value: RouteDirection.returnTrip,
                  label: Text('إياب'),
                ),
              ],
              selected: {_dir},
              onSelectionChanged: (s) => setState(() => _dir = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'تفاصيل خط السير',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasCtrl,
              decoration: const InputDecoration(
                labelText: 'أسماء بديلة (افصل بفاصلة)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onFocus,
              icon: const Icon(Icons.map_outlined),
              label: const Text('عرض على الخريطة'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving || _deleting ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('حفظ التعديلات'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving || _deleting ? null : _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: const Text('حذف المسار'),
            ),
          ],
        ),
      ),
    );
  }
}
