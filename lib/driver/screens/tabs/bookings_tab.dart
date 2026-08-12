import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trip_service.dart';
import '../../../models/trip_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';

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
    final userId = context.select<AuthProvider, String?>((a) => a.userId);

    if (_currentUserId != userId && userId != null) {
      _currentUserId = userId;
      _pendingTripsStream = _tripService.getPendingDriverTrips(userId);
    }
  }

  Future<void> _acceptTrip(String tripId, String passengerDisplayId) async {
    if (_processingIds.contains(tripId) || _currentUserId == null) return;

    setState(() => _processingIds.add(tripId));
    final l10n = AppLocalizations.of(context);

    try {
      await _tripService.acceptTripTransaction(tripId, _currentUserId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.acceptPassengerSuccess(passengerDisplayId)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        final errorMessage = raw.contains('غير موجودة') || raw.contains('not found')
            ? l10n.tripNotFound
            : raw.contains('تم تغيير حالة') || raw.contains('another')
                ? l10n.tripTakenByOther
                : l10n.acceptRequestFailed;
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
    final l10n = AppLocalizations.of(context);

    if (_currentUserId == null) {
      return Center(child: Text(l10n.pleaseLoginRequests));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.incomingRequests),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
            tooltip: l10n.refresh,
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
                  Text(
                    l10n.loadRequestsError,
                    style: const TextStyle(fontSize: 16),
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
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          final trips = snapshot.data ?? [];

          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox, size: 60, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noIncomingRequests,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noIncomingRequestsHint,
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            cacheExtent: 320,
            addAutomaticKeepAlives: false,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemBuilder: (context, index) {
              final trip = trips[index];
              final isProcessing = _processingIds.contains(trip.id);

              final passengerDisplayId = trip.passengerId.length > 8
                  ? '${trip.passengerId.substring(0, 8)}...'
                  : trip.passengerId;

              return Card(
                key: ValueKey(trip.id),
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
                            child: Text(
                              l10n.statusPending,
                              style: const TextStyle(
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
                            '${l10n.passengerLabel}: $passengerDisplayId',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(trip.createdAt, l10n),
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
                            isProcessing ? l10n.accepting : l10n.acceptRequest,
                          ),
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

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return l10n.daysAgo(diff.inDays);
    } else if (diff.inHours > 0) {
      return l10n.hoursAgo(diff.inHours);
    } else if (diff.inMinutes > 0) {
      return l10n.minutesAgo(diff.inMinutes);
    } else {
      return l10n.now;
    }
  }
}
