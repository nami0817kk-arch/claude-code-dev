import '../models/match_result.dart';
import 'enum_json.dart';

/// カップ戦の不在(不戦勝)を表す仮想チームID。
const String byeTeamId = '__BYE__';

enum CupType { domestic, continental }

extension CupTypeInfo on CupType {
  String get label => switch (this) {
        CupType.domestic => '国内カップ',
        CupType.continental => '大陸カップ',
      };
}

class CupMatch {
  final int round;
  final String homeTeamId;
  final String awayTeamId;
  MatchResult? result;

  /// PK戦で決着した場合の勝者チームID(引き分け時のみ使用)。
  String? penaltyWinnerId;

  CupMatch({
    required this.round,
    required this.homeTeamId,
    required this.awayTeamId,
    this.result,
    this.penaltyWinnerId,
  });

  bool get isBye => homeTeamId == byeTeamId || awayTeamId == byeTeamId;

  String? get winnerId {
    if (result == null) return null;
    if (result!.homeGoals > result!.awayGoals) return homeTeamId;
    if (result!.homeGoals < result!.awayGoals) return awayTeamId;
    return penaltyWinnerId;
  }

  Map<String, dynamic> toJson() => {
        'round': round,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
        'result': result?.toJson(),
        'penaltyWinnerId': penaltyWinnerId,
      };

  factory CupMatch.fromJson(Map<String, dynamic> json) => CupMatch(
        round: json['round'] as int,
        homeTeamId: json['homeTeamId'] as String,
        awayTeamId: json['awayTeamId'] as String,
        result: json['result'] == null
            ? null
            : MatchResult.fromJson(json['result'] as Map<String, dynamic>),
        penaltyWinnerId: json['penaltyWinnerId'] as String?,
      );
}

class Cup {
  final CupType type;
  final String name;
  final List<List<CupMatch>> rounds;

  /// 優勝報酬(賞金・信頼度)を既に付与済みかどうか。二重付与を防ぐためのフラグ。
  bool rewardClaimed;

  /// 直近の試合を消化した時点でのリーグの節数(未消化ならnull)。
  /// 現実の試合間隔を再現するため、次の試合はリーグがこの節から
  /// 1節以上進むまで消化できないようにする。
  int? lastPlayedAtMatchday;

  Cup({
    required this.type,
    required this.name,
    required this.rounds,
    this.rewardClaimed = false,
    this.lastPlayedAtMatchday,
  });

  bool get isComplete =>
      rounds.isNotEmpty &&
      rounds.last.length == 1 &&
      rounds.last.first.winnerId != null;

  String? get championId => isComplete ? rounds.last.first.winnerId : null;

  int get currentRoundNumber => rounds.isEmpty ? 1 : rounds.last.first.round;

  CupMatch? get nextUnplayedMatch {
    for (final round in rounds) {
      for (final m in round) {
        if (m.result == null) return m;
      }
    }
    return null;
  }

  bool involvesTeam(String teamId) => rounds.any((round) =>
      round.any((m) => m.homeTeamId == teamId || m.awayTeamId == teamId));

  /// このカップにおけるチームの最終成績(敗退ラウンド、または優勝)。まだ参加/敗退していなければnull。
  bool isEliminated(String teamId) {
    for (final round in rounds) {
      for (final m in round) {
        if ((m.homeTeamId == teamId || m.awayTeamId == teamId) &&
            m.winnerId != null &&
            m.winnerId != teamId) {
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        'rounds': rounds.map((r) => r.map((m) => m.toJson()).toList()).toList(),
        'rewardClaimed': rewardClaimed,
        'lastPlayedAtMatchday': lastPlayedAtMatchday,
      };

  factory Cup.fromJson(Map<String, dynamic> json) => Cup(
        type: enumFromName(
            CupType.values, json['type'] as String?, CupType.domestic),
        name: json['name'] as String,
        rounds: (json['rounds'] as List)
            .map((r) => (r as List)
                .map((m) => CupMatch.fromJson(m as Map<String, dynamic>))
                .toList())
            .toList(),
        rewardClaimed: json['rewardClaimed'] as bool? ?? false,
        lastPlayedAtMatchday: json['lastPlayedAtMatchday'] as int?,
      );
}
