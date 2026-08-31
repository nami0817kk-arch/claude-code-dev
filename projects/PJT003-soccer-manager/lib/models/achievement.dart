import 'save_game.dart';
import 'team.dart';
import '../l10n/tr.dart';

/// 実績のジャンル分け。実績画面での表示グルーピングに使う。
enum AchievementCategory { title, record, management, squad, career }

extension AchievementCategoryInfo on AchievementCategory {
  String get label => switch (this) {
        AchievementCategory.title => Tr.pick('タイトル', 'Trophies'),
        AchievementCategory.record => Tr.pick('通算記録', 'Career Records'),
        AchievementCategory.management => Tr.pick('クラブ経営', 'Club Management'),
        AchievementCategory.squad => Tr.pick('選手・育成', 'Players & Development'),
        AchievementCategory.career => Tr.pick('監督キャリア', 'Managerial Career'),
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

  /// 閾値型の実績の進捗(現在値, 目標値)。実績画面が未達成カードに
  /// プログレスバーを表示するために使う。単純な数値の積み上げで表現
  /// できない実績(連覇・無敗優勝など)はnullのままにする。
  final (int current, int target) Function(SaveGame save, Team userTeam)?
      progress;

  const Achievement({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.isUnlocked,
    this.progress,
  });
}
