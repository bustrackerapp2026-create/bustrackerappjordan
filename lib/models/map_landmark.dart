import 'package:cloud_firestore/cloud_firestore.dart';

/// نوع المعلم على خريطة المشروع (طبقة خاصة بالتطبيق فوق Mapbox).
/// مجموعة شاملة مستوحاة من أيقونات Mapbox Maki / POI.
enum MapLandmarkType {
  // طعام ومشروبات
  restaurant,
  cafe,
  fastFood,
  bakery,
  bar,

  // إقامة
  hotel,

  // تسوق
  shop,
  supermarket,
  clothing,
  convenience,
  market,

  // صحة
  hospital,
  pharmacy,
  clinic,
  dentist,

  // تعليم
  school,
  university,
  kindergarten,
  library,

  // عبادة
  mosque,
  church,

  // مالية
  bank,
  atm,

  // مواصلات
  fuel,
  chargingStation,
  parking,
  busStation,
  trainStation,
  airport,
  taxi,

  // خدمات عامة
  government,
  police,
  fireStation,
  postOffice,
  embassy,

  // ترفيه وثقافة
  park,
  playground,
  museum,
  cinema,
  gym,
  stadium,
  beach,
  zoo,
  aquarium,
  attraction,

  // خدمات أخرى
  carRepair,
  carRental,
  laundry,
  hairdresser,
  toilet,

  other,
}

extension MapLandmarkTypeX on MapLandmarkType {
  String get firestoreValue {
    switch (this) {
      case MapLandmarkType.restaurant:
        return 'restaurant';
      case MapLandmarkType.cafe:
        return 'cafe';
      case MapLandmarkType.fastFood:
        return 'fast_food';
      case MapLandmarkType.bakery:
        return 'bakery';
      case MapLandmarkType.bar:
        return 'bar';
      case MapLandmarkType.hotel:
        return 'hotel';
      case MapLandmarkType.shop:
        return 'shop';
      case MapLandmarkType.supermarket:
        return 'supermarket';
      case MapLandmarkType.clothing:
        return 'clothing';
      case MapLandmarkType.convenience:
        return 'convenience';
      case MapLandmarkType.market:
        return 'market';
      case MapLandmarkType.hospital:
        return 'hospital';
      case MapLandmarkType.pharmacy:
        return 'pharmacy';
      case MapLandmarkType.clinic:
        return 'clinic';
      case MapLandmarkType.dentist:
        return 'dentist';
      case MapLandmarkType.school:
        return 'school';
      case MapLandmarkType.university:
        return 'university';
      case MapLandmarkType.kindergarten:
        return 'kindergarten';
      case MapLandmarkType.library:
        return 'library';
      case MapLandmarkType.mosque:
        return 'mosque';
      case MapLandmarkType.church:
        return 'church';
      case MapLandmarkType.bank:
        return 'bank';
      case MapLandmarkType.atm:
        return 'atm';
      case MapLandmarkType.fuel:
        return 'fuel';
      case MapLandmarkType.chargingStation:
        return 'charging_station';
      case MapLandmarkType.parking:
        return 'parking';
      case MapLandmarkType.busStation:
        return 'bus_station';
      case MapLandmarkType.trainStation:
        return 'train_station';
      case MapLandmarkType.airport:
        return 'airport';
      case MapLandmarkType.taxi:
        return 'taxi';
      case MapLandmarkType.government:
        return 'government';
      case MapLandmarkType.police:
        return 'police';
      case MapLandmarkType.fireStation:
        return 'fire_station';
      case MapLandmarkType.postOffice:
        return 'post_office';
      case MapLandmarkType.embassy:
        return 'embassy';
      case MapLandmarkType.park:
        return 'park';
      case MapLandmarkType.playground:
        return 'playground';
      case MapLandmarkType.museum:
        return 'museum';
      case MapLandmarkType.cinema:
        return 'cinema';
      case MapLandmarkType.gym:
        return 'gym';
      case MapLandmarkType.stadium:
        return 'stadium';
      case MapLandmarkType.beach:
        return 'beach';
      case MapLandmarkType.zoo:
        return 'zoo';
      case MapLandmarkType.aquarium:
        return 'aquarium';
      case MapLandmarkType.attraction:
        return 'attraction';
      case MapLandmarkType.carRepair:
        return 'car_repair';
      case MapLandmarkType.carRental:
        return 'car_rental';
      case MapLandmarkType.laundry:
        return 'laundry';
      case MapLandmarkType.hairdresser:
        return 'hairdresser';
      case MapLandmarkType.toilet:
        return 'toilet';
      case MapLandmarkType.other:
        return 'other';
    }
  }

