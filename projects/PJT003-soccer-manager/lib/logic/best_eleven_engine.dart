import '../models/best_eleven.dart';
import '../models/league.dart';
import '../models/player.dart';

class BestElevenEngine {
  /// この試合数以上、採点対象になった選手のみベストイレブンの候補とする
  /// (1、2試合の好成績だけで選ばれてしまうのを防ぐ)。
  static const int minAppearances = 3;

  /// GK1・DF4・MF4・FW2の4-4-2型で各グループの平均採点上位者を選出する。
  static const Map<PositionGroup, int> slotsPerGroup = {
    PositionGroup.gk: 1,
    PositionGroup.def: 4,
    PositionGroup.mid: 4,
    PositionGroup.att: 2,
  };

  static SeasonBestEleven compute(League league, int season) {
    final ratingSum = <String, double>{};
    final ratingCount = <String, int>{};
    for (final f in league.fixtures) {
      final result = f.result;
      if (result == null) continue;
      result.playerRatings.forEach((playerId, rating) {
        ratingSum[playerId] = (ratingSum[playerId] ?? 0) + rating;
        ratingCount[playerId] = (ratingCount[playerId] ?? 0) + 1;
      });
    }

    final candidates = <BestElevenEntry>[];
    for (final t in league.teams) {
      for (final p in t.players) {
        final count = ratingCount[p.id] ?? 0;
        if (count < minAppearances) continue;
        candidates.add(BestElevenEntry(
          playerId: p.id,
          playerName: p.name,
          teamName: t.name,
          teamId: t.id,
          group: p.position.group,
          avgRating: ratingSum[p.id]! / count,
          appearances: count,
        ));
      }
    }

    final selected = <BestElevenEntry>[];
    for (final group in PositionGroup.values) {
      final pool = candidates.where((c) => c.group == group).toList()
        ..sort((a, b) => b.avgRating.compareTo(a.avgRating));
      selected.addAll(pool.take(slotsPerGroup[group]!));
    }

    return SeasonBestEleven(season: season, entries: selected);
  }
}
