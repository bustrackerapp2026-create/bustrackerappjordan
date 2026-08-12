import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/trip_service.dart';
import '../../../models/trip_model.dart';
import '../../../models/trip_status.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';

class TripsTab extends StatefulWidget {
  const TripsTab({super.key});

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> {
  final TripService _tripService = TripService();
  Stream<List<TripModel>>? _tripsStream;
  List<TripModel> _latestTrips = const [];

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

  int? _indexOfTripKey(Key key) {
    if (key is! ValueKey<String>) return null;
    final id = key.value;
    for (var i = 0; i < _latestTrips.length; i++) {
      if (_latestTrips[i].id == id) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.select<AuthProvider, String?>((a) => a.userId);
    final l10n = AppLocalizations.of(context);

    if (_tripsStream == null && userId != null) {
      _tripsStream = _tripService.getPassengerTrips(userId);
    }

    if (userId == null) {
      return Center(child: Text(l10n.pleaseLoginTrips));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('🚌 ${l10n.myTrips}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _tripsStream = _tripService.getPassengerTrips(userId);
              });
            },
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: StreamBuilder<List<TripModel>>(
        stream: _tripsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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
                    l10n.loadTripsError,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _tripsStream = _tripService.getPassengerTrips(userId);
                      });
                    },
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          final trips = snapshot.data ?? const <TripModel>[];
          _latestTrips = trips;

          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 60, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noPastTrips,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noPastTripsPassengerHint,
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
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            findChildIndexCallback: _indexOfTripKey,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return _buildTripCard(context, trip, l10n);
            },
          );
        },
      ),
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    TripModel trip,
    AppLocalizations l10n,
  ) {
    final Color statusColor;
    final String statusText;

    switch (trip.status) {
      case TripStatus.pending:
        statusColor = Colors.orange;
        statusText = l10n.statusPending;
        break;
      case TripStatus.active:
        statusColor = Colors.green;
        statusText = l10n.statusInProgress;
        break;
      case TripStatus.completed:
        statusColor = Colors.blue;
        statusText = l10n.statusCompleted;
        break;
      case TripStatus.cancelled:
        statusColor = Colors.red;
        statusText = l10n.statusCancelled;
        break;
    }

    return Card(
      key: ValueKey(trip.id),
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
                  _formatDate(trip.createdAt, l10n),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                if (trip.fare != null) ...[
                  const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.fare!.toStringAsFixed(2)} ${l10n.dinar}',
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
