import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    _usersStatsFuture = _service.getAllUsersStats();
    _pointsStatsFuture = _service.getPickupPointsStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 الإحصائيات'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textColor,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 1. إحصائيات المستخدمين (حسب النوع)
            const Text(
              '👥 إحصائيات المستخدمين',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, int>>(
              future: _usersStatsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('⚠️ خطأ: ${snapshot.error}'));
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
                        '🚌 باص', stats['driver'] ?? 0, Colors.orange),
                    _buildStatCard(
                        '🛠️ سرفيس', stats['service'] ?? 0, Colors.purple),
                    _buildStatCard(
                        '🏢 باص شركه', stats['bus_company'] ?? 0, Colors.teal),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ✅ 2. حالة السائقين (المعلقون / الموثقون / المرفوضون)
            const Text(
              '📋 حالة السائقين',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, int>>(
              future: _usersStatsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('⚠️ خطأ: ${snapshot.error}'));
                }
                final stats = snapshot.data ?? {};
                return Row(
                  children: [
                    Expanded(
                        child: _buildStatCard(
                            'المعلقون', stats['pending'] ?? 0, Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildStatCard(
                            'الموثقون', stats['verified'] ?? 0, Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildStatCard(
                            'المرفوضون', stats['rejected'] ?? 0, Colors.red)),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ✅ 3. إحصائيات النقاط (الإجمالي / الموثقة / قيد المراجعة)
            const Text(
              '📍 النقاط',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, int>>(
              future: _pointsStatsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('⚠️ خطأ: ${snapshot.error}'));
                }
                final stats = snapshot.data ?? {};
                return Row(
                  children: [
                    Expanded(
                        child: _buildStatCard(
                            'الإجمالي', stats['total'] ?? 0, Colors.blue)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildStatCard(
                            'موثقة', stats['approved'] ?? 0, Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildStatCard('قيد المراجعة',
                            stats['pending'] ?? 0, Colors.orange)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ دالة مساعدة لبناء بطاقة الإحصائية الواحدة
  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
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
