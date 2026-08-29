import 'enum_json.dart';
import 'player.dart';

/// シーズンベストイレブンの1枠分の記録。
class BestElevenEntry {
  final String playerId;
  final String playerName;
  final String teamName;
  final String? teamId;
  final PositionGroup group;
  final double avgRating;
  final int appearances;

  BestElevenEntry({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    this.teamId,
    required this.group,
    required this.avgRating,
    required this.appearances,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'teamName': teamName,
        'teamId': teamId,
        'group': group.name,
        'avgRating': avgRating,
        'appearances': appearances,
      };

  factory BestElevenEntry.fromJson(Map<String, dynamic> json) =>
      BestElevenEntry(
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        teamName: json['teamName'] as String,
        teamId: json['teamId'] as String?,
        group: enumFromName(
            PositionGroup.values, json['group'] as String?, PositionGroup.mid),
        avgRating: (json['avgRating'] as num).toDouble(),
        appearances: json['appearances'] as int,
      );
}

/// あるシーズンのベストイレブン(11名分)。
class SeasonBestEleven {
  final int season;
  final List<BestElevenEntry> entries;

  SeasonBestEleven({required this.season, required this.entries});

  Map<String, dynamic> toJson() => {
        'season': season,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory SeasonBestEleven.fromJson(Map<String, dynamic> json) =>
      SeasonBestEleven(
        season: json['season'] as int,
        entries: (json['entries'] as List)
            .map((e) => BestElevenEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
