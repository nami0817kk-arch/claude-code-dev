/// シーズン終了時に確定する、ユーザークラブの成績アーカイブ。
class SeasonRecord {
  final int season;
  final String clubName;
  final String leagueName;

  /// そのシーズンにプレーしたディビジョン(1部/2部)。
  final int divisionTier;

  final int finalRank;
  final int teamCount;
  final int played;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  final bool wonLeague;
  final bool promoted;
  final bool relegated;

  /// このシーズンに優勝したカップ戦名の一覧。
  final List<String> cupsWon;

  SeasonRecord({
    required this.season,
    required this.clubName,
    required this.leagueName,
    required this.divisionTier,
    required this.finalRank,
    required this.teamCount,
    required this.played,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    this.wonLeague = false,
    this.promoted = false,
    this.relegated = false,
    List<String>? cupsWon,
  }) : cupsWon = cupsWon ?? [];

  int get points => won * 3 + draw;
  int get goalDiff => goalsFor - goalsAgainst;

  Map<String, dynamic> toJson() => {
        'season': season,
        'clubName': clubName,
        'leagueName': leagueName,
        'divisionTier': divisionTier,
        'finalRank': finalRank,
        'teamCount': teamCount,
        'played': played,
        'won': won,
        'draw': draw,
        'lost': lost,
        'goalsFor': goalsFor,
        'goalsAgainst': goalsAgainst,
        'wonLeague': wonLeague,
        'promoted': promoted,
        'relegated': relegated,
        'cupsWon': cupsWon,
      };

  factory SeasonRecord.fromJson(Map<String, dynamic> json) => SeasonRecord(
        season: json['season'] as int,
        clubName: json['clubName'] as String,
        leagueName: json['leagueName'] as String,
        divisionTier: json['divisionTier'] as int,
        finalRank: json['finalRank'] as int,
        teamCount: json['teamCount'] as int,
        played: json['played'] as int,
        won: json['won'] as int,
        draw: json['draw'] as int,
        lost: json['lost'] as int,
        goalsFor: json['goalsFor'] as int,
        goalsAgainst: json['goalsAgainst'] as int,
        wonLeague: json['wonLeague'] as bool? ?? false,
        promoted: json['promoted'] as bool? ?? false,
        relegated: json['relegated'] as bool? ?? false,
        cupsWon:
            (json['cupsWon'] as List?)?.map((e) => e as String).toList() ?? [],
      );
}
