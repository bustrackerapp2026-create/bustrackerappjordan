import 'package:flutter/material.dart';

import '../../core/map/landmark_marker_images.dart';
import '../../core/theme/app_theme.dart';
import '../../models/map_landmark.dart';

class AdminLandmarkFormResult {
  final String name;
  final MapLandmarkType type;
  final String? notes;

  const AdminLandmarkFormResult({
    required this.name,
    required this.type,
    this.notes,
  });
}

class AdminLandmarkFormSheet extends StatefulWidget {
  final String title;
  final MapLandmark? initial;
  final double? latitude;
  final double? longitude;

  const AdminLandmarkFormSheet({
    super.key,
    required this.title,
    this.initial,
    this.latitude,
    this.longitude,
  });

  static Future<AdminLandmarkFormResult?> show(
    BuildContext context, {
    required String title,
    MapLandmark? initial,
    double? latitude,
    double? longitude,
  }) {
    return showModalBottomSheet<AdminLandmarkFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AdminLandmarkFormSheet(
        title: title,
        initial: initial,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  State<AdminLandmarkFormSheet> createState() => _AdminLandmarkFormSheetState();
}

class _AdminLandmarkFormSheetState extends State<AdminLandmarkFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  late MapLandmarkType _type;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameCtrl = TextEditingController(text: i?.name ?? '');
    _notesCtrl = TextEditingController(text: i?.notes ?? '');
    _type = i?.type ?? MapLandmarkType.mosque;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      AdminLandmarkFormResult(
        name: name,
        type: _type,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    );
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
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم المعلم *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            const Text('النوع', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MapLandmarkType.values.map((t) {
                final selected = _type == t;
                final color = LandmarkMarkerImages.colorFor(t);
                return ChoiceChip(
                  selected: selected,
                  label: Text(t.labelAr),
                  avatar: Icon(
                    LandmarkMarkerImages.iconDataFor(t),
                    size: 18,
                    color: selected ? Colors.white : color,
                  ),
                  selectedColor: color,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
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
              label: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
