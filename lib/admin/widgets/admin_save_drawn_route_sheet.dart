import 'package:flutter/material.dart';

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
  final _detailCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  RouteDirection _dir = RouteDirection.outbound;

  @override
  void dispose() {
    _startCtrl.dispose();
    _middleCtrl.dispose();
    _endCtrl.dispose();
    _detailCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  String _composeLineName(String start, String middle, String end) {
    final parts = <String>[
      start,
      if (middle.isNotEmpty) middle,
      end,
    ];
    return parts.join(' - ');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              'حفظ مسار مرسوم',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.pointCount} نقطة تحكم'
              '${widget.roadPointCount > 0 ? ' · ~${widget.roadPointCount} نقطة شارع' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _startCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم بداية الخط *',
                border: OutlineInputBorder(),
                hintText: 'مثال: الكرك',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _middleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم أوسط (اختياري)',
                border: OutlineInputBorder(),
                hintText: 'مثال: القصر',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم نهاية الخط *',
                border: OutlineInputBorder(),
                hintText: 'مثال: عمان',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasCtrl,
              decoration: const InputDecoration(
                labelText: 'أسماء بديلة (مفصولة بفاصلة)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'تفاصيل خط السير (المناطق)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                hintText: 'الجيزة - القسطل - شارع المطار ...',
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
            Text(
              'الرسم على الخريطة يتم قبل هذه الشاشة: انقر نقاط المسار ثم «حفظ».',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final start = _startCtrl.text.trim();
                final middle = _middleCtrl.text.trim();
                final end = _endCtrl.text.trim();
                if (start.isEmpty || end.isEmpty) return;
                final name = _composeLineName(start, middle, end);
                final aliases = _aliasCtrl.text
                    .split(RegExp(r'[,،]'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                for (final p in [start, if (middle.isNotEmpty) middle, end]) {
                  if (!aliases.contains(p)) aliases.add(p);
                }
                final notes = _detailCtrl.text.trim();
                Navigator.pop(
                  context,
                  (
                    name: name,
                    dir: _dir,
                    aliases: aliases,
                    notes: notes.isEmpty ? null : notes,
                    start: start,
                    middle: middle.isEmpty ? null : middle,
                    end: end,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'حفظ واعتماد على Firebase',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
