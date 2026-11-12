import 'package:bubble_shooter/game/bubble.dart';
import 'package:bubble_shooter/game/match_finder.dart';
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;

import '../helpers.dart';

void main() {
  group('MatchFinder.findMatch', () {
    test('three in a row match', () {
      final grid = gridFromRows(9, ['R R R B']);
      final match = MatchFinder.findMatch(grid, const GridCell(0, 2));
      expect(match.toSet(), {const GridCell(0, 0), const GridCell(0, 1), const GridCell(0, 2)});
      expect(match.first, const GridCell(0, 2), reason: 'start cell first');
    });

    test('two connected bubbles do not match', () {
      final grid = gridFromRows(9, ['R R B R']);
      expect(MatchFinder.findMatch(grid, const GridCell(0, 1)), isEmpty);
      expect(MatchFinder.findConnectedSameColor(grid, const GridCell(0, 1)).length, 2);
    });

    test('four or more connected bubbles match across rows', () {
      final grid = gridFromRows(9, [
        'R R B G',
        ' R R Y', // shifted row: (1,0) and (1,1) touch (0,0),(0,1),(0,2)
        'B . R',
      ]);
      final match = MatchFinder.findMatch(grid, const GridCell(0, 0));
      expect(match.toSet(), {
        const GridCell(0, 0),
        const GridCell(0, 1),
        const GridCell(1, 0),
        const GridCell(1, 1),
        const GridCell(2, 2), // touches shifted (1,1) diagonally
      });
    });

    test('purely diagonal chains match', () {
      // Zig-zag down the middle: (0,4) -> (1,4) -> (2,4), each a diagonal link.
      final grid = gridFromRows(9, [
        'B B . . R . . . .',
        '. . . . R . . .',
        '. . . . R . . . .',
      ]);
      final match = MatchFinder.findMatch(grid, const GridCell(2, 4));
      expect(match.toSet(), {const GridCell(0, 4), const GridCell(1, 4), const GridCell(2, 4)});
    });

    test('other colors break the group', () {
      final grid = gridFromRows(9, ['R B R R']);
      expect(MatchFinder.findMatch(grid, const GridCell(0, 0)), isEmpty);
    });

    test('empty start cell yields nothing', () {
      final grid = gridFromRows(9, ['R R R']);
      expect(MatchFinder.findConnectedSameColor(grid, const GridCell(0, 5)), isEmpty);
    });
  });

  group('MatchFinder.findFloating', () {
    test('a fully attached board has no floating bubbles', () {
      final grid = gridFromRows(9, ['R B G Y', ' P O B', 'G . R']);
      expect(MatchFinder.findFloating(grid), isEmpty);
    });

    test('bubbles cut off from the ceiling float, regardless of color', () {
      final grid = gridFromRows(9, [
        'B . . . R R . . .',
        '. . . . G . . .',
        '. . . . Y . . . .',
      ]);
      // Remove the R anchors: G and Y lose their connection to the ceiling.
      grid.remove(0, 4);
      grid.remove(0, 5);
      expect(MatchFinder.findFloating(grid).toSet(), {const GridCell(1, 4), const GridCell(2, 4)});
    });

    test('bubbles connected to the ceiling through other colors stay', () {
      final grid = gridFromRows(9, [
        'B . . . . . . . .',
        'G . . . . . . .',
        'R Y . . . . . . .',
      ]);
      expect(MatchFinder.findFloating(grid), isEmpty);
      grid.remove(1, 0);
      expect(MatchFinder.findFloating(grid).toSet(), {const GridCell(2, 0), const GridCell(2, 1)});
    });
  });
}
