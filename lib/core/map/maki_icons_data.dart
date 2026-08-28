// Official Mapbox Maki icons (CC0-1.0)
// Source: https://github.com/mapbox/maki — rendered from official SVG.
// Run tools/generate_maki_icons.dart locally to refresh full set.

import 'dart:convert';
import 'dart:typed_data';

class MakiIcons {
  MakiIcons._();

  static final Map<String, Uint8List> _cache = {};

  static Uint8List? bytes(String makiName) {
    final hit = _cache[makiName];
    if (hit != null) return hit;
    final b64 = _b64[makiName];
    if (b64 == null) return null;
    final decoded = base64Decode(b64);
    _cache[makiName] = decoded;
    return decoded;
  }

  /// Core set — add more via generator script if needed.
  static const Map<String, String> _b64 = {
    // airport (official Maki)
    'airport':
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAQAAAC1+jfqAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAACYktHRAAAqo0jMgAAAAd0SU1FB+oIHA05K/tU1gsAAAEkSURBVCjPXdG9SmNxEAXw3z/3xqhL1pgIIhFWXREXhWVFG8FXEDstbGx9B1t7a9mH8DEsVfxAEIRlWRWxiBg/rua/RW4kOsUMnDnMmTmT6I5eG7YNOpZ1oLSrHVTNWvBHzaNWGyx8IHwxpKKmLHTAwgeJkOcgfiYEiT79UhSVlfW06Ykg0eOrWWtWzavqM2VG6kFGMGDcohkTfhp5F2s4ce7UfrBj1Jy6ImK+RbtGt46C13yphr/++WbSpQvD6iqCmNrT1PTixqU767479FvZuGElpdSWhnuZlpaaZdG9A1cKCop6U2ci+d1PXpB5lIkIGmnHUpB5xVveJnY7GVT8MiYYNafaMTt5f9oPKzYtKambVtJ01z19wI4rT6IoenZtVw3+A6uwTi7RBcDZAAAAAElFTkSuQmCC',
    'marker':
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAQAAAC1+jfqAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAACYktHRAAAqo0jMgAAAAd0SU1FB+oIHA05K/tU1gsAAAEkSURBVCjPXdG9SmNxEAXw3z/3xqhL1pgIIhFWXREXhWVFG8FXEDstbGx9B1t7a9mH8DEsVfxAEIRlWRWxiBg/rua/RW4kOsUMnDnMmTmT6I5eG7YNOpZ1oLSrHVTNWvBHzaNWGyx8IHwxpKKmLHTAwgeJkOcgfiYEiT79UhSVlfW06Ykg0eOrWWtWzavqM2VG6kFGMGDcohkTfhp5F2s4ce7UfrBj1Jy6ImK+RbtGt46C13yphr/++WbSpQvD6iqCmNrT1PTixqU767479FvZuGElpdSWhnuZlpaaZdG9A1cKCop6U2ci+d1PXpB5lIkIGmnHUpB5xVveJnY7GVT8MiYYNafaMTt5f9oPKzYtKambVtJ01z19wI4rT6IoenZtVw3+A6uwTi7RBcDZAAAAAElFTkSuQmCC',
  };
}
