# توليد رموز Mapbox Maki الرسمية بالكامل

الرموز الرسمية مفتوحة المصدر (CC0): https://github.com/mapbox/maki

## على جهازك (مرة واحدة)

```bash
# 1) تنزيل الحزمة
npm pack @mapbox/maki@8.0.1
tar -xzf mapbox-maki-*.tgz

# 2) تحويل SVG → PNG (يتطلب ImageMagick)
mkdir -p assets/maki_png
for f in package/icons/*.svg; do
  name=$(basename "$f" .svg)
  convert -background none -density 300 -resize 32x32 "$f" "assets/maki_png/${name}.png"
done

# 3) توليد ملف Dart
python3 - <<'PY'
import base64, pathlib
out = pathlib.Path('lib/core/map/maki_icons_data.dart')
lines = [
  '// Official Mapbox Maki (CC0) https://github.com/mapbox/maki',
  "import 'dart:convert';",
  "import 'dart:typed_data';",
  '',
  'class MakiIcons {',
  '  MakiIcons._();',
  '  static final Map<String, Uint8List> _cache = {};',
  '  static Uint8List? bytes(String makiName) {',
  '    final hit = _cache[makiName];',
  '    if (hit != null) return hit;',
  '    final b64 = _b64[makiName];',
  '    if (b64 == null) return null;',
  '    final decoded = base64Decode(b64);',
  '    _cache[makiName] = decoded;',
  '    return decoded;',
  '  }',
  '  static const Map<String, String> _b64 = {',
]
for p in sorted(pathlib.Path('assets/maki_png').glob('*.png')):
  b64 = base64.b64encode(p.read_bytes()).decode()
  lines.append(f"    '{p.stem}': '{b64}',")
lines += ['  };', '}', '']
out.write_text('\n'.join(lines), encoding='utf-8')
print('Wrote', out)
PY
```

ثم:

```bash
flutter pub get
flutter run
```

الكود في `landmark_marker_images.dart` يقرأ من `MakiIcons.bytes(makiName)` ويلّون الرمز حسب نوع المعلم.
