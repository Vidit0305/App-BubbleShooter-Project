import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/board_layout.dart';
import '../game/game_engine.dart';
import '../painters/game_painter.dart';
import '../theme/app_theme.dart';
import 'hud/next_bubble_preview.dart';
import 'overlays/level_banner.dart';

/// The playfield: input handling, the painted board, the launcher HUD
/// (next bubble, shots until a new row) and the level-cleared banner.
///
/// Sizes the engine to the space it is given.
class GameBoard extends StatefulWidget {
  const GameBoard({super.key, required this.engine});

  final GameEngine engine;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  late final GamePainter _painter = GamePainter(widget.engine);
  Size? _pendingSize;

  GameEngine get _engine => widget.engine;

  /// Configuring may start a game, which updates notifiers that widgets
  /// outside this LayoutBuilder listen to, so it must not run during layout.
  void _scheduleConfigure(Size size) {
    if (_engine.isConfiguredFor(size) || _pendingSize == size) return;
    _pendingSize = size;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingSize != size) return;
      _pendingSize = null;
      _engine.configure(size);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // Painters have no theme, so give it the app font for popups/banners.
    _painter.fontFamily = Theme.of(context).textTheme.titleLarge?.fontFamily;
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleConfigure(constraints.biggest);
        if (!_engine.isReady) return const SizedBox.shrink();
        final layout = _engine.layout;
        final scale = layout.scale;
        final shooter = layout.toPixels(layout.shooterPosition);
        final hudTop = (layout.worldHeight - BoardLayout.launcherAreaHeight) * scale;
        final hudHeight = BoardLayout.launcherAreaHeight * scale;
        final sideWidth = shooter.dx - 2.0 * scale;

        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.board.withValues(alpha: 0.55),
                  border: Border.symmetric(
                    vertical: BorderSide(color: AppColors.panelBorder.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('game-board'),
                behavior: HitTestBehavior.opaque,
                // Dragging only aims; a tap fires in the current direction.
                onPanStart: (d) => _engine.aimAtPixels(d.localPosition),
                onPanUpdate: (d) => _engine.aimAtPixels(d.localPosition),
                onTapUp: (_) => _engine.fire(),
                child: RepaintBoundary(
                  child: CustomPaint(painter: _painter, size: Size.infinite),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: hudTop,
              width: sideWidth,
              height: hudHeight,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: NextBubblePreview(
                    key: const ValueKey('next-preview'),
                    color: _engine.nextColor,
                    rainbow: _engine.nextIsRainbow,
                    bubbleSize: 1.7 * scale,
                    onSwap: _engine.swapBubbles,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: hudTop,
              width: sideWidth,
              height: hudHeight,
              child: IgnorePointer(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ShotsIndicator(
                      remaining: _engine.shotsUntilNewRow,
                      total: GameEngine.shotsPerRow,
                    ),
                  ),
                ),
              ),
            ),
            if (_engine.phase.value == GamePhase.levelCleared)
              Positioned.fill(
                child: LevelClearedBanner(
                  bonus: _engine.lastLevelBonus,
                  nextLevel: _engine.level.value + 1,
                ),
              ),
          ],
        );
      },
    );
  }
}
