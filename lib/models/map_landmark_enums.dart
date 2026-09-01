part of 'map_landmark.dart';

enum MapLandmarkType {
  restaurant,
  cafe,
  fastFood,
  bakery,
  bar,
  hotel,
  house,
  shop,
  supermarket,
  clothing,
  convenience,
  market,
  hospital,
  medicalCenter,
  pharmacy,
  clinic,
  dentist,
  school,
  university,
  college,
  kindergarten,
  library,
  mosque,
  church,
  bank,
  atm,
  fuel,
  chargingStation,
  parking,
  busStation,
  trainStation,
  airport,
  taxi,
  roundabout,
  trafficLight,
  pedestrianBridge,
  vehicleBridge,
  crosswalk,
  tunnel,
  warningTriangle,
  government,
  police,
  fireStation,
  postOffice,
  embassy,
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
  carRepair,
  carRental,
  laundry,
  hairdresser,
  barber,
  beautySalon,
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
      case MapLandmarkType.house:
        return 'house';
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
      case MapLandmarkType.medicalCenter:
        return 'medical_center';
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
      case MapLandmarkType.college:
        return 'college';
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
      case MapLandmarkType.roundabout:
        return 'roundabout';
      case MapLandmarkType.trafficLight:
        return 'traffic_light';
      case MapLandmarkType.pedestrianBridge:
        return 'pedestrian_bridge';
      case MapLandmarkType.vehicleBridge:
        return 'vehicle_bridge';
      case MapLandmarkType.crosswalk:
        return 'crosswalk';
      case MapLandmarkType.tunnel:
        return 'tunnel';
      case MapLandmarkType.warningTriangle:
        return 'warning_triangle';
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
      case MapLandmarkType.barber:
        return 'barber';
      case MapLandmarkType.beautySalon:
        return 'beauty_salon';
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
      case MapLandmarkType.house:
        return 'منزل';
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
      case MapLandmarkType.medicalCenter:
        return 'مركز طبي';
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
      case MapLandmarkType.college:
        return 'كلية';
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
      case MapLandmarkType.roundabout:
        return 'دوار';
      case MapLandmarkType.trafficLight:
        return 'إشارة مرور';
      case MapLandmarkType.pedestrianBridge:
        return 'جسر مشاة';
      case MapLandmarkType.vehicleBridge:
        return 'جسر سيارات';
      case MapLandmarkType.crosswalk:
        return 'ممر مشاة';
      case MapLandmarkType.tunnel:
        return 'نفق';
      case MapLandmarkType.warningTriangle:
        return 'مثلث تحذيري';
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
      case MapLandmarkType.barber:
        return 'صالون رجال';
      case MapLandmarkType.beautySalon:
        return 'صالون نسائي';
      case MapLandmarkType.toilet:
        return 'دورة مياه';
      case MapLandmarkType.other:
        return 'معلم آخر';
    }
  }

  String get labelMapboxAr {
    switch (this) {
      case MapLandmarkType.restaurant:
        return 'مطعم · طعام';
      case MapLandmarkType.cafe:
        return 'مقهى · مشروبات';
      case MapLandmarkType.fastFood:
        return 'وجبات سريعة · طعام';
      case MapLandmarkType.bakery:
        return 'مخبز · طعام';
      case MapLandmarkType.bar:
        return 'بار · مشروبات';
      case MapLandmarkType.hotel:
        return 'فندق · إقامة';
      case MapLandmarkType.house:
        return 'منزل · سكن';
      case MapLandmarkType.shop:
        return 'متجر · تسوق';
      case MapLandmarkType.supermarket:
        return 'سوبرماركت · تسوق';
      case MapLandmarkType.clothing:
        return 'ملابس · تسوق';
      case MapLandmarkType.convenience:
        return 'بقالة · تسوق';
      case MapLandmarkType.market:
        return 'سوق · تسوق';
      case MapLandmarkType.hospital:
        return 'مستشفى · صحة';
      case MapLandmarkType.medicalCenter:
        return 'مركز طبي · صحة';
      case MapLandmarkType.pharmacy:
        return 'صيدلية · صحة';
      case MapLandmarkType.clinic:
        return 'عيادة · صحة';
      case MapLandmarkType.dentist:
        return 'أسنان · صحة';
      case MapLandmarkType.school:
        return 'مدرسة · تعليم';
      case MapLandmarkType.university:
        return 'جامعة · تعليم';
      case MapLandmarkType.college:
        return 'كلية · تعليم';
      case MapLandmarkType.kindergarten:
        return 'روضة · تعليم';
      case MapLandmarkType.library:
        return 'مكتبة · تعليم';
      case MapLandmarkType.mosque:
        return 'مسجد · مكان عبادة';
      case MapLandmarkType.church:
        return 'كنيسة · مكان عبادة';
      case MapLandmarkType.bank:
        return 'بنك · مالية';
      case MapLandmarkType.atm:
        return 'صراف آلي · مالية';
      case MapLandmarkType.fuel:
        return 'محطة بنزين · مواصلات';
      case MapLandmarkType.chargingStation:
        return 'شحن كهربائي · مواصلات';
      case MapLandmarkType.parking:
        return 'موقف · مواصلات';
      case MapLandmarkType.busStation:
        return 'موقف حافلات · مواصلات';
      case MapLandmarkType.trainStation:
        return 'محطة قطار · مواصلات';
      case MapLandmarkType.airport:
        return 'مطار · مواصلات';
      case MapLandmarkType.taxi:
        return 'تاكسي · مواصلات';
      case MapLandmarkType.roundabout:
        return 'دوار · طريق';
      case MapLandmarkType.trafficLight:
        return 'إشارة · طريق';
      case MapLandmarkType.pedestrianBridge:
        return 'جسر مشاة · طريق';
      case MapLandmarkType.vehicleBridge:
        return 'جسر · طريق';
      case MapLandmarkType.crosswalk:
        return 'ممر مشاة · طريق';
      case MapLandmarkType.tunnel:
        return 'نفق · طريق';
      case MapLandmarkType.warningTriangle:
        return 'تحذير · طريق';
      case MapLandmarkType.government:
        return 'حكومي · خدمة';
      case MapLandmarkType.police:
        return 'شرطة · خدمة';
      case MapLandmarkType.fireStation:
        return 'إطفاء · خدمة';
      case MapLandmarkType.postOffice:
        return 'بريد · خدمة';
      case MapLandmarkType.embassy:
        return 'سفارة · خدمة';
      case MapLandmarkType.park:
        return 'حديقة · ترفيه';
      case MapLandmarkType.playground:
        return 'ملعب أطفال · ترفيه';
      case MapLandmarkType.museum:
        return 'متحف · ثقافة';
      case MapLandmarkType.cinema:
        return 'سينما · ترفيه';
      case MapLandmarkType.gym:
        return 'نادي · رياضة';
      case MapLandmarkType.stadium:
        return 'استاد · رياضة';
      case MapLandmarkType.beach:
        return 'شاطئ · ترفيه';
      case MapLandmarkType.zoo:
        return 'حديقة حيوان · ترفيه';
      case MapLandmarkType.aquarium:
        return 'أكواريوم · ترفيه';
      case MapLandmarkType.attraction:
        return 'معلم · سياحة';
      case MapLandmarkType.carRepair:
        return 'ورشة · سيارات';
      case MapLandmarkType.carRental:
        return 'تأجير · سيارات';
      case MapLandmarkType.laundry:
        return 'مغسلة · خدمة';
      case MapLandmarkType.hairdresser:
        return 'حلاقة · خدمة';
      case MapLandmarkType.barber:
        return 'حلاقة رجال · خدمة';
      case MapLandmarkType.beautySalon:
        return 'تجميل · خدمة';
      case MapLandmarkType.toilet:
        return 'دورة مياه · خدمة';
      case MapLandmarkType.other:
        return 'أخرى';
    }
  }

  static MapLandmarkType fromString(String? v) {
    switch ((v ?? '').toLowerCase().trim()) {
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
        return MapLandmarkType.bar;
      case 'hotel':
      case 'lodging':
        return MapLandmarkType.hotel;
      case 'house':
      case 'home':
        return MapLandmarkType.house;
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
        return MapLandmarkType.market;
      case 'hospital':
        return MapLandmarkType.hospital;
      case 'medical_center':
        return MapLandmarkType.medicalCenter;
      case 'pharmacy':
        return MapLandmarkType.pharmacy;
      case 'clinic':
      case 'doctor':
        return MapLandmarkType.clinic;
      case 'dentist':
        return MapLandmarkType.dentist;
      case 'school':
        return MapLandmarkType.school;
      case 'university':
        return MapLandmarkType.university;
      case 'college':
        return MapLandmarkType.college;
      case 'kindergarten':
        return MapLandmarkType.kindergarten;
      case 'library':
        return MapLandmarkType.library;
      case 'mosque':
      case 'religious_muslim':
        return MapLandmarkType.mosque;
      case 'church':
      case 'religious_christian':
        return MapLandmarkType.church;
      case 'bank':
        return MapLandmarkType.bank;
      case 'atm':
        return MapLandmarkType.atm;
      case 'fuel':
        return MapLandmarkType.fuel;
      case 'charging_station':
        return MapLandmarkType.chargingStation;
      case 'parking':
        return MapLandmarkType.parking;
      case 'bus_station':
      case 'bus':
        return MapLandmarkType.busStation;
      case 'train_station':
      case 'rail':
        return MapLandmarkType.trainStation;
      case 'airport':
        return MapLandmarkType.airport;
      case 'taxi':
        return MapLandmarkType.taxi;
      case 'roundabout':
      case 'rotary':
        return MapLandmarkType.roundabout;
      case 'traffic_light':
      case 'traffic_signals':
        return MapLandmarkType.trafficLight;
      case 'pedestrian_bridge':
      case 'footbridge':
        return MapLandmarkType.pedestrianBridge;
      case 'vehicle_bridge':
      case 'bridge':
        return MapLandmarkType.vehicleBridge;
      case 'crosswalk':
      case 'crossing':
        return MapLandmarkType.crosswalk;
      case 'tunnel':
        return MapLandmarkType.tunnel;
      case 'warning_triangle':
      case 'caution':
        return MapLandmarkType.warningTriangle;
      case 'government':
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
        return MapLandmarkType.cinema;
      case 'gym':
      case 'fitness_centre':
        return MapLandmarkType.gym;
      case 'stadium':
        return MapLandmarkType.stadium;
      case 'beach':
        return MapLandmarkType.beach;
      case 'zoo':
        return MapLandmarkType.zoo;
      case 'aquarium':
        return MapLandmarkType.aquarium;
      case 'attraction':
        return MapLandmarkType.attraction;
      case 'car_repair':
        return MapLandmarkType.carRepair;
      case 'car_rental':
        return MapLandmarkType.carRental;
      case 'laundry':
        return MapLandmarkType.laundry;
      case 'hairdresser':
        return MapLandmarkType.hairdresser;
      case 'barber':
        return MapLandmarkType.barber;
      case 'beauty_salon':
        return MapLandmarkType.beautySalon;
      case 'toilet':
        return MapLandmarkType.toilet;
      default:
        return MapLandmarkType.other;
    }
  }
}
