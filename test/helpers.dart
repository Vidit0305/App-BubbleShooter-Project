import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:bubble_shooter/game/board_layout.dart';
import 'package:bubble_shooter/game/bubble_color.dart';
import 'package:bubble_shooter/game/bubble_grid.dart';
import 'package:bubble_shooter/game/game_engine.dart';

/// Builds a grid from rows of color codes separated by spaces
/// ('R', 'B', 'G', 'Y', 'P', 'O'; '.' = empty). Row 0 is a full row,
/// odd rows are shifted and hold one bubble fewer.
BubbleGrid gridFromRows(int columns, List<String> rows) {
  final grid = BubbleGrid(columns: columns);
  fillGrid(grid, rows);
  return grid;
}

void fillGrid(BubbleGrid grid, List<String> rows) {
  grid.clear();
  for (var r = 0; r < rows.length; r++) {
    final cells = rows[r].trim().split(RegExp(r'\s+'));
    for (var c = 0; c < cells.length; c++) {
      final color = BubbleColor.fromCode(cells[c]);
      if (color != null) grid.setColor(r, c, color);
    }
  }
}

/// A 9-column board, 30 world units tall (danger row = 14), ready to aim.
GameEngine createEngine({int seed = 1}) {
  final engine = GameEngine(random: math.Random(seed));
  engine.configureLayout(BoardLayout.world(columns: 9, worldHeight: 30));
  settle(engine);
  return engine;
}

/// Runs 60 fps frames until the engine waits for input (or a frame limit).
void settle(GameEngine engine, {int maxFrames = 600}) {
  for (var i = 0; i < maxFrames; i++) {
    switch (engine.phase.value) {
      case GamePhase.aiming:
      case GamePhase.gameOver:
      case GamePhase.levelCleared:
        return;
      case GamePhase.flying:
      case GamePhase.rowSliding:
        engine.update(1 / 60);
    }
  }
}

/// Replaces the board with [rows] and returns to aiming.
void loadBoard(GameEngine engine, List<String> rows) {
  fillGrid(engine.grid, rows);
  engine.refreshAfterGridEdit();
}

/// Loads [color], aims at [target] (world units), fires, and runs the
/// simulation until the shot resolves.
void shoot(GameEngine engine, BubbleColor color, Offset target) {
  engine.shooter.current = color;
  engine.aimAt(target);
  if (!engine.fire()) {
    throw StateError('fire() was rejected in phase ${engine.phase.value}');
  }
  settle(engine);
}
