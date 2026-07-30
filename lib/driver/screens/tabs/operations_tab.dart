import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trip_service.dart';
import '../../../models/trip_model.dart';
import '../../../models/trip_status.dart';
import '../../../features/auth/providers/auth_provider.dart';

class OperationsTab extends StatefulWidget {
  const OperationsTab({super.key});

  @override
  State<OperationsTab> createState() => _OperationsTabState();
}

class _OperationsTabState extends State<OperationsTab> {
  final TripService _tripService = TripService();
  final Set<String> _processingIds = {};

  Stream<List<TripModel>>? _activeTripsStream;
  Stream<List<TripModel>>? _pastTripsStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    if (userId != null) {
      _activeTripsStream = _tripService.getActiveDriverTrips(userId);
      _pastTripsStream = _tripService.getPastDriverTrips(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.userId;

    // ✅ حماية إضافية: تجهيز الـ Streams إذا لم تكن قد جهزت في initState
    if (_activeTripsStream == null && userId != null) {
      _activeTripsStream = _tripService.getActiveDriverTrips(userId);
      _pastTripsStream = _tripService.getPastDriverTrips(userId);
    }

    if (userId == null) {
      return const Center(child: Text('يرجى تسجيل الدخول لعرض العمليات'));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📊 العمليات'),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textColor,
          elevation: 1,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الحالية'),
              Tab(text: 'السابقة'),
            ],
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            _buildActiveTrips(),
            _buildPastTrips(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTrips() {
    return StreamBuilder<List<TripModel>>(
      stream: _activeTripsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }

        final trips = snapshot.data ?? [];

        if (trips.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 60, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'لا توجد رحلات نشطة حالياً',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'ستظهر الرحلات التي قبلتها هنا.',
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
            return _buildTripCard(context, trip, isActive: true);
          },
        );
      },
    );
  }

  Widget _buildPastTrips() {
    return StreamBuilder<List<TripModel>>(
      stream: _pastTripsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
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
                  'ستظهر الرحلات المكتملة أو الملغية هنا.',
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
            return _buildTripCard(context, trip, isActive: false);
          },
        );
      },
    );
  }

  Widget _buildTripCard(BuildContext context, TripModel trip,
      {required bool isActive}) {
    final bool isProcessing = _processingIds.contains(trip.id);

    final Color statusColor;
    final String statusText;

    switch (trip.status) {
      case TripStatus.completed:
        statusColor = Colors.blue;
        statusText = '✅ مكتملة';
        break;
      case TripStatus.cancelled:
        statusColor = Colors.red;
        statusText = '❌ ملغية';
        break;
      case TripStatus.active:
        statusColor = Colors.green;
        statusText = '🚀 نشطة';
        break;
      default:
        statusColor = Colors.grey;
        statusText = '⏳ قيد الانتظار';
    }

    final passengerDisplayId = trip.passengerId.length >= 8
        ? trip.passengerId.substring(0, 8)
        : trip.passengerId;

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
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'الراكب: $passengerDisplayId...',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDate(trip.createdAt),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () =>
                              _updateTripStatus(trip.id, TripStatus.completed),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(isProcessing ? 'جاري...' : 'إنهاء الرحلة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () =>
                              _updateTripStatus(trip.id, TripStatus.cancelled),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.close, size: 18),
                      label: Text(isProcessing ? 'جاري...' : 'إلغاء'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateTripStatus(String tripId, TripStatus newStatus) async {
    if (_processingIds.contains(tripId)) return;

    setState(() => _processingIds.add(tripId));

    try {
      await _tripService.updateTripStatus(tripId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == TripStatus.completed
                  ? '✅ تم إنهاء الرحلة بنجاح'
                  : '🗑️ تم إلغاء الرحلة',
            ),
            backgroundColor: newStatus == TripStatus.completed
                ? Colors.green
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل تحديث حالة الرحلة، يرجى المحاولة لاحقاً.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(tripId));
      }
    }
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
