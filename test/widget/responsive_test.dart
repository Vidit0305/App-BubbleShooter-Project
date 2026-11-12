import 'dart:math' as math;

import 'package:bubble_shooter/game/game_engine.dart';
import 'package:bubble_shooter/app.dart';
import 'package:bubble_shooter/screens/game_screen.dart';
import 'package:bubble_shooter/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show createServices, frames;

/// Logical screen sizes: small, typical, tall, large phones and a tablet.
const sizes = <Size>[
  Size(320, 568),
  Size(360, 640),
  Size(393, 852),
  Size(430, 932),
  Size(768, 1024),
];

void main() {
  for (final size in sizes) {
    testWidgets('all screens lay out without overflow at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final services = await createServices();

      // Home.
      await tester.pumpWidget(BubbleShooterApp(services: services));
      await frames(tester, 2);
      expect(find.text('PLAY'), findsOneWidget);

      // Settings.
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(services: services)));
      await frames(tester, 2);

      // Game, pause and game over.
      final engine = GameEngine(random: math.Random(1));
      await tester.pumpWidget(MaterialApp(home: GameScreen(services: services, engine: engine)));
      await frames(tester, 60);
      expect(engine.phase.value, GamePhase.aiming);

      // The whole playfield, launcher and danger line fit inside the board.
      final board = tester.getSize(find.byKey(const ValueKey('game-board')));
      final layout = engine.layout;
      expect(layout.worldWidth * layout.scale, closeTo(board.width, 0.01));
      expect(layout.worldHeight * layout.scale, closeTo(board.height, 0.01));
      expect(layout.dangerRow, greaterThan(engine.grid.rowCount + 3),
          reason: 'room to play above the danger line');
      expect(layout.scale * 2, inInclusiveRange(24, 72), reason: 'bubble diameter in px');

      engine.pause();
      await frames(tester, 20);
      expect(find.text('PAUSED'), findsOneWidget);
      engine.resume();
      await frames(tester, 2);
    });
  }
}
