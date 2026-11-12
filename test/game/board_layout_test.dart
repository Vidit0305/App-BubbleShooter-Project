import 'dart:ui' show Offset, Size;

import 'package:bubble_shooter/game/board_layout.dart';
import 'package:bubble_shooter/game/bubble_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoardLayout.forSize', () {
    test('picks columns from the width (about 40 px per bubble)', () {
      expect(BoardLayout.forSize(const Size(360, 700)).columns, 9);
      expect(BoardLayout.forSize(const Size(412, 760)).columns, 10);
    });

    test('clamps the column count on very narrow and very wide boards', () {
      expect(BoardLayout.forSize(const Size(250, 900)).columns, BoardLayout.minColumns);
      expect(BoardLayout.forSize(const Size(900, 1400)).columns, BoardLayout.maxColumns);
    });

    test('adds columns on short screens so enough rows fit', () {
      final layout = BoardLayout.forSize(const Size(320, 400));
      expect(layout.columns, greaterThan(BoardLayout.minColumns));
      expect(layout.dangerRow, greaterThanOrEqualTo(BoardLayout.minPlayableRows));
    });

    test('keeps a given column count when resizing', () {
      expect(BoardLayout.forSize(const Size(500, 700), columns: 9).columns, 9);
    });

    test('the world fills the board exactly', () {
      const size = Size(393, 700);
      final layout = BoardLayout.forSize(size);
      expect(layout.worldWidth * layout.scale, closeTo(size.width, 1e-9));
      expect(layout.worldHeight * layout.scale, closeTo(size.height, 1e-9));
    });
  });

  group('BoardLayout geometry', () {
    final layout = BoardLayout.world(columns: 9, worldHeight: 30);

    test('the shooter sits centered in the launcher area', () {
      expect(layout.shooterPosition.dx, layout.worldWidth / 2);
      expect(layout.shooterPosition.dy, 30 - BoardLayout.launcherAreaHeight / 2);
    });

    test('the danger line is above the launcher', () {
      expect(layout.dangerLineY, lessThan(layout.shooterPosition.dy - BubbleGrid.radius));
    });

    test('rows below dangerRow fit above the line, dangerRow does not', () {
      final grid = BubbleGrid(columns: 9);
      final lastSafe = grid.centerOf(layout.dangerRow - 1, 0).dy + BubbleGrid.radius;
      final firstOver = grid.centerOf(layout.dangerRow, 0).dy + BubbleGrid.radius;
      expect(lastSafe, lessThanOrEqualTo(layout.dangerLineY));
      expect(firstOver, greaterThan(layout.dangerLineY));
    });

    test('pixel <-> world conversion round-trips', () {
      final px = BoardLayout.forSize(const Size(360, 700));
      const p = Offset(123, 456);
      expect(px.toPixels(px.toWorld(p)), p);
    });
  });
}
