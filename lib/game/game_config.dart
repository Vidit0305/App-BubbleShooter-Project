/// Gameplay tuning in one place. Distances are in world units (bubble
/// radius = 1), times in seconds.
class GameConfig {
  const GameConfig._();

  /// Unsuccessful shots before a new row is pushed in.
  static const int shotsPerRow = 5;

  /// Speed of a fired bubble.
  static const double bubbleSpeed = 46;

  /// Speed of the grid sliding down when a row is added.
  static const double rowSlideSpeed = 10;

  /// Time for a new board to slide in at the start of a level.
  static const double levelIntroDuration = 0.55;

  /// Pause on the LEVEL CLEARED banner before the next board.
  static const double levelClearDelay = 2.0;

  /// Longest simulated frame; slower frames are clamped.
  static const double maxFrameStep = 1 / 20;

  /// Starting rows: [baseRows] + level, at most [maxStartRows], and always
  /// leaving [safetyRows] free above the danger line (minimum [minStartRows]).
  static const int baseRows = 6;
  static const int maxStartRows = 9;
  static const int safetyRows = 4;
  static const int minStartRows = 3;

  /// Chance that a generated bubble copies a neighbor's color (clusters make
  /// boards friendlier); it drops each level down to [minClusterChance].
  static const double clusterChance = 0.5;
  static const double clusterChanceStep = 0.07;
  static const double minClusterChance = 0.15;

  /// Rows above the danger line that count as "near danger" (warning).
  static const int dangerWarningRows = 2;
}
