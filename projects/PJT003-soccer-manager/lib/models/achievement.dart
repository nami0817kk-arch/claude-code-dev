import 'save_game.dart';
import 'team.dart';

/// 実績のジャンル分け。実績画面での表示グルーピングに使う。
enum AchievementCategory { title, record, management, squad, career }

extension AchievementCategoryInfo on AchievementCategory {
  String get label => switch (this) {
        AchievementCategory.title => 'タイトル',
        AchievementCategory.record => '通算記録',
        AchievementCategory.management => 'クラブ経営',
        AchievementCategory.squad => '選手・育成',
        AchievementCategory.career => '監督キャリア',
      };
}

/// 実績(アチーブメント)の定義。[isUnlocked]は現在のセーブデータの状態
/// から都度判定する純粋関数で、達成済みIDの保持・通知はGameState側が
/// 行う(この定義自体は状態を持たない)。
class Achievement {
  final String id;
  final AchievementCategory category;
  final String name;
  final String description;
  final bool Function(SaveGame save, Team userTeam) isUnlocked;

  const Achievement({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.isUnlocked,
  });
}
