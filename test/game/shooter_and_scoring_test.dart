import 'dart:math' as math;

import 'package:bubble_shooter/game/bubble_color.dart';
import 'package:bubble_shooter/game/bubble_shooter.dart';
import 'package:bubble_shooter/game/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BubbleShooter', () {
    late BubbleShooter shooter;
    setUp(() {
      shooter = BubbleShooter(math.Random(3))..position = const Offset(9, 25);
    });

    test('aims at the target point', () {
      shooter.aimAt(const Offset(4, 20));
      expect(shooter.aimDirection.dx, closeTo(-math.sqrt(0.5), 1e-9));
      expect(shooter.aimDirection.dy, closeTo(-math.sqrt(0.5), 1e-9));
    });

    test('cannot aim below the shooting boundary', () {
      shooter.aimAt(const Offset(15, 30)); // below, to the right
      expect(shooter.aimAngle, closeTo(BubbleShooter.minAimAngle, 1e-9));
      shooter.aimAt(const Offset(2, 26)); // below, to the left
      expect(shooter.aimAngle, closeTo(math.pi - BubbleShooter.minAimAngle, 1e-9));
      shooter.aimAt(const Offset(30, 25)); // exactly horizontal
      expect(shooter.aimAngle, closeTo(BubbleShooter.minAimAngle, 1e-9));
      expect(shooter.aimDirection.dy, lessThan(0));
    });

    test('taking a shot advances next -> current and makes a new next', () {
      shooter.current = BubbleColor.red;
      shooter.next = BubbleColor.blue;
      final fired = shooter.takeShot({BubbleColor.green});
      expect(fired, BubbleColor.red);
      expect(shooter.current, BubbleColor.blue);
      expect(shooter.next, BubbleColor.green);
    });

    test('only picks colors that are still on the board', () {
      final available = {BubbleColor.yellow, BubbleColor.purple};
      for (var i = 0; i < 50; i++) {
        expect(available, contains(shooter.pickColor(available)));
      }
      shooter.current = BubbleColor.red;
      shooter.next = BubbleColor.yellow;
      shooter.sync(available);
      expect(available, contains(shooter.current));
      expect(shooter.next, BubbleColor.yellow);
    });

    test('swap exchanges current and next', () {
      shooter.current = BubbleColor.red;
      shooter.next = BubbleColor.blue;
      shooter.swap();
      expect(shooter.current, BubbleColor.blue);
      expect(shooter.next, BubbleColor.red);
    });
  });

  group('ScoreRules', () {
    test('10 per popped bubble, 20 per dropped bubble', () {
      expect(ScoreRules.forMatch(popped: 3, dropped: 0), 30);
      expect(ScoreRules.forMatch(popped: 3, dropped: 2), 70);
    });

    test('bonus for larger combinations and big drops', () {
      expect(ScoreRules.forMatch(popped: 5, dropped: 0), 50 + 20);
      expect(ScoreRules.forMatch(popped: 3, dropped: 5), 30 + 5 * 40);
    });

    test('no points without a pop', () {
      expect(ScoreRules.forMatch(popped: 0, dropped: 0), 0);
    });
  });
}
