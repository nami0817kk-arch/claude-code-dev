import '../models/league.dart';
import '../models/team.dart';
import 'background_match_engine.dart';
import 'cup_engine.dart';
import 'fixture_generator.dart';
import 'match_engine.dart';

/// 昇格プレーオフの1試合(準決勝または決勝)の結果。
class PromotionPlayoffMatch {
  final String roundLabel;
  final String homeId;
  final String homeName;
  final String awayId;
  final String awayName;
  final int homeGoals;
  final int awayGoals;
  final bool decidedByPenalties;
  final String winnerId;

  const PromotionPlayoffMatch({
    required this.roundLabel,
    required this.homeId,
    required this.homeName,
    required this.awayId,
    required this.awayName,
    required this.homeGoals,
    required this.awayGoals,
    required this.decidedByPenalties,
    required this.winnerId,
  });

  String get winnerName => winnerId == homeId ? homeName : awayName;
}

/// シーズン終了時の昇格・降格を解決した結果。
class PromotionResult {
  final List<Team> tier1;
  final List<Team> tier2;
  final List<String> promotedTeamNames;
  final List<String> relegatedTeamNames;

  /// 昇格プレーオフが行われた場合の各試合結果(準決勝2試合+決勝の順)。
  /// プレーオフが発生しなかった場合(下部リーグの参加数が少ない場合など)は空。
  final List<PromotionPlayoffMatch> promotionPlayoff;

  const PromotionResult({
    required this.tier1,
    required this.tier2,
    required this.promotedTeamNames,
    required this.relegatedTeamNames,
    this.promotionPlayoff = const [],
  });
}

/// 1部・2部の入れ替え(昇格/降格)を解決する。
///
/// ユーザーが所属しない側のディビジョンは週次で試合を進行させないため、シーズン
/// 終了時にその場で1シーズン分をまとめてシミュレートし、最終順位を確定する。
class PromotionEngine {
  static const int swapCount = 3;

  /// 2部の最終順位のうち、自動昇格となる上位チーム数。
  static const int automaticPromotionCount = 2;

  /// 昇格プレーオフに進出するチーム数(3位〜(2+playoffPoolSize)位)。
  static const int playoffPoolSize = 4;

  /// [teams]で1シーズン分(ホーム&アウェイ総当たり)を即座にシミュレートし、
  /// 最終順位順に並べ替えて返す。呼び出し側([tier1PlayedOrder]/
  /// [tier2PlayedOrder]が渡されない場合のフォールバック)でしか使わないため、
  /// 大量の試合を一括処理してもUIが固まらないよう軽量エンジンを使う。
  static List<Team> _simulateSeason(List<Team> teams) {
    final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
    for (final f in fixtures) {
      final home = teams.firstWhere((t) => t.id == f.homeTeamId);
      final away = teams.firstWhere((t) => t.id == f.awayTeamId);
      f.result = BackgroundMatchEngine.simulate(
          home: home, away: away, matchday: f.matchday);
    }
    final standings = League(teams: teams, fixtures: fixtures).sortedStandings;
    return standings
        .map((row) => teams.firstWhere((t) => t.id == row.teamId))
        .toList();
  }

  /// 昇格プレーオフの1試合を決着させる(引き分けの場合はPK戦)。
  static PromotionPlayoffMatch _playSingleMatch({
    required String roundLabel,
    required Team home,
    required Team away,
  }) {
    final result = MatchEngine.simulate(home: home, away: away, matchday: 0);
    final decidedByPenalties = result.homeGoals == result.awayGoals;
    final winnerId = result.homeGoals > result.awayGoals
        ? home.id
        : result.homeGoals < result.awayGoals
            ? away.id
            : CupEngine.decidePenaltyWinner(home, away);
    return PromotionPlayoffMatch(
      roundLabel: roundLabel,
      homeId: home.id,
      homeName: home.name,
      awayId: away.id,
      awayName: away.name,
      homeGoals: result.homeGoals,
      awayGoals: result.awayGoals,
      decidedByPenalties: decidedByPenalties,
      winnerId: winnerId,
    );
  }

  /// [tier1Teams]/[tier2Teams]は今シーズンの各ディビジョンの全チーム。実際に
  /// プレイされた側は[tier1PlayedOrder]/[tier2PlayedOrder]に最終順位順のチーム
  /// リストを渡す(片方のみ非null)。渡されなかった側はその場でシミュレートする。
  ///
  /// 2部の昇格は上位2チームが自動昇格し、3位〜6位の4チームが昇格プレーオフ
  /// (準決勝2試合+決勝、引き分けはPK戦)を行い、その勝者が3枠目の昇格を得る。
  static PromotionResult resolve({
    required List<Team> tier1Teams,
    required List<Team> tier2Teams,
    List<Team>? tier1PlayedOrder,
    List<Team>? tier2PlayedOrder,
  }) {
    final orderedTier1 = tier1PlayedOrder ?? _simulateSeason(tier1Teams);
    final orderedTier2 = tier2PlayedOrder ?? _simulateSeason(tier2Teams);

    final relegated = orderedTier1.sublist(orderedTier1.length - swapCount);
    final remainingTier1 =
        orderedTier1.take(orderedTier1.length - swapCount).toList();

    List<Team> promoted;
    List<Team> tier2Remainder;
    List<PromotionPlayoffMatch> playoffMatches = const [];

    if (orderedTier2.length >= automaticPromotionCount + playoffPoolSize) {
      final autoPromoted = orderedTier2.take(automaticPromotionCount).toList();
      final pool = orderedTier2
          .skip(automaticPromotionCount)
          .take(playoffPoolSize)
          .toList();

      final semiA = _playSingleMatch(
          roundLabel: '昇格プレーオフ 準決勝', home: pool[0], away: pool[3]);
      final semiB = _playSingleMatch(
          roundLabel: '昇格プレーオフ 準決勝', home: pool[1], away: pool[2]);
      final finalHome = pool.firstWhere((t) => t.id == semiA.winnerId);
      final finalAway = pool.firstWhere((t) => t.id == semiB.winnerId);
      final finalMatch = _playSingleMatch(
          roundLabel: '昇格プレーオフ 決勝', home: finalHome, away: finalAway);
      playoffMatches = [semiA, semiB, finalMatch];

      final playoffWinner =
          orderedTier2.firstWhere((t) => t.id == finalMatch.winnerId);
      promoted = [...autoPromoted, playoffWinner];
      tier2Remainder = orderedTier2
          .where((t) => !promoted.any((p) => p.id == t.id))
          .toList();
    } else {
      promoted = orderedTier2.take(swapCount).toList();
      tier2Remainder = orderedTier2.skip(swapCount).toList();
    }

    final newTier1 = [...remainingTier1, ...promoted];
    final newTier2 = [...tier2Remainder, ...relegated];

    return PromotionResult(
      tier1: newTier1,
      tier2: newTier2,
      promotedTeamNames: promoted.map((t) => t.name).toList(),
      relegatedTeamNames: relegated.map((t) => t.name).toList(),
      promotionPlayoff: playoffMatches,
    );
  }
}
