/// Score rules.
class ScoreRules {
  const ScoreRules._();

  static const int popPoints = 10;
  static const int dropPoints = 20;

  /// Extra points per popped bubble beyond the minimum group of 3.
  static const int comboBonusPerBubble = 10;

  /// Dropping this many bubbles at once doubles the drop points.
  static const int bigDropThreshold = 5;

  /// Highest streak multiplier.
  static const int maxMultiplier = 5;

  /// Every this many consecutive matches awards a rainbow bubble.
  static const int rainbowStreak = 3;

  static int forMatch({required int popped, required int dropped}) {
    if (popped <= 0) return 0;
    final combo = popped > 3 ? (popped - 3) * comboBonusPerBubble : 0;
    final dropMultiplier = dropped >= bigDropThreshold ? 2 : 1;
    return popped * popPoints + combo + dropped * dropPoints * dropMultiplier;
  }

  /// Multiplier for the [streak]-th consecutive matching shot (1, 2, ... 5).
  static int multiplierFor(int streak) => streak.clamp(1, maxMultiplier);

  static int levelClearBonus(int level) => 500 + (level - 1) * 250;

  /// Praise for a single shot, or null when it was ordinary.
  static String? praiseFor({required int popped, required int dropped}) {
    final total = popped + dropped;
    if (total >= 22) return 'INCREDIBLE!';
    if (dropped >= 8) return 'AVALANCHE!';
    if (total >= 15) return 'AMAZING!';
    if (total >= 10) return 'AWESOME!';
    if (total >= 6) return 'GREAT!';
    return null;
  }
}