  String get labelAr {
    switch (this) {
      case MapLandmarkType.restaurant:
        return 'مطعم';
      case MapLandmarkType.cafe:
        return 'مقهى';
      case MapLandmarkType.fastFood:
        return 'وجبات سريعة';
      case MapLandmarkType.bakery:
        return 'مخبز';
      case MapLandmarkType.bar:
        return 'مقهى/بار';
      case MapLandmarkType.hotel:
        return 'فندق';
      case MapLandmarkType.shop:
        return 'متجر';
      case MapLandmarkType.supermarket:
        return 'سوبرماركت';
      case MapLandmarkType.clothing:
        return 'ملابس';
      case MapLandmarkType.convenience:
        return 'بقالة';
      case MapLandmarkType.market:
        return 'سوق';
      case MapLandmarkType.hospital:
        return 'مستشفى';
      case MapLandmarkType.pharmacy:
        return 'صيدلية';
      case MapLandmarkType.clinic:
        return 'عيادة';
      case MapLandmarkType.dentist:
        return 'طبيب أسنان';
      case MapLandmarkType.school:
        return 'مدرسة';
      case MapLandmarkType.university:
        return 'جامعة';
      case MapLandmarkType.kindergarten:
        return 'روضة أطفال';
      case MapLandmarkType.library:
        return 'مكتبة';
      case MapLandmarkType.mosque:
        return 'مسجد';
      case MapLandmarkType.church:
        return 'كنيسة';
      case MapLandmarkType.bank:
        return 'بنك';
      case MapLandmarkType.atm:
        return 'صراف آلي';
      case MapLandmarkType.fuel:
        return 'محطة بنزين';
      case MapLandmarkType.chargingStation:
        return 'شحن كهربائي';
      case MapLandmarkType.parking:
        return 'موقف سيارات';
      case MapLandmarkType.busStation:
        return 'موقف حافلات';
      case MapLandmarkType.trainStation:
        return 'محطة قطار';
      case MapLandmarkType.airport:
        return 'مطار';
      case MapLandmarkType.taxi:
        return 'موقف تاكسي';
      case MapLandmarkType.government:
        return 'مبنى حكومي';
      case MapLandmarkType.police:
        return 'مركز شرطة';
      case MapLandmarkType.fireStation:
        return 'إطفائية';
      case MapLandmarkType.postOffice:
        return 'بريد';
      case MapLandmarkType.embassy:
        return 'سفارة';
      case MapLandmarkType.park:
        return 'حديقة';
      case MapLandmarkType.playground:
        return 'ملعب أطفال';
      case MapLandmarkType.museum:
        return 'متحف';
      case MapLandmarkType.cinema:
        return 'سينما';
      case MapLandmarkType.gym:
        return 'نادي رياضي';
      case MapLandmarkType.stadium:
        return 'ملعب / استاد';
      case MapLandmarkType.beach:
        return 'شاطئ';
      case MapLandmarkType.zoo:
        return 'حديقة حيوان';
      case MapLandmarkType.aquarium:
        return 'حوض أسماك';
      case MapLandmarkType.attraction:
        return 'معلم سياحي';
      case MapLandmarkType.carRepair:
        return 'ورشة سيارات';
      case MapLandmarkType.carRental:
        return 'تأجير سيارات';
      case MapLandmarkType.laundry:
        return 'مغسلة';
      case MapLandmarkType.hairdresser:
        return 'صالون حلاقة';
      case MapLandmarkType.toilet:
        return 'دورة مياه';
      case MapLandmarkType.other:
        return 'معلم آخر';
    }
  }

