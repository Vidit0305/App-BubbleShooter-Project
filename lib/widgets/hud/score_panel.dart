import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/scoring.dart';
import '../../theme/app_theme.dart';
import '../common/game_button.dart';

/// Top bar: pause button, current score (bumps when it grows) with a combo
/// badge, best score and level.
class ScorePanel extends StatelessWidget {
  const ScorePanel({
    super.key,
    required this.score,
    required this.best,
    required this.level,
    required this.streak,
    required this.onPause,
  });

  final ValueListenable<int> score;
  final ValueListenable<int> best;
  final ValueListenable<int> level;
  final ValueListenable<int> streak;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.panel.withValues(alpha: 0.92), AppColors.navy.withValues(alpha: 0.85)],
        ),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.18), width: 1.5)),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          GameIconButton(icon: Icons.pause_rounded, tooltip: 'Pause', size: 44, onPressed: onPause),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SCORE', style: AppTheme.label(12, color: AppColors.lightBlue)),
                _BumpingNumber(listenable: score, style: AppTheme.label(28)),
                SizedBox(
                  height: 20,
                  child: ValueListenableBuilder<int>(
                    valueListenable: streak,
                    builder: (_, value, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                      child: value >= 2
                          ? _ComboBadge(
                              key: ValueKey(ScoreRules.multiplierFor(value)),
                              multiplier: ScoreRules.multiplierFor(value),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('BEST', style: AppTheme.label(12, color: AppColors.lightBlue)),
                ValueListenableBuilder<int>(
                  valueListenable: best,
                  builder: (_, value, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('$value', style: AppTheme.label(20, color: AppColors.gold)),
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: level,
                  builder: (_, value, _) =>
                      Text('LEVEL $value', style: AppTheme.label(10, color: AppColors.lightBlue)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComboBadge extends StatelessWidget {
  const _ComboBadge({super.key, required this.multiplier});

  final int multiplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFF3CAC)]),
        boxShadow: const [BoxShadow(color: Color(0x88FF5A3C), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 3),
          Text('COMBO x$multiplier', style: AppTheme.label(11)),
        ],
      ),
    );
  }
}

class _BumpingNumber extends StatefulWidget {
  const _BumpingNumber({required this.listenable, required this.style});

  final ValueListenable<int> listenable;
  final TextStyle style;

  @override
  State<_BumpingNumber> createState() => _BumpingNumberState();
}

class _BumpingNumberState extends State<_BumpingNumber> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late int _value = widget.listenable.value;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_BumpingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onChanged);
      widget.listenable.addListener(_onChanged);
      _value = widget.listenable.value;
    }
  }

  void _onChanged() {
    final v = widget.listenable.value;
    final grew = v > _value;
    setState(() => _value = v);
    if (grew) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Transform.scale(scale: 1 + 0.25 * math.sin(math.pi * _controller.value), child: child),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('$_value', style: widget.style),
      ),
    );
  }
}
