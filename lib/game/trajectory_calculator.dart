import 'dart:ui' show Offset;

import 'bubble.dart';
import 'bubble_grid.dart';
import 'collision_detector.dart';

class TrajectoryResult {
  const TrajectoryResult({required this.points, required this.landingCell});

  /// Polyline: start point, each wall bounce point, and the end point.
  final List<Offset> points;

  /// Where the bubble would snap, or null if the preview was cut short
  /// (too many bounces).
  final GridCell? landingCell;

  int get bounceCount => points.length - 2;
}

/// Predicts the path of a shot using the same physics as the real bubble.
class TrajectoryCalculator {
  const TrajectoryCalculator({
    this.maxBounces = 3,
    this.maxLength = 250,
    this.stepLength = 0.5,
  });

  final int maxBounces;
  final double maxLength;
  final double stepLength;

  TrajectoryResult compute(
    BubbleGrid grid,
    CollisionDetector detector,
    Offset start,
    Offset direction,
  ) {
    final points = <Offset>[start];
    var bounces = 0;
    var pos = start;
    var dir = direction;
    var travelled = 0.0;

    while (travelled < maxLength) {
      var cut = false;
      final result = detector.move(grid, pos, dir, stepLength, onBounce: (p) {
        if (cut) return;
        points.add(p);
        bounces++;
        if (bounces > maxBounces) cut = true;
      });
      if (cut) {
        return TrajectoryResult(points: points, landingCell: null);
      }
      pos = result.position;
      dir = result.direction;
      travelled += stepLength;
      if (result.stopped) {
        points.add(pos);
        return TrajectoryResult(
          points: points,
          landingCell: detector.findSnapCell(grid, pos),
        );
      }
    }
    points.add(pos);
    return TrajectoryResult(points: points, landingCell: null);
  }
}