  static MapLandmarkType fromString(String? v) {
    switch (v) {
      case 'restaurant':
        return MapLandmarkType.restaurant;
      case 'cafe':
        return MapLandmarkType.cafe;
      case 'fast_food':
      case 'fastfood':
        return MapLandmarkType.fastFood;
      case 'bakery':
        return MapLandmarkType.bakery;
      case 'bar':
      case 'pub':
        return MapLandmarkType.bar;
      case 'hotel':
      case 'lodging':
        return MapLandmarkType.hotel;
      case 'shop':
        return MapLandmarkType.shop;
      case 'supermarket':
      case 'grocery':
        return MapLandmarkType.supermarket;
      case 'clothing':
      case 'clothing_store':
        return MapLandmarkType.clothing;
      case 'convenience':
        return MapLandmarkType.convenience;
      case 'market':
      case 'marketplace':
        return MapLandmarkType.market;
      case 'hospital':
        return MapLandmarkType.hospital;
      case 'pharmacy':
        return MapLandmarkType.pharmacy;
      case 'clinic':
      case 'doctors':
      case 'doctor':
        return MapLandmarkType.clinic;
      case 'dentist':
        return MapLandmarkType.dentist;
      case 'school':
        return MapLandmarkType.school;
      case 'university':
      case 'college':
        return MapLandmarkType.university;
      case 'kindergarten':
        return MapLandmarkType.kindergarten;
      case 'library':
        return MapLandmarkType.library;
      case 'mosque':
        return MapLandmarkType.mosque;
      case 'church':
      case 'place_of_worship':
        return MapLandmarkType.church;
      case 'bank':
        return MapLandmarkType.bank;
      case 'atm':
        return MapLandmarkType.atm;
      case 'fuel':
      case 'gas_station':
      case 'petrol':
        return MapLandmarkType.fuel;
      case 'charging_station':
      case 'ev_charging':
        return MapLandmarkType.chargingStation;
      case 'parking':
        return MapLandmarkType.parking;
      case 'bus_station':
      case 'bus':
      case 'transit':
        return MapLandmarkType.busStation;
      case 'train_station':
      case 'rail':
      case 'railway':
        return MapLandmarkType.trainStation;
      case 'airport':
        return MapLandmarkType.airport;
      case 'taxi':
        return MapLandmarkType.taxi;
      case 'government':
      case 'townhall':
      case 'town_hall':
        return MapLandmarkType.government;
      case 'police':
        return MapLandmarkType.police;
      case 'fire_station':
        return MapLandmarkType.fireStation;
      case 'post_office':
      case 'post':
        return MapLandmarkType.postOffice;
      case 'embassy':
        return MapLandmarkType.embassy;
      case 'park':
        return MapLandmarkType.park;
      case 'playground':
        return MapLandmarkType.playground;
      case 'museum':
        return MapLandmarkType.museum;
      case 'cinema':
      case 'theater':
      case 'theatre':
        return MapLandmarkType.cinema;
      case 'gym':
      case 'fitness':
      case 'fitness_centre':
        return MapLandmarkType.gym;
      case 'stadium':
      case 'sports':
        return MapLandmarkType.stadium;
      case 'beach':
        return MapLandmarkType.beach;
      case 'zoo':
        return MapLandmarkType.zoo;
      case 'aquarium':
        return MapLandmarkType.aquarium;
      case 'attraction':
      case 'tourist':
      case 'viewpoint':
        return MapLandmarkType.attraction;
      case 'car_repair':
      case 'garage':
        return MapLandmarkType.carRepair;
      case 'car_rental':
        return MapLandmarkType.carRental;
      case 'laundry':
        return MapLandmarkType.laundry;
      case 'hairdresser':
      case 'beauty':
        return MapLandmarkType.hairdresser;
      case 'toilet':
      case 'toilets':
      case 'restroom':
        return MapLandmarkType.toilet;
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
