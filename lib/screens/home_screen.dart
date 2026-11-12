import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/bubble_color.dart';
import '../painters/brand_painter.dart';
import '../services/settings_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_route.dart';
import '../widgets/game_button.dart';
import '../widgets/play_button.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  SettingsController get _settings => services.settings;

  void _play(BuildContext context) {
    _settings.click();
    Navigator.of(context).push(FadeRoute<void>(GameScreen(services: services)));
  }

  void _openSettings(BuildContext context) {
    _settings.click();
    Navigator.of(context).push(FadeRoute<void>(SettingsScreen(services: services)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ArcadeBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 640;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          BrandEmblem(size: compact ? 120 : 170),
                          const _Title(),
                          const SizedBox(height: 10),
                          Text(
                            'POP  •  MATCH  •  RELAX',
                            style: AppTheme.label(12, color: AppColors.lightBlue.withValues(alpha: 0.85))
                                .copyWith(letterSpacing: 4),
                          ),
                          const Spacer(flex: 2),
                          ListenableBuilder(
                            listenable: _settings,
                            builder: (_, _) => _BestScoreCard(best: _settings.bestScore),
                          ),
                          SizedBox(height: compact ? 20 : 30),
                          PlayButton(onPressed: () => _play(context)),
                          SizedBox(height: compact ? 22 : 34),
                          ListenableBuilder(
                            listenable: _settings,
                            builder: (_, _) => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _LabeledIconButton(
                                  icon: Icons.settings_rounded,
                                  label: 'SETTINGS',
                                  onPressed: () => _openSettings(context),
                                ),
                                const SizedBox(width: 44),
                                _LabeledIconButton(
                                  icon: _settings.soundOn
                                      ? Icons.volume_up_rounded
                                      : Icons.volume_off_rounded,
                                  label: _settings.soundOn ? 'SOUND ON' : 'SOUND OFF',
                                  onPressed: () async {
                                    await _settings.setSoundOn(!_settings.soundOn);
                                    _settings.click();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Glossy outlined title; the BUBBLE letters bob in a gentle wave.
class _Title extends StatefulWidget {
  const _Title();

  @override
  State<_Title> createState() => _TitleState();
}

class _TitleState extends State<_Title> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const word = 'BUBBLE';
    const colors = BubbleColor.values;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < word.length; i++)
                  Transform.translate(
                    offset: Offset(0, math.sin(_controller.value * 2 * math.pi - i * 0.7) * 4),
                    child: _GlossyText(
                      word[i],
                      size: 62,
                      colors: [
                        colors[i % colors.length].light,
                        colors[i % colors.length].color,
                        colors[i % colors.length].dark,
                      ],
                      glow: colors[i % colors.length].color,
                    ),
                  ),
              ],
            ),
          ),
          const _GlossyText(
            'SHOOTER',
            size: 40,
            letterSpacing: 9,
            colors: [Colors.white, Color(0xFFD6EEFF), Color(0xFF8FC8FF)],
            glow: Color(0xFF5AB4FF),
          ),
        ],
      ),
    );
  }
}

class _GlossyText extends StatelessWidget {
  const _GlossyText(
    this.text, {
    required this.size,
    required this.colors,
    required this.glow,
    this.letterSpacing = 1,
  });

  final String text;
  final double size;
  final List<Color> colors;
  final Color glow;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
      height: 1.05,
    );
    return Stack(
      children: [
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.14
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF140C45),
            shadows: [
              Shadow(color: glow.withValues(alpha: 0.75), blurRadius: size * 0.35),
              Shadow(color: const Color(0xAA000000), offset: Offset(0, size * 0.08)),
            ],
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: const [0.0, 0.55, 1.0],
          ).createShader(rect),
          child: Text(text, style: base.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}

class _BestScoreCard extends StatelessWidget {
  const _BestScoreCard({required this.best});

  final int best;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFFFFF1A8), Color(0xFFFFB300)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(r),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 6),
              Text('BEST SCORE', style: AppTheme.label(13, color: AppColors.lightBlue)),
            ],
          ),
          const SizedBox(height: 2),
          Text('$best', style: AppTheme.label(32, color: AppColors.gold)),
        ],
      ),
    );
  }
}

class _LabeledIconButton extends StatelessWidget {
  const _LabeledIconButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIconButton(icon: icon, tooltip: label, size: 58, onPressed: onPressed),
        const SizedBox(height: 7),
        Text(label, style: AppTheme.label(11, color: AppColors.lightBlue)),
      ],
    );
  }
}
