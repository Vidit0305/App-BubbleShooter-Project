import 'package:bubble_shooter/app.dart';
import 'package:bubble_shooter/game/game_config.dart';
import 'package:bubble_shooter/screens/how_to_play_screen.dart';
import 'package:bubble_shooter/widgets/hud/next_bubble_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show createServices, frames, usePhoneScreen;

void main() {
  group('How to play', () {
    testWidgets('opens from the home screen and closes with GOT IT', (tester) async {
      usePhoneScreen(tester);
      final services = await createServices();
      await tester.pumpWidget(BubbleShooterApp(services: services));
      await frames(tester, 2);

      await tester.tap(find.byIcon(Icons.menu_book_rounded));
      await frames(tester, 30);
      expect(find.byType(HowToPlayScreen), findsOneWidget);
      expect(find.text('AIM'), findsOneWidget);
      expect(find.text('SHOOT'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('GOT IT'), 200);
      await tester.tap(find.text('GOT IT'));
      await frames(tester, 30);
      expect(find.byType(HowToPlayScreen), findsNothing);
      expect(find.text('PLAY'), findsOneWidget);
    });

    testWidgets('rule numbers come from the game configuration', (tester) async {
      usePhoneScreen(tester);
      final services = await createServices();
      await tester.pumpWidget(MaterialApp(home: HowToPlayScreen(services: services)));
      await frames(tester, 2);

      await tester.scrollUntilVisible(find.text('NEW ROWS'), 200);
      expect(find.textContaining('After ${GameConfig.shotsPerRow} shots'), findsOneWidget);
      expect(HowToPlayScreen.tipTitles, [
        'AIM',
        'SHOOT',
        'MATCH 3',
        'COMBOS',
        'NEW ROWS',
        'DANGER LINE',
      ]);
    });
  });

  group('NEW ROW counter', () {
    double pulseScale(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byKey(const ValueKey('shots-pulse')),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    testWidgets('pulses only on the last shot before a new row', (tester) async {
      final remaining = ValueNotifier<int>(3);
      addTearDown(remaining.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: ShotsIndicator(remaining: remaining, total: 5)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(pulseScale(tester), 1);

      remaining.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(pulseScale(tester), greaterThan(1));

      remaining.value = 5;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(pulseScale(tester), 1);
    });
  });
}
