import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../models/planned_route.dart';

class SaveDrawnRouteSheet extends StatefulWidget {
  final int pointCount;
  final int roadPointCount;
  const SaveDrawnRouteSheet({
    super.key,
    required this.pointCount,
    required this.roadPointCount,
  });

  @override
  State<SaveDrawnRouteSheet> createState() => _SaveDrawnRouteSheetState();
}

class _SaveDrawnRouteSheetState extends State<SaveDrawnRouteSheet> {
  final _startCtrl = TextEditingController();
  final _middleCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  RouteDirection _direction = RouteDirection.outbound;

  @override
  void dispose() {
    _startCtrl.dispose();
    _middleCtrl.dispose();
    _endCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _composedLineName {
    final a = _startCtrl.text.trim();
    final b = _middleCtrl.text.trim();
    final c = _endCtrl.text.trim();
    final parts = <String>[];
    if (a.isNotEmpty) parts.add(a);
    if (b.isNotEmpty) parts.add(b);
    if (c.isNotEmpty) parts.add(c);
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
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
              'حفظ المسار المرسوم',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'نقاط الرسم: ${widget.pointCount} · نقاط الطريق: ${widget.roadPointCount}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _startCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم بداية الخط *',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _middleCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم أوسط (اختياري)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم نهاية الخط *',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(
              'الاسم المركّب: ${_composedLineName.isEmpty ? '—' : _composedLineName}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
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
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'تفاصيل خط السير (المناطق)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final start = _startCtrl.text.trim();
                final end = _endCtrl.text.trim();
                if (start.isEmpty || end.isEmpty) return;
                Navigator.pop(context, {
                  'lineName': _composedLineName,
                  'lineStart': start,
                  'lineMiddle': _middleCtrl.text.trim(),
                  'lineEnd': end,
                  'direction': _direction,
                  'notes': _notesCtrl.text.trim(),
                });
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
