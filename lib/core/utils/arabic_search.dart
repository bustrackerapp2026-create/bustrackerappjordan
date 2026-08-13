/// تطبيع وبحث ذكي لأسماء الخطوط العربية (مع ترتيب النتائج).
class ArabicSearch {
  ArabicSearch._();

  /// مرادفات شائعة في الأردن لتوسيع المطابقة.
  static const Map<String, List<String>> _synonyms = {
    'عمان': ['عمان', 'العاصمه', 'العاصمة', 'امان'],
    'الزرقاء': ['الزرقاء', 'زرقاء', 'الزرقه', 'زرقه'],
    'اربد': ['اربد', 'إربد'],
    'العقبه': ['العقبه', 'العقبة', 'عقبه', 'عقبة'],
    'السلط': ['السلط', 'سلط'],
    'المفرق': ['المفرق', 'مفرق'],
    'الكرك': ['الكرك', 'كرك'],
    'مادبا': ['مادبا', 'مادبة'],
    'جرش': ['جرش'],
    'عجلون': ['عجلون'],
    'الطفيله': ['الطفيله', 'الطفيلة', 'طفيله'],
    'معان': ['معان'],
    'الرمثا': ['الرمثا', 'رمثا'],
    'الصويلح': ['الصويلح', 'صويلح'],
    'الجبيهه': ['الجبيهه', 'الجبيهة', 'جبيهه'],
    'ماركا': ['ماركا'],
    'وسط البلد': ['وسط البلد', 'البلد', 'وسط'],
    'الجامعه': ['الجامعه', 'الجامعة', 'جامعه'],
    'المطار': ['المطار', 'مطار'],
    'المدينه الرياضيه': ['المدينه الرياضيه', 'المدينة الرياضية', 'الرياضيه'],
    'تلاع العلي': ['تلاع العلي', 'تلاع'],
    'خلدا': ['خلدا'],
    'الشميساني': ['الشميساني', 'شميساني'],
    'جبل الحسين': ['جبل الحسين', 'الحسين'],
    'جبل النصر': ['جبل النصر'],
    'المهاجرين': ['المهاجرين'],
    'وادي السير': ['وادي السير', 'السير'],
    'صويلح': ['صويلح', 'الصويلح'],
  };

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

    // أرقام عربية شرقية → غربية
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    for (var i = 0; i < eastern.length; i++) {
      s = s.replaceAll(eastern[i], western[i]);
    }

    s = s.replaceAll(RegExp(r'[-_/|،,\.]+'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static List<String> tokens(String input) {
    return normalize(input)
        .split(' ')
        .where((t) => t.length >= 2)
        .toList();
  }

  /// توسيع كلمة بمرادفاتها (إن وُجدت).
  static Set<String> expandToken(String token) {
    final t = normalize(token);
    if (t.isEmpty) return {};
    final out = <String>{t};

    for (final entry in _synonyms.entries) {
      final keyN = normalize(entry.key);
      final valuesN = entry.value.map(normalize).toSet();
      if (keyN == t || valuesN.contains(t) || keyN.contains(t) || t.contains(keyN)) {
        out.add(keyN);
        out.addAll(valuesN);
      }
      for (final v in valuesN) {
        if (v.contains(t) || t.contains(v)) {
          out.add(keyN);
          out.addAll(valuesN);
          break;
        }
      }
    }
    return out;
  }

  /// مفاتيح بحث تُخزَّن في Firestore.
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
        keys.addAll(expandToken(p));
        // بادئات للكتابة الجزئية: زرق → زرقاء
        if (p.length >= 3) {
          for (var len = 3; len < p.length; len++) {
            keys.add(p.substring(0, len));
          }
        }
      }
      if (parts.length >= 2) {
        keys.add(parts.join(' '));
        keys.add(parts.reversed.join(' '));
        for (var i = 0; i < parts.length - 1; i++) {
          keys.add('${parts[i]} ${parts[i + 1]}');
          keys.add('${parts[i + 1]} ${parts[i]}');
        }
      }
    }

