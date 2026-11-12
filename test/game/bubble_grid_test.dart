import 'dart:math' as math;

import 'package:bubble_shooter/game/bubble.dart';
import 'package:bubble_shooter/game/bubble_color.dart';
import 'package:bubble_shooter/game/bubble_grid.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('BubbleGrid geometry', () {
    test('rows alternate between full and shifted', () {
      final grid = BubbleGrid(columns: 9);
      expect(grid.columnsInRow(0), 9);
      expect(grid.columnsInRow(1), 8);
      expect(grid.columnsInRow(2), 9);
      expect(grid.isRowShifted(1), isTrue);
    });

    test('cell centers are staggered and stay inside the board', () {
      final grid = BubbleGrid(columns: 9);
      expect(grid.centerOf(0, 0), const Offset(1, 1));
      expect(grid.centerOf(1, 0).dx, 2);
      expect(grid.centerOf(1, 0).dy, closeTo(1 + math.sqrt(3), 1e-9));
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < grid.columnsInRow(r); c++) {
          final p = grid.centerOf(r, c);
          expect(p.dx - 1, greaterThanOrEqualTo(0));
          expect(p.dx + 1, lessThanOrEqualTo(grid.width + 1e-9));
        }
      }
    });

    test('every neighbor touches (center distance == diameter)', () {
      final grid = BubbleGrid(columns: 9);
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < grid.columnsInRow(r); c++) {
          for (final n in grid.neighborsOf(r, c)) {
            final d = (grid.centerOf(r, c) - grid.centerOfCell(n)).distance;
            expect(d, closeTo(2, 1e-9), reason: '($r,$c) -> $n');
          }
        }
      }
    });

    test('interior cells have six neighbors, edges fewer', () {
      final grid = BubbleGrid(columns: 9);
      expect(grid.neighborsOf(2, 4).length, 6); // full row
      expect(grid.neighborsOf(3, 4).length, 6); // shifted row
      expect(grid.neighborsOf(0, 0).length, 2); // top-left corner
      expect(grid.neighborsOf(2, 0).length, 3); // left edge of a full row
      expect(
        grid.neighborsOf(1, 0).toSet(),
        {
          const GridCell(1, 1),
          const GridCell(0, 0),
          const GridCell(0, 1),
          const GridCell(2, 0),
          const GridCell(2, 1),
        },
      );
    });

    test('nearestCell maps positions back to cells', () {
      final grid = BubbleGrid(columns: 9);
      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < grid.columnsInRow(r); c++) {
          expect(grid.nearestCell(grid.centerOf(r, c)), GridCell(r, c));
        }
      }
    });
  });

  group('BubbleGrid contents', () {
    test('add, remove, count and colors', () {
      final grid = gridFromRows(9, ['R B . G', '. Y']);
      expect(grid.bubbleCount, 4);
      expect(grid.colorAt(0, 1), BubbleColor.blue);
      expect(grid.colorAt(1, 1), BubbleColor.yellow);
      expect(grid.colorsPresent,
          {BubbleColor.red, BubbleColor.blue, BubbleColor.green, BubbleColor.yellow});
      expect(grid.remove(0, 1), BubbleColor.blue);
      expect(grid.isOccupied(0, 1), isFalse);
      expect(grid.lowestOccupiedRow, 1);
    });

    test('setColor rejects invalid cells', () {
      final grid = BubbleGrid(columns: 9);
      expect(() => grid.setColor(1, 8, BubbleColor.red), throwsRangeError);
      expect(() => grid.setColor(0, -1, BubbleColor.red), throwsRangeError);
    });

    test('trimEmptyRows drops empty bottom rows', () {
      final grid = gridFromRows(9, ['R', '.', 'G']);
      grid.remove(2, 0);
      grid.trimEmptyRows();
      expect(grid.rowCount, 1);
    });

    test('inserting a row at the top shifts bubbles down and keeps x', () {
      final grid = gridFromRows(9, ['R B G', 'Y P']);
      final before = grid.centerOf(0, 2);
      final beforeShifted = grid.centerOf(1, 0);
      grid.insertRowAtTop((_) => BubbleColor.orange);

      expect(grid.rowCount, 3);
      expect(grid.colorAt(1, 2), BubbleColor.green);
      expect(grid.colorAt(2, 0), BubbleColor.yellow);
      expect(grid.centerOf(1, 2).dx, before.dx);
      expect(grid.centerOf(2, 0).dx, beforeShifted.dx);
      expect(grid.centerOf(1, 2).dy, closeTo(before.dy + BubbleGrid.rowHeight, 1e-9));
      // The new top row is shifted (old row 0 was full), so it has 8 bubbles.
      expect(grid.columnsInRow(0), 8);
      expect(List.generate(8, (c) => grid.colorAt(0, c)),
          everyElement(BubbleColor.orange));
      // Honeycomb still intact.
      for (final n in grid.neighborsOf(1, 2)) {
        expect((grid.centerOf(1, 2) - grid.centerOfCell(n)).distance, closeTo(2, 1e-9));
      }
    });
  });
}
