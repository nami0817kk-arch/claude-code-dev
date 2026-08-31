import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/scouting_engine.dart';
import '../logic/youth_match_engine.dart';
import '../models/player.dart';
import '../models/training_focus.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/position_filter_bar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';

/// 潜在能力と現在能力の差がこの値以上なら、伸びしろの大きい「有望株」として強調する。
const int _wonderkidGap = 15;

enum YouthSortOption { overall, potential, age, wonderkidGap }

extension on YouthSortOption {
  String get label => switch (this) {
        YouthSortOption.overall => Tr.pick('総合力', 'Overall'),
        YouthSortOption.potential => Tr.pick('ポテンシャル', 'Potential'),
        YouthSortOption.age => Tr.pick('年齢(若い順)', 'Age (youngest)'),
        YouthSortOption.wonderkidGap =>
          Tr.pick('伸びしろ(潜在−総合)', 'Room to grow (potential − overall)'),
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
        title: Text(Tr.pick('ユース・スカウト', 'Youth & scouting')),
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
                    Tr.pick('資金: ${save.budget}万円', 'Funds: ${save.budget}'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(Tr.pick(
                      '昇格枠: ${save.youthProspects.length}/$maxProspects',
                      'Academy places: ${save.youthProspects.length}/$maxProspects')),
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
                      Tr.pick(
                          'スカウト網（獲得費用: $scoutCost万円/人・${candidates.length}人閲覧可）',
                          'Scouting network ($scoutCost per signing, ${candidates.length} to look at)'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: Tr.pick('候補を更新する（$refreshCost万円）',
                        'Refresh the shortlist ($refreshCost)'),
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
                  hintText: Tr.pick('選手名で検索', 'Search by name'),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: Tr.pick('検索をクリア', 'Clear the search'),
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
                    tooltip: Tr.pick('並び替え', 'Sort'),
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  Tr.pick('該当する候補選手はいません', 'No prospects match'),
                  style: const TextStyle(color: Colors.grey),
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
                                Tooltip(
                                  message: Tr.pick(
                                      'ワンダーキッドの可能性あり(推定潜在能力の上限が高い。獲得するまで確定情報ではない)',
                                      'Could be a wonderkid. His estimated ceiling is high, but nothing is certain until you sign him'),
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            Tr.pick(
                                '${p.age}歳 / ${p.position.label} / 総合 ${p.overall} / 潜在(推定) ${range.$1}〜${range.$2} / 成長 ${p.growthType.label}',
                                'Age ${p.age} / ${p.position.label} / overall ${p.overall} / potential (est.) ${range.$1}–${range.$2} / ${p.growthType.label}'),
                          ),
                          trailing: FilledButton(
                            onPressed:
                                canScout ? () => _scout(context, p.id) : null,
                            child: Text(Tr.pick('獲得', 'Sign')),
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
                Tr.pick('昇格候補', 'Academy prospects'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                Tr.pick(
                    '昇格候補はユース施設で育成され続けます(成長係数 x${gameState.youthAcademyGrowthFactor.toStringAsFixed(2)}。ユース施設のレベルを上げるとじっくり育てる価値が高まります)。毎週ユース練習試合も行われ、活躍した候補はさらに伸びます',
                    'Prospects keep developing in your youth setup (growth x${gameState.youthAcademyGrowthFactor.toStringAsFixed(2)}; better facilities make it more worthwhile to be patient). They also play a youth match each week, and those who do well improve faster'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            if (gameState.lastYouthMatchReport != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Builder(
                      builder: (context) {
                        final report = gameState.lastYouthMatchReport!;
                        final best = report.performances.isEmpty
                            ? null
                            : report.performances.first;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Tr.pick(
                                  '今週のユース練習試合: ${report.scoreLabel} ${report.isWin ? '勝利' : report.isDraw ? '引き分け' : '敗戦'}(相手の総合力 ${report.opponentRating})',
                                  "This week's youth match: ${report.scoreLabel} ${report.isWin ? 'win' : report.isDraw ? 'draw' : 'defeat'} (opponent overall ${report.opponentRating})"),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (best != null)
                              Text(
                                Tr.pick(
                                    'ベストプレイヤー: ${best.player.name}(評点 ${best.rating.toStringAsFixed(1)}${best.goals > 0 ? '・${best.goals}得点' : ''})',
                                    "Best on the day: ${best.player.name} (rated ${best.rating.toStringAsFixed(1)}${best.goals > 0 ? ', ${best.goals} goals' : ''})"),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (prospects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  save.youthProspects.isEmpty
                      ? Tr.pick(
                          '現在、昇格候補はいません', 'You have no prospects right now')
                      : Tr.pick('該当する昇格候補はいません', 'No prospects match'),
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
                            Tooltip(
                              message: Tr.pick('ワンダーキッド(潜在能力が現在能力を大きく上回る逸材)',
                                  'Wonderkid: his ceiling sits far above where he is now'),
                              child: const Icon(
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
                            Tr.pick(
                                '${p.age}歳 / 総合 ${p.overall} / 潜在 ${p.potential} / 成長 ${p.growthType.label}',
                                'Age ${p.age} / overall ${p.overall} / potential ${p.potential} / ${p.growthType.label}'),
                          ),
                          Text(
                            p.youthMatchApps == 0
                                ? Tr.pick(
                                    'ユース戦: まだ出場なし', 'Youth matches: none yet')
                                : Tr.pick(
                                    'ユース戦: ${p.youthMatchApps}試合 ${p.youthMatchGoals}得点 / 直近評点 ${p.lastYouthMatchRating.toStringAsFixed(1)}',
                                    'Youth matches: ${p.youthMatchApps} apps, ${p.youthMatchGoals} goals / last rating ${p.lastYouthMatchRating.toStringAsFixed(1)}'),
                            style: TextStyle(
                              fontSize: 12,
                              color: p.lastYouthMatchRating >=
                                      YouthMatchEngine.standoutRatingThreshold
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                Tr.pick('育成方針: ', 'Focus: '),
                                style: const TextStyle(fontSize: 12),
                              ),
                              DropdownButton<TrainingFocus?>(
                                value: p.individualFocus,
                                isDense: true,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                                hint: Text(
                                  Tr.pick(
                                      'ポジション別(既定)', 'By position (default)'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                items: [
                                  DropdownMenuItem<TrainingFocus?>(
                                    value: null,
                                    child: Text(Tr.pick(
                                        'ポジション別(既定)', 'By position (default)')),
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
                            tooltip: Tr.pick('解雇', 'Release'),
                            onPressed: () =>
                                _confirmRelease(context, p.id, p.name),
                          ),
                          FilledButton(
                            onPressed: squadFull
                                ? null
                                : () => _promote(context, p.id, p.name),
                            child: Text(Tr.pick('昇格', 'Promote')),
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
        SnackBar(
            content: Text(ok
                ? Tr.pick('スカウト候補を更新しました', 'Shortlist refreshed')
                : Tr.pick('資金が足りず更新できませんでした', 'Not enough funds to refresh'))),
      );
    }
  }

  Future<void> _scout(BuildContext context, String candidateId) async {
    final ok = await context.read<GameState>().scoutProspect(candidateId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok
                ? Tr.pick('新しい有望株を発見しました', 'You found a new prospect')
                : Tr.pick('スカウトできませんでした', 'The scouting did not come off'))),
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
        SnackBar(
            content: Text(ok
                ? Tr.pick('$nameをトップチームに昇格させました',
                    'You promoted $name to the first team')
                : Tr.pick('昇格できませんでした', 'The promotion did not go through'))),
      );
    }
  }

  void _confirmRelease(BuildContext context, String playerId, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('この有望株を解雇しますか？', 'Release this prospect?')),
        content: Text(Tr.pick('$nameを手放します。この操作は元に戻せません。',
            'You let $name go. This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              FeedbackService.tap();
              context.read<GameState>().releaseYouthProspect(playerId);
            },
            child: Text(Tr.pick('解雇する', 'Release him')),
          ),
        ],
      ),
    );
  }
}
