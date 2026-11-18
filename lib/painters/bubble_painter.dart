import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/bubble_color.dart';

/// Draws glossy, slightly 3D bubbles: soft drop shadow, radial gradient body,
/// darker rim and an upper-left highlight.
///
/// Paints (including gradient shaders) are built once per color in a unit
/// coordinate space and reused; each bubble is drawn by translating and
/// scaling the canvas, so no objects are allocated per frame.
class BubblePainter {
  const BubblePainter._();

  static final Map<BubbleColor, _BubbleStyle> _styles = {
    for (final c in BubbleColor.values) c: _BubbleStyle(c),
  };

  static final Paint _shadowPaint = Paint()..color = const Color(0x40000000);
  static final Paint _highlightPaint = Paint()..color = const Color(0xB3FFFFFF);
  static final Paint _sparklePaint = Paint()..color = const Color(0xE6FFFFFF);
  static final Paint _layerPaint = Paint();
  static const Rect _highlightRect = Rect.fromLTWH(-0.62, -0.72, 0.62, 0.36);

  /// Paints a bubble centered at [center] with [radius] (canvas units).
  static void paint(
    Canvas canvas,
    Offset center,
    double radius,
    BubbleColor color, {
    double opacity = 1,
    bool shadow = true,
  }) {
    if (opacity <= 0) return;
    final style = _styles[color]!;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius);
    final fading = opacity < 1;
    if (fading) {
      _layerPaint.color = Color.fromRGBO(0, 0, 0, opacity);
      canvas.saveLayer(const Rect.fromLTWH(-1.3, -1.3, 2.6, 2.6), _layerPaint);
    }
    if (shadow) canvas.drawCircle(const Offset(0.08, 0.14), 0.98, _shadowPaint);
    canvas.drawCircle(Offset.zero, 0.96, style.body);
    canvas.drawCircle(Offset.zero, 0.92, style.rim);

    canvas.save();
    canvas.rotate(-0.5);
    canvas.drawOval(_highlightRect.shift(const Offset(0.28, 0.02)), _highlightPaint);
    canvas.restore();
    canvas.drawCircle(const Offset(-0.5, -0.12), 0.09, _sparklePaint);

    if (fading) canvas.restore();
    canvas.restore();
  }
}

/// The rainbow (wildcard) bubble: a slowly rotating sweep of all colors with
/// a pearly center.
class RainbowBubblePainter {
  const RainbowBubblePainter._();

  static final Paint _body = Paint()
    ..shader = const SweepGradient(
      colors: [
        Color(0xFFFF3B3B),
        Color(0xFFFF8A1F),
        Color(0xFFFFD60A),
        Color(0xFF2ECC40),
        Color(0xFF2F80FF),
        Color(0xFFA442F5),
        Color(0xFFFF3B3B),
      ],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
  static final Paint _pearl = Paint()
    ..shader = ui.Gradient.radial(Offset.zero, 0.75, const [Color(0xB3FFFFFF), Color(0x00FFFFFF)]);
  static final Paint _rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.08
    ..color = const Color(0xE6FFFFFF);
  static final Paint _glow = Paint()
    ..shader = ui.Gradient.radial(Offset.zero, 1.6, const [Color(0x66FFFFFF), Color(0x00FFFFFF)]);
  static final Paint _shadow = Paint()..color = const Color(0x40000000);
  static final Paint _highlight = Paint()..color = const Color(0xCCFFFFFF);

  static void paint(Canvas canvas, Offset center, double radius, double time) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius);
    canvas.drawCircle(Offset.zero, 1.6, _glow);
    canvas.drawCircle(const Offset(0.08, 0.14), 0.98, _shadow);
    canvas.save();
    canvas.rotate(time * 1.8);
    canvas.drawCircle(Offset.zero, 0.96, _body);
    canvas.restore();
    canvas.drawCircle(const Offset(-0.15, -0.2), 0.75, _pearl);
    canvas.drawCircle(Offset.zero, 0.92, _rim);
    canvas.save();
    canvas.rotate(-0.5);
    canvas.drawOval(const Rect.fromLTWH(-0.34, -0.7, 0.62, 0.34), _highlight);
    canvas.restore();
    canvas.restore();
  }
}

class _BubbleStyle {
  _BubbleStyle(BubbleColor color)
    : body = Paint()
        ..shader = ui.Gradient.radial(
          const Offset(-0.35, -0.4),
          1.5,
          [color.light, color.color, color.dark],
          const [0.0, 0.5, 1.0],
        ),
      rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08
        ..color = Color.lerp(color.dark, const Color(0xFF000000), 0.2)!;

  final Paint body;
  final Paint rim;
}

/// A widget showing a single bubble (menus, next-bubble preview).
class BubbleView extends StatelessWidget {
  const BubbleView({super.key, required this.color, required this.size});

  final BubbleColor color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _SingleBubblePainter(color)),
  );
}

/// A spinning rainbow bubble widget (next-bubble preview).
class RainbowBubbleView extends StatefulWidget {
  const RainbowBubbleView({super.key, required this.size});

  final double size;

  @override
  State<RainbowBubbleView> createState() => _RainbowBubbleViewState();
}

class _RainbowBubbleViewState extends State<RainbowBubbleView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: CustomPaint(painter: _RainbowPainter(_controller)),
  );
}

class _RainbowPainter extends CustomPainter {
  _RainbowPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    RainbowBubblePainter.paint(
      canvas,
      size.center(Offset.zero),
      size.shortestSide / 2 * 0.85,
      animation.value * 4 * 2 * 3.14159265 / 1.8,
    );
  }

  @override
  bool shouldRepaint(_RainbowPainter oldDelegate) => false;
}

class _SingleBubblePainter extends CustomPainter {
  _SingleBubblePainter(this.color);

  final BubbleColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    BubblePainter.paint(canvas, size.center(Offset.zero), r * 0.92, color);
  }

  @override
  bool shouldRepaint(_SingleBubblePainter oldDelegate) => oldDelegate.color != color;
}
