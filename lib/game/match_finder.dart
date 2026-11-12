import 'dart:collection';

import 'bubble.dart';
import 'bubble_grid.dart';

/// Connected-component searches over the bubble grid (breadth-first).
class MatchFinder {
  const MatchFinder._();

  /// Minimum group size that pops.
  static const int minMatch = 3;

  /// All bubbles connected to [start] that share its color, in BFS order
  /// (so the start cell comes first and nearer cells come earlier).
  /// Uses all six hex neighbors, so diagonal connections count.
  static List<GridCell> findConnectedSameColor(BubbleGrid grid, GridCell start) {
    final color = grid.colorAtCell(start);
    if (color == null) return const <GridCell>[];

    final visited = <GridCell>{start};
    final order = <GridCell>[start];
    final queue = ListQueue<GridCell>()..add(start);
    while (queue.isNotEmpty) {
      final cell = queue.removeFirst();
      for (final n in grid.neighborsOf(cell.row, cell.col)) {
        if (grid.colorAtCell(n) == color && visited.add(n)) {
          order.add(n);
          queue.add(n);
        }
      }
    }
    return order;
  }

  /// The same-color group at [start] if it is large enough to pop,
  /// otherwise an empty list.
  static List<GridCell> findMatch(BubbleGrid grid, GridCell start) {
    final group = findConnectedSameColor(grid, start);
    return group.length >= minMatch ? group : const <GridCell>[];
  }

  /// Bubbles that are no longer connected (through any color) to the ceiling.
  static List<GridCell> findFloating(BubbleGrid grid) {
    final anchored = <GridCell>{};
    final queue = ListQueue<GridCell>();
    if (grid.rowCount > 0) {
      for (var c = 0; c < grid.columnsInRow(0); c++) {
        if (grid.isOccupied(0, c)) {
          final cell = GridCell(0, c);
          anchored.add(cell);
          queue.add(cell);
        }
      }
    }
    while (queue.isNotEmpty) {
      final cell = queue.removeFirst();
      for (final n in grid.neighborsOf(cell.row, cell.col)) {
        if (grid.isOccupied(n.row, n.col) && anchored.add(n)) {
          queue.add(n);
        }
      }
    }

    final floating = <GridCell>[];
    grid.forEachOccupied((r, c, _) {
      final cell = GridCell(r, c);
      if (!anchored.contains(cell)) floating.add(cell);
    });
    return floating;
  }
}
