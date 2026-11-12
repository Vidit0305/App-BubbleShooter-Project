import 'dart:math' as math;

import 'package:bubble_shooter/game/bubble_color.dart';
import 'package:bubble_shooter/game/game_engine.dart';
import 'package:bubble_shooter/app.dart';
import 'package:bubble_shooter/screens/game_screen.dart';
import 'package:bubble_shooter/services/audio_service.dart';
import 'package:bubble_shooter/services/settings_controller.dart';
import 'package:bubble_shooter/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppServices> createServices([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await StorageService.create();
  final settings = SettingsController(storage: storage, audio: SilentAudioService())..load();
  return AppServices(settings: settings);
}

void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pumps [count] 60 fps frames (the game loop runs continuously, so
/// pumpAndSettle would never return).
Future<void> frames(WidgetTester tester, [int count = 1]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Opens a GameScreen driven by [engine] from a simple launcher page.
Future<void> openGame(WidgetTester tester, AppServices services, GameEngine engine) async {
  usePhoneScreen(tester);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => GameScreen(services: services, engine: engine),
            )),
            child: const Text('launch'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('launch'));
  await frames(tester, 60); // route transition + level intro slide
  expect(engine.phase.value, GamePhase.aiming);
}

void main() {
  group('home screen', () {
    testWidgets('shows title, play, best score, settings and sound toggle', (tester) async {
      usePhoneScreen(tester);
      final services = await createServices({StorageService.bestScoreKey: 1234});
      await tester.pumpWidget(BubbleShooterApp(services: services));
      await tester.pump();

      expect(find.text('SHOOTER'), findsWidgets);
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('BEST SCORE'), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('SOUND ON'), findsOneWidget);
    });

    testWidgets('PLAY starts a new game', (tester) async {
      usePhoneScreen(tester);
      final services = await createServices();
      await tester.pumpWidget(BubbleShooterApp(services: services));
      await tester.tap(find.text('PLAY'));
      await frames(tester, 40);

      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
      expect(find.text('NEW ROW'), findsOneWidget);
      expect(find.byKey(const ValueKey('game-board')), findsOneWidget);
    });

    testWidgets('sound toggle mutes everything and persists', (tester) async {
      usePhoneScreen(tester);
      final services = await createServices();
      await tester.pumpWidget(BubbleShooterApp(services: services));
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();

      expect(find.text('SOUND OFF'), findsOneWidget);
      expect(services.audio.sfxEnabled, isFalse);
      expect(services.audio.musicEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StorageService.sfxEnabledKey), isFalse);
      expect(prefs.getBool(StorageService.musicEnabledKey), isFalse);
    });
  });

  group('settings', () {
    testWidgets('effects and music toggles persist', (tester) async {
      usePhoneScreen(tester);
      final services = await createServices();
      await tester.pumpWidget(BubbleShooterApp(services: services));
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await frames(tester, 30);

      expect(find.text('SOUND EFFECTS'), findsOneWidget);
      expect(find.text('MUSIC'), findsOneWidget);
      expect(find.text('RETURN TO HOME'), findsOneWidget);
      await tester.tap(find.byType(Switch).at(1)); // music off
      await tester.pump();

      // Simulate an app restart: a fresh storage/settings instance.
      final reloaded = SettingsController(
        storage: await StorageService.create(),
        audio: SilentAudioService(),
      )..load();
      expect(reloaded.musicEnabled, isFalse);
      expect(reloaded.sfxEnabled, isTrue);
      expect(reloaded.vibrationEnabled, isTrue);

      expect(find.text('VIBRATION'), findsOneWidget);
      await tester.tap(find.byType(Switch).at(2)); // vibration off
      await tester.pump();
      final again = SettingsController(
        storage: await StorageService.create(),
        audio: SilentAudioService(),
      )..load();
      expect(again.vibrationEnabled, isFalse);

      await tester.tap(find.text('RETURN TO HOME'));
      await frames(tester, 30);
      expect(find.text('PLAY'), findsOneWidget);
    });

    testWidgets('best score persists after restarting the app', (tester) async {
      final services = await createServices();
      expect(services.settings.submitScore(900), isTrue);
      expect(services.settings.submitScore(500), isFalse);
      await tester.pump();

      final reloaded = SettingsController(
        storage: await StorageService.create(),
        audio: SilentAudioService(),
      )..load();
      expect(reloaded.bestScore, 900);
    });
  });

  group('gameplay screen', () {
    testWidgets('drag aims without shooting; tap shoots once', (tester) async {
      final services = await createServices();
      final engine = GameEngine(random: math.Random(4));
      await openGame(tester, services, engine);

      final board = find.byKey(const ValueKey('game-board'));
      final center = tester.getCenter(board);
      final gesture = await tester.startGesture(center);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-15, -5));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await frames(tester, 5);

      expect(engine.shooter.aimDirection.dx, lessThan(0), reason: 'aimed left');
      expect(engine.phase.value, GamePhase.aiming, reason: 'releasing must not shoot');
      expect(engine.flyingBubble, isNull);

      final aim = engine.shooter.aimDirection;
      final next = engine.nextColor.value;
      await tester.tapAt(center + const Offset(80, 40));
      await tester.pump();
      expect(engine.phase.value, GamePhase.flying);
      expect(engine.flyingBubble!.direction, aim, reason: 'fires in the selected direction');
      expect(engine.currentColor.value, next, reason: 'next bubble moved into the launcher');

      final flying = engine.flyingBubble;
      await tester.tapAt(center);
      await tester.pump();
      expect(engine.flyingBubble, same(flying), reason: 'no second bubble while moving');

      await frames(tester, 90);
      expect(engine.flyingBubble, isNull);
    });

    testWidgets('pause freezes the game, resume continues', (tester) async {
      final services = await createServices();
      final engine = GameEngine(random: math.Random(5));
      await openGame(tester, services, engine);

      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('game-board'))));
      await frames(tester, 3);
      expect(engine.phase.value, GamePhase.flying);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);
      expect(find.text('RESTART'), findsOneWidget);
      expect(find.text('HOME'), findsOneWidget);
      final pos = engine.flyingBubble!.position;
      await frames(tester, 60);
      expect(engine.flyingBubble!.position, pos);

      await tester.tap(find.text('RESUME'));
      await frames(tester, 3);
      expect(find.text('PAUSED'), findsNothing);
      expect(engine.flyingBubble?.position, isNot(pos));
    });

    testWidgets('restart resets the game and records the unfinished score', (tester) async {
      final services = await createServices();
      final engine = GameEngine(random: math.Random(6));
      await openGame(tester, services, engine);

      engine.score.value = 120;
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      await tester.tap(find.text('RESTART'));
      await frames(tester, 60);

      expect(find.text('PAUSED'), findsNothing);
      expect(engine.score.value, 0);
      expect(engine.level.value, 1);
      expect(engine.phase.value, GamePhase.aiming);
      expect(services.settings.bestScore, 120);
    });

    testWidgets('game over shows the result with a new high score', (tester) async {
      final services = await createServices({StorageService.bestScoreKey: 100});
      final engine = GameEngine(random: math.Random(7));
      await openGame(tester, services, engine);

      // Fill the board down to the danger line, then miss straight up.
      final grid = engine.grid;
      grid.clear();
      for (var r = 0; r < engine.layout.dangerRow; r++) {
        for (var c = 0; c < grid.columnsInRow(r); c++) {
          grid.setColor(r, c, (r + c).isEven ? BubbleColor.blue : BubbleColor.green);
        }
      }
      engine.refreshAfterGridEdit();
      engine.score.value = 450;
      engine.shooter.current = BubbleColor.red;
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('game-board'))));
      await frames(tester, 90);

      expect(engine.phase.value, GamePhase.gameOver);
      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('NEW HIGH SCORE!'), findsOneWidget);
      expect(services.settings.bestScore, 450);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(StorageService.bestScoreKey), 450);

      // Taps on the board no longer shoot.
      expect(engine.fire(), isFalse);

      await tester.tap(find.text('HOME'));
      await frames(tester, 40);
      expect(find.byType(GameScreen), findsNothing);
      expect(find.text('launch'), findsOneWidget);
    });

    testWidgets('tapping the next bubble swaps it with the loaded one', (tester) async {
      final services = await createServices();
      final engine = GameEngine(random: math.Random(8));
      await openGame(tester, services, engine);
      engine.shooter
        ..current = BubbleColor.red
        ..next = BubbleColor.blue;
      engine.refreshAfterGridEdit();
      // refreshAfterGridEdit may re-pick colors missing from the board.
      final current = engine.shooter.current;
      final next = engine.shooter.next;

      await tester.tap(find.byKey(const ValueKey('next-preview')));
      await tester.pump();
      expect(engine.shooter.current, next);
      expect(engine.shooter.next, current);
      expect(engine.phase.value, GamePhase.aiming, reason: 'swapping does not shoot');
    });
  });
}
