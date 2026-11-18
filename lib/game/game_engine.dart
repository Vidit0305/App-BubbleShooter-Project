import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import 'board_layout.dart';
import 'bubble.dart';
import 'bubble_color.dart';
import 'bubble_grid.dart';
import 'bubble_shooter.dart';
import 'collision_detector.dart';
import 'game_config.dart';
import 'game_effects.dart';
import 'match_finder.dart';
import 'scoring.dart';
import 'trajectory_calculator.dart';

enum GamePhase {
  /// Waiting for the player to shoot.
  aiming,

  /// A bubble is travelling.
  flying,

  /// The grid is sliding down (new row pushed in, or a new level arriving).
  rowSliding,

  /// The board was cleared; a new arrangement follows shortly.
  levelCleared,

  gameOver,
}

/// Gameplay events the UI turns into sounds (and haptics).
enum GameSound {
  shoot,
  hit,
  bounce,
  swap,

  /// level = position in the popping cascade (0..4), so pitch can rise.
  pop,
  fall,

  /// level = streak multiplier (2..5).
  combo,
  praise,
  rainbow,
  newRow,
  danger,
  newBest,
  levelClear,
  gameOver,
}

typedef GameSoundCallback = void Function(GameSound sound, int level);

/// Summary of the most recent shot, useful for UI feedback and tests.
class ShotResult {
  const ShotResult({
    required this.cell,
    required this.color,
    required this.popped,
    required this.dropped,
    required this.points,
    required this.multiplier,
    this.praise,
  });

  final GridCell cell;
  final BubbleColor color;
  final int popped;
  final int dropped;
  final int points;
  final int multiplier;
  final String? praise;

  bool get matched => popped > 0;
}

/// All gameplay state and rules. Independent of widgets: the UI drives it via
/// [configure], [aimAt], [fire], [update], [pause]/[resume] and observes the
/// [ValueNotifier]s and [ChangeNotifier] (which ticks once per frame).
class GameEngine extends ChangeNotifier {
  GameEngine({math.Random? random, this.onSound}) : _random = random ?? math.Random() {
    shooter = BubbleShooter(_random);
    effects = GameEffects(_random);
  }

  // Shortcuts to the tuning values in GameConfig.
  static const int shotsPerRow = GameConfig.shotsPerRow;
  static const double bubbleSpeed = GameConfig.bubbleSpeed;
  static const double rowSlideSpeed = GameConfig.rowSlideSpeed;
  static const double levelIntroDuration = GameConfig.levelIntroDuration;
  static const double levelClearDelay = GameConfig.levelClearDelay;
  static const double maxFrameStep = GameConfig.maxFrameStep;

  final math.Random _random;
  GameSoundCallback? onSound;

  late final BubbleShooter shooter;
  late final GameEffects effects;
  final TrajectoryCalculator _trajectoryCalculator = const TrajectoryCalculator();

  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> level = ValueNotifier<int>(1);
  final ValueNotifier<int> shotsUntilNewRow = ValueNotifier<int>(shotsPerRow);
  final ValueNotifier<GamePhase> phase = ValueNotifier<GamePhase>(GamePhase.aiming);
  final ValueNotifier<bool> paused = ValueNotifier<bool>(false);
  final ValueNotifier<BubbleColor> currentColor = ValueNotifier<BubbleColor>(BubbleColor.red);
  final ValueNotifier<BubbleColor> nextColor = ValueNotifier<BubbleColor>(BubbleColor.blue);
  final ValueNotifier<bool> nextIsRainbow = ValueNotifier<bool>(false);

  /// Consecutive matching shots (0 after a miss).
  final ValueNotifier<int> streak = ValueNotifier<int>(0);

  BoardLayout? _layout;
  BubbleGrid? _grid;
  CollisionDetector? _detector;
  Size? _lastSize;

  FlyingBubble? _flying;
  double _flyCarry = 0;
  bool _bouncedThisFrame = false;
  int _missedShots = 0;
  double _slideOffset = 0;
  double _slideSpeed = rowSlideSpeed;
  bool _gameOverAfterSlide = false;
  bool _wasNearDanger = false;
  double _levelTimer = 0;
  double _shake = 0;
  double _time = 0;
  int _lastLevelBonus = 0;
  ShotResult? _lastShot;

  TrajectoryResult? _trajectory;
  Offset? _trajectoryAim;
  bool _trajectoryDirty = true;

