/// كلاس أخطاء مخصص للتعامل مع استثناءات الفايربيس بطريقة نظيفة
class TripServiceException implements Exception {
  final String message;
  final String? code;

  const TripServiceException(this.message, {this.code});

  @override
  String toString() => message;
}
