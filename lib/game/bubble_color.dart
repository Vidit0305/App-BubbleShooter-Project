import 'dart:ui';

/// The six classic bubble colors.
enum BubbleColor {
  red(Color(0xFFFF3B3B), 'R'),
  blue(Color(0xFF2F80FF), 'B'),
  green(Color(0xFF2ECC40), 'G'),
  yellow(Color(0xFFFFD60A), 'Y'),
  purple(Color(0xFFA442F5), 'P'),
  orange(Color(0xFFFF8A1F), 'O');

  const BubbleColor(this.color, this.code);

  /// Base display color.
  final Color color;

  /// Single-letter code, handy for debugging and tests.
  final String code;

  /// Lighter tint used for the glossy gradient.
  Color get light => Color.lerp(color, const Color(0xFFFFFFFF), 0.45)!;

  /// Darker shade used for the gradient edge and border.
  Color get dark => Color.lerp(color, const Color(0xFF000000), 0.45)!;

  static BubbleColor? fromCode(String code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }
}
