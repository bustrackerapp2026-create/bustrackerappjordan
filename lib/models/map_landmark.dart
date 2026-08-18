import 'package:cloud_firestore/cloud_firestore.dart';

/// نوع المعلم على خريطة المشروع (طبقة خاصة بالتطبيق فوق Mapbox).
/// الأنواع مستوحاة من فئات POI الشائعة في Mapbox.
enum MapLandmarkType {
  mosque,
  restaurant,
  cafe,
  university,
  hospital,
  pharmacy,
  school,
  shop,
  supermarket,
  park,
  government,
  bank,
  atm,
  hotel,
  fuel,
  parking,
  busStation,
  police,
  postOffice,
  library,
  museum,
  cinema,
  gym,
  church,
  airport,
  carRepair,
  other,
}

extension MapLandmarkTypeX on MapLandmarkType {
  String get firestoreValue {
    switch (this) {
      case MapLandmarkType.mosque:
        return 'mosque';
      case MapLandmarkType.restaurant:
        return 'restaurant';
      case MapLandmarkType.cafe:
        return 'cafe';
      case MapLandmarkType.university:
        return 'university';
      case MapLandmarkType.hospital:
        return 'hospital';
      case MapLandmarkType.pharmacy:
        return 'pharmacy';
      case MapLandmarkType.school:
        return 'school';
      case MapLandmarkType.shop:
        return 'shop';
      case MapLandmarkType.supermarket:
        return 'supermarket';
      case MapLandmarkType.park:
        return 'park';
      case MapLandmarkType.government:
        return 'government';
      case MapLandmarkType.bank:
        return 'bank';
      case MapLandmarkType.atm:
        return 'atm';
      case MapLandmarkType.hotel:
        return 'hotel';
      case MapLandmarkType.fuel:
        return 'fuel';
      case MapLandmarkType.parking:
        return 'parking';
      case MapLandmarkType.busStation:
        return 'bus_station';
      case MapLandmarkType.police:
        return 'police';
      case MapLandmarkType.postOffice:
        return 'post_office';
      case MapLandmarkType.library:
        return 'library';
      case MapLandmarkType.museum:
        return 'museum';
      case MapLandmarkType.cinema:
        return 'cinema';
      case MapLandmarkType.gym:
        return 'gym';
      case MapLandmarkType.church:
        return 'church';
      case MapLandmarkType.airport:
        return 'airport';
      case MapLandmarkType.carRepair:
        return 'car_repair';
      case MapLandmarkType.other:
        return 'other';
    }
  }

  String get labelAr {
    switch (this) {
      case MapLandmarkType.mosque:
        return 'مسجد';
      case MapLandmarkType.restaurant:
        return 'مطعم';
      case MapLandmarkType.cafe:
        return 'مقهى';
      case MapLandmarkType.university:
        return 'جامعة';
      case MapLandmarkType.hospital:
        return 'مستشفى';
      case MapLandmarkType.pharmacy:
        return 'صيدلية';
      case MapLandmarkType.school:
        return 'مدرسة';
      case MapLandmarkType.shop:
        return 'متجر';
      case MapLandmarkType.supermarket:
        return 'سوبرماركت';
      case MapLandmarkType.park:
        return 'حديقة';
      case MapLandmarkType.government:
        return 'مبنى حكومي';
      case MapLandmarkType.bank:
        return 'بنك';
      case MapLandmarkType.atm:
        return 'صراف آلي';
      case MapLandmarkType.hotel:
        return 'فندق';
      case MapLandmarkType.fuel:
        return 'محطة بنزين';
      case MapLandmarkType.parking:
        return 'موقف سيارات';
      case MapLandmarkType.busStation:
        return 'موقف حافلات';
      case MapLandmarkType.police:
        return 'مركز شرطة';
      case MapLandmarkType.postOffice:
        return 'بريد';
      case MapLandmarkType.library:
        return 'مكتبة';
      case MapLandmarkType.museum:
        return 'متحف';
      case MapLandmarkType.cinema:
        return 'سينما';
      case MapLandmarkType.gym:
        return 'نادي رياضي';
      case MapLandmarkType.church:
        return 'كنيسة';
      case MapLandmarkType.airport:
        return 'مطار';
      case MapLandmarkType.carRepair:
        return 'ورشة سيارات';
      case MapLandmarkType.other:
        return 'معلم آخر';
    }
  }

