import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_effects.dart';

/// A one-shot confetti shower over its area (e.g. a new high score).
/// Reuses the game's confetti physics; never blocks touches.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, this.pieces = 140});

  final int pieces;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  /// Logical pixels per simulation unit.
  static const double _unit = 14;

  final GameEffects _effects = GameEffects(math.Random());
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  Size _size = Size.zero;
  bool _spawned = false;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_size.isEmpty) return;
    if (!_spawned) {
      _spawned = true;
      _effects.rainConfetti(_size.width / _unit, widget.pieces);
    }
    _effects.update(math.min(dt, 1 / 20), _size.height / _unit);
    _frame.value++;
    if (_effects.confetti.isEmpty) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, constraints) {
        _size = constraints.biggest;
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_effects, _frame),
        );
      }),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.effects, Listenable repaint) : super(repaint: repaint);

  final GameEffects effects;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(_ConfettiOverlayState._unit);
    for (final c in effects.confetti) {
      final fade = c.life < 0.5 ? c.life / 0.5 : 1.0;
      _paint.color = c.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(c.position.dx, c.position.dy);
      canvas.rotate(c.rotation);
      canvas.scale(math.cos(c.age * c.flip).abs() * 0.85 + 0.15, 1);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: c.width, height: c.height), _paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}
