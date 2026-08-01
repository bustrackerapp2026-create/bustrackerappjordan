/// كلاس أخطاء مخصص للتعامل مع استثناءات نقاط التجمع
class PickupPointServiceException implements Exception {
  final String message;
  final String? code;

  const PickupPointServiceException(this.message, {this.code});

  @override
  String toString() => message;
}
