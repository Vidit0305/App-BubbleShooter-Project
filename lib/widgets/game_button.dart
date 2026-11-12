import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Chunky arcade button with press-down feedback.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.buttonBlue,
    this.large = false,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool large;
  final double? width;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final base = enabled ? widget.color : Colors.grey.shade700;
    final top = Color.lerp(base, Colors.white, 0.25)!;
    final bottom = Color.lerp(base, Colors.black, 0.25)!;
    final edge = Color.lerp(base, Colors.black, 0.5)!;
    final height = widget.large ? 68.0 : 52.0;
    final fontSize = widget.large ? 28.0 : 18.0;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: widget.width,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2.6),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [top, bottom],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
              boxShadow: [
                BoxShadow(color: edge, offset: Offset(0, _pressed ? 2 : 5)),
                const BoxShadow(
                    color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 6)),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2.6),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.white, size: fontSize * 1.1),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(widget.label, style: AppTheme.label(fontSize)),
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

/// Round icon button with the same press feedback.
class GameIconButton extends StatefulWidget {
  const GameIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 48,
    this.color = AppColors.buttonNavy,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final double size;
  final Color color;

  @override
  State<GameIconButton> createState() => _GameIconButtonState();
}

class _GameIconButtonState extends State<GameIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(widget.color, Colors.white, 0.3)!.withValues(alpha: 0.9),
                  Color.lerp(widget.color, Colors.black, 0.25)!.withValues(alpha: 0.9),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.52),
          ),
        ),
      ),
    );
  }
}
