import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/scouting_engine.dart';
import '../models/player.dart';
import '../models/training_focus.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/position_filter_bar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';

/// 潜在能力と現在能力の差がこの値以上なら、伸びしろの大きい「有望株」として強調する。
const int _wonderkidGap = 15;

enum YouthSortOption { overall, potential, age, wonderkidGap }

extension on YouthSortOption {
  String get label => switch (this) {
        YouthSortOption.overall => '総合力',
        YouthSortOption.potential => 'ポテンシャル',
        YouthSortOption.age => '年齢(若い順)',
        YouthSortOption.wonderkidGap => '伸びしろ(潜在−総合)',
      };
}

class YouthScreen extends StatefulWidget {
  const YouthScreen({super.key});

  /// フィルタ・検索・並び替えを適用した選手リストを返す。UIから切り離してテスト可能にしてある。
  static List<Player> filterAndSort(
    List<Player> all, {
    PositionGroup? group,
    String query = '',
    YouthSortOption sort = YouthSortOption.overall,
  }) {
    var players = all;
    if (group != null) {
      players = players.where((p) => p.position.group == group).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      players = players.where((p) => p.name.toLowerCase().contains(q)).toList();
    } else {
      players = [...players];
    }
    switch (sort) {
      case YouthSortOption.overall:
        players.sort((a, b) => b.overall.compareTo(a.overall));
        break;
      case YouthSortOption.potential:
        players.sort((a, b) => b.potential.compareTo(a.potential));
        break;
      case YouthSortOption.age:
        players.sort((a, b) => a.age.compareTo(b.age));
        break;
      case YouthSortOption.wonderkidGap:
        players.sort(
          (a, b) =>
              (b.potential - b.overall).compareTo(a.potential - a.overall),
        );
        break;
    }
    return players;
  }

  @override
  State<YouthScreen> createState() => _YouthScreenState();
}

class _YouthScreenState extends State<YouthScreen> {
  PositionGroup? _filter;
  YouthSortOption _sort = YouthSortOption.overall;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final squadFull = gameState.userTeam.players.length >= maxSquadSize;
    final scoutCost = gameState.scoutCost;
    final maxProspects = gameState.maxYouthProspects;
    final refreshCost = gameState.scoutRefreshCost;
    final canRefresh = save.budget >= refreshCost;

    final prospects = YouthScreen.filterAndSort(
      save.youthProspects,
      group: _filter,
      query: _query,
      sort: _sort,
    );
    final canScout =
        save.budget >= scoutCost && save.youthProspects.length < maxProspects;

