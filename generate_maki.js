const fs = require('fs');
const path = require('path');

const dir = 'assets/maki_png';
const outFile = 'lib/core/map/maki_icons_data.dart';

const files = fs.readdirSync(dir).filter(f => f.endsWith('.png')).sort();

let body = '';
body += '// Official Mapbox Maki (CC0)\n';
body += "import 'dart:convert';\n";
body += "import 'dart:typed_data';\n";
body += '\n';
body += 'class MakiIcons {\n';
body += '  MakiIcons._();\n';
body += '  static final Map<String, Uint8List> _cache = {};\n';
body += '  static Uint8List? bytes(String makiName) {\n';
body += '    final hit = _cache[makiName];\n';
body += '    if (hit != null) return hit;\n';
body += '    final b64 = _b64[makiName];\n';
body += '    if (b64 == null) return null;\n';
body += '    final decoded = base64Decode(b64);\n';
body += '    _cache[makiName] = decoded;\n';
body += '    return decoded;\n';
body += '  }\n';
body += '  static const Map<String, String> _b64 = {\n';

for (const f of files) {
  const stem = f.replace(/\.png$/, '');
  const b64 = fs.readFileSync(path.join(dir, f)).toString('base64');
  body += "    '" + stem + "': '" + b64 + "',\n";
}

body += '  };\n';
body += '}\n';

fs.writeFileSync(outFile, body);
console.log('OK icons:', files.length);
console.log('Wrote:', outFile);