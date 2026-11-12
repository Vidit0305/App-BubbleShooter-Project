import 'dart:math' as math;

import 'package:bubble_shooter/game/bubble.dart';
import 'package:bubble_shooter/game/bubble_grid.dart';
import 'package:bubble_shooter/game/collision_detector.dart';
import 'package:bubble_shooter/game/trajectory_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  const detector = CollisionDetector(worldWidth: 18);
  const up = Offset(0, -1);

  group('CollisionDetector.move', () {
    test('travels straight up to the ceiling in an empty grid', () {
      final grid = BubbleGrid(columns: 9);
      final r = detector.move(grid, const Offset(9, 25), up, 100);
      expect(r.outcome, MoveOutcome.hitCeiling);
      expect(r.position.dx, closeTo(9, 1e-9));
      expect(r.position.dy, BubbleGrid.radius);
    });

    test('bounces off the left wall', () {
      final grid = BubbleGrid(columns: 9);
      final dir = Offset(-math.cos(math.pi / 4), -math.sin(math.pi / 4));
      final bounces = <Offset>[];
      final r = detector.move(grid, const Offset(3, 25), dir, 4, onBounce: bounces.add);
      expect(bounces, hasLength(1));
      expect(bounces.single.dx, BubbleGrid.radius);
      expect(r.direction.dx, greaterThan(0), reason: 'horizontal direction reversed');
      expect(r.direction.dy, dir.dy, reason: 'vertical direction unchanged');
      expect(r.position.dx, greaterThanOrEqualTo(BubbleGrid.radius));
    });

    test('bounces off the right wall', () {
      final grid = BubbleGrid(columns: 9);
      final dir = Offset(math.cos(math.pi / 4), -math.sin(math.pi / 4));
      final r = detector.move(grid, const Offset(15, 25), dir, 4);
      expect(r.direction.dx, lessThan(0));
      expect(r.position.dx, lessThanOrEqualTo(18 - BubbleGrid.radius));
    });

    test('stops at the first bubble without tunneling through it', () {
      final grid = gridFromRows(9, ['. . . . R . . . .']);
      // One huge step: the bubble must still stop below (0,4).
      final r = detector.move(grid, const Offset(9, 25), up, 1000);
      expect(r.outcome, MoveOutcome.hitBubble);
      expect(r.hitCell, const GridCell(0, 4));
      final gap = (r.position - grid.centerOf(0, 4)).distance;
      expect(gap, lessThan(CollisionDetector.defaultHitDistance));
      expect(gap, greaterThan(CollisionDetector.defaultHitDistance - detector.maxStep - 1e-9));
    });

    test('passes bubbles that are not on its path', () {
      final grid = gridFromRows(9, ['R . . . . . . . R']);
      final r = detector.move(grid, const Offset(9, 25), up, 1000);
      expect(r.outcome, MoveOutcome.hitCeiling);
    });
  });

  group('CollisionDetector.findSnapCell', () {
    test('snaps below the bubble that was hit', () {
      final grid = gridFromRows(9, ['. . . . R . . . .']);
      final r = detector.move(grid, const Offset(9.3, 25), up, 1000);
      final cell = detector.findSnapCell(grid, r.position);
      expect(cell.row, 1);
      expect(grid.neighborsOf(cell.row, cell.col), contains(const GridCell(0, 4)));
      expect(grid.isOccupied(cell.row, cell.col), isFalse);
    });

    test('snaps to the nearest top-row cell at the ceiling', () {
      final grid = BubbleGrid(columns: 9);
      expect(detector.findSnapCell(grid, const Offset(7.2, 1)), const GridCell(0, 3));
      expect(detector.findSnapCell(grid, const Offset(17, 1)), const GridCell(0, 8));
    });

    test('never returns an occupied cell', () {
      final grid = gridFromRows(9, ['R R R R R R R R R', ' B B B B B B B B']);
      for (var x = 1.0; x <= 17; x += 0.5) {
        final cell = detector.findSnapCell(grid, Offset(x, 4.2));
        expect(grid.isOccupied(cell.row, cell.col), isFalse);
        expect(grid.hasOccupiedNeighbor(cell.row, cell.col), isTrue);
      }
    });
  });

  group('TrajectoryCalculator', () {
    const calc = TrajectoryCalculator();

    test('straight shot: no bounce, lands in the top row', () {
      final grid = BubbleGrid(columns: 9);
      final t = calc.compute(grid, detector, const Offset(9, 25), up);
      expect(t.bounceCount, 0);
      expect(t.landingCell, const GridCell(0, 4));
    });

    test('angled shot shows the reflected path after a wall', () {
      final grid = BubbleGrid(columns: 9);
      final a = 60 * math.pi / 180;
      final t = calc.compute(grid, detector, const Offset(9, 25), Offset(math.cos(a), -math.sin(a)));
      expect(t.bounceCount, 1);
      expect(t.points[1].dx, 18 - BubbleGrid.radius);
      expect(t.points.last.dx, lessThan(t.points[1].dx));
      expect(t.landingCell, isNotNull);
    });

    test('stops at the first predicted collision', () {
      final grid = gridFromRows(9, ['B B B B B B B B B', ' B B B B B B B B']);
      final t = calc.compute(grid, detector, const Offset(9, 25), up);
      expect(t.points.last.dy, greaterThan(grid.centerOf(1, 0).dy));
      expect(t.landingCell!.row, 2);
    });

    test('very shallow shots are cut after the bounce limit', () {
      final grid = BubbleGrid(columns: 9);
      final a = 11 * math.pi / 180;
      final t = calc.compute(grid, detector, const Offset(9, 25), Offset(math.cos(a), -math.sin(a)));
      expect(t.bounceCount, calc.maxBounces);
      expect(t.landingCell, isNull);
    });
  });
}
