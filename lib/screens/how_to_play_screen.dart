import 'package:flutter/material.dart';

import '../game/bubble_color.dart';
import '../game/game_config.dart';
import '../game/scoring.dart';
import '../painters/bubble_painter.dart';
import '../services/settings_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common/game_button.dart';

/// A short illustrated guide to the controls and rules.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key, required this.services});

  final AppServices services;

  /// Titles of the tips, in order (used by tests).
  static List<String> get tipTitles => [for (final t in _tips) t.title];

  static final List<_Tip> _tips = [
    const _Tip(
      icon: Icons.swipe_rounded,
      title: 'AIM',
      text:
          'Drag anywhere on the board. The dotted line shows the path, '
          'including bounces off the walls, and where the bubble will land.',
    ),
    const _Tip(
      icon: Icons.touch_app_rounded,
      title: 'SHOOT',
      text:
          'Lifting your finger does not shoot. Tap to fire in the direction '
          'you aimed. Tap the NEXT bubble to swap it with the loaded one.',
    ),
    _Tip(
      bubbles: const [BubbleColor.red, BubbleColor.red, BubbleColor.red],
      title: 'MATCH 3',
      text:
          'Connect 3 or more bubbles of the same color to pop them. '
          'Bubbles left hanging with nothing above them fall for bonus points.',
    ),
    _Tip(
      icon: Icons.local_fire_department_rounded,
      title: 'COMBOS',
      text:
          'Matching shots in a row multiply your points, up to '
          'x${ScoreRules.maxMultiplier}. Every ${ScoreRules.rainbowStreak} in a row '
          'earns a rainbow bubble that matches any color.',
    ),
    const _Tip(
      icon: Icons.vertical_align_bottom_rounded,
      title: 'NEW ROWS',
      text:
          'After ${GameConfig.shotsPerRow} shots without a match, a new row '
          'pushes the bubbles down. The NEW ROW counter shows how many shots are left.',
    ),
    const _Tip(
      icon: Icons.warning_amber_rounded,
      title: 'DANGER LINE',
      text:
          'The game ends when a bubble crosses the red dashed line. Clear the '
          'whole board to reach the next level.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    return Scaffold(
      body: ArcadeBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        GameIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          size: 44,
                          onPressed: () {
                            settings.click();
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('HOW TO PLAY', style: AppTheme.label(28)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: _tips.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i == _tips.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: GameButton(
                              label: 'GOT IT',
                              icon: Icons.check_rounded,
                              onPressed: () {
                                settings.click();
                                Navigator.of(context).pop();
                              },
                            ),
                          );
                        }
                        return _TipCard(tip: _tips[i]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tip {
  const _Tip({required this.title, required this.text, this.icon, this.bubbles});

  final String title;
  final String text;
  final IconData? icon;
  final List<BubbleColor>? bubbles;
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});

  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            height: 44,
            child: Center(
              child: tip.bubbles != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [for (final c in tip.bubbles!) BubbleView(color: c, size: 18)],
                    )
                  : Icon(tip.icon, color: AppColors.gold, size: 32),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title, style: AppTheme.label(15, color: AppColors.lightBlue)),
                const SizedBox(height: 4),
                Text(
                  tip.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
