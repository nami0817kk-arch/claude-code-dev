/// シーズン終了時に確定する個人タイトル(得点王・年間MVP・ゴールデングラブ)の記録。
class SeasonAward {
  final int season;
  final String? topScorerId;
  final String? topScorerName;
  final String? topScorerTeamName;
  final String? topScorerTeamId;
  final int topScorerGoals;
  final String? mvpId;
  final String? mvpName;
  final String? mvpTeamName;
  final String? mvpTeamId;
  final String? goldenGloveId;
  final String? goldenGloveName;
  final String? goldenGloveTeamName;
  final String? goldenGloveTeamId;
  final int goldenGloveCleanSheets;

  SeasonAward({
    required this.season,
    this.topScorerId,
    this.topScorerName,
    this.topScorerTeamName,
    this.topScorerTeamId,
    this.topScorerGoals = 0,
    this.mvpId,
    this.mvpName,
    this.mvpTeamName,
    this.mvpTeamId,
    this.goldenGloveId,
    this.goldenGloveName,
    this.goldenGloveTeamName,
    this.goldenGloveTeamId,
    this.goldenGloveCleanSheets = 0,
  });

  Map<String, dynamic> toJson() => {
        'season': season,
        'topScorerId': topScorerId,
        'topScorerName': topScorerName,
        'topScorerTeamName': topScorerTeamName,
        'topScorerTeamId': topScorerTeamId,
        'topScorerGoals': topScorerGoals,
        'mvpId': mvpId,
        'mvpName': mvpName,
        'mvpTeamName': mvpTeamName,
        'mvpTeamId': mvpTeamId,
        'goldenGloveId': goldenGloveId,
        'goldenGloveName': goldenGloveName,
        'goldenGloveTeamName': goldenGloveTeamName,
        'goldenGloveTeamId': goldenGloveTeamId,
        'goldenGloveCleanSheets': goldenGloveCleanSheets,
      };

  factory SeasonAward.fromJson(Map<String, dynamic> json) => SeasonAward(
        season: json['season'] as int,
        topScorerId: json['topScorerId'] as String?,
        topScorerName: json['topScorerName'] as String?,
        topScorerTeamName: json['topScorerTeamName'] as String?,
        topScorerTeamId: json['topScorerTeamId'] as String?,
        topScorerGoals: json['topScorerGoals'] as int? ?? 0,
        mvpId: json['mvpId'] as String?,
        mvpName: json['mvpName'] as String?,
        mvpTeamName: json['mvpTeamName'] as String?,
        mvpTeamId: json['mvpTeamId'] as String?,
        goldenGloveId: json['goldenGloveId'] as String?,
        goldenGloveName: json['goldenGloveName'] as String?,
        goldenGloveTeamName: json['goldenGloveTeamName'] as String?,
        goldenGloveTeamId: json['goldenGloveTeamId'] as String?,
        goldenGloveCleanSheets: json['goldenGloveCleanSheets'] as int? ?? 0,
      );
}
