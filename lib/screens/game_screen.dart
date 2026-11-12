import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/board_layout.dart';
import '../game/game_engine.dart';
import '../painters/game_painter.dart';
import '../services/game_feedback.dart';
import '../services/settings_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common/fade_route.dart';
import '../widgets/overlays/game_over_overlay.dart';
import '../widgets/overlays/level_banner.dart';
import '../widgets/hud/next_bubble_preview.dart';
import '../widgets/overlays/pause_overlay.dart';
import '../widgets/hud/score_panel.dart';
import 'settings_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.services, this.engine});

  final AppServices services;

  /// Optional engine (tests inject one to observe and control the game).
  final GameEngine? engine;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameOverInfo {
  const _GameOverInfo(this.score, this.best, this.isNewHighScore);

  final int score;
  final int best;
  final bool isNewHighScore;
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final GameFeedback _feedback = GameFeedback(widget.services.settings);
  late final GameEngine _engine = (widget.engine ?? GameEngine())
    ..onSound = _feedback.onGameSound;
  late final GamePainter _painter = GamePainter(_engine);
  late final Ticker _ticker = createTicker(_onTick);
  late final AppLifecycleListener _lifecycle;
  final ValueNotifier<int> _best = ValueNotifier<int>(0);
  Duration _lastTick = Duration.zero;
  Size? _pendingSize;
  _GameOverInfo? _gameOver;
  int _bestAtStart = 0;
  bool _bestAnnounced = false;

  SettingsController get _settings => widget.services.settings;

  @override
  void initState() {
    super.initState();
    _best.value = _settings.bestScore;
    _bestAtStart = _settings.bestScore;
    _engine.score.addListener(_updateBest);
    _engine.phase.addListener(_onPhaseChanged);
    _engine.paused.addListener(_onPausedChanged);
    // Never let gameplay run in the background.
    _lifecycle = AppLifecycleListener(
      onInactive: _engine.pause,
      onHide: _engine.pause,
      onPause: _engine.pause,
    );
    _startTicker();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker.dispose();
    _engine.score.removeListener(_updateBest);
    _engine.phase.removeListener(_onPhaseChanged);
    _engine.paused.removeListener(_onPausedChanged);
    _engine.dispose();
    _best.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Game loop
  // ---------------------------------------------------------------------------

  void _startTicker() {
    if (_ticker.isActive) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    _engine.update(dt);
    // Once the game is over and the last effects finished, stop ticking.
    if (_engine.phase.value == GamePhase.gameOver && _engine.effects.isIdle) {
      _ticker.stop();
    }
  }

  void _onPausedChanged() {
    if (_engine.paused.value) {
      _ticker.stop();
    } else {
      _startTicker();
    }
    setState(() {});
  }

  void _updateBest() {
    final score = _engine.score.value;
    _best.value = math.max(_settings.bestScore, score);
    // Celebrate once per game when the previous best is beaten. Deferred so
    // it shows after (and replaces) the praise for the shot that did it.
    if (!_bestAnnounced && _bestAtStart > 0 && score > _bestAtStart) {
      _bestAnnounced = true;
      scheduleMicrotask(() {
        if (!mounted) return;
        _engine.celebrate('NEW BEST!');
        _settings.haptic(Haptic.heavy);
      });
    }
  }

  void _onPhaseChanged() {
    final phase = _engine.phase.value;
    if (phase == GamePhase.gameOver && _gameOver == null) {
      final score = _engine.score.value;
      final isNew = _settings.submitScore(score);
      setState(() => _gameOver = _GameOverInfo(score, _settings.bestScore, isNew));
    } else if (phase == GamePhase.levelCleared || phase == GamePhase.rowSliding) {
      setState(() {}); // shows / hides the level banner
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _pause() {
    _settings.click();
    _engine.pause();
  }

  void _resume() {
    _settings.click();
    _engine.resume();
  }

  /// Records the score of an unfinished game (restart / leaving mid-game).
  void _submitUnfinishedScore() {
    if (_gameOver == null) _settings.submitScore(_engine.score.value);
  }

  void _restart() {
    _settings.click();
    _submitUnfinishedScore();
    setState(() => _gameOver = null);
    _engine.newGame();
    _best.value = _settings.bestScore;
    _bestAtStart = _settings.bestScore;
    _bestAnnounced = false;
    _startTicker();
  }

  void _goHome() {
    _settings.click();
    _submitUnfinishedScore();
    Navigator.of(context).pop();
  }

  Future<void> _openSettings() async {
    _settings.click();
    final action = await Navigator.of(context).push<SettingsAction>(
      FadeRoute<SettingsAction>(SettingsScreen(services: widget.services, inGame: true)),
    );
    if (!mounted) return;
    switch (action) {
      case SettingsAction.restart:
        _restart();
      case SettingsAction.home:
        _goHome();
      case null:
        break;
    }
  }

  void _onBackPressed() {
    if (_gameOver != null) {
      _goHome();
    } else if (_engine.paused.value) {
      _resume();
    } else {
      _pause();
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final gameOver = _gameOver;
    _painter.fontFamily = Theme.of(context).textTheme.titleLarge?.fontFamily;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        body: ArcadeBackground(
          calm: true,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    ScorePanel(
                      score: _engine.score,
                      best: _best,
                      level: _engine.level,
                      streak: _engine.streak,
                      onPause: _pause,
                    ),
                    Expanded(child: _buildBoard()),
                  ],
                ),
                if (_engine.paused.value && gameOver == null)
                  ListenableBuilder(
                    listenable: _settings,
                    builder: (_, _) => PauseOverlay(
                      soundOn: _settings.soundOn,
                      onResume: _resume,
                      onRestart: _restart,
                      onHome: _goHome,
                      onSettings: _openSettings,
                      onToggleSound: () async {
                        await _settings.setSoundOn(!_settings.soundOn);
                        _settings.click();
                      },
                    ),
                  ),
                if (gameOver != null)
                  GameOverOverlay(
                    score: gameOver.score,
                    bestScore: gameOver.best,
                    isNewHighScore: gameOver.isNewHighScore,
                    onRestart: _restart,
                    onHome: _goHome,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildBoard() {
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
