import '../models/achievement.dart';
import '../models/club_infrastructure.dart';
import '../models/save_game.dart';
import '../models/season_record.dart';
import '../models/team.dart';

/// シーズン成績アーカイブの中で、隣り合う2シーズンの組み合わせが条件を
/// 満たすかどうかを調べる(連覇・降格からの即時昇格など)。
bool _anyConsecutivePair(
  SaveGame save,
  bool Function(SeasonRecord a, SeasonRecord b) test,
) {
  final history = save.seasonHistory;
  for (var i = 0; i < history.length - 1; i++) {
    if (test(history[i], history[i + 1])) return true;
  }
  return false;
}

/// 実績の全定義とその判定ロジック。既存のセーブデータの状態のみから
/// 判定できるものに絞り、実績専用の新しい進捗トラッキングは追加しない
/// (セーブ互換性を壊さず、既存プレイのセーブでも過去の記録から即座に
/// 実績が解除されるようにするため)。
class AchievementEngine {
  static final List<Achievement> all = [
    // --- タイトル ---
    Achievement(
      id: 'first_title',
      category: AchievementCategory.title,
      name: '初優勝',
      description: 'リーグ優勝を果たす',
      isUnlocked: (save, team) => save.seasonHistory.any((r) => r.wonLeague),
    ),
    Achievement(
      id: 'back_to_back',
      category: AchievementCategory.title,
      name: '連覇',
      description: '2シーズン連続でリーグ優勝を果たす',
      isUnlocked: (save, team) =>
          _anyConsecutivePair(save, (a, b) => a.wonLeague && b.wonLeague),
    ),
    Achievement(
      id: 'unbeaten_champion',
      category: AchievementCategory.title,
      name: '無敗優勝',
      description: '一度も負けることなくリーグ優勝を果たす',
      isUnlocked: (save, team) =>
          save.seasonHistory.any((r) => r.wonLeague && r.lost == 0),
    ),
    Achievement(
      id: 'cup_winner',
      category: AchievementCategory.title,
      name: 'カップ制覇',
      description: '国内カップ・大陸カップのいずれかで優勝する',
      isUnlocked: (save, team) =>
          save.seasonHistory.any((r) => r.cupsWon.isNotEmpty),
    ),
    Achievement(
      id: 'double',
      category: AchievementCategory.title,
      name: '二冠達成',
      description: '同一シーズンでリーグ優勝とカップ制覇を同時に果たす',
      isUnlocked: (save, team) =>
          save.seasonHistory.any((r) => r.wonLeague && r.cupsWon.isNotEmpty),
    ),
    Achievement(
      id: 'five_titles',
      category: AchievementCategory.title,
      name: '常勝軍団',
      description: '通算タイトル(リーグ優勝+カップ優勝)を5回獲得する',
      isUnlocked: (save, team) =>
          save.seasonHistory.fold<int>(
              0, (s, r) => s + (r.wonLeague ? 1 : 0) + r.cupsWon.length) >=
          5,
    ),

    // --- 通算記録 ---
    Achievement(
      id: 'wins_50',
      category: AchievementCategory.record,
      name: '通算50勝',
      description: '監督として通算50勝を挙げる',
      isUnlocked: (save, team) => save.careerWins >= 50,
    ),
    Achievement(
      id: 'wins_100',
      category: AchievementCategory.record,
      name: '通算100勝',
      description: '監督として通算100勝を挙げる',
      isUnlocked: (save, team) => save.careerWins >= 100,
    ),
    Achievement(
      id: 'wins_200',
      category: AchievementCategory.record,
      name: '通算200勝',
      description: '監督として通算200勝を挙げる',
      isUnlocked: (save, team) => save.careerWins >= 200,
    ),
    Achievement(
      id: 'seasons_5',
      category: AchievementCategory.record,
      name: '監督歴5シーズン',
      description: '同一クラブで5シーズンを指揮する',
      isUnlocked: (save, team) => save.careerSeasons >= 5,
    ),
    Achievement(
      id: 'seasons_10',
      category: AchievementCategory.record,
      name: '監督歴10シーズン',
      description: '同一クラブで10シーズンを指揮する',
      isUnlocked: (save, team) => save.careerSeasons >= 10,
    ),
    Achievement(
      id: 'win_rate_60',
      category: AchievementCategory.record,
      name: '高勝率監督',
      description: '通算20試合以上を指揮し、勝率60%以上を記録する',
      isUnlocked: (save, team) {
        final total = save.careerWins + save.careerDraws + save.careerLosses;
        return total >= 20 && save.careerWins / total >= 0.6;
      },
    ),

    // --- クラブ経営 ---
    Achievement(
      id: 'promoted',
      category: AchievementCategory.management,
      name: '昇格達成',
      description: '下位ディビジョンから上位ディビジョンへの昇格を果たす',
      isUnlocked: (save, team) => save.seasonHistory.any((r) => r.promoted),
    ),
    Achievement(
      id: 'bounce_back',
      category: AchievementCategory.management,
      name: '即時昇格',
      description: '降格した翌シーズンに即座に昇格を果たす',
      isUnlocked: (save, team) =>
          _anyConsecutivePair(save, (a, b) => a.relegated && b.promoted),
    ),
    Achievement(
      id: 'rich_club',
      category: AchievementCategory.management,
      name: '潤沢な資金',
      description: 'クラブ資金が3万(万円)に到達する',
      isUnlocked: (save, team) => save.budget >= 30000,
    ),
    Achievement(
      id: 'facilities_maxed',
      category: AchievementCategory.management,
      name: '施設完成',
      description: '全ての施設をレベルMAXまで強化する',
      isUnlocked: (save, team) => save.infrastructure.facilityLevels.values
          .every((v) => v >= ClubInfrastructure.maxLevel),
    ),
    Achievement(
      id: 'staff_maxed',
      category: AchievementCategory.management,
      name: '最強スタッフ陣',
      description: '全てのスタッフをレベルMAXまで強化する',
      isUnlocked: (save, team) => save.infrastructure.staffLevels.values
          .every((v) => v >= ClubInfrastructure.maxLevel),
    ),
    Achievement(
      id: 'trusted_manager',
      category: AchievementCategory.management,
      name: '理事会からの絶大な信頼',
      description: '理事会の信頼度が90に到達する',
      isUnlocked: (save, team) => save.confidence >= 90,
    ),

    // --- 選手・育成 ---
    Achievement(
      id: 'superstar_player',
      category: AchievementCategory.squad,
      name: 'スター選手誕生',
      description: '総合力90以上の選手を保有する',
      isUnlocked: (save, team) => team.players.any((p) => p.overall >= 90),
    ),
    Achievement(
      id: 'deep_squad',
      category: AchievementCategory.squad,
      name: '分厚い戦力',
      description: '総合力80以上の選手を5人以上保有する',
      isUnlocked: (save, team) =>
          team.players.where((p) => p.overall >= 80).length >= 5,
    ),
    Achievement(
      id: 'best_eleven_selection',
      category: AchievementCategory.squad,
      name: 'ベストイレブン選出',
      description: '自クラブの選手がシーズンベストイレブンに選ばれる',
      isUnlocked: (save, team) => save.bestElevenHistory
          .any((h) => h.entries.any((e) => e.teamId == save.userTeamId)),
    ),
    Achievement(
      id: 'hall_of_fame',
      category: AchievementCategory.squad,
      name: '初の殿堂入り',
      description: '選手を1人殿堂入り(引退)させる',
      isUnlocked: (save, team) => save.retiredLegends.isNotEmpty,
    ),
    Achievement(
      id: 'legend_collector',
      category: AchievementCategory.squad,
      name: 'レジェンドの系譜',
      description: '5人の選手を殿堂入りさせる',
      isUnlocked: (save, team) => save.retiredLegends.length >= 5,
    ),

    // --- 監督キャリア ---
    Achievement(
      id: 'veteran_manager',
      category: AchievementCategory.career,
      name: '百戦錬磨',
      description: '同一クラブで15シーズンを指揮する',
      isUnlocked: (save, team) => save.careerSeasons >= 15,
    ),
    Achievement(
      id: 'reputation_elite',
      category: AchievementCategory.career,
      name: '世界的名将',
      description: '世間の評価が90に到達する',
      isUnlocked: (save, team) => save.managerReputation >= 90,
    ),
  ];

  /// まだ未達成の実績のうち、現在のセーブデータの状態で新たに条件を
  /// 満たしたものを返す。達成済みIDの記録・通知はGameState側で行う。
  static List<Achievement> evaluate(SaveGame save, Team userTeam) {
    return all
        .where((a) => !save.unlockedAchievements.containsKey(a.id))
        .where((a) => a.isUnlocked(save, userTeam))
        .toList();
  }
}
