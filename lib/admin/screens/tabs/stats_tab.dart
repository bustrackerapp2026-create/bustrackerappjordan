import 'package:flutter/material.dart';
import '../../../services/firestore_service.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final FirestoreService _service = FirestoreService();
  late Future<Map<String, int>> _usersStatsFuture;
  late Future<Map<String, int>> _pointsStatsFuture;
  late Future<int> _routesCountFuture;

  @override
  void initState() {
    super.initState();
    _reloadFutures();
  }

  void _reloadFutures() {
    _usersStatsFuture = _service.getAllUsersStats(useFallback: false);
    _pointsStatsFuture = _service.getPickupPointsStats(useFallback: false);
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
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard(
                          'الإجمالي', stats['total'] ?? 0, Colors.blue),
                      _buildStatCard(
                          '🚶 راكب', stats['passenger'] ?? 0, Colors.green),
                      _buildStatCard(
                          '🚌 سائق', stats['driver'] ?? 0, Colors.orange),
                      _buildStatCard(
                          '🛠️ سرفيس', stats['service'] ?? 0, Colors.purple),
                      _buildStatCard('🏢 باص شركة',
                          stats['bus_company'] ?? 0, Colors.teal),
                      _buildStatCard(
                          '👑 أدمن', stats['admin'] ?? 0, Colors.indigo),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              const Text(
                '📋 حالة السائقين / السرفيس / باصات الشركات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'المعلقون = غير موثّقين وغير مرفوضين',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, int>>(
                future: _usersStatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  if (snapshot.hasError) {
                    return _errorBox(snapshot.error);
                  }
                  final stats = snapshot.data ?? {};
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                            'المعلقون', stats['pending'] ?? 0, Colors.orange),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                            'الموثقون', stats['verified'] ?? 0, Colors.green),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                            'المرفوضون', stats['rejected'] ?? 0, Colors.red),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              const Text(
                '📍 نقاط التجمع',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                'الإجمالي', stats['total'] ?? 0, Colors.blue),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard('موثّقة',
                                stats['approved'] ?? 0, Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard('قيد المراجعة',
                                stats['pending'] ?? 0, Colors.orange),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard('مرفوضة',
                                stats['rejected'] ?? 0, Colors.red),
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
