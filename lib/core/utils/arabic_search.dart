/// تطبيع وبحث ذكي لأسماء الخطوط العربية.
class ArabicSearch {
  ArabicSearch._();

  /// توحيد الحروف العربية وإزالة التشكيل والرموز الزائدة.
  static String normalize(String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return s;

    const diacritics = 'ًٌٍَُِّْـ';
    for (final c in diacritics.split('')) {
      s = s.replaceAll(c, '');
    }

    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ء', '');

    s = s.replaceAll(RegExp(r'[\-_/|،,\.]+'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static List<String> tokens(String input) {
    return normalize(input)
        .split(' ')
        .where((t) => t.length >= 2)
        .toList();
  }

  /// مفاتيح بحث تُخزَّن في Firestore لتسهيل المطابقة التقريبية.
  static List<String> buildSearchKeys(
    String lineName, {
    List<String> aliases = const [],
  }) {
    final keys = <String>{};
    final sources = <String>[lineName, ...aliases];

    for (final src in sources) {
      final n = normalize(src);
      if (n.isEmpty) continue;
      keys.add(n);

      final parts = tokens(src);
      for (final p in parts) {
        keys.add(p);
      }
      if (parts.length >= 2) {
        keys.add(parts.join(' '));
        keys.add(parts.reversed.join(' '));
        // أزواج متجاورة: عمان الزرقاء
        for (var i = 0; i < parts.length - 1; i++) {
          keys.add('${parts[i]} ${parts[i + 1]}');
          keys.add('${parts[i + 1]} ${parts[i]}');
        }
      }
    }

    return keys.toList();
  }

  /// هل الاستعلام يطابق اسم الخط أو مفاتيحه؟
  static bool matches({
    required String query,
    required String lineName,
    List<String> searchKeys = const [],
    List<String> aliases = const [],
  }) {
    final q = normalize(query);
    if (q.isEmpty) return false;

    final nameN = normalize(lineName);
    if (nameN.contains(q) || q.contains(nameN)) return true;

    for (final a in aliases) {
      final an = normalize(a);
      if (an.contains(q) || q.contains(an)) return true;
    }

    for (final k in searchKeys) {
      final kn = normalize(k);
      if (kn.isEmpty) continue;
      if (kn.contains(q) || q.contains(kn)) return true;
    }

    // تداخل الكلمات: "زرقاء عمان" ≈ "عمان - الزرقاء"
    final qTokens = tokens(query);
    if (qTokens.isEmpty) return false;
    final nameTokens = tokens(lineName);
    final keyTokenSet = <String>{
      ...nameTokens,
      for (final k in searchKeys) ...tokens(k),
      for (final a in aliases) ...tokens(a),
    };

    var hit = 0;
    for (final t in qTokens) {
      if (keyTokenSet.any((k) => k.contains(t) || t.contains(k))) {
        hit++;
      }
    }
    // يكفي تطابق أغلب الكلمات أو كلمة واحدة مميزة (≥3 أحرف)
    if (qTokens.length == 1) return hit == 1;
    return hit >= (qTokens.length / 2).ceil();
  }
}
