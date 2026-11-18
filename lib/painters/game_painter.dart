import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/bubble_grid.dart';
import '../game/game_effects.dart';
import '../game/game_engine.dart';
import 'bubble_painter.dart';

/// Renders the playfield. Repaints whenever the engine ticks; never causes
/// widget rebuilds.
class GamePainter extends CustomPainter {
  GamePainter(this.engine) : super(repaint: engine);

  final GameEngine engine;

  /// Font for score popups and banners (the app theme's font). Painters have
  /// no theme of their own, so the screen passes it in.
  String? fontFamily;

  static const double _dotSpacing = 1.1;
  static const double _dotRadius = 0.17;
  static final RRect _barrel = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, -0.55, 2.4, 1.1),
    const Radius.circular(0.35),
  );
  static const List<Color> _rainbowColors = [
    Color(0xFFFF5A5A),
    Color(0xFFFFA23A),
    Color(0xFFFFE14D),
    Color(0xFF4BE36B),
    Color(0xFF4FA3FF),
    Color(0xFFC07CFF),
  ];

  final Paint _dangerPaint = Paint()
    ..strokeWidth = 0.12
    ..strokeCap = StrokeCap.round;
  final Paint _dotPaint = Paint();
  final Paint _ghostFill = Paint();
  final Paint _ghostStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.1;
  final Paint _particlePaint = Paint();
  final Paint _trailPaint = Paint();
  final Paint _ringPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _confettiPaint = Paint();
  final Paint _flashPaint = Paint();
  final Paint _dangerGlow = Paint();
  final Paint _dimPaint = Paint()..color = const Color(0x66000000);
  final Paint _wallPaint = Paint()
    ..color = const Color(0x22FFFFFF)
    ..strokeWidth = 0.08;
  final Paint _baseFill = Paint();
  final Paint _baseRim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.14
    ..color = const Color(0xFF9FD3FF);
  final Paint _barrelPaint = Paint()..color = const Color(0xFF5F6FE0);
  final Paint _barrelRim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.1
    ..color = const Color(0xFFC6CCFF);
  final Paint _layerPaint = Paint();
  final Expando<TextPainter> _popupText = Expando<TextPainter>();
  final Expando<_BannerText> _bannerText = Expando<_BannerText>();
  double _textScale = 0;
  Size? _dangerGlowSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (!engine.isReady) return;
    final layout = engine.layout;
    final scale = layout.scale;
    if (_textScale != scale) {
      // Text caches are sized for the scale; drop them if it changes.
      _textScale = scale;
      for (final p in engine.effects.popups) {
        _popupText[p] = null;
      }
      for (final b in engine.effects.banners) {
        _bannerText[b] = null;
      }
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (engine.shakeAmount > 0) {
      final s = engine.shakeAmount * 0.9 * scale;
      canvas.translate(math.sin(engine.time * 95) * s, math.cos(engine.time * 83) * s);
    }

    _paintDangerGlow(canvas, size);
    canvas.save();
    canvas.scale(scale);

    _paintWalls(canvas);
    _paintDangerLine(canvas);
    _paintGrid(canvas);
    if (engine.phase.value == GamePhase.gameOver) {
      canvas.drawRect(Rect.fromLTWH(0, 0, layout.worldWidth, layout.worldHeight), _dimPaint);
    }
    _paintTrajectory(canvas);
    _paintLauncher(canvas);
    _paintFlying(canvas);
    _paintEffects(canvas);
    canvas.restore();

    _paintPopups(canvas, scale);
    _paintBanners(canvas, size, scale);
    _paintFlash(canvas, size);
    canvas.restore();
  }

  void _paintWalls(Canvas canvas) {
    final l = engine.layout;
    canvas.drawLine(const Offset(0.04, 0), Offset(0.04, l.worldHeight), _wallPaint);
    canvas.drawLine(
      Offset(l.worldWidth - 0.04, 0),
      Offset(l.worldWidth - 0.04, l.worldHeight),
      _wallPaint,
    );
  }

  /// Red glow rising from the bottom while bubbles are close to the line.
  void _paintDangerGlow(Canvas canvas, Size size) {
    if (!engine.isNearDanger || engine.phase.value == GamePhase.gameOver) return;
    if (_dangerGlowSize != size) {
      _dangerGlowSize = size;
      _dangerGlow.shader = ui.Gradient.linear(
        Offset(0, size.height),
        Offset(0, size.height * 0.55),
        const [Color(0xFFFF2D4A), Color(0x00FF2D4A)],
      );
    }
    final pulse = 0.5 + 0.5 * math.sin(engine.time * 6);
    _dangerGlow.color = Color.fromRGBO(0, 0, 0, 0.12 + 0.18 * pulse);
    canvas.drawRect(Offset.zero & size, _dangerGlow);
  }

  void _paintDangerLine(Canvas canvas) {
    final l = engine.layout;
    final y = l.dangerLineY;
    var alpha = 0.45;
    if (engine.isNearDanger) {
      alpha = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(engine.time * 8));
    }
    _dangerPaint.color = Color.fromRGBO(255, 77, 94, alpha);
    const dash = 0.7;
    const gap = 0.45;
    for (var x = 0.2; x < l.worldWidth; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, l.worldWidth), y), _dangerPaint);
    }
  }

  void _paintGrid(Canvas canvas) {
    final grid = engine.grid;
    final offset = engine.gridSlideOffset;
    canvas.save();
    if (offset != 0) canvas.translate(0, offset);
    grid.forEachOccupied((row, col, color) {
      BubblePainter.paint(canvas, grid.centerOf(row, col), BubbleGrid.radius, color);
    });
    canvas.restore();
  }

  void _paintTrajectory(Canvas canvas) {
    if (engine.paused.value) return;
    final trajectory = engine.trajectory;
    if (trajectory == null) return;
    final points = trajectory.points;

    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    if (total <= 0) return;

    final rainbow = engine.shooter.currentRainbow;
    final base = rainbow ? Colors.white : engine.shooter.current.light;
    final tint = Color.lerp(base, Colors.white, 0.35)!;
    // Dots march gently towards the target.
    var carry = (engine.time * 2.2) % _dotSpacing;
    var travelled = 0.0;
    var index = 0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final seg = b - a;
      final len = seg.distance;
      if (len <= 0) continue;
      final dir = seg / len;
      var t = carry;
      while (t < len) {
        final along = travelled + t;
        if (along > 1.6) {
          final fade = 1 - 0.55 * (along / total);
          final color = rainbow ? _rainbowColors[index++ % _rainbowColors.length] : tint;
          _dotPaint.color = color.withValues(alpha: 0.95 * fade);
          canvas.drawCircle(a + dir * t, _dotRadius, _dotPaint);
        }
        t += _dotSpacing;
      }
      carry = t - len;
      travelled += len;
    }

    final landing = trajectory.landingCell;
    if (landing != null) {
      final center = engine.grid.centerOfCell(landing);
      final color = rainbow ? Colors.white : engine.shooter.current.color;
      _ghostFill.color = color.withValues(alpha: 0.18);
      _ghostStroke.color = color.withValues(alpha: 0.6);
      canvas.drawCircle(center, 0.92, _ghostFill);
      canvas.drawCircle(center, 0.92, _ghostStroke);
    }
  }

  void _paintLauncher(Canvas canvas) {
    final pos = engine.shooter.position;
    final angle = engine.shooter.aimAngle;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    // Barrel pointing along the aim.
    canvas.save();
    canvas.rotate(-angle);
    canvas.drawRRect(_barrel, _barrelPaint);
    canvas.drawRRect(_barrel, _barrelRim);
    canvas.restore();

    // Base ring (drawn in local coordinates so the cached shader stays valid).
    const baseRadius = 1.45;
    _baseFill.shader ??= const RadialGradient(colors: [Color(0xFF4B4FD8), Color(0xFF1B1766)])
        .createShader(Rect.fromCircle(center: Offset.zero, radius: baseRadius));
    canvas.drawCircle(Offset.zero, baseRadius, _baseFill);
    canvas.drawCircle(Offset.zero, baseRadius, _baseRim);
    canvas.restore();

    if (engine.phase.value != GamePhase.gameOver) {
      if (engine.shooter.currentRainbow) {
        RainbowBubblePainter.paint(canvas, pos, BubbleGrid.radius, engine.time);
      } else {
        BubblePainter.paint(canvas, pos, BubbleGrid.radius, engine.shooter.current);
      }
    }
  }

  void _paintFlying(Canvas canvas) {
    final flying = engine.flyingBubble;
    if (flying == null) return;
    final trail = flying.trail;
    final color = flying.rainbow ? Colors.white : flying.color.light;
    for (var i = 0; i < trail.length; i++) {
      final f = (i + 1) / (trail.length + 1);
      _trailPaint.color = color.withValues(alpha: 0.32 * f);
      canvas.drawCircle(trail[i], BubbleGrid.radius * (0.35 + 0.55 * f), _trailPaint);
    }
    if (flying.rainbow) {
      RainbowBubblePainter.paint(canvas, flying.position, BubbleGrid.radius, engine.time);
    } else {
      BubblePainter.paint(canvas, flying.position, BubbleGrid.radius, flying.color);
    }
  }

  void _paintEffects(Canvas canvas) {
    final fx = engine.effects;
    for (final s in fx.shockwaves) {
      final p = s.progress;
      _ringPaint
        ..strokeWidth = 0.28 * (1 - p) + 0.02
        ..color = s.color.withValues(alpha: 0.75 * (1 - p));
      canvas.drawCircle(s.position, 0.9 + 1.6 * Curves.easeOut.transform(p), _ringPaint);
    }
    for (final f in fx.falls) {
      BubblePainter.paint(canvas, f.position, BubbleGrid.radius, f.color);
    }
    for (final p in fx.pops) {
      if (!p.started) {
        BubblePainter.paint(canvas, p.position, BubbleGrid.radius, p.color);
        continue;
      }
      final t = p.progress;
      final s = t < 0.3 ? 1 + t * 0.6 : 1.18 * (1 - (t - 0.3) / 0.7);
      BubblePainter.paint(
        canvas,
        p.position,
        BubbleGrid.radius * s,
        p.color,
        opacity: 1 - t,
        shadow: false,
      );
    }
    for (final p in fx.particles) {
      _particlePaint.color = p.color.withValues(alpha: p.fraction);
      canvas.drawCircle(p.position, p.size * (0.5 + 0.5 * p.fraction), _particlePaint);
    }
    for (final c in fx.confetti) {
      final fade = c.life < 0.5 ? c.life / 0.5 : 1.0;
      _confettiPaint.color = c.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(c.position.dx, c.position.dy);
      canvas.rotate(c.rotation);
      // Squash horizontally to fake the paper flipping in 3D.
      canvas.scale(math.cos(c.age * c.flip).abs() * 0.85 + 0.15, 1);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: c.width, height: c.height),
        _confettiPaint,
      );
      canvas.restore();
    }
  }

  /// Score popups are drawn in pixel space so text renders crisply.
  void _paintPopups(Canvas canvas, double scale) {
    for (final ScorePopup p in engine.effects.popups) {
      final painter = _popupText[p] ??= TextPainter(
        text: TextSpan(
          text: p.text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 1.3 * scale,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: const [Shadow(color: Color(0xCC000000), offset: Offset(1, 2), blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final t = p.progress;
      final center = engine.layout.toPixels(p.origin) + Offset(0, -t * 2.2 * scale);
      final topLeft = center - Offset(painter.width / 2, painter.height / 2);
      final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
      _layerPaint.color = Color.fromRGBO(0, 0, 0, opacity);
      canvas.saveLayer(topLeft & painter.size, _layerPaint);
      painter.paint(canvas, topLeft);
      canvas.restore();
    }
  }

  void _paintBanners(Canvas canvas, Size size, double scale) {
    for (final PraiseBanner b in engine.effects.banners) {
      final text = _bannerText[b] ??= _BannerText.build(b, scale, size.width * 0.92, fontFamily);
      final t = b.age;
      final appear = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
      final remaining = b.lifetime - t;
      final opacity = remaining < 0.3 ? (remaining / 0.3).clamp(0.0, 1.0) : 1.0;
      final rise = remaining < 0.3 ? (0.3 - remaining) * 2 * scale : 0.0;
      final center = Offset(size.width / 2, size.height * 0.4 - rise);
      final s = 0.35 + 0.65 * appear;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(s);
      final topLeft = Offset(-text.fill.width / 2, -text.fill.height / 2);
      _layerPaint.color = Color.fromRGBO(0, 0, 0, opacity);
      canvas.saveLayer(
        Rect.fromCenter(
          center: Offset.zero,
          width: text.fill.width + 40,
          height: text.fill.height + 40,
        ),
        _layerPaint,
      );
      text.stroke.paint(canvas, topLeft);
      text.fill.paint(canvas, topLeft);
      canvas.restore();
      canvas.restore();
    }
  }

  void _paintFlash(Canvas canvas, Size size) {
    final flash = engine.effects.flash;
    if (flash <= 0) return;
    _flashPaint.color = Colors.white.withValues(alpha: 0.4 * flash);
    canvas.drawRect(Offset.zero & size, _flashPaint);
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => oldDelegate.engine != engine;
}

/// Cached text layers for a banner: dark outline + gradient fill.
class _BannerText {
  _BannerText(this.stroke, this.fill);

  final TextPainter stroke;
  final TextPainter fill;

  static _BannerText build(PraiseBanner b, double scale, double maxWidth, String? fontFamily) {
    var fontSize = b.size * scale;
    // Shrink long texts to fit the board.
    final estimate = b.text.length * fontSize * 0.72;
    if (estimate > maxWidth) fontSize *= maxWidth / estimate;
    final height = fontSize * 1.2;
    final width = b.text.length * fontSize * 0.72;

    final List<Color> colors;
    final bool horizontal;
    switch (b.style) {
      case PraiseStyle.gold:
        colors = const [Color(0xFFFFF6C2), Color(0xFFFFD23F), Color(0xFFFF8A00)];
        horizontal = false;
      case PraiseStyle.cool:
        colors = const [Color(0xFFFFFFFF), Color(0xFF9FE6FF), Color(0xFF4FA3FF)];
        horizontal = false;
      case PraiseStyle.rainbow:
        colors = GamePainter._rainbowColors;
        horizontal = true;
    }
    final shader = horizontal
        ? ui.Gradient.linear(Offset.zero, Offset(width, 0), colors, [
            for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
          ])
        : ui.Gradient.linear(Offset.zero, Offset(0, height), colors, const [0.0, 0.5, 1.0]);

    TextStyle style(Paint foreground, List<Shadow> shadows) => TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: fontSize * 0.04,
      foreground: foreground,
      shadows: shadows,
    );

    final stroke = TextPainter(
      text: TextSpan(
        text: b.text,
        style: style(
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.16
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF1A0F4D),
          [
            Shadow(
              color: colors[colors.length ~/ 2].withValues(alpha: 0.7),
              blurRadius: fontSize * 0.5,
            ),
            Shadow(color: const Color(0x99000000), offset: Offset(0, fontSize * 0.08)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fill = TextPainter(
      text: TextSpan(text: b.text, style: style(Paint()..shader = shader, const [])),
      textDirection: TextDirection.ltr,
    )..layout();
    return _BannerText(stroke, fill);
  }
}
