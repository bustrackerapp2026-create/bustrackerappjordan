import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trip_service.dart';
import '../../../models/trip_model.dart';
import '../../../models/trip_status.dart';
import '../../../features/auth/providers/auth_provider.dart';

class TripsTab extends StatefulWidget {
  const TripsTab({super.key});

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> {
  final TripService _tripService = TripService();
  Stream<List<TripModel>>? _tripsStream;

  @override
  void initState() {
    super.initState();
    _initTripsStream();
  }

  void _initTripsStream() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    if (userId != null) {
      _tripsStream = _tripService.getPassengerTrips(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.userId;

    // ✅ حماية إضافية: تجهيز الـ Stream إذا لم يكن قد تم تجهيزه في initState
    if (_tripsStream == null && userId != null) {
      _tripsStream = _tripService.getPassengerTrips(userId);
    }

    if (userId == null) {
      return const Center(child: Text('يرجى تسجيل الدخول لعرض رحلاتك'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🚌 رحلاتي'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _tripsStream = _tripService.getPassengerTrips(userId);
              });
            },
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: StreamBuilder<List<TripModel>>(
        stream: _tripsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'حدث خطأ أثناء تحميل الرحلات.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _tripsStream = _tripService.getPassengerTrips(userId);
                      });
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final trips = snapshot.data ?? [];

          if (trips.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'لا توجد رحلات سابقة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'سوف تظهر رحلاتك هنا بعد حجز أول رحلة.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return _buildTripCard(context, trip);
            },
          );
        },
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, TripModel trip) {
    final Color statusColor;
    final String statusText;

    switch (trip.status) {
      case TripStatus.pending:
        statusColor = Colors.orange;
        statusText = '⏳ قيد الانتظار';
        break;
      case TripStatus.active:
        statusColor = Colors.green;
        statusText = '🚀 قيد التنفيذ';
        break;
      case TripStatus.completed:
        statusColor = Colors.blue;
        statusText = '✅ مكتملة';
        break;
      case TripStatus.cancelled:
        statusColor = Colors.red;
        statusText = '❌ ملغية';
        break;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${trip.pickupPoint} → ${trip.dropoffPoint}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDate(trip.createdAt),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                if (trip.fare != null) ...[
                  const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.fare!.toStringAsFixed(2)} دينار',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ],
            ),
            if (trip.notes != null && trip.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                trip.notes!,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return 'قبل ${diff.inDays} يوم${diff.inDays > 1 ? 'اً' : ''}';
    } else if (diff.inHours > 0) {
      return 'قبل ${diff.inHours} ساعة${diff.inHours > 1 ? 'اً' : ''}';
    } else if (diff.inMinutes > 0) {
      return 'قبل ${diff.inMinutes} دقيقة${diff.inMinutes > 1 ? 'اً' : ''}';
    } else {
      return 'الآن';
    }
  }
}