    return keys.where((k) => k.isNotEmpty).toList();
  }

  /// مسافة تحرير تقريبية (Levenshtein) محدودة الطول.
  static int editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if ((a.length - b.length).abs() > 2) return 99;

    final m = a.length;
    final n = b.length;
    var prev = List<int>.generate(n + 1, (j) => j);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  static bool _fuzzyTokenMatch(String queryToken, String candidate) {
    if (candidate == queryToken) return true;
    if (candidate.contains(queryToken) || queryToken.contains(candidate)) {
      return true;
    }
    // تسامح خطأ إملائي واحد أو اثنين حسب الطول
    final maxDist = queryToken.length >= 5 ? 2 : 1;
    if (queryToken.length >= 3 && candidate.length >= 3) {
      return editDistance(queryToken, candidate) <= maxDist;
    }
    return false;
  }

  /// درجة المطابقة من 0 إلى 100 (أعلى = أفضل).
  static double score({
    required String query,
    required String lineName,
    List<String> searchKeys = const [],
    List<String> aliases = const [],
  }) {
    final q = normalize(query);
    if (q.isEmpty) return 0;

    final nameN = normalize(lineName);
    if (nameN.isEmpty) return 0;

    // تطابق كامل
    if (nameN == q) return 100;

    // الاسم يحتوي الاستعلام أو العكس
    if (nameN.startsWith(q)) return 92;
    if (nameN.contains(q)) return 85;
    if (q.contains(nameN) && nameN.length >= 3) return 80;

    // aliases
    for (final a in aliases) {
      final an = normalize(a);
      if (an.isEmpty) continue;
      if (an == q) return 95;
      if (an.contains(q) || q.contains(an)) return 78;
    }

    // searchKeys مباشرة
    for (final k in searchKeys) {
      final kn = normalize(k);
      if (kn.isEmpty) continue;
      if (kn == q) return 88;
      if (kn.startsWith(q) && q.length >= 3) return 75;
      if (kn.contains(q) || q.contains(kn)) return 70;
    }

    // تطابق بالكلمات + مرادفات + أخطاء إملائية
    final qTokens = tokens(query);
    if (qTokens.isEmpty) return 0;

    final candidateTokens = <String>{
      ...tokens(lineName),
      for (final k in searchKeys) ...tokens(k),
      for (final a in aliases) ...tokens(a),
    };

    // وسّع المرشحين بالمرادفات
    final expandedCandidates = <String>{...candidateTokens};
    for (final c in candidateTokens) {
      expandedCandidates.addAll(expandToken(c));
    }

    var hits = 0;
    var fuzzyHits = 0;
    for (final qt in qTokens) {
      final expandedQ = expandToken(qt);
      var matched = false;
      var fuzzy = false;

      for (final eq in expandedQ) {
        for (final c in expandedCandidates) {
          if (c == eq || c.contains(eq) || eq.contains(c)) {
            matched = true;
            break;
          }
          if (_fuzzyTokenMatch(eq, c)) {
            fuzzy = true;
          }
        }
        if (matched) break;
      }

      if (matched) {
        hits++;
      } else if (fuzzy) {
        fuzzyHits++;
      }
    }

    final total = qTokens.length;
    final coverage = (hits + fuzzyHits * 0.6) / total;

    if (hits == total) return 72;
    if (hits >= (total / 2).ceil() || coverage >= 0.5) {
      return 50 + (coverage * 20);
    }
    if (hits == 1 && total == 1) return 55;
    if (fuzzyHits > 0 && coverage >= 0.4) return 40 + (coverage * 10);

    return 0;
  }

  /// عتبة القبول الافتراضية.
  static const double minAcceptScore = 40;

  /// هل الاستعلام يطابق؟
  static bool matches({
    required String query,
    required String lineName,
    List<String> searchKeys = const [],
    List<String> aliases = const [],
    double minScore = minAcceptScore,
  }) {
    return score(
          query: query,
          lineName: lineName,
          searchKeys: searchKeys,
          aliases: aliases,
        ) >=
        minScore;
  }

  /// ترتيب قائمة عناصر حسب درجة البحث (الأعلى أولاً).
  static List<T> rankByScore<T>({
    required String query,
    required List<T> items,
    required String Function(T) lineNameOf,
    List<String> Function(T)? searchKeysOf,
    List<String> Function(T)? aliasesOf,
    double minScore = minAcceptScore,
  }) {
    final scored = <({T item, double s})>[];
    for (final item in items) {
      final s = score(
        query: query,
        lineName: lineNameOf(item),
        searchKeys: searchKeysOf?.call(item) ?? const [],
        aliases: aliasesOf?.call(item) ?? const [],
      );
      if (s >= minScore) {
        scored.add((item: item, s: s));
      }
    }
    scored.sort((a, b) => b.s.compareTo(a.s));
    return scored.map((e) => e.item).toList();
  }
}
