import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'bubble.dart';
import 'bubble_grid.dart';

enum MoveOutcome { moving, hitBubble, hitCeiling }

class MoveResult {
  const MoveResult(this.position, this.direction, this.outcome, {this.hitCell});

  final Offset position;
  final Offset direction;
  final MoveOutcome outcome;

  /// The grid bubble that was hit (for [MoveOutcome.hitBubble]).
  final GridCell? hitCell;

  bool get stopped => outcome != MoveOutcome.moving;
}

/// Moves a bubble through the playfield, handles wall bounces and detects
/// collisions with the ceiling and with grid bubbles.
///
/// Shared by the live physics and the aiming trajectory so the predicted
/// path always matches the real one.
class CollisionDetector {
  const CollisionDetector({
    required this.worldWidth,
    this.hitDistance = defaultHitDistance,
    this.maxStep = 0.25,
  });

  /// Center-to-center distance that counts as a collision. Slightly less
  /// than a full diameter (2.0) so bubbles can slip through narrow gaps,
  /// as in classic bubble shooters.
  static const double defaultHitDistance = 1.7;

  final double worldWidth;
  final double hitDistance;

  /// Largest sub-step used while moving. Much smaller than [hitDistance],
  /// so a fast bubble can never tunnel through another bubble.
  final double maxStep;

  /// The closest grid bubble within [hitDistance] of [p], if any.
  GridCell? findCollision(BubbleGrid grid, Offset p) {
    if (grid.rowCount == 0) return null;
    const r = BubbleGrid.radius;
    final approxRow = ((p.dy - r) / BubbleGrid.rowHeight).round();
    final hitSq = hitDistance * hitDistance;
    GridCell? best;
    var bestSq = double.infinity;
    for (var row = approxRow - 1; row <= approxRow + 1; row++) {
      if (row < 0 || row >= grid.rowCount) continue;
      final shift = grid.isRowShifted(row) ? r : 0.0;
      final approxCol = ((p.dx - r - shift) / BubbleGrid.diameter).round();
      for (var col = approxCol - 1; col <= approxCol + 1; col++) {
        if (!grid.isOccupied(row, col)) continue;
        final d = (grid.centerOf(row, col) - p).distanceSquared;
        if (d < hitSq && d < bestSq) {
          bestSq = d;
          best = GridCell(row, col);
        }
      }
    }
    return best;
  }

  /// Advances a bubble by [distance] along [direction], bouncing off the
  /// side walls. Stops early at the first collision.
  MoveResult move(
    BubbleGrid grid,
    Offset start,
    Offset direction,
    double distance, {
    void Function(Offset bouncePoint)? onBounce,
  }) {
    const r = BubbleGrid.radius;
    var x = start.dx;
    var y = start.dy;
    var dx = direction.dx;
    final dy = direction.dy;
    var remaining = distance;

    while (remaining > 0) {
      final step = math.min(remaining, maxStep);
      remaining -= step;
      x += dx * step;
      y += dy * step;

      if (x < r) {
        x = 2 * r - x;
        dx = -dx;
        onBounce?.call(Offset(r, y));
      } else if (x > worldWidth - r) {
        x = 2 * (worldWidth - r) - x;
        dx = -dx;
        onBounce?.call(Offset(worldWidth - r, y));
      }

      if (y <= r) {
        return MoveResult(Offset(x, r), Offset(dx, dy), MoveOutcome.hitCeiling);
      }
      final hit = findCollision(grid, Offset(x, y));
      if (hit != null) {
        return MoveResult(Offset(x, y), Offset(dx, dy), MoveOutcome.hitBubble,
            hitCell: hit);
      }
    }
    return MoveResult(Offset(x, y), Offset(dx, dy), MoveOutcome.moving);
  }

  /// The empty cell a bubble stopping at [p] should snap to: the nearest
  /// empty cell that is attached to the ceiling (row 0) or to another bubble.
  GridCell findSnapCell(BubbleGrid grid, Offset p) {
    final base = grid.nearestCell(p);
    GridCell? best;
    var bestSq = double.infinity;

    void consider(int row, int col, {required bool requireSupport}) {
      if (!grid.isValidCell(row, col) || grid.isOccupied(row, col)) return;
      if (requireSupport && row != 0 && !grid.hasOccupiedNeighbor(row, col)) {
        return;
      }
      final d = (grid.centerOf(row, col) - p).distanceSquared;
      if (d < bestSq) {
        bestSq = d;
        best = GridCell(row, col);
      }
    }

    void search(int rowSpan, {required bool requireSupport}) {
      for (var row = base.row - rowSpan; row <= base.row + rowSpan; row++) {
        if (row < 0) continue;
        for (var col = base.col - rowSpan - 1; col <= base.col + rowSpan + 1; col++) {
          consider(row, col, requireSupport: requireSupport);
        }
      }
    }

    search(1, requireSupport: true);
    if (best == null) search(2, requireSupport: false);
    return best ?? base;
  }
}