  final List<_ScheduledSound> _scheduledSounds = <_ScheduledSound>[];

  // ---------------------------------------------------------------------------
  // Read-only state for rendering and tests
  // ---------------------------------------------------------------------------

  bool get isReady => _layout != null;
  bool isConfiguredFor(Size size) => _layout != null && _lastSize == size;
  BoardLayout get layout => _layout!;
  BubbleGrid get grid => _grid!;
  FlyingBubble? get flyingBubble => _flying;

  /// Vertical offset (world units, <= 0) applied when drawing the grid while
  /// it slides into place.
  double get gridSlideOffset => _slideOffset;
  double get shakeAmount => _shake;
  double get time => _time;
  int get missedShots => _missedShots;
  int get lastLevelBonus => _lastLevelBonus;
  ShotResult? get lastShot => _lastShot;

  bool get canFire => isReady && !paused.value && phase.value == GamePhase.aiming;

  /// True when the lowest bubbles are close to the danger line.
  bool get isNearDanger =>
      isReady && grid.lowestOccupiedRow >= layout.dangerRow - GameConfig.dangerWarningRows;

  /// Predicted path for the current aim (only while aiming).
  TrajectoryResult? get trajectory {
    if (!isReady || phase.value != GamePhase.aiming) return null;
    final aim = shooter.aimDirection;
    if (_trajectoryDirty || aim != _trajectoryAim) {
      _trajectory = _trajectoryCalculator.compute(grid, _detector!, shooter.position, aim);
      _trajectoryAim = aim;
      _trajectoryDirty = false;
    }
    return _trajectory;
  }

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  /// Adapts the engine to the board size in logical pixels. Starts a new game
  /// on first call. Later calls only rescale (the column count is kept).
  void configure(Size size) {
    if (size.width <= 0 || size.height <= 0 || size == _lastSize) return;
    _lastSize = size;
    if (_layout == null) {
      configureLayout(BoardLayout.forSize(size));
    } else {
      _applyLayout(BoardLayout.forSize(size, columns: _layout!.columns));
    }
  }

  /// Uses an explicit layout and starts a new game.
  void configureLayout(BoardLayout layout) {
    _grid = BubbleGrid(columns: layout.columns);
    _applyLayout(layout);
    newGame();
  }

  void _applyLayout(BoardLayout layout) {
    _layout = layout;
    _detector = CollisionDetector(worldWidth: layout.worldWidth);
    shooter.position = layout.shooterPosition;
    _trajectoryDirty = true;
  }

  void newGame() {
    if (!isReady) return;
    score.value = 0;
    streak.value = 0;
    paused.value = false;
    _shake = 0;
    _lastShot = null;
    _scheduledSounds.clear();
    effects.clear();
    shooter.resetAim();
    _startLevel(1);
  }

  /// Number of starting rows for a level (7, 8, then 9), limited so there is
  /// always room above the danger line.
  int initialRowsFor(int level) {
    final wanted = math.min(GameConfig.baseRows + level, GameConfig.maxStartRows);
    return math.max(
      GameConfig.minStartRows,
      math.min(wanted, layout.dangerRow - GameConfig.safetyRows),
    );
  }

  void _startLevel(int newLevel) {
    level.value = newLevel;
    _flying = null;
    _missedShots = 0;
    _gameOverAfterSlide = false;
    _wasNearDanger = false;
    shotsUntilNewRow.value = shotsPerRow;
    grid.clear();
    _generateBoard(newLevel);
    final keepRainbow = shooter.nextRainbow || shooter.currentRainbow;
    shooter.load(grid.colorsPresent);
    shooter.nextRainbow = keepRainbow && newLevel > 1;
    _syncColorNotifiers();
    // Slide the new arrangement in from above.
    _slideOffset = -(grid.rowCount * BubbleGrid.rowHeight + BubbleGrid.diameter);
    _slideSpeed = -_slideOffset / levelIntroDuration;
    _trajectoryDirty = true;
    if (newLevel > 1) effects.addBanner('LEVEL $newLevel', style: PraiseStyle.cool);
    phase.value = GamePhase.rowSliding;
  }

