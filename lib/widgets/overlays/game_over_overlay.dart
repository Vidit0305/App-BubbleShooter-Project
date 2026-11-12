import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'confetti_overlay.dart';
import '../common/game_button.dart';
import 'overlay_card.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.score,
    required this.bestScore,
    required this.isNewHighScore,
    required this.onRestart,
    required this.onHome,
  });

  final int score;
  final int bestScore;
  final bool isNewHighScore;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final card = OverlayCard(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('GAME OVER', style: AppTheme.label(34, color: AppColors.danger)),
        ),
        const SizedBox(height: 16),
        if (isNewHighScore) ...[
          const Center(child: _NewHighScoreBadge()),
          const SizedBox(height: 14),
        ],
        Text('SCORE',
            textAlign: TextAlign.center, style: AppTheme.label(14, color: AppColors.lightBlue)),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: score),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (_, value, _) =>
              Text('$value', textAlign: TextAlign.center, style: AppTheme.label(44)),
        ),
        const SizedBox(height: 8),
        Text('BEST',
            textAlign: TextAlign.center, style: AppTheme.label(14, color: AppColors.lightBlue)),
        Text('$bestScore',
            textAlign: TextAlign.center, style: AppTheme.label(24, color: AppColors.gold)),
        const SizedBox(height: 24),
        GameButton(label: 'RESTART', icon: Icons.refresh_rounded, onPressed: onRestart),
        const SizedBox(height: 14),
        GameButton(
          label: 'HOME',
          icon: Icons.home_rounded,
          color: AppColors.buttonNavy,
          onPressed: onHome,
        ),
      ],
    );
    if (!isNewHighScore) return card;
    return Positioned.fill(
      child: Stack(
        children: [
          card,
          const Positioned.fill(child: ConfettiOverlay()),
        ],
      ),
    );
  }
}

class _NewHighScoreBadge extends StatefulWidget {
  const _NewHighScoreBadge();

  @override
  State<_NewHighScoreBadge> createState() => _NewHighScoreBadgeState();
}

class _NewHighScoreBadgeState extends State<_NewHighScoreBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1.06).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x88FFD60A), blurRadius: 16),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppColors.navy, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('NEW HIGH SCORE!',
                    style: AppTheme.label(15, color: AppColors.navy).copyWith(shadows: const [])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
