/// حالات الرحلة
enum TripStatus {
  pending,
  active,
  completed,
  cancelled,
}

extension TripStatusExtension on TripStatus {
  String get stringValue {
    switch (this) {
      case TripStatus.pending:
        return 'pending';
      case TripStatus.active:
        return 'active';
      case TripStatus.completed:
        return 'completed';
      case TripStatus.cancelled:
        return 'cancelled';
    }
  }

  static TripStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return TripStatus.pending;
      case 'active':
        return TripStatus.active;
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      default:
        return TripStatus.pending;
    }
  }
}
