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

/// تصنيف مطابق لفئات Mapbox Streets / POI قدر الإمكان.
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
  _LandmarkCategory('أماكن عبادة', [
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
  _LandmarkCategory('خدمات طوارئ وعامة', [
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
  late final TextEditingController _typeSearchCtrl;
  late MapLandmarkType _type;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameCtrl = TextEditingController(text: i?.name ?? '');
    _notesCtrl = TextEditingController(text: i?.notes ?? '');
    _typeSearchCtrl = TextEditingController();
    _type = i?.type ?? MapLandmarkType.mosque;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _typeSearchCtrl.dispose();
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

  bool _matchesSearch(MapLandmarkType t, String q) {
    if (q.isEmpty) return true;
    final hay = '${t.labelAr} ${t.labelMapboxAr} ${t.firestoreValue}'
        .toLowerCase();
    return hay.contains(q.toLowerCase());
  }

  Widget _buildTypeTile(MapLandmarkType t) {
    final selected = _type == t;
    final color = LandmarkMarkerImages.colorFor(t);
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _type = t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              // أيقونة بأسلوب الخريطة (لون الفئة بدون شارة كبيرة)
              Icon(
                LandmarkMarkerImages.iconDataFor(t),
                size: 22,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.labelAr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: selected ? color : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.labelMapboxAr,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final selectedColor = LandmarkMarkerImages.colorFor(_type);
    final query = _typeSearchCtrl.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.latitude != null && widget.longitude != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم المعلم على الخريطة *',
                      hintText: 'مثال: مسجد الحسين · مدرسة اليرموك',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // معاينة كما ستظهر تقريباً على الخريطة
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LandmarkMarkerImages.iconDataFor(_type),
                          size: 26,
                          color: selectedColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameCtrl.text.trim().isEmpty
                                    ? 'معاينة الاسم…'
                                    : _nameCtrl.text.trim(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_type.labelAr} · ${_type.labelMapboxAr}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selectedColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'نوع المعلم (متوافق مع Mapbox)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _typeSearchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'ابحث: مسجد، شرطة، مدرسة، مستشفى…',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _typeSearchCtrl.clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  for (final cat in _categories) ...[
                    Builder(
                      builder: (context) {
                        final types = cat.types
                            .where((t) => _matchesSearch(t, query))
                            .toList();
                        if (types.isEmpty) return const SizedBox.shrink();
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
                              const SizedBox(height: 8),
                              ...types.map(
                                (t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildTypeTile(t),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
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
                    label: const Text('حفظ على الخريطة'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
