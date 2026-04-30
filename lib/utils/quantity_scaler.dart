/// Scales a recipe quantity string by a ratio.
///
/// Handles:
///   "2 cups"        × 0.5 → "1 cups"
///   "1/2 tsp"       × 2   → "1 tsp"
///   "1 1/2 cups"    × 2   → "3 cups"
///   "1.5 oz"        × 0.5 → "3/4 oz"
///   "2-3 cloves"    × 2   → "4-6 cloves"
///   "300 g"         × 1.5 → "450 g"
///   "to taste"      × any → "to taste"        (non-numeric, unchanged)
///   "Pinch of salt" × any → "Pinch of salt"   (non-numeric, unchanged)
class QuantityScaler {
  static String scale(String original, double ratio) {
    if (ratio == 1.0) return original;
    if (original.trim().isEmpty) return original;

    final scaled = _scaleString(original, ratio);
    return scaled ?? original;
  }

  // --- internals ---

  static final _rangeRegex = RegExp(
    r'^\s*(\d+(?:\.\d+)?(?:\s+\d+/\d+)?|\d+/\d+)\s*(?:-|–|to)\s*(\d+(?:\.\d+)?(?:\s+\d+/\d+)?|\d+/\d+)\s*(.*)$',
  );

  static final _singleRegex = RegExp(
    r'^\s*(\d+(?:\.\d+)?(?:\s+\d+/\d+)?|\d+/\d+)\s*(.*)$',
  );

  static String? _scaleString(String s, double ratio) {
    final rangeMatch = _rangeRegex.firstMatch(s);
    if (rangeMatch != null) {
      final lo = _parseNumber(rangeMatch.group(1)!);
      final hi = _parseNumber(rangeMatch.group(2)!);
      final rest = (rangeMatch.group(3) ?? '').trim();
      if (lo != null && hi != null) {
        final scaledLo = _formatNumber(lo * ratio);
        final scaledHi = _formatNumber(hi * ratio);
        return rest.isEmpty
            ? '$scaledLo–$scaledHi'
            : '$scaledLo–$scaledHi $rest';
      }
    }

    final singleMatch = _singleRegex.firstMatch(s);
    if (singleMatch != null) {
      final value = _parseNumber(singleMatch.group(1)!);
      final rest = (singleMatch.group(2) ?? '').trim();
      if (value != null) {
        final scaled = _formatNumber(value * ratio);
        return rest.isEmpty ? scaled : '$scaled $rest';
      }
    }

    return null;
  }

  static double? _parseNumber(String raw) {
    final s = raw.trim();
    final mixed = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(s);
    if (mixed != null) {
      final whole = int.parse(mixed.group(1)!);
      final num = int.parse(mixed.group(2)!);
      final den = int.parse(mixed.group(3)!);
      if (den == 0) return null;
      return whole + num / den;
    }
    final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(s);
    if (frac != null) {
      final num = int.parse(frac.group(1)!);
      final den = int.parse(frac.group(2)!);
      if (den == 0) return null;
      return num / den;
    }
    return double.tryParse(s);
  }

  static const _kFractions = <(double, String)>[
    (1 / 8, '1/8'),
    (1 / 4, '1/4'),
    (1 / 3, '1/3'),
    (1 / 2, '1/2'),
    (2 / 3, '2/3'),
    (3 / 4, '3/4'),
  ];

  static String _formatNumber(double n) {
    if (n.isNaN || n.isInfinite) return '0';
    if (n <= 0) return '0';

    final whole = n.floor();
    final frac = n - whole;

    // Distance to nearest "kitchen-friendly" fraction.
    var bestLabel = '';
    var bestDist = frac; // the distance from frac to 0 (no fraction at all)
    for (final (value, label) in _kFractions) {
      final d = (frac - value).abs();
      if (d < bestDist) {
        bestDist = d;
        bestLabel = label;
      }
    }

    // If we're closer to rounding up than to any fraction, do that.
    final upDist = 1 - frac;
    if (upDist < bestDist) {
      return '${whole + 1}';
    }

    // If even the closest fraction is too far off, fall back to a 1-decimal.
    // This avoids forcing things like 0.42 → 1/2.
    if (bestDist > 0.07) {
      final rounded = (n * 10).round() / 10;
      if (rounded == rounded.floorToDouble()) return '${rounded.toInt()}';
      return rounded.toStringAsFixed(1);
    }

    if (bestLabel.isEmpty) {
      return whole == 0 ? '0' : '$whole';
    }
    return whole == 0 ? bestLabel : '$whole $bestLabel';
  }
}
