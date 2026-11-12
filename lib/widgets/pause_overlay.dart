import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'game_button.dart';
import 'overlay_card.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.soundOn,
    required this.onResume,
    required this.onRestart,
    required this.onHome,
    required this.onToggleSound,
    required this.onSettings,
  });

  final bool soundOn;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final VoidCallback onToggleSound;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return OverlayCard(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('PAUSED', style: AppTheme.label(36)),
        ),
        const SizedBox(height: 24),
        GameButton(label: 'RESUME', icon: Icons.play_arrow_rounded, onPressed: onResume),
        const SizedBox(height: 14),
        GameButton(
          label: 'RESTART',
          icon: Icons.refresh_rounded,
          color: AppColors.buttonNavy,
          onPressed: onRestart,
        ),
        const SizedBox(height: 14),
        GameButton(
          label: 'HOME',
          icon: Icons.home_rounded,
          color: AppColors.buttonNavy,
          onPressed: onHome,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameIconButton(
              icon: soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              tooltip: soundOn ? 'Sound on' : 'Sound off',
              onPressed: onToggleSound,
            ),
            const SizedBox(width: 20),
            GameIconButton(
              icon: Icons.settings_rounded,
              tooltip: 'Settings',
              onPressed: onSettings,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          soundOn ? 'SOUND ON' : 'SOUND OFF',
          textAlign: TextAlign.center,
          style: AppTheme.label(11, color: AppColors.lightBlue),
        ),
      ],
    );
  }
}
