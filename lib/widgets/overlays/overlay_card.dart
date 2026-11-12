import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Dimmed full-screen barrier with a centered card that pops in.
/// Absorbs all touches so gameplay underneath cannot be controlled.
class OverlayCard extends StatelessWidget {
  const OverlayCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB3000514),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.panel, AppColors.navy],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.panelBorder, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
