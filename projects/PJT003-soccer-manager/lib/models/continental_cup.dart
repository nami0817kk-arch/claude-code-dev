import 'cup.dart';
import 'match_result.dart';

/// 大陸カップの決勝トーナメントにおける1つの対戦カード。準決勝までは
/// ホーム&アウェイの2試合合計スコアで、決勝は1試合のみで勝敗を決める。
class CupTie {
  final int round;
  final String teamAId;
  final String teamBId;
  final List<MatchResult> legs;

  /// 合計スコアが同点だった場合のPK戦勝者チームID。
  String? penaltyWinnerId;

  /// 決勝(1試合のみ)かどうか。
  final bool singleLeg;

  CupTie({
    required this.round,
    required this.teamAId,
    required this.teamBId,
    List<MatchResult>? legs,
    this.penaltyWinnerId,
    this.singleLeg = false,
  }) : legs = legs ?? [];

  int get totalLegs => singleLeg ? 1 : 2;

  bool get isComplete => legs.length >= totalLegs;

  int goalsFor(String teamId) => legs.fold<int>(0,
      (sum, m) => sum + (m.homeTeamId == teamId ? m.homeGoals : m.awayGoals));

  String? get winnerId {
    if (!isComplete) return null;
    final aGoals = goalsFor(teamAId);
    final bGoals = goalsFor(teamBId);
    if (aGoals > bGoals) return teamAId;
    if (aGoals < bGoals) return teamBId;
    return penaltyWinnerId;
  }

  Map<String, dynamic> toJson() => {
        'round': round,
        'teamAId': teamAId,
        'teamBId': teamBId,
        'legs': legs.map((m) => m.toJson()).toList(),
        'penaltyWinnerId': penaltyWinnerId,
        'singleLeg': singleLeg,
      };

  factory CupTie.fromJson(Map<String, dynamic> json) => CupTie(
        round: json['round'] as int,
        teamAId: json['teamAId'] as String,
        teamBId: json['teamBId'] as String,
        legs: (json['legs'] as List)
            .map((e) => MatchResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        penaltyWinnerId: json['penaltyWinnerId'] as String?,
        singleLeg: json['singleLeg'] as bool? ?? false,
      );
}

/// 大陸カップ: 4チームずつのグループステージ(1回戦総当たり)を行い、各組
/// 上位2チームが決勝トーナメント(準決勝は2回戦制、決勝は1試合)に進む。
class ContinentalCup {
  final String name;
  final List<List<String>> groups;
  final List<CupMatch> groupMatches;
  final List<List<CupTie>> knockoutRounds;

  /// 優勝報酬(賞金・信頼度)を既に付与済みかどうか。二重付与を防ぐためのフラグ。
  bool rewardClaimed;

  /// 直近の試合を消化した時点でのリーグの節数(未消化ならnull)。
  /// 現実の試合間隔を再現するため、次の試合はリーグがこの節から
  /// 1節以上進むまで消化できないようにする。
  int? lastPlayedAtMatchday;

  ContinentalCup({
    required this.name,
    required this.groups,
    List<CupMatch>? groupMatches,
    List<List<CupTie>>? knockoutRounds,
    this.rewardClaimed = false,
    this.lastPlayedAtMatchday,
  })  : groupMatches = groupMatches ?? [],
        knockoutRounds = knockoutRounds ?? [];

  bool get isGroupStageComplete =>
      groupMatches.isNotEmpty && groupMatches.every((m) => m.result != null);

  bool get isComplete =>
      knockoutRounds.isNotEmpty &&
      knockoutRounds.last.length == 1 &&
      knockoutRounds.last.first.winnerId != null;

  String? get championId =>
      isComplete ? knockoutRounds.last.first.winnerId : null;

  bool involvesTeam(String teamId) => groups.any((g) => g.contains(teamId));

  /// このカップにおいてチームが敗退済みかどうか(グループステージ敗退・決勝
  /// トーナメント敗退のいずれも含む)。
  bool isEliminated(String teamId) {
    if (!involvesTeam(teamId)) return false;
    for (final round in knockoutRounds) {
      for (final tie in round) {
        if ((tie.teamAId == teamId || tie.teamBId == teamId) &&
            tie.winnerId != null &&
            tie.winnerId != teamId) {
          return true;
        }
      }
    }
    if (isGroupStageComplete && knockoutRounds.isNotEmpty) {
      final advanced = knockoutRounds.first
          .any((t) => t.teamAId == teamId || t.teamBId == teamId);
      if (!advanced) return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'groups': groups,
        'groupMatches': groupMatches.map((m) => m.toJson()).toList(),
        'knockoutRounds': knockoutRounds
            .map((round) => round.map((t) => t.toJson()).toList())
            .toList(),
        'rewardClaimed': rewardClaimed,
        'lastPlayedAtMatchday': lastPlayedAtMatchday,
      };

  factory ContinentalCup.fromJson(Map<String, dynamic> json) => ContinentalCup(
        name: json['name'] as String,
        groups: (json['groups'] as List)
            .map((g) => (g as List).map((id) => id as String).toList())
            .toList(),
        groupMatches: (json['groupMatches'] as List)
            .map((e) => CupMatch.fromJson(e as Map<String, dynamic>))
            .toList(),
        knockoutRounds: (json['knockoutRounds'] as List)
            .map((round) => (round as List)
                .map((e) => CupTie.fromJson(e as Map<String, dynamic>))
                .toList())
            .toList(),
        rewardClaimed: json['rewardClaimed'] as bool? ?? false,
        lastPlayedAtMatchday: json['lastPlayedAtMatchday'] as int?,
      );
}
