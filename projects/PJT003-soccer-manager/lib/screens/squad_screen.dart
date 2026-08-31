import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/contract_engine.dart';
import '../models/player.dart';
import '../models/player_season_stats.dart';
import '../models/team.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/position_filter_bar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'glossary_screen.dart';
import 'player_compare_screen.dart';
import 'player_detail_screen.dart';
import '../l10n/tr.dart';

enum SquadSortOption {
  position,
  overall,
  age,
  potential,
  wage,
  fatigue,
  sharpness,
  happiness,
  contract,
  marketValue,
}

extension on SquadSortOption {
  String get label => switch (this) {
        SquadSortOption.position => Tr.pick('ポジション順', 'By position'),
        SquadSortOption.overall => Tr.pick('総合力', 'Overall'),
        SquadSortOption.age => Tr.pick('年齢(若い順)', 'Age (youngest)'),
        SquadSortOption.potential => Tr.pick('ポテンシャル', 'Potential'),
        SquadSortOption.wage => Tr.pick('週俸', 'Wage'),
        SquadSortOption.fatigue => Tr.pick('疲労が大きい順', 'Most tired'),
        SquadSortOption.sharpness => Tr.pick('実戦感覚が低い順', 'Least sharp'),
        SquadSortOption.happiness => Tr.pick('不満が大きい順', 'Least happy'),
        SquadSortOption.contract =>
          Tr.pick('契約残りが短い順', 'Contract running down'),
        SquadSortOption.marketValue => Tr.pick('市場価値', 'Value'),
      };
}

/// スカッドの状況で絞り込むフィルタ。
enum SquadStatusFilter { all, starters, bench, needsAttention }

