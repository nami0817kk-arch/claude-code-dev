/// 監督としての生涯成長(通算実績の積み重ねによる長期的なやり込み要素)。
/// セーブデータをまたいでも消えない通算成績・トロフィー・実績解除数から
/// 監督経験値(XP)とレベルを算出し、レベルに応じてわずかな永続ボーナスを与える。
class ManagerCareerEngine {
  static const int maxLevel = 20;

  /// 通算実績から監督経験値を算出する。
  static int xpFor({
    required int careerWins,
    required int careerDraws,
    required int trophyCount,
    required int unlockedAchievementCount,
  }) =>
      careerWins * 3 +
      careerDraws * 1 +
      trophyCount * 50 +
      unlockedAchievementCount * 20;

  /// 経験値から監督レベル(1〜[maxLevel])を算出する。レベルが上がるほど
  /// 次のレベルに必要な経験値も増えていく。
  static int levelFor(int xp) {
    var level = 1;
    var required = 0;
    while (level < maxLevel && xp >= required + level * 100) {
      required += level * 100;
      level++;
    }
    return level;
  }

  /// 次のレベルまでに必要な残り経験値(最大レベルの場合は0)。
  static int xpToNextLevel(int xp) {
    final level = levelFor(xp);
    if (level >= maxLevel) return 0;
    var required = 0;
    for (var l = 1; l < level; l++) {
      required += l * 100;
    }
    return required + level * 100 - xp;
  }

  /// 監督レベルに応じた選手成長効率の永続ボーナス倍率(1.0でボーナスなし、
  /// 最大レベルで+19%)。
  static double growthBonusFor(int level) => 1.0 + (level - 1) * 0.01;

  /// 現在のレベル内での経験値の進捗割合(0.0〜1.0)。最大レベルなら1.0。
  static double progressFractionFor(int xp) {
    final level = levelFor(xp);
    if (level >= maxLevel) return 1.0;
    var requiredForLevel = 0;
    for (var l = 1; l < level; l++) {
      requiredForLevel += l * 100;
    }
    final xpIntoLevel = xp - requiredForLevel;
    final xpNeededForLevel = level * 100;
    return (xpIntoLevel / xpNeededForLevel).clamp(0.0, 1.0);
  }
}
