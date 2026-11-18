import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Brief "LEVEL CLEARED" notification shown between endless levels.
class LevelClearedBanner extends StatelessWidget {
  const LevelClearedBanner({super.key, required this.bonus, required this.nextLevel});

  final int bonus;
  final int nextLevel;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
          builder: (_, t, child) => Transform.scale(scale: 0.4 + 0.6 * t, child: child),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x66FFD60A), blurRadius: 24)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: Text('LEVEL CLEARED!', style: AppTheme.label(30, color: AppColors.gold)),
                ),
                const SizedBox(height: 6),
                Text('+$bonus BONUS', style: AppTheme.label(18)),
                const SizedBox(height: 4),
                Text(
                  'GET READY FOR LEVEL $nextLevel',
                  style: AppTheme.label(12, color: AppColors.lightBlue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
