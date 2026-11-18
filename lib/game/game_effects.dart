import 'dart:math' as math;
import 'dart:ui' show Color, Offset;

import 'bubble_color.dart';

/// A matched bubble that waits [delay] seconds, then scales and fades out.
class PoppingBubble {
  PoppingBubble(this.position, this.color, this.delay);

  final Offset position;
  final BubbleColor color;
  double delay;

  /// 0..1 once started.
  double progress = 0;

  bool get started => delay <= 0;
}

/// A disconnected bubble falling under gravity.
class FallingBubble {
  FallingBubble(this.position, this.velocity, this.color);

  Offset position;
  Offset velocity;
  final BubbleColor color;
}

class Particle {
  Particle(this.position, this.velocity, this.color, this.life, this.size) : maxLife = life;

  Offset position;
  Offset velocity;
  final Color color;
  double life;
  final double maxLife;
  final double size;

  double get fraction => (life / maxLife).clamp(0.0, 1.0);
}

/// Expanding ring left behind by a popping bubble.
class Shockwave {
  Shockwave(this.position, this.color);

  static const double lifetime = 0.38;

  final Offset position;
  final Color color;
  double age = 0;

  double get progress => (age / lifetime).clamp(0.0, 1.0);
}

/// A tumbling paper confetti piece.
class Confetti {
  Confetti({
    required this.position,
    required this.velocity,
    required this.color,
    required this.width,
    required this.height,
    required this.spin,
    required this.flip,
    required this.life,
  });

  Offset position;
  Offset velocity;
  final Color color;
  final double width;
  final double height;
  final double spin;
  final double flip;
  double rotation = 0;
  double age = 0;
  double life;
}

/// A floating "+N" label.
class ScorePopup {
  ScorePopup(this.origin, this.text);

  static const double lifetime = 0.9;

  final Offset origin;
  final String text;
  double age = 0;

  double get progress => (age / lifetime).clamp(0.0, 1.0);
}

enum PraiseStyle { gold, rainbow, cool }

/// Big celebratory text ("GREAT!", "COMBO x3", "LEVEL 2") in the middle of
/// the board.
class PraiseBanner {
  PraiseBanner(this.text, this.style, this.size, {this.lifetime = 1.25});

  final String text;
  final PraiseStyle style;

  /// Font size in world units.
  final double size;
  final double lifetime;
  double age = 0;

  double get progress => (age / lifetime).clamp(0.0, 1.0);
}

/// Short-lived visual effects. All values are in world units / seconds.
class GameEffects {
  GameEffects(this._random);

  final math.Random _random;

  static const double popDuration = 0.22;
  static const double gravity = 70;
  static const int maxParticles = 220;
  static const int maxConfetti = 180;

  static const List<Color> confettiColors = [
    Color(0xFFFF3B3B),
    Color(0xFF2F80FF),
    Color(0xFF2ECC40),
    Color(0xFFFFD60A),
    Color(0xFFA442F5),
    Color(0xFFFF8A1F),
    Color(0xFFFFFFFF),
    Color(0xFF6FE7FF),
  ];

  final List<PoppingBubble> pops = <PoppingBubble>[];
  final List<FallingBubble> falls = <FallingBubble>[];
  final List<Particle> particles = <Particle>[];
  final List<ScorePopup> popups = <ScorePopup>[];
  final List<Shockwave> shockwaves = <Shockwave>[];
  final List<Confetti> confetti = <Confetti>[];
  final List<PraiseBanner> banners = <PraiseBanner>[];

  /// Full-board white flash strength (0..1), decays quickly.
  double flash = 0;

  bool get isIdle =>
      pops.isEmpty &&
      falls.isEmpty &&
      particles.isEmpty &&
      popups.isEmpty &&
      shockwaves.isEmpty &&
      confetti.isEmpty &&
      banners.isEmpty &&
      flash <= 0;

  void clear() {
    pops.clear();
    falls.clear();
    particles.clear();
    popups.clear();
    shockwaves.clear();
    confetti.clear();
    banners.clear();
    flash = 0;
  }

  void addPop(Offset position, BubbleColor color, double delay) =>
      pops.add(PoppingBubble(position, color, delay));

  void addFall(Offset position, BubbleColor color) {
    final vx = (_random.nextDouble() - 0.5) * 8;
    final vy = -2 - _random.nextDouble() * 5;
    falls.add(FallingBubble(position, Offset(vx, vy), color));
  }