  /// Fills the starting rows. Colors are random with some clustering (copied
  /// from an already placed neighbor); clustering decreases with level.
  void _generateBoard(int lvl) {
    final rows = initialRowsFor(lvl);
    final clusterChance = math.max(
      GameConfig.minClusterChance,
      GameConfig.clusterChance - GameConfig.clusterChanceStep * (lvl - 1),
    );
    const palette = BubbleColor.values;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < grid.columnsInRow(r); c++) {
        BubbleColor color = palette[_random.nextInt(palette.length)];
        if (_random.nextDouble() < clusterChance) {
          final placed = grid
              .neighborsOf(r, c)
              .where((n) => grid.isOccupied(n.row, n.col))
              .toList(growable: false);
          if (placed.isNotEmpty) {
            color = grid.colorAtCell(placed[_random.nextInt(placed.length)])!;
          }
        }
        grid.setColor(r, c, color);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  /// Aims at a point given in world units. Only changes the direction.
  void aimAt(Offset worldPoint) {
    if (!isReady || paused.value || phase.value == GamePhase.gameOver) return;
    if (shooter.aimAt(worldPoint)) {
      _trajectoryDirty = true;
      notifyListeners();
    }
  }

  /// Aims at a point given in logical pixels relative to the board.
  void aimAtPixels(Offset localPosition) {
    if (!isReady) return;
    aimAt(layout.toWorld(localPosition));
  }

  /// Fires the loaded bubble in the current aim direction. Ignored unless the
  /// game is waiting for a shot (so only one bubble can ever be in flight).
  bool fire() {
    if (!canFire) return false;
    final rainbow = shooter.currentRainbow;
    final color = shooter.takeShot(grid.colorsPresent);
    _flying = FlyingBubble(
      color: color,
      position: shooter.position,
      direction: shooter.aimDirection,
      rainbow: rainbow,
    );
    _flyCarry = 0;
    _syncColorNotifiers();
    phase.value = GamePhase.flying;
    _emit(GameSound.shoot);
    notifyListeners();
    return true;
  }

  /// Swaps the loaded and next bubbles.
  bool swapBubbles() {
    if (!canFire) return false;
    shooter.swap();
    _syncColorNotifiers();
    _emit(GameSound.swap);
    notifyListeners();
    return true;
  }

  void pause() {
    if (!isReady || paused.value || phase.value == GamePhase.gameOver) return;
    paused.value = true;
    notifyListeners();
  }

  void resume() {
    if (!paused.value) return;
    paused.value = false;
    notifyListeners();
  }

  /// Call after editing [grid] directly (tests, tools): re-syncs the loaded
  /// colors and the trajectory and returns to aiming.
  void refreshAfterGridEdit() {
    grid.trimEmptyRows();
    _slideOffset = 0;
    _enterAiming();
    notifyListeners();
  }

  /// Celebrates a milestone reached outside the engine (e.g. beating the
  /// best score mid-game).
  void celebrate(String text) {
    if (!isReady) return;
    effects
      ..addBanner(text, style: PraiseStyle.gold, size: 2.6)
      ..rainConfetti(layout.worldWidth, 90)
      ..addFlash(0.35);
    _emit(GameSound.newBest);
  }

  // ---------------------------------------------------------------------------
  // Frame update
  // ---------------------------------------------------------------------------

  /// Advances the simulation by [dt] seconds. Does nothing while paused.
  void update(double dt) {
    if (!isReady || paused.value || dt <= 0) return;
    final step = math.min(dt, maxFrameStep);
    _time += step;
    effects.update(step, layout.worldHeight);
    _updateScheduledSounds(step);
    if (_shake > 0) _shake = math.max(0, _shake - step);

    switch (phase.value) {
      case GamePhase.flying:
        _updateFlying(step);
      case GamePhase.rowSliding:
        _slideOffset += _slideSpeed * step;
        if (_slideOffset >= 0) {
          _slideOffset = 0;
          if (_gameOverAfterSlide) {
            _gameOver();
          } else {
            _enterAiming();
          }
        }
      case GamePhase.levelCleared:
        _levelTimer -= step;
        if (_levelTimer <= 0) _startLevel(level.value + 1);
      case GamePhase.aiming:
      case GamePhase.gameOver:
        break;
    }
    notifyListeners();
  }

  void _onBounce(Offset _) => _bouncedThisFrame = true;

  void _updateFlying(double dt) {
    final bubble = _flying;
    if (bubble == null) return;
    bubble.recordTrail();
    // Move in whole collision sub-steps (carrying the remainder) so the live
    // bubble samples exactly the same points as the trajectory preview.
    final quantum = _detector!.maxStep;
    _flyCarry += bubbleSpeed * dt;
    final steps = (_flyCarry / quantum).floor();
    if (steps == 0) return;
    _flyCarry -= steps * quantum;
    _bouncedThisFrame = false;
    final result = _detector!.move(
      grid,
      bubble.position,
      bubble.direction,
      steps * quantum,
      onBounce: _onBounce,
    );
    bubble
      ..position = result.position
      ..direction = result.direction;
    if (_bouncedThisFrame) _emit(GameSound.bounce);
    if (result.stopped) _attach(bubble);
  }

  // ---------------------------------------------------------------------------
  // Rules
  // ---------------------------------------------------------------------------

  void _attach(FlyingBubble bubble) {
    _flying = null;
    final cell = _detector!.findSnapCell(grid, bubble.position);
    final color = bubble.rainbow ? (_bestRainbowColor(cell) ?? bubble.color) : bubble.color;
    grid.setColor(cell.row, cell.col, color);
    _emit(GameSound.hit);

    final group = MatchFinder.findMatch(grid, cell);
    var dropped = 0;
    var points = 0;
    var multiplier = 1;
    String? praise;
    final at = grid.centerOfCell(cell);
    if (group.isNotEmpty) {
      streak.value++;
      multiplier = ScoreRules.multiplierFor(streak.value);
      _popGroup(group);
      final floating = MatchFinder.findFloating(grid);
      dropped = floating.length;
      _dropBubbles(floating);
      points = ScoreRules.forMatch(popped: group.length, dropped: dropped) * multiplier;
      _addScore(points, at);
      _missedShots = 0;
      praise = ScoreRules.praiseFor(popped: group.length, dropped: dropped);
      _celebrateShot(praise, multiplier, group.length + dropped, at);
      if (streak.value % ScoreRules.rainbowStreak == 0) _awardRainbow();
    } else {
      _missedShots++;
      streak.value = 0;
    }
    _lastShot = ShotResult(
      cell: cell,
      color: color,
      popped: group.length,
      dropped: dropped,
      points: points,
      multiplier: multiplier,
      praise: praise,
    );
    grid.trimEmptyRows();

    if (grid.isEmpty) {
      _levelCleared();
      return;
    }
    if (grid.lowestOccupiedRow >= layout.dangerRow) {
      _gameOver();
      return;
    }
    if (_missedShots >= shotsPerRow) {
      _missedShots = 0;
      shotsUntilNewRow.value = shotsPerRow;
      _addRow();
      return;
    }
    shotsUntilNewRow.value = shotsPerRow - _missedShots;
    _enterAiming();
  }

  /// The neighbor color that gives a rainbow bubble at [cell] the largest
  /// connected group (null if it has no colored neighbors).
  BubbleColor? _bestRainbowColor(GridCell cell) {
    final candidates = <BubbleColor>{};
    for (final n in grid.neighborsOf(cell.row, cell.col)) {
      final c = grid.colorAtCell(n);
      if (c != null) candidates.add(c);
    }
    BubbleColor? best;
    var bestSize = 0;
    for (final c in candidates) {
      grid.setColor(cell.row, cell.col, c);
      final size = MatchFinder.findConnectedSameColor(grid, cell).length;
      if (size > bestSize) {
        bestSize = size;
        best = c;
      }
    }
    grid.remove(cell.row, cell.col);
    return best;
  }

  void _celebrateShot(String? praise, int multiplier, int cleared, Offset at) {
    if (multiplier >= 2) _schedule(GameSound.combo, 0.16, level: multiplier);
    if (praise != null) {
      final big = cleared >= 10;
      effects.addBanner(
        praise,
        style: cleared >= 15 ? PraiseStyle.rainbow : PraiseStyle.gold,
        size: big ? 2.8 : 2.4,
      );
      _schedule(GameSound.praise, 0.12);
      if (big) {
        effects
          ..burstConfetti(at, math.min(20 + cleared * 3, 80))
          ..addFlash(cleared >= 15 ? 0.55 : 0.35);
        _shake = math.max(_shake, 0.35);
      } else {
        effects.burstConfetti(at, 14);
      }
    } else if (multiplier >= 2) {
      effects.addBanner('COMBO x$multiplier', style: PraiseStyle.cool, size: 1.9);
    }
  }

  void _awardRainbow() {
    shooter.nextRainbow = true;
    _syncColorNotifiers();
    effects.addBanner('RAINBOW BUBBLE!', style: PraiseStyle.rainbow, size: 2.0);
    _schedule(GameSound.rainbow, 0.35);
  }

  void _popGroup(List<GridCell> group) {
    var sounds = 0;
    for (var i = 0; i < group.length; i++) {
      final cell = group[i];
      final pos = grid.centerOfCell(cell);
      final color = grid.remove(cell.row, cell.col)!;
      final delay = i * 0.035;
      effects.addPop(pos, color, delay);
      // A rising cascade of pops (one sound every other bubble).
      if (i.isEven && sounds < 5) _schedule(GameSound.pop, delay, level: sounds++);
    }
  }

  void _dropBubbles(List<GridCell> cells) {
    if (cells.isEmpty) return;
    for (final cell in cells) {
      final pos = grid.centerOfCell(cell);
      final color = grid.remove(cell.row, cell.col)!;
      effects.addFall(pos, color);
    }
    _schedule(GameSound.fall, 0.12);
  }

  void _addScore(int points, Offset at) {
    if (points <= 0) return;
    score.value += points;
    effects.addPopup(at, '+$points');
  }

  /// Pushes a new row in at the top and slides the grid down.
  void _addRow() {
    final present = grid.colorsPresent.toList(growable: false);
    final palette = present.length >= 2 ? present : BubbleColor.values;
    grid.insertRowAtTop((_) => palette[_random.nextInt(palette.length)]);
    _gameOverAfterSlide = grid.lowestOccupiedRow >= layout.dangerRow;
    _slideOffset = -BubbleGrid.rowHeight;
    _slideSpeed = rowSlideSpeed;
    _trajectoryDirty = true;
    _shake = math.max(_shake, 0.18);
    _emit(GameSound.newRow);
    phase.value = GamePhase.rowSliding;
  }

  void _levelCleared() {
    _lastLevelBonus = ScoreRules.levelClearBonus(level.value);
    _addScore(_lastLevelBonus, Offset(layout.worldWidth / 2, layout.worldHeight / 3));
    _levelTimer = levelClearDelay;
    effects
      ..banners.clear()
      ..rainConfetti(layout.worldWidth, 120)
      ..addFlash(0.4);
    _emit(GameSound.levelClear);
    phase.value = GamePhase.levelCleared;
  }

  void _gameOver() {
    _flying = null;
    _scheduledSounds.clear();
    streak.value = 0;
    _emit(GameSound.gameOver);
    phase.value = GamePhase.gameOver;
  }

  void _enterAiming() {
    shooter.sync(grid.colorsPresent);
    _syncColorNotifiers();
    _trajectoryDirty = true;
    final near = isNearDanger;
    if (near && !_wasNearDanger) _emit(GameSound.danger);
    _wasNearDanger = near;
    phase.value = GamePhase.aiming;
  }

  void _syncColorNotifiers() {
    currentColor.value = shooter.current;
    nextColor.value = shooter.next;
    nextIsRainbow.value = shooter.nextRainbow;
  }

  // ---------------------------------------------------------------------------
  // Sounds
  // ---------------------------------------------------------------------------

  void _emit(GameSound sound, {int level = 0}) => onSound?.call(sound, level);

  void _schedule(GameSound sound, double delay, {int level = 0}) {
    if (delay <= 0) {
      _emit(sound, level: level);
    } else {
      _scheduledSounds.add(_ScheduledSound(sound, delay, level));
    }
  }

  void _updateScheduledSounds(double dt) {
    if (_scheduledSounds.isEmpty) return;
    for (final s in _scheduledSounds) {
      s.delay -= dt;
      if (s.delay <= 0) _emit(s.sound, level: s.level);
    }
    _scheduledSounds.removeWhere((s) => s.delay <= 0);
  }

  @override
  void dispose() {
    onSound = null;
    score.dispose();
    level.dispose();
    shotsUntilNewRow.dispose();
    phase.dispose();
    paused.dispose();
    currentColor.dispose();
    nextColor.dispose();
    nextIsRainbow.dispose();
    streak.dispose();
    super.dispose();
  }
}

class _ScheduledSound {
  _ScheduledSound(this.sound, this.delay, this.level);

  final GameSound sound;
  double delay;
  final int level;
}
