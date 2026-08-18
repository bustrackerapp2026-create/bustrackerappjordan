import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/map_text_label.dart';

class AdminTextLabelFormResult {
  final String text;
  final double fontSize;
  final double rotation;
  final int colorArgb;

  const AdminTextLabelFormResult({
    required this.text,
    required this.fontSize,
    required this.rotation,
    required this.colorArgb,
  });
}

class AdminTextLabelFormSheet extends StatefulWidget {
  final String title;
  final MapTextLabel? initial;
  final double? latitude;
  final double? longitude;

  const AdminTextLabelFormSheet({
    super.key,
    required this.title,
    this.initial,
    this.latitude,
    this.longitude,
  });

  static Future<AdminTextLabelFormResult?> show(
    BuildContext context, {
    required String title,
    MapTextLabel? initial,
    double? latitude,
    double? longitude,
  }) {
    return showModalBottomSheet<AdminTextLabelFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AdminTextLabelFormSheet(
        title: title,
        initial: initial,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  State<AdminTextLabelFormSheet> createState() =>
      _AdminTextLabelFormSheetState();
}

class _AdminTextLabelFormSheetState extends State<AdminTextLabelFormSheet> {
  late final TextEditingController _textCtrl;
  late double _fontSize;
  late double _rotation;
  late int _colorArgb;

  static const _presetColors = <int>[
    0xFF1A237E, // نيلي داكن
    0xFF000000, // أسود
    0xFFB71C1C, // أحمر
    0xFF1B5E20, // أخضر
    0xFF0D47A1, // أزرق
    0xFF4A148C, // بنفسجي
    0xFFE65100, // برتقالي
    0xFF37474F, // رمادي داكن
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _textCtrl = TextEditingController(text: i?.text ?? '');
    _fontSize = i?.fontSize ?? 14;
    _rotation = i?.rotation ?? 0;
    _colorArgb = i?.colorArgb ?? 0xFF1A237E;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(
      context,
      AdminTextLabelFormResult(
        text: text,
        fontSize: _fontSize,
        rotation: _rotation,
        colorArgb: _colorArgb,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final previewColor = Color(_colorArgb);

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
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (widget.latitude != null && widget.longitude != null) ...[
              const SizedBox(height: 6),
              Text(
                '${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _textCtrl,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'النص (مثل اسم الشارع) *',
                border: OutlineInputBorder(),
                hintText: 'مثال: شارع الملك حسين',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('حجم النص', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  _fontSize.round().toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            Slider(
              value: _fontSize,
              min: 10,
              max: 28,
              divisions: 18,
              label: _fontSize.round().toString(),
              onChanged: (v) => setState(() => _fontSize = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('الاتجاه (درجة)', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${_rotation.round()}°',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            Slider(
              value: _rotation,
              min: 0,
              max: 360,
              divisions: 72,
              label: '${_rotation.round()}°',
              onChanged: (v) => setState(() => _rotation = v),
            ),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('أفقي 0°'),
                  onPressed: () => setState(() => _rotation = 0),
                ),
                ActionChip(
                  label: const Text('45°'),
                  onPressed: () => setState(() => _rotation = 45),
                ),
                ActionChip(
                  label: const Text('عمودي 90°'),
                  onPressed: () => setState(() => _rotation = 90),
                ),
                ActionChip(
                  label: const Text('135°'),
                  onPressed: () => setState(() => _rotation = 135),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('لون النص', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetColors.map((c) {
                final selected = _colorArgb == c;
                return GestureDetector(
                  onTap: () => setState(() => _colorArgb = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppTheme.primaryColor : Colors.white,
                        width: selected ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            // معاينة
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: _rotation * 3.1415926535 / 180,
                  child: Text(
                    _textCtrl.text.trim().isEmpty
                        ? 'معاينة النص'
                        : _textCtrl.text.trim(),
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w700,
                      color: previewColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('حفظ النص'),
            ),
          ],
        ),
      ),
    );
  }
}