  void addPopup(Offset position, String text) => popups.add(ScorePopup(position, text));

  /// Shows a banner. A new banner replaces any banner still on screen so
  /// they never overlap.
  void addBanner(String text, {PraiseStyle style = PraiseStyle.gold, double size = 2.4}) {
    banners
      ..clear()
      ..add(PraiseBanner(text, style, size));
  }

  void addFlash(double strength) => flash = math.max(flash, strength);

  /// Confetti exploding outward and upward from [at].
  void burstConfetti(Offset at, int count) {
    for (var i = 0; i < count && confetti.length < maxConfetti; i++) {
      final angle = -math.pi / 2 + (_random.nextDouble() - 0.5) * math.pi * 1.3;
      final speed = 10 + _random.nextDouble() * 18;
      confetti.add(_piece(at, Offset(math.cos(angle) * speed, math.sin(angle) * speed)));
    }
  }

  /// Confetti raining down across the whole board width.
  void rainConfetti(double width, int count) {
    for (var i = 0; i < count && confetti.length < maxConfetti; i++) {
      final at = Offset(_random.nextDouble() * width, -1 - _random.nextDouble() * 8);
      confetti.add(
        _piece(at, Offset((_random.nextDouble() - 0.5) * 6, 4 + _random.nextDouble() * 6)),
      );
    }
  }

  Confetti _piece(Offset at, Offset velocity) => Confetti(
    position: at,
    velocity: velocity,
    color: confettiColors[_random.nextInt(confettiColors.length)],
    width: 0.35 + _random.nextDouble() * 0.25,
    height: 0.18 + _random.nextDouble() * 0.12,
    spin: (_random.nextDouble() - 0.5) * 14,
    flip: 4 + _random.nextDouble() * 8,
    life: 2.2 + _random.nextDouble() * 1.4,
  );

  void _burst(Offset at, Color color) {
    for (var i = 0; i < 7 && particles.length < maxParticles; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 4 + _random.nextDouble() * 8;
      particles.add(
        Particle(
          at,
          Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          color,
          0.3 + _random.nextDouble() * 0.3,
          0.12 + _random.nextDouble() * 0.16,
        ),
      );
    }
  }

  /// Advances all effects. [floorY] is the bottom of the playfield.
  void update(double dt, double floorY) {
    for (final p in pops) {
      if (p.delay > 0) {
        p.delay -= dt;
        if (p.delay <= 0) {
          _burst(p.position, p.color.light);
          shockwaves.add(Shockwave(p.position, p.color.light));
        }
      } else {
        p.progress += dt / popDuration;
      }
    }
    pops.removeWhere((p) => p.progress >= 1);

    for (final f in falls) {
      f.velocity = Offset(f.velocity.dx, f.velocity.dy + gravity * dt);
      f.position += f.velocity * dt;
    }
    falls.removeWhere((f) => f.position.dy > floorY + 2);

    final damping = math.pow(0.08, dt).toDouble();
    for (final p in particles) {
      p.life -= dt;
      p.velocity = Offset(p.velocity.dx * damping, p.velocity.dy * damping + gravity * 0.3 * dt);
      p.position += p.velocity * dt;
    }
    particles.removeWhere((p) => p.life <= 0);

    for (final s in shockwaves) {
      s.age += dt;
    }
    shockwaves.removeWhere((s) => s.age >= Shockwave.lifetime);

    final drag = math.pow(0.35, dt).toDouble();
    for (final c in confetti) {
      c.age += dt;
      c.life -= dt;
      c.velocity = Offset(
        c.velocity.dx * drag + math.sin(c.age * 3 + c.flip) * 3 * dt,
        math.min(c.velocity.dy * drag + gravity * 0.22 * dt, 7),
      );
      c.position += c.velocity * dt;
      c.rotation += c.spin * dt;
    }
    confetti.removeWhere((c) => c.life <= 0 || c.position.dy > floorY + 1);

    for (final s in popups) {
      s.age += dt;
    }
    popups.removeWhere((s) => s.age >= ScorePopup.lifetime);

    for (final b in banners) {
      b.age += dt;
    }
    banners.removeWhere((b) => b.age >= b.lifetime);

    if (flash > 0) flash = math.max(0, flash - dt * 2.5);
  }
}
