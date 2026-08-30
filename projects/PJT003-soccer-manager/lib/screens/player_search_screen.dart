import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/player_search.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';

/// FMの選手検索に相当する画面。全ディビジョンの全選手を名前・ポジション・
/// 年齢・総合力で絞り込み、スカッド計画や補強ターゲットの調査に使う
/// (実際の獲得は従来通り移籍市場・フリーエージェント経由)。
class PlayerSearchScreen extends StatefulWidget {
  const PlayerSearchScreen({super.key});

  @override
  State<PlayerSearchScreen> createState() => _PlayerSearchScreenState();
}

class _PlayerSearchScreenState extends State<PlayerSearchScreen> {
  final _queryController = TextEditingController();
  PositionGroup? _group;
  int? _maxAge;
  int? _minOverall;
  PlayerSearchSort _sort = PlayerSearchSort.overall;
  bool _watchedOnly = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  static const _groupLabels = {
    PositionGroup.gk: 'GK',
    PositionGroup.def: 'DF',
    PositionGroup.mid: 'MF',
    PositionGroup.att: 'FW',
  };

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    final results = save == null
        ? const <PlayerSearchResult>[]
        : PlayerSearch.search(
            save.allTeams,
            query: _queryController.text.trim(),
            group: _group,
            maxAge: _maxAge,
            minOverall: _minOverall,
            restrictToIds:
                _watchedOnly ? save.watchlistPlayerIds.toSet() : null,
            sort: _sort,
          );
    final userTeamId = gameState.userTeam.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('選手検索'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  labelText: '選手名で検索',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _queryController.clear()),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('全ポジション'),
                      selected: _group == null,
                      onSelected: (_) => setState(() => _group = null),
                    ),
                    for (final g in PositionGroup.values)
                      ChoiceChip(
                        label: Text(_groupLabels[g]!),
                        selected: _group == g,
                        onSelected: (_) => setState(() => _group = g),
                      ),
                    FilterChip(
                      label: const Text('U-23'),
                      selected: _maxAge == 23,
                      onSelected: (sel) =>
                          setState(() => _maxAge = sel ? 23 : null),
                    ),
                    FilterChip(
                      label: const Text('総合70+'),
                      selected: _minOverall == 70,
                      onSelected: (sel) =>
                          setState(() => _minOverall = sel ? 70 : null),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.star, size: 16),
                      label: const Text('ウォッチ中'),
                      selected: _watchedOnly,
                      onSelected: (sel) => setState(() => _watchedOnly = sel),
                    ),
                    for (final sort in PlayerSearchSort.values)
                      ChoiceChip(
                        label: Text(sort.label),
                        selected: _sort == sort,
                        onSelected: (_) => setState(() => _sort = sort),
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '全ディビジョンから検索(上位50人)。獲得は移籍市場・FA経由で行えます。',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        '条件に合う選手が見つかりません',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final r = results[index];
                        final p = r.player;
                        final isUser = r.team.id == userTeamId;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isUser
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: ListTile(
                            leading: PlayerFaceAvatar(
                              playerId: p.id,
                              position: p.position,
                              size: 40,
                            ),
                            title: Text(
                              '${p.name}(${p.position.label}・${p.age}歳)',
                              style: TextStyle(
                                fontWeight: isUser
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${r.team.name}${isUser ? '(自クラブ)' : ''}'
                              ' / 市場価値${p.marketValue}万円',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    gameState.isWatched(p.id)
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: gameState.isWatched(p.id)
                                        ? Colors.amber.shade700
                                        : Colors.grey,
                                  ),
                                  tooltip: gameState.isWatched(p.id)
                                      ? 'ウォッチリストから外す'
                                      : 'ウォッチリストに追加',
                                  onPressed: () => context
                                      .read<GameState>()
                                      .toggleWatched(p.id),
                                ),
                                Text(
                                  '${p.overall}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
