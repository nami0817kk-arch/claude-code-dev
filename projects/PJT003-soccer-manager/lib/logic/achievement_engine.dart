import '../models/achievement.dart';
import '../models/club_infrastructure.dart';
import '../models/save_game.dart';
import '../models/season_record.dart';
import '../models/team.dart';
import '../l10n/tr.dart';

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

/// 実績の全定義とその判定ロジック。基本はセーブデータの既存状態のみから
/// 判定できるものに絞る。値切り成立数・才能開花数など一部の実績は
/// [SaveGame]の通算カウンター(fromJsonで`?? 0`により補完される後方互換な
/// フィールド)を参照するため、既存プレイのセーブでもロードは壊れず、
/// カウンター系実績はその時点から積み上げが始まる。
class AchievementEngine {
  static final List<Achievement> all = [
    // --- タイトル ---
    Achievement(
      id: 'first_title',
      category: AchievementCategory.title,
      name: Tr.pick('初優勝', 'First Title'),
      description: Tr.pick('リーグ優勝を果たす', 'Win the league'),
      isUnlocked: (save, team) => save.seasonHistory.any((r) => r.wonLeague),
    ),
    Achievement(
      id: 'back_to_back',
      category: AchievementCategory.title,
      name: Tr.pick('連覇', 'Back to Back'),
      description:
          Tr.pick('2シーズン連続でリーグ優勝を果たす', 'Win the league two seasons running'),
      isUnlocked: (save, team) =>
          _anyConsecutivePair(save, (a, b) => a.wonLeague && b.wonLeague),
    ),
    Achievement(
      id: 'unbeaten_champion',
      category: AchievementCategory.title,
      name: Tr.pick('無敗優勝', 'Invincible'),
      description: Tr.pick(
          '一度も負けることなくリーグ優勝を果たす', 'Win the league without losing a match'),
      isUnlocked: (save, team) =>
          save.seasonHistory.any((r) => r.wonLeague && r.lost == 0),
    ),
    Achievement(
      id: 'cup_winner',
      category: AchievementCategory.title,
      name: Tr.pick('カップ制覇', 'Cup Winners'),
      description: Tr.pick('国内カップ・大陸カップのいずれかで優勝する',
          'Win either the domestic or the continental cup'),
      isUnlocked: (save, team) =>
          save.seasonHistory.any((r) => r.cupsWon.isNotEmpty),
    ),
    Achievement(
      id: 'double',
      category: AchievementCategory.title,
      name: Tr.pick('二冠達成', 'The Double'),
      description: Tr.pick('同一シーズンでリーグ優勝とカップ制覇を同時に果たす',
          'Win the league and a cup in the same season'),
      isUnlocked: (save, team) =>
          save.seasonHistory.any((r) => r.wonLeague && r.cupsWon.isNotEmpty),
    ),
    Achievement(
      id: 'five_titles',
      category: AchievementCategory.title,
      name: Tr.pick('常勝軍団', 'Serial Winners'),
      description:
          Tr.pick('通算タイトル(リーグ優勝+カップ優勝)を5回獲得する', 'Win five trophies in total'),
      isUnlocked: (save, team) =>
          save.seasonHistory.fold<int>(
            0,
            (s, r) => s + (r.wonLeague ? 1 : 0) + r.cupsWon.length,
          ) >=
          5,
      progress: (save, team) => (
        save.seasonHistory.fold<int>(
          0,
          (s, r) => s + (r.wonLeague ? 1 : 0) + r.cupsWon.length,
        ),
        5
      ),
    ),

    // --- 通算記録 ---
    Achievement(
      id: 'wins_50',
      category: AchievementCategory.record,
      name: Tr.pick('通算50勝', '50 Wins'),
      description: Tr.pick('監督として通算50勝を挙げる', 'Reach 50 wins as a manager'),
      isUnlocked: (save, team) => save.careerWins >= 50,
      progress: (save, team) => (save.careerWins, 50),
    ),
    Achievement(
      id: 'wins_100',
      category: AchievementCategory.record,
      name: Tr.pick('通算100勝', '100 Wins'),
      description: Tr.pick('監督として通算100勝を挙げる', 'Reach 100 wins as a manager'),
      isUnlocked: (save, team) => save.careerWins >= 100,
      progress: (save, team) => (save.careerWins, 100),
    ),
    Achievement(
      id: 'wins_200',
      category: AchievementCategory.record,
      name: Tr.pick('通算200勝', '200 Wins'),
      description: Tr.pick('監督として通算200勝を挙げる', 'Reach 200 wins as a manager'),
      isUnlocked: (save, team) => save.careerWins >= 200,
      progress: (save, team) => (save.careerWins, 200),
    ),
    Achievement(
      id: 'seasons_5',
      category: AchievementCategory.record,
      name: Tr.pick('監督歴5シーズン', 'Five Seasons'),
      description:
          Tr.pick('同一クラブで5シーズンを指揮する', 'Manage the same club for five seasons'),
      isUnlocked: (save, team) => save.careerSeasons >= 5,
      progress: (save, team) => (save.careerSeasons, 5),
    ),
    Achievement(
      id: 'seasons_10',
      category: AchievementCategory.record,
      name: Tr.pick('監督歴10シーズン', 'Ten Seasons'),
      description:
          Tr.pick('同一クラブで10シーズンを指揮する', 'Manage the same club for ten seasons'),
      isUnlocked: (save, team) => save.careerSeasons >= 10,
      progress: (save, team) => (save.careerSeasons, 10),
    ),
    Achievement(
      id: 'win_rate_60',
      category: AchievementCategory.record,
      name: Tr.pick('高勝率監督', 'A Winning Record'),
      description: Tr.pick('通算20試合以上を指揮し、勝率60%以上を記録する',
          'Manage 20 or more matches at a win rate of 60% or better'),
      isUnlocked: (save, team) {
        final total = save.careerWins + save.careerDraws + save.careerLosses;
        return total >= 20 && save.careerWins / total >= 0.6;
      },
    ),

    // --- クラブ経営 ---
    Achievement(
      id: 'promoted',
      category: AchievementCategory.management,
      name: Tr.pick('昇格達成', 'Promoted'),
      description: Tr.pick(
          '下位ディビジョンから上位ディビジョンへの昇格を果たす', 'Win promotion to a higher division'),
      isUnlocked: (save, team) => save.seasonHistory.any((r) => r.promoted),
    ),
    Achievement(
      id: 'bounce_back',
      category: AchievementCategory.management,
      name: Tr.pick('即時昇格', 'Straight Back Up'),
      description: Tr.pick('降格した翌シーズンに即座に昇格を果たす',
          'Go up again the season after being relegated'),
      isUnlocked: (save, team) =>
          _anyConsecutivePair(save, (a, b) => a.relegated && b.promoted),
    ),
    Achievement(
      id: 'rich_club',
      category: AchievementCategory.management,
      name: Tr.pick('潤沢な資金', 'Deep Pockets'),
      description:
          Tr.pick('クラブ資金が3万(万円)に到達する', "Build the club's funds up to 30,000"),
      isUnlocked: (save, team) => save.budget >= 30000,
      progress: (save, team) => (save.budget, 30000),
    ),
    Achievement(
      id: 'facilities_maxed',
      category: AchievementCategory.management,
      name: Tr.pick('施設完成', 'Everything Built'),
      description: Tr.pick(
          '全ての施設をレベルMAXまで強化する', 'Upgrade every facility to its maximum'),
      isUnlocked: (save, team) => save.infrastructure.facilityLevels.values
          .every((v) => v >= ClubInfrastructure.maxLevel),
    ),
    Achievement(
      id: 'staff_maxed',
      category: AchievementCategory.management,
      name: Tr.pick('最強スタッフ陣', 'The Best Backroom'),
      description: Tr.pick('全てのスタッフをレベルMAXまで強化する',
          'Upgrade every member of staff to their maximum'),
      isUnlocked: (save, team) => save.infrastructure.staffLevels.values.every(
        (v) => v >= ClubInfrastructure.maxLevel,
      ),
    ),
    Achievement(
      id: 'trusted_manager',
      category: AchievementCategory.management,
      name: Tr.pick('理事会からの絶大な信頼', "The Board's Trust"),
      description: Tr.pick('理事会の信頼度が90に到達する', 'Reach 90 board confidence'),
      isUnlocked: (save, team) => save.confidence >= 90,
      progress: (save, team) => (save.confidence, 90),
    ),
    Achievement(
      id: 'bargain_hunter',
      category: AchievementCategory.management,
      name: Tr.pick('腕利きの交渉人', 'Shrewd Negotiator'),
      description: Tr.pick('値切り交渉(市場価値未満のオファー)での獲得を成立させる',
          'Sign a player for less than his value by haggling'),
      isUnlocked: (save, team) => save.negotiationSignings >= 1,
      progress: (save, team) => (save.negotiationSignings, 1),
    ),
    Achievement(
      id: 'cup_prize_1000',
      category: AchievementCategory.management,
      name: Tr.pick('賞金ハンター', 'Prize Hunter'),
      description:
          Tr.pick('カップ戦の賞金を通算1000万円獲得する', 'Collect 1,000 in cup prize money'),
      isUnlocked: (save, team) => save.careerCupPrize >= 1000,
      progress: (save, team) => (save.careerCupPrize, 1000),
    ),

    // --- 選手・育成 ---
    Achievement(
      id: 'superstar_player',
      category: AchievementCategory.squad,
      name: Tr.pick('スター選手誕生', 'A Star Is Born'),
      description:
          Tr.pick('総合力90以上の選手を保有する', 'Have a player rated 90 or above'),
      isUnlocked: (save, team) => team.players.any((p) => p.overall >= 90),
    ),
    Achievement(
      id: 'deep_squad',
      category: AchievementCategory.squad,
      name: Tr.pick('分厚い戦力', 'Strength in Depth'),
      description: Tr.pick(
          '総合力80以上の選手を5人以上保有する', 'Have five or more players rated 80 or above'),
      isUnlocked: (save, team) =>
          team.players.where((p) => p.overall >= 80).length >= 5,
      progress: (save, team) =>
          (team.players.where((p) => p.overall >= 80).length, 5),
    ),
    Achievement(
      id: 'best_eleven_selection',
      category: AchievementCategory.squad,
      name: Tr.pick('ベストイレブン選出', 'Team of the Season'),
      description: Tr.pick('自クラブの選手がシーズンベストイレブンに選ばれる',
          'Get one of your players into the team of the season'),
      isUnlocked: (save, team) => save.bestElevenHistory.any(
        (h) => h.entries.any((e) => e.teamId == save.userTeamId),
      ),
    ),
    Achievement(
      id: 'hall_of_fame',
      category: AchievementCategory.squad,
      name: Tr.pick('初の殿堂入り', 'First of the Greats'),
      description: Tr.pick(
          '選手を1人殿堂入り(引退)させる', 'See one of your players into the hall of fame'),
      isUnlocked: (save, team) => save.retiredLegends.isNotEmpty,
      progress: (save, team) => (save.retiredLegends.length, 1),
    ),
    Achievement(
      id: 'legend_collector',
      category: AchievementCategory.squad,
      name: Tr.pick('レジェンドの系譜', 'A Line of Legends'),
      description:
          Tr.pick('5人の選手を殿堂入りさせる', 'See five players into the hall of fame'),
      isUnlocked: (save, team) => save.retiredLegends.length >= 5,
      progress: (save, team) => (save.retiredLegends.length, 5),
    ),
    Achievement(
      id: 'breakthrough_10',
      category: AchievementCategory.squad,
      name: Tr.pick('才能の開花請負人', 'Bringer of Breakthroughs'),
      description: Tr.pick('週次トレーニングで才能開花を通算10回発生させる',
          'Trigger ten breakthroughs in weekly training'),
      isUnlocked: (save, team) => save.breakthroughCount >= 10,
      progress: (save, team) => (save.breakthroughCount, 10),
    ),
    Achievement(
      id: 'trait_teacher',
      category: AchievementCategory.squad,
      name: Tr.pick('特性の伝道師', 'Teacher of Traits'),
      description: Tr.pick('特訓・伝授で選手に特性を通算3回習得させる',
          'Have players pick up three traits through training or mentoring'),
      isUnlocked: (save, team) => save.traitsAcquired >= 3,
      progress: (save, team) => (save.traitsAcquired, 3),
    ),

    // --- 監督キャリア ---
    Achievement(
      id: 'veteran_manager',
      category: AchievementCategory.career,
      name: Tr.pick('百戦錬磨', 'Battle Hardened'),
      description: Tr.pick(
          '同一クラブで15シーズンを指揮する', 'Manage the same club for fifteen seasons'),
      isUnlocked: (save, team) => save.careerSeasons >= 15,
      progress: (save, team) => (save.careerSeasons, 15),
    ),
    Achievement(
      id: 'reputation_elite',
      category: AchievementCategory.career,
      name: Tr.pick('世界的名将', 'World Renowned'),
      description: Tr.pick('世間の評価が90に到達する', 'Reach a reputation of 90'),
      isUnlocked: (save, team) => save.managerReputation >= 90,
      progress: (save, team) => (save.managerReputation, 90),
    ),
    Achievement(
      id: 'live_wins_10',
      category: AchievementCategory.career,
      name: Tr.pick('采配の妙', 'Master of the Touchline'),
      description: Tr.pick('ライブ観戦(決定機の判断あり)で通算10勝する',
          'Win ten matches watching live and calling the big chances'),
      isUnlocked: (save, team) => save.liveWins >= 10,
      progress: (save, team) => (save.liveWins, 10),
    ),
    Achievement(
      id: 'shootout_winner',
      category: AchievementCategory.career,
      name: Tr.pick('PK戦を制す', 'Nerves of Steel'),
      description: Tr.pick(
          'ライブ観戦のカップ戦でPK戦を制する', 'Win a cup shootout while watching live'),
      isUnlocked: (save, team) => save.pkShootoutWins >= 1,
      progress: (save, team) => (save.pkShootoutWins, 1),
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
