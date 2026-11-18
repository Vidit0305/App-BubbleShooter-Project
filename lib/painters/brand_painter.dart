import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Premium "glass" bubble used by the app icon, logo and menus: glow, soft
/// drop shadow, deep radial body, rim light, glossy highlight and sparkle.
class GlassBubble {
  const GlassBubble._();

  static void paint(
    Canvas canvas,
    Offset c,
    double r,
    Color color, {
    double glow = 0.55,
    bool shadow = true,
    bool monochrome = false,
  }) {
    if (monochrome) {
      canvas.drawCircle(c, r, Paint()..color = Colors.white);
      return;
    }
    final light = Color.lerp(color, Colors.white, 0.6)!;
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    final deep = Color.lerp(color, Colors.black, 0.65)!;

    if (glow > 0) {
      canvas.drawCircle(
        c,
        r * 1.7,
        Paint()
          ..shader = ui.Gradient.radial(c, r * 1.7, [
            color.withValues(alpha: glow),
            color.withValues(alpha: 0),
          ]),
      );
    }
    if (shadow) {
      canvas.drawOval(
        Rect.fromCenter(center: c + Offset(0, r * 0.22), width: r * 1.9, height: r * 1.75),
        Paint()
          ..color = const Color(0x73000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.14),
      );
    }

    // Body.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.35, -r * 0.42),
          r * 1.45,
          [light, color, dark, deep],
          const [0.0, 0.42, 0.82, 1.0],
        ),
    );

    // Rim light along the lower right edge (reflected light).
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.86),
      0.15,
      1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.09
        ..color = Colors.white.withValues(alpha: 0.42)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
    );

    // Thin edge.
    canvas.drawCircle(
      c,
      r * 0.985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = deep.withValues(alpha: 0.7),
    );

    // Glossy top highlight.
    canvas.save();
    canvas.translate(c.dx - r * 0.28, c.dy - r * 0.46);
    canvas.rotate(-0.42);
    final hl = Rect.fromCenter(center: Offset.zero, width: r * 1.0, height: r * 0.56);
    canvas.drawOval(
      hl,
      Paint()
        ..shader = ui.Gradient.linear(hl.topCenter, hl.bottomCenter, [
          Colors.white.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.05),
        ]),
    );
    canvas.restore();

    // Sparkle.
    canvas.drawCircle(
      c + Offset(-r * 0.58, -r * 0.05),
      r * 0.075,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  /// Four-pointed sparkle star.
  static void sparkle(Canvas canvas, Offset c, double size, {double opacity = 1}) {
    final path = Path()
      ..moveTo(c.dx, c.dy - size)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + size, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + size)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - size, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - size)
      ..close();
    canvas.drawCircle(
      c,
      size * 0.9,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.5),
    );
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: opacity));
  }
}

/// The brand artwork shared by the launcher icon and the home screen logo.
class BrandArt {
  const BrandArt._();

  static const Color azure = Color(0xFF1FA8FF);
  static const Color magenta = Color(0xFFFF4FA3);
  static const Color gold = Color(0xFFFFC23D);

  /// Deep indigo background with a soft top-left light and a glow behind the
  /// emblem. Fills [rect].
  static void paintBackground(Canvas canvas, Rect rect) {
    final s = rect.shortestSide;
    Offset p(double x, double y) => rect.topLeft + Offset(x * rect.width, y * rect.height);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          p(0.5, 0.38),
          s * 0.95,
          const [Color(0xFF4433E0), Color(0xFF231A86), Color(0xFF0C0838)],
          const [0.0, 0.55, 1.0],
        ),
    );
    // Cool light from the top-left.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(p(0.18, 0.08), s * 0.6, [
          const Color(0xFF8FD3FF).withValues(alpha: 0.32),
          const Color(0xFF8FD3FF).withValues(alpha: 0),
        ]),
    );
    // Warm glow behind the emblem.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(p(0.52, 0.56), s * 0.45, [
          const Color(0xFF34C6FF).withValues(alpha: 0.35),
          const Color(0xFF34C6FF).withValues(alpha: 0),
        ]),
    );
    // Faint large bubble silhouettes for depth.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.006
      ..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawCircle(p(0.88, 0.86), s * 0.2, ring);
    canvas.drawCircle(p(0.1, 0.62), s * 0.12, ring);
    canvas.drawCircle(p(0.86, 0.14), s * 0.08, ring);
  }

  /// A honeycomb pyramid of three glass bubbles (like the game grid), an
  /// aiming trail and sparkles, laid out inside the square [rect].
  static void paintEmblem(Canvas canvas, Rect rect, {bool monochrome = false, double time = 0}) {
    final s = rect.shortestSide;
    Offset p(double x, double y) => rect.topLeft + Offset(x * rect.width, y * rect.height);
    final bob = math.sin(time * 1.6) * s * 0.008;
    const r = 0.185;

    // Aiming trail rising towards the cluster.
    final dot = Paint()..color = Colors.white.withValues(alpha: monochrome ? 1 : 0.9);
    const dots = [(0.115, 0.95, 0.016), (0.16, 0.895, 0.02), (0.21, 0.84, 0.024)];
    for (final (x, y, d) in dots) {
      canvas.drawCircle(p(x, y), s * d, dot);
    }

    GlassBubble.paint(
      canvas,
      p(0.5, 0.285) + Offset(0, -bob),
      s * r,
      gold,
      glow: 0.5,
      monochrome: monochrome,
    );
    GlassBubble.paint(
      canvas,
      p(0.31, 0.615) + Offset(0, bob * 0.6),
      s * r,
      magenta,
      glow: 0.5,
      monochrome: monochrome,
    );
    GlassBubble.paint(
      canvas,
      p(0.69, 0.615) + Offset(0, bob),
      s * r,
      azure,
      glow: 0.5,
      monochrome: monochrome,
    );

    if (!monochrome) {
      final twinkle = 0.75 + 0.25 * math.sin(time * 3);
      GlassBubble.sparkle(canvas, p(0.8, 0.2), s * 0.045 * twinkle);
      GlassBubble.sparkle(canvas, p(0.18, 0.24), s * 0.028, opacity: 0.9);
      GlassBubble.sparkle(canvas, p(0.9, 0.9), s * 0.024, opacity: 0.8 * twinkle);
    }
  }
}

/// Animated brand emblem for the home screen.
class BrandEmblem extends StatefulWidget {
  const BrandEmblem({super.key, this.size = 180});

  final double size;

  @override
  State<BrandEmblem> createState() => _BrandEmblemState();
}

class _BrandEmblemState extends State<BrandEmblem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: RepaintBoundary(child: CustomPaint(painter: _EmblemPainter(_controller))),
  );
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    BrandArt.paintEmblem(canvas, Offset.zero & size, time: animation.value * 8 * math.pi / 1.6);
  }

  @override
  bool shouldRepaint(_EmblemPainter oldDelegate) => false;
}
