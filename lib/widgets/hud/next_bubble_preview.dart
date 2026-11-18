import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/bubble_color.dart';
import '../../painters/bubble_painter.dart';
import '../../theme/app_theme.dart';

/// Shows the next bubble beside the launcher. Tapping it swaps the loaded
/// and next bubbles.
class NextBubblePreview extends StatelessWidget {
  const NextBubblePreview({
    super.key,
    required this.color,
    required this.rainbow,
    required this.bubbleSize,
    required this.onSwap,
  });

  final ValueListenable<BubbleColor> color;
  final ValueListenable<bool> rainbow;
  final double bubbleSize;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Next bubble, tap to swap',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSwap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NEXT', style: AppTheme.label(11, color: AppColors.lightBlue)),
            const SizedBox(height: 4),
            ListenableBuilder(
              listenable: Listenable.merge([color, rainbow]),
              builder: (_, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: rainbow.value
                    ? RainbowBubbleView(key: const ValueKey('rainbow'), size: bubbleSize)
                    : BubbleView(key: ValueKey(color.value), color: color.value, size: bubbleSize),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'TAP TO SWAP',
              style: AppTheme.label(7, color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dots showing how many unsuccessful shots remain before a new row drops.
class ShotsIndicator extends StatelessWidget {
  const ShotsIndicator({super.key, required this.remaining, required this.total});

  final ValueListenable<int> remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: remaining,
      builder: (_, value, _) {
        final urgent = value <= 1;
        return Semantics(
          label: '$value shots before a new row',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('NEW ROW', style: AppTheme.label(11, color: AppColors.lightBlue)),
              const SizedBox(height: 4),
              Text(
                '$value',
                style: AppTheme.label(22, color: urgent ? AppColors.danger : Colors.white),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < total; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < value
                            ? (urgent ? AppColors.danger : AppColors.lightBlue)
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
