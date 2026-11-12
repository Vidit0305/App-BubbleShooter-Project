import 'dart:ui' show Offset;

import 'bubble_color.dart';

/// A logical position in the hexagonal bubble grid.
class GridCell {
  const GridCell(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.row == row && other.col == col;

  @override
  int get hashCode => row * 1000 + col;

  @override
  String toString() => 'GridCell($row, $col)';
}

/// The bubble currently travelling from the shooter towards the grid.
class FlyingBubble {
  FlyingBubble({
    required this.color,
    required this.position,
    required this.direction,
    this.rainbow = false,
  });

  static const int trailLength = 9;

  final BubbleColor color;

  /// A rainbow (wildcard) bubble takes the color that makes the biggest match.
  final bool rainbow;
  Offset position;

  /// Unit vector of travel.
  Offset direction;

  /// Recent positions, oldest first, for the glowing trail.
  final List<Offset> trail = <Offset>[];

  void recordTrail() {
    trail.add(position);
    if (trail.length > trailLength) trail.removeAt(0);
  }
}
