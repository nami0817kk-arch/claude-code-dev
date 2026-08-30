import '../models/player.dart';
import '../models/team.dart';

/// 選手検索の1件(所属チームつき)。
typedef PlayerSearchResult = ({Player player, Team team});

/// 検索結果の並び順。
enum PlayerSearchSort { overall, age, marketValue }

extension PlayerSearchSortInfo on PlayerSearchSort {
  String get label => switch (this) {
        PlayerSearchSort.overall => '総合力順',
        PlayerSearchSort.age => '年齢が若い順',
        PlayerSearchSort.marketValue => '市場価値順',
      };
}

/// リーグ全体(全ディビジョン)から条件に合う選手を探す純粋関数。
/// FMの選手検索に相当するスカッド計画ツールで、実際の獲得は従来通り
/// 移籍市場・フリーエージェント経由で行う。
class PlayerSearch {
  static List<PlayerSearchResult> search(
    List<Team> teams, {
    String query = '',
    PositionGroup? group,
    int? maxAge,
    int? minOverall,
    Set<String>? restrictToIds,
    PlayerSearchSort sort = PlayerSearchSort.overall,
    int limit = 50,
  }) {
    final results = <PlayerSearchResult>[
      for (final t in teams)
        for (final p in t.players)
          if ((restrictToIds == null || restrictToIds.contains(p.id)) &&
              (query.isEmpty || p.name.contains(query)) &&
              (group == null || p.position.group == group) &&
              (maxAge == null || p.age <= maxAge) &&
              (minOverall == null || p.overall >= minOverall))
            (player: p, team: t),
    ];
    results.sort(
      (a, b) => switch (sort) {
        PlayerSearchSort.overall =>
          b.player.overall.compareTo(a.player.overall),
        PlayerSearchSort.age => a.player.age.compareTo(b.player.age),
        PlayerSearchSort.marketValue =>
          b.player.marketValue.compareTo(a.player.marketValue),
      },
    );
    return results.length > limit ? results.sublist(0, limit) : results;
  }
}
