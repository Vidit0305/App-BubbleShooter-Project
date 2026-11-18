import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'bubble_color.dart';

/// The launcher: aim direction plus the loaded (current) and next bubbles.
class BubbleShooter {
  BubbleShooter(this._random);

  final math.Random _random;

  /// Shots must be at least this far above horizontal (radians).
  static const double minAimAngle = 10 * math.pi / 180;

  /// Launcher position in world units.
  Offset position = Offset.zero;

  Offset _aim = const Offset(0, -1);

  /// Unit vector of the current aim (always pointing upwards).
  Offset get aimDirection => _aim;

  /// Aim angle in radians, measured counter-clockwise from the +x axis.
  double get aimAngle => math.atan2(-_aim.dy, _aim.dx);

  BubbleColor current = BubbleColor.red;
  BubbleColor next = BubbleColor.blue;

  /// Whether the loaded / next bubble is a rainbow (wildcard) bubble.
  bool currentRainbow = false;
  bool nextRainbow = false;

  /// Points the launcher at [target]. Targets below the shooting boundary
  /// are clamped to the minimum angle on the matching side.
  /// Returns true if the aim changed.
  bool aimAt(Offset target) {
    final dx = target.dx - position.dx;
    final up = position.dy - target.dy;
    if (dx.abs() < 1e-9 && up.abs() < 1e-9) return false;
    var angle = math.atan2(up, dx);
    if (angle < minAimAngle || angle > math.pi - minAimAngle) {
      angle = dx >= 0 ? minAimAngle : math.pi - minAimAngle;
    }
    return setAimAngle(angle);
  }

  /// Sets the aim angle directly (clamped). Returns true if it changed.
  bool setAimAngle(double angle) {
    final a = angle.clamp(minAimAngle, math.pi - minAimAngle);
    final aim = Offset(math.cos(a), -math.sin(a));
    if ((aim - _aim).distanceSquared < 1e-12) return false;
    _aim = aim;
    return true;
  }

  void resetAim() => _aim = const Offset(0, -1);

  /// A random color among [available] (falls back to all colors).
  BubbleColor pickColor(Set<BubbleColor> available) {
    final pool = available.isEmpty ? BubbleColor.values : available.toList(growable: false);
    return pool[_random.nextInt(pool.length)];
  }

  void load(Set<BubbleColor> available) {
    current = pickColor(available);
    next = pickColor(available);
    currentRainbow = false;
    nextRainbow = false;
  }

  /// Fires the current bubble: the next bubble moves into the launcher and
  /// a new next bubble is generated. Returns the fired color.
  BubbleColor takeShot(Set<BubbleColor> available) {
    final fired = current;
    current = next;
    currentRainbow = nextRainbow;
    next = pickColor(available);
    nextRainbow = false;
    return fired;
  }

  /// Replaces loaded colors that no longer exist on the board, so the
  /// player is never handed an unmatchable bubble.
  void sync(Set<BubbleColor> available) {
    if (available.isEmpty) return;
    if (!available.contains(current)) current = pickColor(available);
    if (!available.contains(next)) next = pickColor(available);
  }

  void swap() {
    final c = current;
    current = next;
    next = c;
    final r = currentRainbow;
    currentRainbow = nextRainbow;
    nextRainbow = r;
  }
}
