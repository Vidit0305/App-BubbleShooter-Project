import 'package:flutter/material.dart';

import '../widgets/common/premium_background.dart';

/// Arcade palette: deep indigo background (matching the app icon) with
/// white / light-blue UI and warm gold accents.
class AppColors {
  const AppColors._();

  static const Color backgroundTop = Color(0xFF1C1670);
  static const Color backgroundBottom = Color(0xFF06041F);
  static const Color board = Color(0xFF0B0838);
  static const Color panel = Color(0xFF1D1872);
  static const Color panelBorder = Color(0xFF4B47C9);
  static const Color lightBlue = Color(0xFF9FDBFF);
  static const Color navy = Color(0xFF0D0A3C);
  static const Color buttonBlue = Color(0xFF3A7BFF);
  static const Color buttonNavy = Color(0xFF2E2A8F);
  static const Color gold = Color(0xFFFFC93C);
  static const Color orange = Color(0xFFFF7A1A);
  static const Color pink = Color(0xFFFF4FA3);
  static const Color danger = Color(0xFFFF4D5E);

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundBottom,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.buttonBlue,
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      );

  /// Bold arcade label style.
  static TextStyle label(double size, {Color color = Colors.white}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: size * 0.08,
        color: color,
        shadows: const [
          Shadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 3),
        ],
      );
}

/// Full-screen premium backdrop.
///
/// Menus use the animated version; gameplay uses a calm static frame so it
/// never competes with the bubbles.
class ArcadeBackground extends StatelessWidget {
  const ArcadeBackground({super.key, required this.child, this.calm = false});

  final Widget child;
  final bool calm;

  @override
  Widget build(BuildContext context) => calm
      ? PremiumBackground(animated: false, floatingBubbles: false, intensity: 0.55, child: child)
      : PremiumBackground(child: child);
}

/// Frosted glass panel.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
