import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'bubble.dart';
import 'bubble_color.dart';

/// Honeycomb (offset-row hexagonal) bubble grid.
///
/// Geometry is expressed in "world units" where a bubble has radius 1.
/// Rows alternate between "full" rows with [columns] bubbles and "shifted"
/// rows that are offset right by one radius and hold `columns - 1` bubbles,
/// so every row fits exactly within `columns * 2` world units.
///
/// Row 0 is always the ceiling row. When a new row is pushed in from the
/// top, the row parity flips so that existing rows keep their offsets.
class BubbleGrid {
  BubbleGrid({required this.columns}) : assert(columns >= 3);

  static const double radius = 1.0;
  static const double diameter = 2.0;
  static final double rowHeight = math.sqrt(3);

  final int columns;
  final List<List<BubbleColor?>> _rows = <List<BubbleColor?>>[];
  int _parity = 0;

  /// Number of allocated rows (trailing rows may be empty until trimmed).
  int get rowCount => _rows.length;

  /// Width of the playfield in world units.
  double get width => columns * diameter;

  bool isRowShifted(int row) => ((row + _parity) & 1) == 1;

  int columnsInRow(int row) => isRowShifted(row) ? columns - 1 : columns;

  bool isValidCell(int row, int col) =>
      row >= 0 && col >= 0 && col < columnsInRow(row);

  BubbleColor? colorAt(int row, int col) {
    if (row < 0 || row >= _rows.length) return null;
    final r = _rows[row];
    if (col < 0 || col >= r.length) return null;
    return r[col];
  }

  BubbleColor? colorAtCell(GridCell cell) => colorAt(cell.row, cell.col);

  bool isOccupied(int row, int col) => colorAt(row, col) != null;

  void setColor(int row, int col, BubbleColor color) {
    if (!isValidCell(row, col)) {
      throw RangeError('Invalid grid cell ($row, $col)');
    }
    _ensureRows(row + 1);
    _rows[row][col] = color;
  }

  /// Removes the bubble at the cell and returns its color (if any).
  BubbleColor? remove(int row, int col) {
    final color = colorAt(row, col);
    if (color != null) _rows[row][col] = null;
    return color;
  }

  void clear() {
    _rows.clear();
    _parity = 0;
  }

  /// Pushes a new row in at the top; every existing bubble moves down one row
  /// while keeping its horizontal position.
  void insertRowAtTop(BubbleColor? Function(int col) colorFor) {
    _parity ^= 1;
    _rows.insert(0, List<BubbleColor?>.generate(columnsInRow(0), colorFor));
  }

  /// Drops empty rows from the bottom of the grid.
  void trimEmptyRows() {
    while (_rows.isNotEmpty && _rows.last.every((c) => c == null)) {
      _rows.removeLast();
    }
  }

  void _ensureRows(int count) {
    while (_rows.length < count) {
      _rows.add(List<BubbleColor?>.filled(columnsInRow(_rows.length), null));
    }
  }

  /// Center of a cell in world units.
  Offset centerOf(int row, int col) => Offset(
        radius + col * diameter + (isRowShifted(row) ? radius : 0),
        radius + row * rowHeight,
      );

  Offset centerOfCell(GridCell cell) => centerOf(cell.row, cell.col);

  /// The (up to) six valid neighbor cells, regardless of occupancy.
  List<GridCell> neighborsOf(int row, int col) {
    // Diagonal neighbors in the rows above/below sit at columns
    // (col - 1, col) for full rows and (col, col + 1) for shifted rows.
    final dl = isRowShifted(row) ? 0 : -1;
    final result = <GridCell>[];
    void add(int r, int c) {
      if (isValidCell(r, c)) result.add(GridCell(r, c));
    }

    add(row, col - 1);
    add(row, col + 1);
    add(row - 1, col + dl);
    add(row - 1, col + dl + 1);
    add(row + 1, col + dl);
    add(row + 1, col + dl + 1);
    return result;
  }

  bool hasOccupiedNeighbor(int row, int col) {
    for (final n in neighborsOf(row, col)) {
      if (isOccupied(n.row, n.col)) return true;
    }
    return false;
  }

  /// The valid cell whose center is (approximately) closest to [p],
  /// ignoring occupancy.
  GridCell nearestCell(Offset p) {
    final row = math.max(0, ((p.dy - radius) / rowHeight).round());
    final shift = isRowShifted(row) ? radius : 0.0;
    final col = ((p.dx - radius - shift) / diameter)
        .round()
        .clamp(0, columnsInRow(row) - 1);
    return GridCell(row, col);
  }

  void forEachOccupied(void Function(int row, int col, BubbleColor color) f) {
    for (var r = 0; r < _rows.length; r++) {
      final row = _rows[r];
      for (var c = 0; c < row.length; c++) {
        final color = row[c];
        if (color != null) f(r, c, color);
      }
    }
  }

  List<GridCell> get occupiedCells {
    final cells = <GridCell>[];
    forEachOccupied((r, c, _) => cells.add(GridCell(r, c)));
    return cells;
  }

  int get bubbleCount {
    var count = 0;
    forEachOccupied((_, _, _) => count++);
    return count;
  }

  bool get isEmpty => bubbleCount == 0;

  /// Index of the lowest row containing a bubble, or -1 if empty.
  int get lowestOccupiedRow {
    for (var r = _rows.length - 1; r >= 0; r--) {
      if (_rows[r].any((c) => c != null)) return r;
    }
    return -1;
  }

  Set<BubbleColor> get colorsPresent {
    final colors = <BubbleColor>{};
    forEachOccupied((_, _, color) => colors.add(color));
    return colors;
  }

  /// Human-readable dump, e.g. for debugging tests.
  @override
  String toString() {
    final buffer = StringBuffer();
    for (var r = 0; r < _rows.length; r++) {
      if (isRowShifted(r)) buffer.write(' ');
      buffer.writeln(_rows[r].map((c) => c?.code ?? '.').join(' '));
    }
    return buffer.toString();
  }
}
