import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/map_landmark.dart';
import '../../../models/map_text_label.dart';
import '../../../services/map_text_label_service.dart';

/// قائمة تفاصيل إحصائيات المعالم (وليس المستخدمين).
class LandmarkStatsDetailsScreen extends StatelessWidget {
  final String title;
  final String queryType;

  const LandmarkStatsDetailsScreen({
    super.key,
    required this.title,
    required this.queryType,
  });

  bool get _isTextLabels => queryType == 'landmarks_text_labels';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      body: _isTextLabels ? _buildTextLabelsBody() : _buildLandmarksBody(),
    );
  }

  Widget _buildLandmarksBody() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('mapLandmarks')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        final items = <_LandmarkRow>[];
        for (final d in docs) {
          final data = d.data();
          final m = MapLandmark.fromDoc(d.id, data);
          final source = (data['source'] ?? 'admin').toString().toLowerCase();
          final isUser = source == 'user' ||
              source == 'passenger' ||
              source == 'driver';

          final include = switch (queryType) {
            'landmarks_total' => true,
            'landmarks_from_admin' => !isUser,
            'landmarks_from_users' => isUser,
            'landmarks_approved' =>
              m.status == MapLandmarkStatus.approved,
            'landmarks_pending' => m.status == MapLandmarkStatus.pending,
            _ => true,
          };
          if (!include || m.name.isEmpty) continue;
          items.add(
            _LandmarkRow(
              id: m.id,
              name: m.name,
              typeLabel: m.type.labelAr,
              statusLabel: m.status.labelAr,
              sourceLabel: isUser ? 'مستخدم' : 'أدمن',
              notes: m.notes,
            ),
          );
        }

        if (items.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد معالم في هذه الفئة',
              style: TextStyle(fontSize: 15),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final row = items[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.withValues(alpha: 0.12),
                child: const Icon(Icons.place, color: Colors.deepPurple, size: 20),
              ),
              title: Text(
                row.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${row.typeLabel} · ${row.statusLabel} · ${row.sourceLabel}'
                '${row.notes != null && row.notes!.isNotEmpty ? '\n${row.notes}' : ''}',
              ),
              isThreeLine: row.notes != null && row.notes!.isNotEmpty,
            );
          },
        );
      },
    );
  }

  Widget _buildTextLabelsBody() {
    return StreamBuilder<List<MapTextLabel>>(
      stream: MapTextLabelService().watchAllForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        final list = (snapshot.data ?? [])
            .where((e) => e.text.trim().isNotEmpty)
            .toList();
        if (list.isEmpty) {
          return const Center(child: Text('لا توجد تسميات نصية'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final t = list[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.brown.withValues(alpha: 0.12),
                child: const Icon(Icons.label_outline, color: Colors.brown, size: 20),
              ),
              title: Text(t.text, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('حالة: ${t.status}'),
            );
          },
        );
      },
    );
  }
}

class _LandmarkRow {
  final String id;
  final String name;
  final String typeLabel;
  final String statusLabel;
  final String sourceLabel;
  final String? notes;

  const _LandmarkRow({
    required this.id,
    required this.name,
    required this.typeLabel,
    required this.statusLabel,
    required this.sourceLabel,
    this.notes,
  });
}
