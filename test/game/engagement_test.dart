import 'dart:math' as math;

import 'package:bubble_shooter/game/bubble_color.dart';
import 'package:bubble_shooter/game/game_engine.dart';
import 'package:bubble_shooter/game/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late GameEngine engine;
  late List<(GameSound, int)> sounds;

  setUp(() {
    engine = createEngine();
    sounds = [];
    engine.onSound = (s, level) => sounds.add((s, level));
  });

  List<GameSound> played() => [for (final (s, _) in sounds) s];

  group('combo streak', () {
    test('consecutive matches multiply the score and award a rainbow bubble', () {
      loadBoard(engine, ['R R . G G . . B B']);

      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 2));
      expect(engine.lastShot!.multiplier, 1);
      expect(engine.score.value, 30);
      expect(engine.streak.value, 1);

      shoot(engine, BubbleColor.green, engine.grid.centerOf(0, 5));
      expect(engine.lastShot!.multiplier, 2);
      expect(engine.score.value, 30 + 60);
      for (var i = 0; i < 20; i++) {
        engine.update(1 / 60); // the combo chime follows the pop shortly
      }
      expect(sounds, contains((GameSound.combo, 2)));

      expect(engine.nextIsRainbow.value, isFalse);
      shoot(engine, BubbleColor.blue, engine.grid.centerOf(0, 6));
      expect(engine.lastShot!.multiplier, 3);
      expect(engine.streak.value, 3);
      // The board is now clear: level bonus on top of 30 + 60 + 90.
      expect(engine.score.value, 180 + engine.lastLevelBonus);
      expect(engine.shooter.nextRainbow, isTrue, reason: 'every 3rd match in a row');
      expect(engine.nextIsRainbow.value, isTrue);
    });

    test('a miss resets the streak', () {
      loadBoard(engine, ['R R . . . . . B B']);
      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 2));
      expect(engine.streak.value, 1);
      shoot(engine, BubbleColor.yellow, engine.grid.centerOf(0, 4));
      expect(engine.streak.value, 0);
    });

    test('the multiplier is capped', () {
      expect(ScoreRules.multiplierFor(1), 1);
      expect(ScoreRules.multiplierFor(4), 4);
      expect(ScoreRules.multiplierFor(12), ScoreRules.maxMultiplier);
    });
  });

  group('rainbow bubble', () {
    test('joins the neighboring color that makes the biggest group', () {
      loadBoard(engine, ['B B . G . . . Y P']);
      engine.shooter.currentRainbow = true;
      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 2));
      expect(engine.lastShot!.color, BubbleColor.blue);
      expect(engine.lastShot!.popped, 3);
      expect(engine.grid.colorAt(0, 3), BubbleColor.green);
    });

    test('the rainbow flag travels with the bubble through swap and fire', () {
      engine.shooter.nextRainbow = true;
      engine.swapBubbles();
      expect(engine.shooter.currentRainbow, isTrue);
      expect(engine.shooter.nextRainbow, isFalse);
      engine.fire();
      expect(engine.flyingBubble!.rainbow, isTrue);
      expect(engine.shooter.currentRainbow, isFalse);
    });
  });

  group('celebrations', () {
    test('big pops are praised with a banner and confetti', () {
      loadBoard(engine, ['R R R R R . . B B']);
      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 5));
      expect(engine.lastShot!.popped, 6);
      expect(engine.lastShot!.praise, 'GREAT!');
      expect(engine.effects.banners.single.text, 'GREAT!');
      expect(engine.effects.confetti, isNotEmpty);
      for (var i = 0; i < 20; i++) {
        engine.update(1 / 60);
      }
      expect(played(), contains(GameSound.praise));
    });

    test('praise tiers', () {
      expect(ScoreRules.praiseFor(popped: 3, dropped: 1), isNull);
      expect(ScoreRules.praiseFor(popped: 6, dropped: 0), 'GREAT!');
      expect(ScoreRules.praiseFor(popped: 4, dropped: 6), 'AWESOME!');
      expect(ScoreRules.praiseFor(popped: 3, dropped: 9), 'AVALANCHE!');
      expect(ScoreRules.praiseFor(popped: 10, dropped: 5), 'AMAZING!');
      expect(ScoreRules.praiseFor(popped: 12, dropped: 12), 'INCREDIBLE!');
    });

    test('pops produce shockwaves and a rising cascade of pop sounds', () {
      loadBoard(engine, ['R R R R R . . B B']);
      shoot(engine, BubbleColor.red, engine.grid.centerOf(0, 5));
      for (var i = 0; i < 30; i++) {
        engine.update(1 / 60);
      }
      final popLevels = [
        for (final (s, l) in sounds)
          if (s == GameSound.pop) l,
      ];
      expect(popLevels, [0, 1, 2]);
      expect(engine.effects.shockwaves.isNotEmpty || engine.effects.pops.isEmpty, isTrue);
    });

    test('celebrate shows a banner, confetti and plays the fanfare', () {
      engine.celebrate('NEW BEST!');
      expect(engine.effects.banners.single.text, 'NEW BEST!');
      expect(engine.effects.confetti, isNotEmpty);
      expect(played(), contains(GameSound.newBest));
    });
  });

  group('sound events', () {
    test('wall bounces and swaps make sounds', () {
      loadBoard(engine, ['B B . . . . . . .']);
      engine.swapBubbles();
      expect(played(), contains(GameSound.swap));
      engine.shooter.setAimAngle(150 * math.pi / 180);
      engine.fire();
      settle(engine);
      expect(played(), containsAllInOrder([GameSound.shoot, GameSound.bounce, GameSound.hit]));
    });

    test('a new row rumbles', () {
      loadBoard(engine, ['B G B G B G B G B']);
      final colors = [BubbleColor.yellow, BubbleColor.purple, BubbleColor.orange];
      for (var i = 0; i < GameEngine.shotsPerRow; i++) {
        shoot(engine, colors[i % 3], Offset(3.0 + i * 3, 0));
      }
      expect(played(), contains(GameSound.newRow));
    });

    test('the danger warning plays once when bubbles get close', () {
      final rows = engine.layout.dangerRow - 1; // lowest row index = dangerRow - 2
      loadBoard(engine, [
        for (var r = 0; r < rows; r++) r.isEven ? 'B G B G B G B G B' : 'G B G B G B G B',
      ]);
      expect(played().where((s) => s == GameSound.danger), hasLength(1));
      engine.refreshAfterGridEdit();
      expect(played().where((s) => s == GameSound.danger), hasLength(1));
    });
  });
}
