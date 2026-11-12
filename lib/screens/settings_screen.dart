import 'package:flutter/material.dart';

import '../services/settings_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_route.dart';
import '../widgets/game_button.dart';
import 'game_screen.dart';

/// What the game screen should do after settings closes.
enum SettingsAction { restart, home }

/// Sound effects / music toggles, restart and return home.
///
/// When opened from a running game ([inGame]), RESTART and HOME are returned
/// to the game screen as a [SettingsAction]. From the home screen, RESTART
/// starts a new game and HOME simply goes back.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.services, this.inGame = false});

  final AppServices services;
  final bool inGame;

  SettingsController get _settings => services.settings;

  void _restart(BuildContext context) {
    _settings.click();
    if (inGame) {
      Navigator.of(context).pop(SettingsAction.restart);
    } else {
      Navigator.of(context).pushReplacement(FadeRoute<void>(GameScreen(services: services)));
    }
  }

  void _home(BuildContext context) {
    _settings.click();
    Navigator.of(context).pop(inGame ? SettingsAction.home : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ArcadeBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GameIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          size: 44,
                          onPressed: () {
                            _settings.click();
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('SETTINGS', style: AppTheme.label(30)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    ListenableBuilder(
                      listenable: _settings,
                      builder: (_, _) => GlassPanel(
                        radius: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        child: Column(
                          children: [
                            _ToggleRow(
                              icon: Icons.graphic_eq_rounded,
                              label: 'SOUND EFFECTS',
                              value: _settings.sfxEnabled,
                              onChanged: (v) async {
                                await _settings.setSfxEnabled(v);
                                _settings.click();
                              },
                            ),
                            Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
                            _ToggleRow(
                              icon: Icons.music_note_rounded,
                              label: 'MUSIC',
                              value: _settings.musicEnabled,
                              onChanged: (v) {
                                _settings.click();
                                _settings.setMusicEnabled(v);
                              },
                            ),
                            Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
                            _ToggleRow(
                              icon: Icons.vibration_rounded,
                              label: 'VIBRATION',
                              value: _settings.vibrationEnabled,
                              onChanged: (v) {
                                _settings.click();
                                _settings.setVibrationEnabled(v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    GameButton(
                      label: inGame ? 'RESTART GAME' : 'NEW GAME',
                      icon: Icons.refresh_rounded,
                      onPressed: () => _restart(context),
                    ),
                    const SizedBox(height: 16),
                    GameButton(
                      label: 'RETURN TO HOME',
                      icon: Icons.home_rounded,
                      color: AppColors.buttonNavy,
                      onPressed: () => _home(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.lightBlue),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: AppTheme.label(16))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.buttonBlue,
          ),
        ],
      ),
    );
  }
}
