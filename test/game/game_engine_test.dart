import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:bubble_shooter/game/bubble.dart';
import 'package:bubble_shooter/game/bubble_color.dart';
import 'package:bubble_shooter/game/bubble_grid.dart';
import 'package:bubble_shooter/game/game_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  const anchors = 'B B . . . . . . .'; // keeps the board from being cleared

  group('setup', () {
    test('new game builds a 7-row honeycomb and waits for a shot', () {
      final engine = createEngine();
      expect(engine.layout.dangerRow, 14);
      expect(engine.grid.rowCount, 7);
      expect(engine.grid.bubbleCount, 7 * 9 - 3); // 4 full rows + 3 shifted rows
      expect(engine.phase.value, GamePhase.aiming);
      expect(engine.score.value, 0);
      expect(engine.shotsUntilNewRow.value, GameEngine.shotsPerRow);
      expect(engine.grid.colorsPresent, contains(engine.shooter.current));
    });

    test('bubble size adapts to the screen width', () {
      final narrow = GameEngine()..configure(const Size(320, 560));
      final wide = GameEngine()..configure(const Size(430, 760));
      expect(narrow.layout.columns, lessThan(wide.layout.columns));
      for (final e in [narrow, wide]) {
        expect(e.layout.worldWidth * e.layout.scale, closeTo(e == narrow ? 320 : 430, 1e-6));
        expect(e.layout.dangerRow, greaterThanOrEqualTo(12));
      }
    });
  });

  group('shooting', () {
    test('fire launches one bubble and ignores taps while it moves', () {
      final engine = createEngine();
      expect(engine.fire(), isTrue);
      final flying = engine.flyingBubble;
      expect(flying, isNotNull);
      expect(engine.phase.value, GamePhase.flying);
      expect(engine.fire(), isFalse);
      engine.update(1 / 60);
      expect(engine.fire(), isFalse);
      expect(engine.flyingBubble, same(flying));
    });

    test('next bubble moves into the launcher and a new next is generated', () {
      final engine = createEngine();
      final next = engine.shooter.next;
      engine.fire();
      expect(engine.shooter.current, next);
      expect(engine.currentColor.value, next);
      expect(engine.nextColor.value, engine.shooter.next);
    });

    test('dragging (aimAt) only changes direction, never fires', () {
      final engine = createEngine();
      final before = engine.shooter.aimDirection;
      engine.aimAt(const Offset(2, 10));
      expect(engine.shooter.aimDirection, isNot(before));
      expect(engine.phase.value, GamePhase.aiming);
      expect(engine.flyingBubble, isNull);
    });

    test('movement is frame-rate independent', () {
      Offset positionAfter(double fps) {
        final engine = createEngine();
        engine.fire();
        for (var i = 0; i < (fps * 0.2).round(); i++) {
          engine.update(1 / fps);
        }
        return engine.flyingBubble!.position;
      }

      final at30 = positionAfter(30);
      final at60 = positionAfter(60);
      final at120 = positionAfter(120);
      expect((at30 - at60).distance, lessThan(0.3));
      expect((at60 - at120).distance, lessThan(0.3));
    });

    test('the bubble bounces off a side wall', () {
      final engine = createEngine();
      loadBoard(engine, [anchors]);
      engine.shooter.setAimAngle(150 * math.pi / 180); // up-left
      engine.fire();
      var bounced = false;
      while (engine.phase.value == GamePhase.flying) {
        engine.update(1 / 60);
        final b = engine.flyingBubble;
        if (b != null && b.direction.dx > 0) bounced = true;
      }
      expect(bounced, isTrue);
    });

    test('the landing cell matches the aiming trajectory', () {
      for (final degrees in [35.0, 60.0, 80.0, 90.0, 104.0, 128.0, 150.0]) {
        final engine = createEngine(seed: degrees.toInt());
        engine.shooter.setAimAngle(degrees * math.pi / 180);
        final predicted = engine.trajectory!;
        engine.fire();
        settle(engine);
        if (predicted.landingCell != null) {
          expect(engine.lastShot!.cell, predicted.landingCell, reason: 'angle $degrees');
        }
      }
    });
  });

  group('matching', () {
    test('three matching bubbles pop', () {
      final engine = createEngine();
      loadBoard(engine, ['R R . . . . . B B']);
      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 2));
      expect(engine.lastShot!.popped, 3);
      expect(engine.grid.colorAt(0, 0), isNull);
      expect(engine.grid.colorAt(0, 1), isNull);
      expect(engine.grid.bubbleCount, 2);
      expect(engine.score.value, 30);
    });

    test('four or more matching bubbles pop with a combo bonus', () {
      final engine = createEngine();
      loadBoard(engine, ['R R R . . . . B B']);
      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 3));
      expect(engine.lastShot!.popped, 4);
      expect(engine.score.value, 40 + 10);
    });

    test('diagonal matches pop', () {
      final engine = createEngine();
      loadBoard(engine, [
        'B B . . R . . . .',
        '. . . . R . . .',
      ]);
      // Straight up: hits the shifted (1,4) and snaps to (2,4), whose only
      // red neighbor is the diagonal (1,4), which links diagonally to (0,4).
      shoot(engine, BubbleColor.red, const Offset(9, 0));
      expect(engine.lastShot!.cell, const GridCell(2, 4));
      expect(engine.lastShot!.popped, 3);
      expect(engine.grid.colorsPresent, {BubbleColor.blue});
    });

    test('a non-matching shot sticks to the grid', () {
      final engine = createEngine();
      loadBoard(engine, ['R R . . . . . B B']);
      shoot(engine, BubbleColor.green, engine.grid.centerOf(0, 2));
      expect(engine.lastShot!.popped, 0);
      expect(engine.grid.colorAt(0, 2), BubbleColor.green);
      expect(engine.score.value, 0);
      expect(engine.shotsUntilNewRow.value, GameEngine.shotsPerRow - 1);
    });

    test('disconnected bubbles fall and score extra points', () {
      final engine = createEngine();
      loadBoard(engine, [
        'B B . . R R . . .',
        '. . . . . G . .', // hangs only from (0,5)
      ]);
      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 3));
      expect(engine.lastShot!.popped, 3);
      expect(engine.lastShot!.dropped, 1);
      expect(engine.grid.colorAt(1, 5), isNull);
      expect(engine.effects.falls, hasLength(1));
      expect(engine.score.value, 30 + 20);
    });
  });

  group('new rows and game over', () {
    test('a new row appears after 5 unsuccessful shots, and matches reset the count', () {
      final engine = createEngine();
      loadBoard(engine, ['B G B G B G B G B']);
      final colors = [BubbleColor.yellow, BubbleColor.purple, BubbleColor.orange];
      for (var i = 0; i < 4; i++) {
        shoot(engine, colors[i % 3], const Offset(9, 0));
        expect(engine.lastShot!.matched, isFalse);
        expect(engine.shotsUntilNewRow.value, 4 - i);
      }
      final rowsBefore = engine.grid.rowCount;
      final bottomColorBefore = engine.grid.colorAt(rowsBefore - 1, 4) ??
          engine.grid.colorAt(rowsBefore - 1, 3);

      engine.shooter.current = BubbleColor.red;
      engine.aimAt(const Offset(1, 0));
      engine.fire();
      settle(engine);
      expect(engine.lastShot!.matched, isFalse);
      expect(engine.grid.rowCount, greaterThan(rowsBefore));
      expect(engine.shotsUntilNewRow.value, GameEngine.shotsPerRow);
      expect(engine.phase.value, GamePhase.aiming);
      // The old bottom bubble moved one row down.
      expect(
        engine.grid.colorAt(rowsBefore, 4) ?? engine.grid.colorAt(rowsBefore, 3),
        bottomColorBefore,
      );
    });

    test('a match resets the unsuccessful-shot counter', () {
      final engine = createEngine();
      loadBoard(engine, ['R R . . . . . B B']);
      shoot(engine, BubbleColor.yellow, engine.grid.centerOf(0, 5));
      expect(engine.shotsUntilNewRow.value, 4);
      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 2));
      expect(engine.lastShot!.matched, isTrue);
      expect(engine.shotsUntilNewRow.value, GameEngine.shotsPerRow);
    });

    test('the game ends when a bubble crosses the danger line', () {
      final engine = createEngine();
      final dangerRow = engine.layout.dangerRow;
      loadBoard(engine, [
        for (var r = 0; r < dangerRow; r++)
          r.isEven ? 'B G B G B G B G B' : 'G B G B G B G B',
      ]);
      expect(engine.phase.value, GamePhase.aiming);
      shoot(engine, BubbleColor.yellow, const Offset(9, 0));
      expect(engine.lastShot!.cell.row, dangerRow);
      expect(engine.phase.value, GamePhase.gameOver);
      expect(engine.fire(), isFalse, reason: 'shooting disabled after game over');
    });

    test('rows pushed in by misses can end the game', () {
      final engine = createEngine();
      final dangerRow = engine.layout.dangerRow;
      loadBoard(engine, [
        for (var r = 0; r < dangerRow - 1; r++)
          r.isEven ? 'B G B G B G B G B' : 'G B G B G B G B',
      ]);
      final colors = [BubbleColor.yellow, BubbleColor.purple, BubbleColor.orange];
      for (var i = 0; i < GameEngine.shotsPerRow && engine.phase.value == GamePhase.aiming; i++) {
        shoot(engine, colors[i % 3], Offset(3.0 + i * 3, 0));
      }
      expect(engine.phase.value, GamePhase.gameOver);
    });
  });

  group('pause, restart and levels', () {
    test('nothing moves while paused', () {
      final engine = createEngine();
      engine.fire();
      engine.update(1 / 60);
      engine.pause();
      final pos = engine.flyingBubble!.position;
      for (var i = 0; i < 120; i++) {
        engine.update(1 / 60);
      }
      expect(engine.flyingBubble!.position, pos);
      engine.aimAt(const Offset(1, 1));
      engine.resume();
      engine.update(1 / 60);
      expect(engine.flyingBubble!.position, isNot(pos));
    });

    test('cannot fire while paused', () {
      final engine = createEngine();
      engine.pause();
      expect(engine.fire(), isFalse);
      engine.resume();
      expect(engine.fire(), isTrue);
    });

    test('restart resets score, level, counters and board', () {
      final engine = createEngine();
      loadBoard(engine, ['R R . . . . . B B']);
      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 2));
      shoot(engine, BubbleColor.yellow, engine.grid.centerOf(0, 4));
      expect(engine.score.value, greaterThan(0));

      engine.newGame();
      settle(engine);
      expect(engine.score.value, 0);
      expect(engine.level.value, 1);
      expect(engine.shotsUntilNewRow.value, GameEngine.shotsPerRow);
      expect(engine.grid.rowCount, 7);
      expect(engine.phase.value, GamePhase.aiming);
    });

    test('clearing the board shows LEVEL CLEARED then a harder board', () {
      final engine = createEngine();
      loadBoard(engine, ['R R . . . . . . .']);
      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 2));
      expect(engine.phase.value, GamePhase.levelCleared);
      expect(engine.grid.isEmpty, isTrue);
      expect(engine.score.value, 30 + engine.lastLevelBonus);
      expect(engine.fire(), isFalse);

      for (var i = 0; i < 200; i++) {
        engine.update(1 / 60);
      }
      settle(engine);
      expect(engine.level.value, 2);
      expect(engine.grid.rowCount, 8);
      expect(engine.phase.value, GamePhase.aiming);
    });
  });

  test('BubbleGrid row height constant is sqrt(3)', () {
    expect(BubbleGrid.rowHeight, closeTo(math.sqrt(3), 1e-12));
  });
}
