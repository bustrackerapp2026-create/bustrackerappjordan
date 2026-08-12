import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trip_service.dart';
import '../../../models/trip_model.dart';
import '../../../models/trip_status.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';

class OperationsTab extends StatefulWidget {
  const OperationsTab({super.key});

  @override
  State<OperationsTab> createState() => _OperationsTabState();
}

class _OperationsTabState extends State<OperationsTab> {
  final TripService _tripService = TripService();

  Stream<List<TripModel>>? _activeTripsStream;
  Stream<List<TripModel>>? _pastTripsStream;
  List<TripModel> _activeCache = const [];
  List<TripModel> _pastCache = const [];

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    final userId = context.read<AuthProvider>().userId;
    if (userId != null) {
      _activeTripsStream = _tripService.getActiveDriverTrips(userId);
      _pastTripsStream = _tripService.getPastDriverTrips(userId);
    }
  }

  Future<bool> _updateTripStatus(String tripId, TripStatus newStatus) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _tripService.updateTripStatus(tripId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == TripStatus.completed
                  ? l10n.tripEnded
                  : l10n.tripCancelled,
            ),
            backgroundColor: newStatus == TripStatus.completed
                ? Colors.green
                : Colors.orange,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tripStatusUpdateFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  int? _indexIn(List<TripModel> list, Key key) {
    if (key is! ValueKey<String>) return null;
    final id = key.value;
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == id) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.select<AuthProvider, String?>((a) => a.userId);
    final l10n = AppLocalizations.of(context);

    if (_activeTripsStream == null && userId != null) {
      _activeTripsStream = _tripService.getActiveDriverTrips(userId);
      _pastTripsStream = _tripService.getPastDriverTrips(userId);
    }

    if (userId == null) {
      return Center(child: Text(l10n.pleaseLoginOperations));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.operationsTitle),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 1,
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.tabCurrent),
              Tab(text: l10n.tabPast),
            ],
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            _buildTripList(
              stream: _activeTripsStream,
              isActive: true,
              emptyIcon: Icons.inbox,
              emptyTitle: l10n.noActiveTrips,
              emptyHint: l10n.noActiveTripsHint,
              onCache: (list) => _activeCache = list,
              findIndex: (key) => _indexIn(_activeCache, key),
              l10n: l10n,
            ),
            _buildTripList(
              stream: _pastTripsStream,
              isActive: false,
              emptyIcon: Icons.history,
              emptyTitle: l10n.noPastTrips,
              emptyHint: l10n.noPastTripsHint,
              onCache: (list) => _pastCache = list,
              findIndex: (key) => _indexIn(_pastCache, key),
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripList({
    required Stream<List<TripModel>>? stream,
    required bool isActive,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyHint,
    required void Function(List<TripModel>) onCache,
    required int? Function(Key key) findIndex,
    required AppLocalizations l10n,
  }) {
    return StreamBuilder<List<TripModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('${l10n.errorPrefix}: ${snapshot.error}'));
        }

        final trips = snapshot.data ?? const <TripModel>[];
        onCache(trips);

        if (trips.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(emptyIcon, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  emptyTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  emptyHint,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trips.length,
          cacheExtent: 400,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          findChildIndexCallback: findIndex,
          itemBuilder: (context, index) {
            final trip = trips[index];
            return _OperationTripCard(
              key: ValueKey(trip.id),
              trip: trip,
              isActive: isActive,
              l10n: l10n,
              onUpdateStatus: _updateTripStatus,
            );
          },
        );
      },
    );
  }
}

class _OperationTripCard extends StatefulWidget {
  final TripModel trip;
  final bool isActive;
  final AppLocalizations l10n;
  final Future<bool> Function(String tripId, TripStatus status) onUpdateStatus;

  const _OperationTripCard({
    super.key,
    required this.trip,
    required this.isActive,
    required this.l10n,
    required this.onUpdateStatus,
  });

  @override
  State<_OperationTripCard> createState() => _OperationTripCardState();
}

class _OperationTripCardState extends State<_OperationTripCard> {
  bool _busy = false;

  Future<void> _run(TripStatus status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onUpdateStatus(widget.trip.id, status);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final l10n = widget.l10n;

    final Color statusColor;
    final String statusText;

    switch (trip.status) {
      case TripStatus.completed:
        statusColor = Colors.blue;
        statusText = l10n.statusCompleted;
        break;
      case TripStatus.cancelled:
        statusColor = Colors.red;
        statusText = l10n.statusCancelled;
        break;
      case TripStatus.active:
        statusColor = Colors.green;
        statusText = l10n.statusActive;
        break;
      default:
        statusColor = Colors.grey;
        statusText = l10n.statusPending;
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
                  '${l10n.passengerLabel}: $passengerDisplayId...',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDate(trip.createdAt, l10n),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            if (widget.isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _busy ? null : () => _run(TripStatus.completed),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        _busy ? l10n.processing : l10n.endTrip,
                      ),
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
                      onPressed:
                          _busy ? null : () => _run(TripStatus.cancelled),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.close, size: 18),
                      label: Text(
                        _busy ? l10n.processing : l10n.cancel,
                      ),
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
