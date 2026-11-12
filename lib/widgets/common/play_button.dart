import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The hero call-to-action: a golden glossy pill that gently breathes and
/// has a light sweep passing across it.
class PlayButton extends StatefulWidget {
  const PlayButton({super.key, required this.onPressed, this.label = 'PLAY'});

  final VoidCallback onPressed;
  final String label;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    const width = 250.0;
    const height = 74.0;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final breath = 1 + 0.03 * math.sin(t * 2 * math.pi * 2);
            return Transform.scale(
              scale: _pressed ? 0.94 : breath,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE07A), Color(0xFFFFA928), Color(0xFFFF6A00)],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8A00).withValues(alpha: 0.35 + 0.2 * (breath - 1) / 0.03),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                    BoxShadow(color: const Color(0xFFA34500), offset: Offset(0, _pressed ? 2 : 6)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(height / 2),
                  child: Stack(
                    children: [
                      // Gloss on the upper half.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: height * 0.5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.55),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Light sweep (passes during the first 35% of the cycle).
                      Positioned(
                        left: -80 + (width + 160) * (t / 0.35).clamp(0.0, 1.0),
                        top: -10,
                        bottom: -10,
                        width: 50,
                        child: Transform.rotate(
                          angle: 0.35,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.55),
                                Colors.white.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      child!,
                    ],
                  ),
                ),
              ),
            );
          },
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38,
                    shadows: [Shadow(color: Color(0x99A34500), offset: Offset(0, 2), blurRadius: 2)]),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: AppTheme.label(30).copyWith(
                    shadows: const [
                      Shadow(color: Color(0xCCA34500), offset: Offset(0, 2), blurRadius: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
