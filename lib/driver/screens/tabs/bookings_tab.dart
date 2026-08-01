import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trip_service.dart';
import '../../../models/trip_model.dart';
import '../../../features/auth/providers/auth_provider.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  final TripService _tripService = TripService();
  final Set<String> _processingIds = {};
  Stream<List<TripModel>>? _pendingTripsStream;
  String? _currentUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.userId;

    if (_currentUserId != userId && userId != null) {
      _currentUserId = userId;
      _pendingTripsStream = _tripService.getPendingDriverTrips(userId);
    }
  }

  /// ✅ قبول الطلب بـ Transaction وحماية كاملة
  Future<void> _acceptTrip(String tripId, String passengerDisplayId) async {
    if (_processingIds.contains(tripId) || _currentUserId == null) return;

    setState(() => _processingIds.add(tripId));

    try {
      await _tripService.acceptTripTransaction(tripId, _currentUserId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم قبول طلب الراكب $passengerDisplayId بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // ✅ عرض رسالة خطأ صديقة للمستخدم بدلاً من عرض $e مباشرة
        final errorMessage = e.toString().contains('غير موجودة')
            ? '⚠️ الرحلة غير موجودة أو تم حذفها.'
            : e.toString().contains('تم تغيير حالة')
                ? '⚠️ تم قبول هذه الرحلة من قبل سائق آخر.'
                : '❌ فشل قبول الطلب، يرجى المحاولة لاحقاً.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('يرجى تسجيل الدخول لعرض الطلبات'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 الطلبات الواردة'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_currentUserId != null) {
                setState(() {
                  _pendingTripsStream =
                      _tripService.getPendingDriverTrips(_currentUserId!);
                });
              }
            },
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: StreamBuilder<List<TripModel>>(
        stream: _pendingTripsStream,
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
                    'حدث خطأ أثناء تحميل الطلبات.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentUserId != null) {
                        setState(() {
                          _pendingTripsStream = _tripService
                              .getPendingDriverTrips(_currentUserId!);
                        });
                      }
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
                  Icon(Icons.inbox, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'لا توجد طلبات واردة حالياً',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ستظهر طلبات الركاب هنا عند حجزهم لرحلة.',
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
              final isProcessing = _processingIds.contains(trip.id);

              final passengerDisplayId = trip.passengerId.length > 8
                  ? '${trip.passengerId.substring(0, 8)}...'
                  : trip.passengerId;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '⏳ قيد الانتظار',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'الراكب: $passengerDisplayId',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(trip.createdAt),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          trip.notes!,
                          style:
                              const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => _acceptTrip(trip.id, passengerDisplayId),
                          icon: isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle, size: 18),
                          label: Text(
                              isProcessing ? 'جاري القبول...' : '✅ قبول الطلب'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
