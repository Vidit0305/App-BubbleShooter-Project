import 'dart:ui' show Offset, Size;

import 'bubble_grid.dart';

/// Maps the playfield (world units, bubble radius = 1) onto the screen and
/// positions the shooter and danger line.
class BoardLayout {
  BoardLayout._({required this.columns, required this.scale, required this.worldHeight});

  /// Builds a layout for a world of a given size (used by tests).
  factory BoardLayout.world({required int columns, required double worldHeight}) =>
      BoardLayout._(columns: columns, scale: 1, worldHeight: worldHeight);

  /// Builds a layout for a board of [size] logical pixels. The column count
  /// is derived from the width (unless given), and increased if the screen is
  /// too short to leave enough rows above the danger line.
  factory BoardLayout.forSize(Size size, {int? columns}) {
    if (columns != null) return _fit(size, columns);
    var cols = (size.width / targetBubbleDiameter).floor().clamp(minColumns, maxColumns);
    var layout = _fit(size, cols);
    while (layout.dangerRow < minPlayableRows && cols < absoluteMaxColumns) {
      cols++;
      layout = _fit(size, cols);
    }
    return layout;
  }

  static BoardLayout _fit(Size size, int columns) {
    final scale = size.width / (columns * BubbleGrid.diameter);
    return BoardLayout._(columns: columns, scale: scale, worldHeight: size.height / scale);
  }

  /// Preferred bubble diameter in logical pixels.
  static const double targetBubbleDiameter = 40;
  static const int minColumns = 8;
  static const int maxColumns = 12;
  static const int absoluteMaxColumns = 16;

  /// Rows that must fit above the danger line for the game to be playable.
  static const int minPlayableRows = 12;

  /// Height of the launcher area at the bottom, in world units.
  static const double launcherAreaHeight = 4.6;

  /// Gap between the top of the launcher area and the danger line.
  static const double dangerGap = 0.6;

  final int columns;

  /// Logical pixels per world unit.
  final double scale;
  final double worldHeight;

  double get worldWidth => columns * BubbleGrid.diameter;

  Offset get shooterPosition => Offset(worldWidth / 2, worldHeight - launcherAreaHeight / 2);

  double get dangerLineY => worldHeight - launcherAreaHeight - dangerGap;

  /// Number of rows that fit completely above the danger line. A bubble in
  /// a row with index >= [dangerRow] has crossed it.
  int get dangerRow => ((dangerLineY - BubbleGrid.diameter) / BubbleGrid.rowHeight).floor() + 1;

  Offset toWorld(Offset logicalPixels) => logicalPixels / scale;

  Offset toPixels(Offset world) => world * scale;
}
