import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../models/planned_route.dart';

class SaveDrawnRouteSheet extends StatefulWidget {
  final int pointCount;
  final int roadPointCount;
  const SaveDrawnRouteSheet({
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

  List<String> get _suggestions => AppConstants.jordanRoutes;

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
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'اسم الخط (يُركَّب تلقائياً)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _startCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '1) بداية الخط *',
                hintText: 'مثال: الكرك',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _middleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '2) اسم أوسط (اختياري)',
                hintText: 'مثال: القصر — لبعض السرافيس/الباصات',
                border: OutlineInputBorder(),
                helperText: 'اتركه فارغاً إن كان الاسم من خانتين فقط',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _endCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '3) نهاية الخط *',
                hintText: 'مثال: عمان',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final start = _startCtrl.text.trim();
                final mid = _middleCtrl.text.trim();
                final end = _endCtrl.text.trim();
                final composed = (start.isNotEmpty && end.isNotEmpty)
                    ? _composeLineName(start, mid, end)
                    : '—';
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: Text(
                    'الاسم النهائي: $composed',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5B21B6),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _suggestions.take(6).map((s) {
                return ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    final parts = s.split(RegExp(r'\s*[-–—]\s*'));
                    setState(() {
                      if (parts.length >= 2) {
                        _startCtrl.text = parts.first.trim();
                        _endCtrl.text = parts.last.trim();
                        if (parts.length >= 3) {
                          _middleCtrl.text =
                              parts.sublist(1, parts.length - 1).join(' - ');
                        } else {
                          _middleCtrl.clear();
                        }
                      } else {
                        _startCtrl.text = s;
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _detailCtrl,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'تفاصيل خط السير (المناطق بالترتيب)',
                hintText:
                    'مثال: الجيزة - القسطل - شارع المطار - جامعة الإسراء - …',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                helperText:
                    'وصف نصي للمناطق التي يمر بها الباص — يظهر مع معلومات الخط',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasCtrl,
              decoration: const InputDecoration(
                labelText: 'أسماء بديلة للبحث (اختياري)',
                hintText: 'الكرك عمان، خط الكرك…',
                border: OutlineInputBorder(),
                helperText: 'افصل بفاصلة — تساعد الراكب عند البحث التقريبي',
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
