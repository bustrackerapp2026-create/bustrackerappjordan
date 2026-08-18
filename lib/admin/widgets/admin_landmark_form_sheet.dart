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

/// تصنيف أنواع المعالم للعرض في الشيت.
class _LandmarkCategory {
  final String title;
  final List<MapLandmarkType> types;

  const _LandmarkCategory(this.title, this.types);
}

const List<_LandmarkCategory> _categories = [
  _LandmarkCategory('طعام ومشروبات', [
    MapLandmarkType.restaurant,
    MapLandmarkType.cafe,
    MapLandmarkType.fastFood,
    MapLandmarkType.bakery,
    MapLandmarkType.bar,
  ]),
  _LandmarkCategory('إقامة وسكن', [
    MapLandmarkType.hotel,
    MapLandmarkType.house,
  ]),
  _LandmarkCategory('تسوق', [
    MapLandmarkType.shop,
    MapLandmarkType.supermarket,
    MapLandmarkType.clothing,
    MapLandmarkType.convenience,
    MapLandmarkType.market,
  ]),
  _LandmarkCategory('صحة', [
    MapLandmarkType.hospital,
    MapLandmarkType.medicalCenter,
    MapLandmarkType.pharmacy,
    MapLandmarkType.clinic,
    MapLandmarkType.dentist,
  ]),
  _LandmarkCategory('تعليم', [
    MapLandmarkType.school,
    MapLandmarkType.university,
    MapLandmarkType.college,
    MapLandmarkType.kindergarten,
    MapLandmarkType.library,
  ]),
  _LandmarkCategory('عبادة', [
    MapLandmarkType.mosque,
    MapLandmarkType.church,
  ]),
  _LandmarkCategory('مالية', [
    MapLandmarkType.bank,
    MapLandmarkType.atm,
  ]),
  _LandmarkCategory('مواصلات', [
    MapLandmarkType.fuel,
    MapLandmarkType.chargingStation,
    MapLandmarkType.parking,
    MapLandmarkType.busStation,
    MapLandmarkType.trainStation,
    MapLandmarkType.airport,
    MapLandmarkType.taxi,
  ]),
  _LandmarkCategory('طرق وبنية تحتية', [
    MapLandmarkType.roundabout,
    MapLandmarkType.trafficLight,
    MapLandmarkType.pedestrianBridge,
    MapLandmarkType.vehicleBridge,
    MapLandmarkType.crosswalk,
    MapLandmarkType.tunnel,
    MapLandmarkType.warningTriangle,
  ]),
  _LandmarkCategory('خدمات عامة', [
    MapLandmarkType.government,
    MapLandmarkType.police,
    MapLandmarkType.fireStation,
    MapLandmarkType.postOffice,
    MapLandmarkType.embassy,
  ]),
  _LandmarkCategory('ترفيه وثقافة', [
    MapLandmarkType.park,
    MapLandmarkType.playground,
    MapLandmarkType.museum,
    MapLandmarkType.cinema,
    MapLandmarkType.gym,
    MapLandmarkType.stadium,
    MapLandmarkType.beach,
    MapLandmarkType.zoo,
    MapLandmarkType.aquarium,
    MapLandmarkType.attraction,
  ]),
  _LandmarkCategory('خدمات أخرى', [
    MapLandmarkType.carRepair,
    MapLandmarkType.carRental,
    MapLandmarkType.laundry,
    MapLandmarkType.hairdresser,
    MapLandmarkType.barber,
    MapLandmarkType.beautySalon,
    MapLandmarkType.toilet,
    MapLandmarkType.other,
  ]),
];

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

  Widget _buildTypeChip(MapLandmarkType t) {
    final selected = _type == t;
    final color = LandmarkMarkerImages.colorFor(t);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(t.labelAr),
        avatar: Icon(
          LandmarkMarkerImages.iconDataFor(t),
          size: 18,
          color: selected ? Colors.white : color,
        ),
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.08),
        side: BorderSide(
          color: selected ? color : color.withValues(alpha: 0.35),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        onSelected: (_) => setState(() => _type = t),
      ),
    );
  }

  Widget _buildCategorySection(_LandmarkCategory cat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cat.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cat.types.map(_buildTypeChip).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final selectedColor = LandmarkMarkerImages.colorFor(_type);

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
            const SizedBox(height: 12),
            // النوع المختار حالياً
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selectedColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selectedColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: selectedColor,
                    child: Icon(
                      LandmarkMarkerImages.iconDataFor(_type),
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'النوع المحدد: ${_type.labelAr}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selectedColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'اختر نوع المعلم',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 10),
            // أقسام أفقية حسب التصنيف
            ..._categories.map(_buildCategorySection),
            const SizedBox(height: 4),
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
