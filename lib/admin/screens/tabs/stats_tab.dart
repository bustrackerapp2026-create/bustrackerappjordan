import 'package:flutter/material.dart';

import '../../../services/firestore_service.dart';
import '../../../services/map_landmark_service.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final FirestoreService _service = FirestoreService();
  final MapLandmarkService _landmarks = MapLandmarkService();

  late Future<Map<String, int>> _usersStatsFuture;
  late Future<Map<String, int>> _pointsStatsFuture;
  late Future<Map<String, int>> _landmarksStatsFuture;
  late Future<int> _routesCountFuture;

  @override
  void initState() {
    super.initState();
    _reloadFutures();
  }

  void _reloadFutures() {
    _usersStatsFuture = _service.getAllUsersStats(useFallback: false);
    _pointsStatsFuture = _service.getPickupPointsStats(useFallback: false);
    _landmarksStatsFuture = _landmarks.getStats(useFallback: false);
    _routesCountFuture = _service.getActiveRoutesCount(useFallback: false);
  }

  void _loadStats() {
    setState(_reloadFutures);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 الإحصائيات'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadStats(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '👥 إحصائيات المستخدمين',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, int>>(
                future: _usersStatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _errorBox(snapshot.error);
                  }
                  final stats = snapshot.data ?? {};
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'الإجمالي',
                              stats['total'] ?? 0,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              '🚶 راكب',
                              stats['passenger'] ?? 0,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              '🚌 سائق',
                              stats['driver'] ?? 0,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '🛠️ سرفيس',
                              stats['service'] ?? 0,
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'شركة باصات',
                              stats['bus_company'] ?? 0,
                              Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              '👑 أدمن',
                              stats['admin'] ?? 0,
                              Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'المعلقون',
                              stats['pending'] ?? 0,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'الموثقون',
                              stats['verified'] ?? 0,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'المرفوضون',
                              stats['rejected'] ?? 0,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              const Text(
                '🗺️ إحصائيات المعالم',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'تشمل المعالم والمجمعات (مثل مجمع الجنوب) وأسماء الشوارع والتسميات النصية',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, int>>(
                future: _landmarksStatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _errorBox(snapshot.error);
                  }
                  final s = snapshot.data ?? {};
                  final totalLandmarks = s['total'] ?? 0;
                  final fromAdmin = s['fromAdmin'] ?? 0;
                  final fromUsers = s['fromUsers'] ?? 0;
                  final textLabels = s['textLabels'] ?? 0;
                  final combined = totalLandmarks + textLabels;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'إجمالي المعالم',
                              totalLandmarks,
                              Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'مع التسميات',
                              combined,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'حسب مصدر الإضافة',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'من شاشة الأدمن',
                              fromAdmin,
                              Colors.indigo,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'من المستخدمين',
                              fromUsers,
                              Colors.cyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'حالة الاعتماد + التسميات',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'معتمدة',
                              s['approved'] ?? 0,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'قيد المراجعة',
                              s['pending'] ?? 0,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'مرفوضة',
                              s['rejected'] ?? 0,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'أسماء شوارع / تسميات',
                              textLabels,
                              Colors.brown,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'تسميات معتمدة',
                              s['textLabelsApproved'] ?? 0,
                              Colors.brown,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              const Text(
                '📍 نقاط التجمع',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'نقاط تجمع الركاب ونقاط تجمع الباصات فقط — منفصلة عن المعالم',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, int>>(
                future: _pointsStatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _errorBox(snapshot.error);
                  }
                  final stats = snapshot.data ?? {};
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'الإجمالي',
                              stats['total'] ?? 0,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'موثّقة',
                              stats['approved'] ?? 0,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'قيد المراجعة',
                              stats['pending'] ?? 0,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'مرفوضة',
                              stats['rejected'] ?? 0,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              const Text(
                '🚌 المسارات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<int>(
                future: _routesCountFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  if (snapshot.hasError) {
                    return _errorBox(snapshot.error);
                  }
                  return _buildStatCard(
                    'مسارات نشطة',
                    snapshot.data ?? 0,
                    Colors.deepPurple,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBox(Object? error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        '⚠️ خطأ في جلب الإحصائيات:\n$error',
        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