  static MapLandmarkType fromString(String? v) {
    switch (v) {
      case 'mosque':
        return MapLandmarkType.mosque;
      case 'restaurant':
        return MapLandmarkType.restaurant;
      case 'cafe':
        return MapLandmarkType.cafe;
      case 'university':
        return MapLandmarkType.university;
      case 'hospital':
        return MapLandmarkType.hospital;
      case 'pharmacy':
        return MapLandmarkType.pharmacy;
      case 'school':
        return MapLandmarkType.school;
      case 'shop':
        return MapLandmarkType.shop;
      case 'supermarket':
      case 'grocery':
        return MapLandmarkType.supermarket;
      case 'park':
        return MapLandmarkType.park;
      case 'government':
        return MapLandmarkType.government;
      case 'bank':
        return MapLandmarkType.bank;
      case 'atm':
        return MapLandmarkType.atm;
      case 'hotel':
      case 'lodging':
        return MapLandmarkType.hotel;
      case 'fuel':
      case 'gas_station':
      case 'petrol':
        return MapLandmarkType.fuel;
      case 'parking':
        return MapLandmarkType.parking;
      case 'bus_station':
      case 'bus':
      case 'transit':
        return MapLandmarkType.busStation;
      case 'police':
        return MapLandmarkType.police;
      case 'post_office':
      case 'post':
        return MapLandmarkType.postOffice;
      case 'library':
        return MapLandmarkType.library;
      case 'museum':
        return MapLandmarkType.museum;
      case 'cinema':
      case 'theater':
        return MapLandmarkType.cinema;
      case 'gym':
      case 'fitness':
        return MapLandmarkType.gym;
      case 'church':
      case 'place_of_worship':
        return MapLandmarkType.church;
      case 'airport':
        return MapLandmarkType.airport;
      case 'car_repair':
      case 'garage':
        return MapLandmarkType.carRepair;
      default:
        return MapLandmarkType.other;
    }
  }
}

/// حالة اعتماد المعلم.
enum MapLandmarkStatus {
  pending,
  approved,
  rejected,
}

extension MapLandmarkStatusX on MapLandmarkStatus {
  String get firestoreValue {
    switch (this) {
      case MapLandmarkStatus.pending:
        return 'pending';
      case MapLandmarkStatus.approved:
        return 'approved';
      case MapLandmarkStatus.rejected:
        return 'rejected';
    }
  }

  String get labelAr {
    switch (this) {
      case MapLandmarkStatus.pending:
        return 'بانتظار المراجعة';
      case MapLandmarkStatus.approved:
        return 'معتمد';
      case MapLandmarkStatus.rejected:
        return 'مرفوض';
    }
  }

  static MapLandmarkStatus fromString(String? v) {
    switch (v) {
      case 'approved':
        return MapLandmarkStatus.approved;
      case 'rejected':
        return MapLandmarkStatus.rejected;
      default:
        return MapLandmarkStatus.pending;
    }
  }
}

/// معلم خاص بمشروع التطبيق — يُعرض كطبقة خاصة فوق Mapbox ولا يُنشر عالمياً.
class MapLandmark {
  final String id;
  final String name;
  final MapLandmarkType type;
  final double latitude;
  final double longitude;
  final MapLandmarkStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final List<String> searchKeys;

  const MapLandmark({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.status = MapLandmarkStatus.approved,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.notes,
    this.searchKeys = const [],
  });

  bool get isApproved => status == MapLandmarkStatus.approved;

  factory MapLandmark.fromDoc(String id, Map<String, dynamic> data) {
    return MapLandmark(
      id: id,
      name: (data['name'] ?? '').toString().trim(),
      type: MapLandmarkTypeX.fromString(data['type']?.toString()),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      status: MapLandmarkStatusX.fromString(data['status']?.toString()),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: _ts(data['createdAt']),
      updatedAt: _ts(data['updatedAt']),
      notes: data['notes']?.toString(),
      searchKeys: (data['searchKeys'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'type': type.firestoreValue,
      'latitude': latitude,
      'longitude': longitude,
      'status': status.firestoreValue,
      'createdBy': createdBy,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (searchKeys.isNotEmpty) 'searchKeys': searchKeys,
    };
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