    final candidates = YouthScreen.filterAndSort(
      gameState.scoutCandidates,
      group: _filter,
      query: _query,
      sort: _sort,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('ユース・スカウト'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '資金: ${save.budget}万円',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('昇格枠: ${save.youthProspects.length}/$maxProspects'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'スカウト網（獲得費用: $scoutCost万円/人・${candidates.length}人閲覧可）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '候補を更新する（$refreshCost万円）',
                    onPressed: canRefresh ? () => _refresh(context) : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: '選手名で検索',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: '検索をクリア',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: PositionFilterBar(
                      value: _filter,
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                  ),
                  PopupMenuButton<YouthSortOption>(
                    icon: const Icon(Icons.sort),
                    tooltip: '並び替え',
                    initialValue: _sort,
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (context) => [
                      for (final option in YouthSortOption.values)
                        PopupMenuItem(value: option, child: Text(option.label)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '該当する候補選手はいません',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              for (final p in candidates)
                Builder(
                  builder: (context) {
                    final range = ScoutingEngine.estimatedPotentialRange(
                      p,
                      scoutLevel: gameState.scoutLevel,
                    );
                    final maybeWonderkid =
                        range.$2 - p.overall >= _wonderkidGap;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Card(
                        child: ListTile(
                          leading: PlayerFaceAvatar(
                            playerId: p.id,
                            position: p.position,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (maybeWonderkid) ...[
                                const SizedBox(width: 6),
                                const Tooltip(
                                  message:
                                      'ワンダーキッドの可能性あり(推定潜在能力の上限が高い。獲得するまで確定情報ではない)',
                                  child: Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${p.age}歳 / ${p.position.label} / 総合 ${p.overall} / '
                            '潜在(推定) ${range.$1}〜${range.$2} / 成長 ${p.growthType.label}',
                          ),
                          trailing: FilledButton(
                            onPressed:
                                canScout ? () => _scout(context, p.id) : null,
                            child: const Text('獲得'),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '昇格候補',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '昇格候補はユース施設で育成され続けます'
                '(成長係数 x${gameState.youthAcademyGrowthFactor.toStringAsFixed(2)}。'
                'ユース施設のレベルを上げるとじっくり育てる価値が高まります)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            if (prospects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  save.youthProspects.isEmpty
                      ? '現在、昇格候補はいません'
                      : '該当する昇格候補はいません',
                ),
              )
            else
              for (final p in prospects)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Card(
                    child: ListTile(
                      leading: PlayerFaceAvatar(
                        playerId: p.id,
                        position: p.position,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (p.potential - p.overall >= _wonderkidGap) ...[
                            const SizedBox(width: 6),
                            const Tooltip(
                              message: 'ワンダーキッド(潜在能力が現在能力を大きく上回る逸材)',
                              child: Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.age}歳 / 総合 ${p.overall} / 潜在 ${p.potential} / 成長 ${p.growthType.label}',
                          ),
                          Row(
                            children: [
                              const Text(
                                '育成方針: ',
                                style: TextStyle(fontSize: 12),
                              ),
                              DropdownButton<TrainingFocus?>(
                                value: p.individualFocus,
                                isDense: true,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                                hint: const Text(
                                  'ポジション別(既定)',
                                  style: TextStyle(fontSize: 12),
                                ),
                                items: [
                                  const DropdownMenuItem<TrainingFocus?>(
                                    value: null,
                                    child: Text('ポジション別(既定)'),
                                  ),
                                  for (final focus in const [
                                    TrainingFocus.attack,
                                    TrainingFocus.defense,
                                    TrainingFocus.fitness,
                                  ])
                                    DropdownMenuItem<TrainingFocus?>(
                                      value: focus,
                                      child: Text(focus.label),
                                    ),
                                ],
                                onChanged: (focus) {
                                  FeedbackService.tap();
                                  context
                                      .read<GameState>()
                                      .setYouthProspectTrainingFocus(
                                        p.id,
                                        focus,
                                      );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: '解雇',
                            onPressed: () =>
                                _confirmRelease(context, p.id, p.name),
                          ),
                          FilledButton(
                            onPressed: squadFull
                                ? null
                                : () => _promote(context, p.id, p.name),
                            child: const Text('昇格'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(BuildContext context) async {
    final ok = await context.read<GameState>().refreshScoutCandidates();
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'スカウト候補を更新しました' : '資金が足りず更新できませんでした')),
      );
    }
  }

  Future<void> _scout(BuildContext context, String candidateId) async {
    final ok = await context.read<GameState>().scoutProspect(candidateId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '新しい有望株を発見しました' : 'スカウトできませんでした')),
      );
    }
  }

  Future<void> _promote(
    BuildContext context,
    String playerId,
    String name,
  ) async {
    final ok = await context.read<GameState>().promoteYouthProspect(playerId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '$nameをトップチームに昇格させました' : '昇格できませんでした')),
      );
    }
  }

  void _confirmRelease(BuildContext context, String playerId, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この有望株を解雇しますか？'),
        content: Text('$nameを手放します。この操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              FeedbackService.tap();
              context.read<GameState>().releaseYouthProspect(playerId);
            },
            child: const Text('解雇する'),
          ),
        ],
      ),
    );
  }
}
