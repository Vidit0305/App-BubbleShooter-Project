import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Layered animated backdrop: deep indigo gradient, drifting aurora glows,
/// twinkling stars, rising glass bubbles and a vignette.
///
/// [animated] = false paints a single calm frame (used behind gameplay so
/// it never distracts and never repaints).
class PremiumBackground extends StatefulWidget {
  const PremiumBackground({
    super.key,
    required this.child,
    this.animated = true,
    this.floatingBubbles = true,
    this.intensity = 1,
  });

  final Widget child;
  final bool animated;
  final bool floatingBubbles;

  /// Strength of the aurora glows (0..1).
  final double intensity;

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground> with SingleTickerProviderStateMixin {
  static const double _period = 60; // seconds per animation cycle
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated) _controller.repeat();
  }

  @override
  void didUpdateWidget(PremiumBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !_controller.isAnimating) _controller.repeat();
    if (!widget.animated && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _BackgroundPainter(
              _controller,
              period: _period,
              floatingBubbles: widget.floatingBubbles,
              intensity: widget.intensity,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Star {
  const _Star(this.x, this.y, this.size, this.phase, this.speed);
  final double x, y, size, phase, speed;
}

class _Floater {
  const _Floater(this.x, this.radius, this.speed, this.phase, this.sway, this.color);
  final double x, radius, speed, phase, sway;
  final Color color;
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(
    this.animation, {
    required this.period,
    required this.floatingBubbles,
    required this.intensity,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final double period;
  final bool floatingBubbles;
  final double intensity;

  static final math.Random _rnd = math.Random(42);
  static final List<_Star> _stars = List.generate(
    70,
    (_) => _Star(
      _rnd.nextDouble(),
      _rnd.nextDouble(),
      0.6 + _rnd.nextDouble() * 1.6,
      _rnd.nextDouble() * math.pi * 2,
      0.5 + _rnd.nextDouble() * 1.5,
    ),
  );
  static const List<Color> _bubbleColors = [
    Color(0xFF6FD3FF),
    Color(0xFFFF6FB5),
    Color(0xFFFFD36F),
    Color(0xFFB88CFF),
    Color(0xFF7DFFB0),
  ];
  static final List<_Floater> _floaters = List.generate(16, (i) {
    final depth = _rnd.nextDouble();
    return _Floater(
      _rnd.nextDouble(),
      6 + depth * 26,
      0.012 + depth * 0.03,
      _rnd.nextDouble(),
      0.01 + _rnd.nextDouble() * 0.03,
      _bubbleColors[i % _bubbleColors.length],
    );
  });

  final Paint _paint = Paint();
  final Paint _ring = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * period;
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final diag = math.sqrt(w * w + h * h);

    // Base gradient.
    _paint.shader = ui.Gradient.linear(
      rect.topCenter,
      rect.bottomCenter,
      const [Color(0xFF1C1670), Color(0xFF0F0B45), Color(0xFF06041F)],
      const [0.0, 0.5, 1.0],
    );
    canvas.drawRect(rect, _paint);

    // Aurora glows drifting on slow Lissajous paths (periods divide 60 s,
    // so the loop is seamless).
    final omega = 2 * math.pi / period;
    void glow(Offset c, double radius, Color color, double alpha) {
      _paint.shader = ui.Gradient.radial(c, radius, [
        color.withValues(alpha: alpha * intensity),
        color.withValues(alpha: 0),
      ]);
      canvas.drawRect(rect, _paint);
    }

    glow(
      Offset(w * (0.2 + 0.12 * math.sin(omega * t)), h * (0.18 + 0.06 * math.cos(omega * 2 * t))),
      diag * 0.55,
      const Color(0xFF7B3FF2),
      0.45,
    );
    glow(
      Offset(w * (0.85 + 0.1 * math.cos(omega * t)), h * (0.42 + 0.08 * math.sin(omega * t))),
      diag * 0.5,
      const Color(0xFF00B4FF),
      0.32,
    );
    glow(
      Offset(w * (0.35 + 0.15 * math.sin(omega * 3 * t)), h * (0.88 + 0.04 * math.cos(omega * t))),
      diag * 0.5,
      const Color(0xFFFF3CAC),
      0.22,
    );

    // Stars.
    for (final s in _stars) {
      // Whole number of twinkles per cycle keeps the loop seamless.
      final cycles = (s.speed * 20).roundToDouble();
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(s.phase + t * cycles * omega));
      _paint
        ..shader = null
        ..color = Colors.white.withValues(alpha: 0.55 * twinkle);
      canvas.drawCircle(Offset(s.x * w, s.y * h), s.size * 0.6, _paint);
    }

    // Rising glass bubbles with parallax.
    if (floatingBubbles) {
      for (final f in _floaters) {
        final travel = h + f.radius * 4;
        // speed is in screen heights per second; keep whole cycles per period.
        final cycles = math.max(1, (f.speed * period).round());
        final progress = (f.phase + animation.value * cycles) % 1.0;
        final y = h + f.radius * 2 - progress * travel;
        final x = f.x * w + math.sin(progress * math.pi * 4 + f.phase * 6) * f.sway * w;
        _paintFloater(canvas, Offset(x, y), f.radius, f.color);
      }
    }

    // Vignette.
    _paint.shader = ui.Gradient.radial(
      rect.center,
      diag * 0.62,
      [Colors.transparent, const Color(0xAA02010F)],
      const [0.55, 1.0],
    );
    canvas.drawRect(rect, _paint);
    _paint.shader = null;
  }

  void _paintFloater(Canvas canvas, Offset c, double r, Color color) {
    _paint.shader = ui.Gradient.radial(c + Offset(-r * 0.3, -r * 0.35), r * 1.2, [
      color.withValues(alpha: 0.05),
      color.withValues(alpha: 0.16),
    ]);
    canvas.drawCircle(c, r, _paint);
    _ring
      ..strokeWidth = math.max(1, r * 0.07)
      ..color = color.withValues(alpha: 0.45);
    canvas.drawCircle(c, r, _ring);
    _ring
      ..strokeWidth = math.max(1, r * 0.12)
      ..color = Colors.white.withValues(alpha: 0.5);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.68),
      math.pi * 1.1,
      math.pi * 0.45,
      false,
      _ring,
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) =>
      oldDelegate.floatingBubbles != floatingBubbles || oldDelegate.intensity != intensity;
}
