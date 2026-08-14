import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trip_service.dart';
import '../../../models/trip_model.dart';
import '../../../models/trip_status.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  final TripService _tripService = TripService();
  Stream<List<TripModel>>? _pendingTripsStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureStream());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureStream();
  }

  void _ensureStream() {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null || userId.isEmpty) {
      if (_currentUserId != null) {
        _currentUserId = null;
        _pendingTripsStream = null;
      }
      return;
    }
    if (_currentUserId == userId && _pendingTripsStream != null) return;
    _currentUserId = userId;
    _pendingTripsStream = _tripService.getPendingDriverTrips(userId).handleError(
      (e, st) {
        debugPrint('pending trips stream error: $e\n$st');
      },
    );
  }

  void _refreshStream() {
    if (_currentUserId == null) return;
    setState(() {
      _pendingTripsStream =
          _tripService.getPendingDriverTrips(_currentUserId!).handleError(
        (e, st) {
          debugPrint('pending trips stream error: $e\n$st');
        },
      );
    });
  }

  Future<bool> _acceptTrip(String tripId, String passengerDisplay) async {
    if (_currentUserId == null) return false;
    final l10n = AppLocalizations.of(context);

    try {
      await _tripService.acceptTripTransaction(tripId, _currentUserId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.acceptPassengerSuccess(passengerDisplay)),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        final errorMessage = raw.contains('غير موجودة') ||
                raw.contains('not found')
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
      return false;
    }
  }

  Future<bool> _rejectTrip(String tripId) async {
    if (_currentUserId == null) return false;
    try {
      await _tripService.updateTripStatus(
        tripId,
        TripStatus.cancelled,
        driverId: _currentUserId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض الطلب'),
            backgroundColor: Color(0xFFB45309),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('reject trip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر رفض الطلب'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_currentUserId == null || _pendingTripsStream == null) {
      return Center(child: Text(l10n.pleaseLoginRequests));
    }

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.incomingRequests,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshStream,
                  tooltip: l10n.refresh,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<TripModel>>(
            stream: _pendingTripsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugPrint('BookingsTab snapshot error: ${snapshot.error}');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 60, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          l10n.loadRequestsError,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshStream,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final trips = snapshot.data ?? const <TripModel>[];

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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          l10n.noIncomingRequestsHint,
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: trips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  if (index < 0 || index >= trips.length) {
                    return const SizedBox.shrink();
                  }
                  final trip = trips[index];
                  return _BookingRequestCard(
                    key: ValueKey(trip.id),
                    trip: trip,
                    l10n: l10n,
                    onAccept: _acceptTrip,
                    onReject: _rejectTrip,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BookingRequestCard extends StatefulWidget {
  final TripModel trip;
  final AppLocalizations l10n;
  final Future<bool> Function(String tripId, String passengerDisplay) onAccept;
  final Future<bool> Function(String tripId) onReject;

  const _BookingRequestCard({
    super.key,
    required this.trip,
    required this.l10n,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_BookingRequestCard> createState() => _BookingRequestCardState();
}

class _BookingRequestCardState extends State<_BookingRequestCard> {
  bool _busy = false;

  String get _passengerLabel {
    final name = widget.trip.passengerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = widget.trip.passengerId;
    if (id.isEmpty) return 'راكب';
    return id.length > 8 ? '${id.substring(0, 8)}...' : id;
  }

  Future<void> _handleAccept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onAccept(widget.trip.id, _passengerLabel);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleReject() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onReject(widget.trip.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final l10n = widget.l10n;
    final route = trip.route?.trim();
    final pickup =
        trip.pickupPoint.trim().isEmpty ? 'نقطة صعود' : trip.pickupPoint;
    final dropoff =
        trip.dropoffPoint.trim().isEmpty ? 'على طول الخط' : trip.dropoffPoint;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pickup,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.statusPending,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'إلى: $dropoff',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _miniChip(Icons.person_outline, _passengerLabel),
                if (route != null && route.isNotEmpty)
                  _miniChip(Icons.route, route),
                _miniChip(Icons.schedule, _formatDate(trip.createdAt, l10n)),
              ],
            ),
            if (trip.notes != null && trip.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                trip.notes!,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _handleReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'رفض',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _handleAccept,
                    icon: _busy
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
                      _busy ? l10n.accepting : l10n.acceptRequest,
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
          ],
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date, AppLocalizations l10n) {
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