extension SquadStatusFilterInfo on SquadStatusFilter {
  String get label => switch (this) {
        SquadStatusFilter.all => Tr.pick('すべて', 'All'),
        SquadStatusFilter.starters => Tr.pick('スタメン', 'Starters'),
        SquadStatusFilter.bench => Tr.pick('控え', 'Backups'),
        SquadStatusFilter.needsAttention => Tr.pick('要対応', 'Needs attention'),
      };
}

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});

  /// 「要対応」フィルタが拾う状態かどうか。負傷・出場停止・移籍希望のほか、
  /// 疲労過多・実戦感覚の低下(成長ペナルティ圏)・契約最終年(ローンを除く)
  /// といった「放置するとまずい」状態を横断的に検知する。
  static bool needsAttention(Player p) =>
      p.isInjured ||
      p.isSuspended ||
      p.wantsTransfer ||
      p.fatigue >= 75 ||
      (!p.isLoanedOut && p.matchSharpness < 40) ||
      (!p.isLoan && p.contractYearsRemaining <= 1);

  /// フィルタ・検索・並び替えを適用した選手リストを返す。UIから切り離してテスト可能にしてある。
  /// [status]でスタメン/控え/要対応を絞り込む場合は[startingIds]
  /// (現在の先発ID)を渡す。
  static List<Player> filterAndSort(
    List<Player> all, {
    PositionGroup? group,
    String query = '',
    SquadSortOption sort = SquadSortOption.position,
    SquadStatusFilter status = SquadStatusFilter.all,
    Set<String> startingIds = const {},
  }) {
    var players = all;
    if (group != null) {
      players = players.where((p) => p.position.group == group).toList();
    }
    switch (status) {
      case SquadStatusFilter.all:
        break;
      case SquadStatusFilter.starters:
        players = players.where((p) => startingIds.contains(p.id)).toList();
        break;
      case SquadStatusFilter.bench:
        players = players
            .where((p) => !startingIds.contains(p.id) && !p.isLoanedOut)
            .toList();
        break;
      case SquadStatusFilter.needsAttention:
        players = players.where(needsAttention).toList();
        break;
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      players = players.where((p) => p.name.toLowerCase().contains(q)).toList();
    } else {
      players = [...players];
    }
    switch (sort) {
      case SquadSortOption.position:
        players.sort((a, b) {
          final c = a.position.index.compareTo(b.position.index);
          if (c != 0) return c;
          return b.overall.compareTo(a.overall);
        });
        break;
      case SquadSortOption.overall:
        players.sort((a, b) => b.overall.compareTo(a.overall));
        break;
      case SquadSortOption.age:
        players.sort((a, b) => a.age.compareTo(b.age));
        break;
      case SquadSortOption.potential:
        players.sort((a, b) => b.potential.compareTo(a.potential));
        break;
      case SquadSortOption.wage:
        players.sort((a, b) => b.wage.compareTo(a.wage));
        break;
      case SquadSortOption.fatigue:
        players.sort((a, b) => b.fatigue.compareTo(a.fatigue));
        break;
      case SquadSortOption.sharpness:
        players.sort((a, b) => a.matchSharpness.compareTo(b.matchSharpness));
        break;
      case SquadSortOption.happiness:
        players.sort((a, b) => a.happiness.compareTo(b.happiness));
        break;
      case SquadSortOption.contract:
        // ローン加入選手には自クラブとの契約年数の概念がないため末尾に回す。
        int key(Player p) => p.isLoan ? 999 : p.contractYearsRemaining;
        players.sort((a, b) => key(a).compareTo(key(b)));
        break;
      case SquadSortOption.marketValue:
        players.sort((a, b) => b.marketValue.compareTo(a.marketValue));
        break;
    }
    return players;
  }

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  bool _compareMode = false;
  final List<String> _selected = [];
  PositionGroup? _filterGroup;
  SquadSortOption _sort = SquadSortOption.position;
  SquadStatusFilter _statusFilter = SquadStatusFilter.all;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCompareMode() {
    setState(() {
      _compareMode = !_compareMode;
      _selected.clear();
    });
  }

  void _toggleSelected(String playerId) {
    setState(() {
      if (_selected.contains(playerId)) {
        _selected.remove(playerId);
      } else {
        if (_selected.length >= 2) _selected.removeAt(0);
        _selected.add(playerId);
      }
    });
  }

  void _showContractSheet(BuildContext context, Player p) {
    final gameState = context.read<GameState>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final renewalCost = gameState.renewalCostFor(p.id);
        final signingBonus = gameState.signingBonusFor(p.id);
        final newAppearanceFee = gameState.appearanceFeeFor(p.id);
        final totalCost = renewalCost + signingBonus;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  Tr.pick(
                      '週俸: ${p.wage}万円 / ${ContractEngine.yearsLabel(p.contractYearsRemaining)}',
                      'Wage: ${p.wage} / ${ContractEngine.yearsLabel(p.contractYearsRemaining)}'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: gameState.save!.budget < totalCost
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            final ok = await gameState.renewContract(p.id);
                            ok
                                ? FeedbackService.success()
                                : FeedbackService.error();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? Tr.pick(
                                            '契約を更新しました', 'Contract renewed')
                                        : Tr.pick('契約を更新できませんでした',
                                            'Could not renew the contract'),
                                  ),
                                ),
                              );
                            }
                          },
                    child: Text(
                      Tr.pick(
                          '契約更新する（基本$renewalCost万円 + サインボーナス$signingBonus万円 / 新契約${ContractEngine.negotiatedYears(p)}年 / 新出場手当$newAppearanceFee万円）',
                          'Renew (base $renewalCost + signing bonus $signingBonus / ${ContractEngine.negotiatedYears(p)} years / new appearance fee $newAppearanceFee)'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlayerDetailScreen(playerId: p.id),
                        ),
                      );
                    },
                    child: Text(Tr.pick('週俸交渉・放出など詳しい操作を開く',
                        'Open wage talks, release and other actions')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showIconLegend(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('アイコンの意味', 'What the icons mean')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendRow(
              icon: Icons.swap_horiz,
              color: Colors.indigo,
              label: Tr.pick('ローンで加入中の選手', 'On loan at your club'),
            ),
            _LegendRow(
              icon: Icons.sentiment_dissatisfied,
              color: Colors.redAccent,
              label: Tr.pick('移籍を希望している', 'Wants a move away'),
            ),
            _LegendRow(
              icon: Icons.flag,
              color: Colors.blueAccent,
              label: Tr.pick('代表召集中', 'On international duty'),
            ),
            _LegendRow(
              icon: Icons.shield,
              color: Colors.amber,
              label: Tr.pick('「C」=キャプテン / 「VC」=副キャプテン(選手詳細画面から指名)',
                  '"C" = captain, "VC" = vice captain (named from the player\'s page)'),
            ),
            _LegendRow(
              icon: Icons.block,
              color: Colors.redAccent,
              label: Tr.pick('出場停止中(警告累積または退場)',
                  'Suspended (booked too often, or sent off)'),
            ),
            _LegendRow(
              icon: Icons.flight_takeoff,
              color: Colors.deepPurple,
              label: Tr.pick('他クラブへローン放出中', 'Out on loan elsewhere'),
            ),
            _LegendRow(
              icon: Icons.sell_outlined,
              color: Colors.orange,
              label: Tr.pick('移籍リストに登録中', 'On the transfer list'),
            ),
            _LegendRow(
              icon: Icons.trending_up,
              color: Colors.green,
              label: Tr.pick('総合値の下の▲/▼ = 直近5節の総合力の変化(成長トレンド)',
                  '▲/▼ under the overall = change across the last 5 matchdays'),
            ),
            _LegendRow(
              icon: Icons.monitor_heart_outlined,
              color: Colors.grey,
              label: Tr.pick('2行目の疲労/感覚/士気は、問題のある値だけ赤く強調される',
                  'On the second line, only fatigue, sharpness and morale that need attention turn red'),
            ),
            _LegendRow(
              icon: Icons.workspace_premium,
              color: Colors.teal,
              label: Tr.pick('名前の横のKP/ROT/育成 = スカッド・ステータス(主力は非表示)',
                  'KP/ROT/Prospect beside the name is his squad status (first-team players show nothing)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('閉じる', 'Close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final players = SquadScreen.filterAndSort(
      team.players,
      group: _filterGroup,
      query: _query,
      sort: _sort,
      status: _statusFilter,
      startingIds: team.startingXI.toSet(),
    );
    final lastRatings = gameState.save!.league
        .lastPlayedFixtureFor(team.id)
        ?.result
        ?.playerRatings;

    return Scaffold(
      appBar: AppBar(
        title: Text(_compareMode
            ? Tr.pick('選手を2人選択', 'Pick two players')
            : Tr.pick('スカッド', 'Squad')),
        actions: [
          if (!_compareMode) ...[
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: Tr.pick('アイコンの意味', 'What the icons mean'),
              onPressed: () => _showIconLegend(context),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: Tr.pick('用語集', 'Glossary'),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GlossaryScreen())),
            ),
            PopupMenuButton<SquadSortOption>(
              icon: const Icon(Icons.sort),
              tooltip: Tr.pick('並び替え', 'Sort'),
              initialValue: _sort,
              onSelected: (v) => setState(() => _sort = v),
              itemBuilder: (context) => [
                for (final option in SquadSortOption.values)
                  PopupMenuItem(value: option, child: Text(option.label)),
              ],
            ),
          ],
          IconButton(
            icon: Icon(_compareMode ? Icons.close : Icons.compare_arrows),
            tooltip: _compareMode
                ? Tr.pick('比較モードを終了', 'Leave compare mode')
                : Tr.pick('選手を比較', 'Compare players'),
            onPressed: _toggleCompareMode,
          ),
        ],
      ),
      drawer: const QuickAccessDrawer(),
      floatingActionButton: _compareMode && _selected.length == 2
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => PlayerCompareScreen(
                          playerAId: _selected[0],
                          playerBId: _selected[1],
                        ),
                      ),
                    )
                    .then((_) => _toggleCompareMode());
              },
              icon: const Icon(Icons.compare_arrows),
              label: Text(Tr.pick('比較する', 'Compare')),
            )
          : null,
      body: ResponsiveBody(
        child: Column(
          children: [
            if (!_compareMode) _SquadSummaryCard(team: team),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: PositionFilterBar(
                value: _filterGroup,
                onChanged: (g) => setState(() => _filterGroup = g),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final f in SquadStatusFilter.values)
                      ChoiceChip(
                        label: Text(
                          f == SquadStatusFilter.needsAttention
                              ? '${f.label} '
                                  '${team.players.where(SquadScreen.needsAttention).length}'
                              : f.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                        selected: _statusFilter == f,
                        onSelected: (_) => setState(() => _statusFilter = f),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
            Expanded(
              child: players.isEmpty
                  ? Center(
                      child: Text(Tr.pick('該当する選手がいません', 'No players match')))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: players.length,
                      itemBuilder: (context, i) {
                        final p = players[i];
                        final isStarting = team.startingXI.contains(p.id);
                        final isSelected = _selected.contains(p.id);
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: ListTile(
                            tileColor: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                : isStarting
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.3)
                                    : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: _compareMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleSelected(p.id),
                                  )
                                : PlayerFaceAvatar(
                                    playerId: p.id,
                                    position: p.position,
                                    size: 40,
                                    highlighted: isStarting,
                                  ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (team.captainId == p.id) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: Tr.pick('キャプテン', 'Captain'),
                                    child: CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Colors.amber.shade700,
                                      child: const Text(
                                        'C',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (team.viceCaptainId == p.id) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: Tr.pick('副キャプテン', 'Vice captain'),
                                    child: const CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Colors.blueGrey,
                                      child: Text(
                                        'VC',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (p.squadStatus != SquadStatus.regular) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: Tr.pick(
                                        'スカッド・ステータス: ${p.squadStatus.label}',
                                        'Squad status: ${p.squadStatus.label}'),
                                    child: Text(
                                      switch (p.squadStatus) {
                                        SquadStatus.keyPlayer => 'KP',
                                        SquadStatus.rotation => 'ROT',
                                        SquadStatus.prospect =>
                                          Tr.pick('育成', 'Prospect'),
                                        SquadStatus.regular => '',
                                      },
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: switch (p.squadStatus) {
                                          SquadStatus.keyPlayer =>
                                            Colors.amber.shade800,
                                          SquadStatus.rotation => Colors.teal,
                                          _ => Colors.grey,
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                                if (p.isLoan) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: Tr.pick('ローン加入中', 'On loan here'),
                                    child: const Icon(
                                      Icons.swap_horiz,
                                      size: 16,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                                if (p.wantsTransfer) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: Tr.pick(
                                        '移籍を希望している', 'Wants a move away'),
                                    child: const Icon(
                                      Icons.sentiment_dissatisfied,
                                      size: 16,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                                if (p.isOnInternationalDuty) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: Tr.pick(
                                        '代表召集中', 'On international duty'),
                                    child: const Icon(
                                      Icons.flag,
                                      size: 16,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                                if (p.isSuspended) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: Tr.pick('出場停止中', 'Suspended'),
                                    child: const Icon(
                                      Icons.block,
                                      size: 16,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                                if (p.isLoanedOut) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: Tr.pick('ローンで放出中', 'Out on loan'),
                                    child: const Icon(
                                      Icons.flight_takeoff,
                                      size: 16,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                                if (p.isTransferListed) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: Tr.pick(
                                        '移籍リストに登録済み', 'On the transfer list'),
                                    child: const Icon(
                                      Icons.sell_outlined,
                                      size: 16,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.isInjured
                                      ? Tr.pick('負傷中（あと${p.injuryWeeks}週）',
                                          'Injured (${p.injuryWeeks} weeks)')
                                      : p.isSuspended
                                          ? Tr.pick(
                                              '出場停止（あと${p.suspendedMatches}試合）',
                                              'Suspended (${p.suspendedMatches} matches)')
                                          : p.isOnInternationalDuty
                                              ? Tr.pick(
                                                  '代表召集中（あと${p.internationalDutyWeeksRemaining}週）',
                                                  'On international duty (${p.internationalDutyWeeksRemaining} weeks)')
                                              : p.isLoanedOut
                                                  ? Tr.pick(
                                                      '${p.loanedOutToClubName}へローン放出中（あと${p.loanedOutWeeksRemaining}週）',
                                                      'On loan at ${p.loanedOutToClubName} (${p.loanedOutWeeksRemaining} weeks left)')
                                                  : Tr.pick(
                                                      '${p.age}歳 / ${p.position.label} / 総合 ${p.overall}${lastRatings?[p.id] != null ? ' / 前節 ${lastRatings![p.id]!.toStringAsFixed(1)}' : ''}${p.isLoan ? '' : ' / ${ContractEngine.yearsLabel(p.contractYearsRemaining)}'}',
                                                      "Age ${p.age} / ${p.position.label} / overall ${p.overall}${lastRatings?[p.id] != null ? ' / last ${lastRatings![p.id]!.toStringAsFixed(1)}' : ''}${p.isLoan ? '' : ' / ${ContractEngine.yearsLabel(p.contractYearsRemaining)}'}"),
                                  style: (p.isInjured ||
                                          p.isSuspended ||
                                          p.isOnInternationalDuty ||
                                          p.isLoanedOut)
                                      ? const TextStyle(color: Colors.redAccent)
                                      : (!p.isLoan &&
                                              p.contractYearsRemaining <= 1)
                                          ? const TextStyle(
                                              color: Colors.orange)
                                          : null,
                                ),
                                if (!_compareMode &&
                                    !p.isInjured &&
                                    !p.isSuspended &&
                                    !p.isOnInternationalDuty &&
                                    !p.isLoanedOut)
                                  _ConditionLine(
                                    player: p,
                                    stats: gameState.seasonStatsFor(p.id),
                                  ),
                              ],
                            ),
                            trailing: _compareMode
                                ? Text(
                                    '${p.overall}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Builder(
                                        builder: (context) {
                                          // 成長トレンド: 直近5節前と比べた
                                          // 総合力の変化(記録が浅ければ先頭と比較)。
                                          final h = p.overallHistory;
                                          final trend = h.length >= 2
                                              ? h.last -
                                                  h[h.length >= 6
                                                      ? h.length - 6
                                                      : 0]
                                              : 0;
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${p.overall}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              if (trend != 0)
                                                Tooltip(
                                                  message: Tr.pick(
                                                      '直近5節の総合力の変化',
                                                      'Change over the last 5 matchdays'),
                                                  child: Text(
                                                    trend > 0
                                                        ? '▲$trend'
                                                        : '▼${-trend}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: trend > 0
                                                          ? Colors.green
                                                          : Colors.redAccent,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                      if (!p.isLoan && !p.isLoanedOut) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.description_outlined,
                                            size: 20,
                                          ),
                                          tooltip: Tr.pick(
                                              '契約を操作', 'Contract actions'),
                                          onPressed: () =>
                                              _showContractSheet(context, p),
                                        ),
                                      ],
                                    ],
                                  ),
                            onTap: _compareMode
                                ? () => _toggleSelected(p.id)
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PlayerDetailScreen(playerId: p.id),
                                      ),
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

class _SquadSummaryCard extends StatelessWidget {
  final Team team;

  const _SquadSummaryCard({required this.team});

  @override
  Widget build(BuildContext context) {
    final players = team.players;
    final count = players.length;
    final avgOverall = count == 0
        ? 0
        : (players.fold<int>(0, (s, p) => s + p.overall) / count).round();
    final avgAge = count == 0
        ? 0
        : (players.fold<int>(0, (s, p) => s + p.age) / count).round();
    final wageBill = ContractEngine.weeklyWageBill(team);
    final injured = players.where((p) => p.isInjured).length;
    final attention = players.where(SquadScreen.needsAttention).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          // 6項目を1行に並べると、英語のラベル(Needs attention など)では
          // 幅に収まらない。折り返せるようにして、収まるときは
          // これまでどおり均等配置になるようにする。
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              _SummaryItem(label: Tr.pick('人数', 'Players'), value: '$count'),
              _SummaryItem(
                  label: Tr.pick('平均総合', 'Avg overall'), value: '$avgOverall'),
              _SummaryItem(
                  label: Tr.pick('平均年齢', 'Avg age'),
                  value: Tr.pick('$avgAge歳', '$avgAge')),
              _SummaryItem(
                  label: Tr.pick('週俸', 'Wage'),
                  value: Tr.pick('$wageBill万', '$wageBill')),
              _SummaryItem(
                label: Tr.pick('負傷', 'Injured'),
                value: '$injured',
                valueColor: injured > 0 ? Colors.redAccent : null,
              ),
              _SummaryItem(
                label: Tr.pick('要対応', 'Needs attention'),
                value: '$attention',
                valueColor: attention > 0 ? Colors.orange : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: valueColor),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

/// 出場可能な選手のコンディションと今季成績を1行にまとめたサブ表示。
/// 問題のある値(疲労過多・実戦感覚低下・不満)だけを色で強調する。
class _ConditionLine extends StatelessWidget {
  final Player player;
  final PlayerSeasonStats stats;

  const _ConditionLine({required this.player, required this.stats});

  @override
  Widget build(BuildContext context) {
    Widget cond(String label, int value, bool bad) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            // 日本語は「疲労72」と続けて読めるが、英語は語と数字の間に
            // 空白がないと «Fatigue72» になってしまう。
            Tr.pick('$label$value', '$label $value'),
            style: TextStyle(
              fontSize: 11,
              color: bad ? Colors.redAccent : Colors.grey,
              fontWeight: bad ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );

    // 英語ではラベルが長く1行に収まらないので折り返せるようにする。
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        cond(Tr.pick('疲労', 'Fatigue'), player.fatigue, player.fatigue >= 75),
        cond(Tr.pick('感覚', 'Sharpness'), player.matchSharpness,
            player.matchSharpness < 40),
        cond(Tr.pick('士気', 'Morale'), player.happiness, player.happiness < 40),
        // Wrap の子に Flexible は使えない (FlexParentData を要求してしまう)。
        // 折り返しは Wrap 側が面倒を見るので、そのまま置く。
        Text(
          Tr.pick(
              '今季${stats.appearances}試合${stats.goals}点${stats.averageRating != null ? '・評点${stats.averageRating!.toStringAsFixed(1)}' : ''}',
              "${stats.appearances} apps, ${stats.goals} goals${stats.averageRating != null ? ', avg ${stats.averageRating!.toStringAsFixed(1)}' : ''}"),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LegendRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
