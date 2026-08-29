import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/contract_engine.dart';
import '../models/player.dart';
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

enum SquadSortOption { position, overall, age, potential, wage }

extension on SquadSortOption {
  String get label => switch (this) {
        SquadSortOption.position => 'ポジション順',
        SquadSortOption.overall => '総合力',
        SquadSortOption.age => '年齢(若い順)',
        SquadSortOption.potential => 'ポテンシャル',
        SquadSortOption.wage => '週俸',
      };
}

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});

  /// フィルタ・検索・並び替えを適用した選手リストを返す。UIから切り離してテスト可能にしてある。
  static List<Player> filterAndSort(
    List<Player> all, {
    PositionGroup? group,
    String query = '',
    SquadSortOption sort = SquadSortOption.position,
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
                    '週俸: ${p.wage}万円 / ${ContractEngine.yearsLabel(p.contractYearsRemaining)}'),
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
                                        ok ? '契約を更新しました' : '契約を更新できませんでした')),
                              );
                            }
                          },
                    child: Text(
                      '契約更新する（基本$renewalCost万円 + サインボーナス$signingBonus万円 / '
                      '+40週 / 新出場手当$newAppearanceFee万円）',
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
                            builder: (_) => PlayerDetailScreen(playerId: p.id)),
                      );
                    },
                    child: const Text('週俸交渉・放出など詳しい操作を開く'),
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
        title: const Text('アイコンの意味'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendRow(
                icon: Icons.swap_horiz,
                color: Colors.indigo,
                label: 'ローンで加入中の選手'),
            _LegendRow(
                icon: Icons.sentiment_dissatisfied,
                color: Colors.redAccent,
                label: '移籍を希望している'),
            _LegendRow(
                icon: Icons.flag, color: Colors.blueAccent, label: '代表召集中'),
            _LegendRow(
                icon: Icons.shield,
                color: Colors.amber,
                label: '「C」=キャプテン / 「VC」=副キャプテン(選手詳細画面から指名)'),
            _LegendRow(
                icon: Icons.block,
                color: Colors.redAccent,
                label: '出場停止中(警告累積または退場)'),
            _LegendRow(
                icon: Icons.flight_takeoff,
                color: Colors.deepPurple,
                label: '他クラブへローン放出中'),
            _LegendRow(
                icon: Icons.sell_outlined,
                color: Colors.orange,
                label: '移籍リストに登録中'),
            _LegendRow(
                icon: Icons.battery_alert,
                color: Colors.orange,
                label: '疲労が大きい'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
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
    );
    final lastRatings = gameState.save!.league
        .lastPlayedFixtureFor(team.id)
        ?.result
        ?.playerRatings;

    return Scaffold(
      appBar: AppBar(
        title: Text(_compareMode ? '選手を2人選択' : 'スカッド'),
        actions: [
          if (!_compareMode) ...[
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'アイコンの意味',
              onPressed: () => _showIconLegend(context),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: '用語集',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GlossaryScreen())),
            ),
            PopupMenuButton<SquadSortOption>(
              icon: const Icon(Icons.sort),
              tooltip: '並び替え',
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
            tooltip: _compareMode ? '比較モードを終了' : '選手を比較',
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
                            playerAId: _selected[0], playerBId: _selected[1]),
                      ),
                    )
                    .then((_) => _toggleCompareMode());
              },
              icon: const Icon(Icons.compare_arrows),
              label: const Text('比較する'),
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
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
            Expanded(
              child: players.isEmpty
                  ? const Center(child: Text('該当する選手がいません'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: players.length,
                      itemBuilder: (context, i) {
                        final p = players[i];
                        final isStarting = team.startingXI.contains(p.id);
                        final isSelected = _selected.contains(p.id);
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
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
                                borderRadius: BorderRadius.circular(16)),
                            leading: _compareMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleSelected(p.id))
                                : PlayerFaceAvatar(
                                    playerId: p.id,
                                    position: p.position,
                                    size: 40,
                                    highlighted: isStarting),
                            title: Row(
                              children: [
                                Flexible(
                                    child: Text(p.name,
                                        overflow: TextOverflow.ellipsis)),
                                if (team.captainId == p.id) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'キャプテン',
                                    child: CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Colors.amber.shade700,
                                      child: const Text('C',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                                if (team.viceCaptainId == p.id) ...[
                                  const SizedBox(width: 6),
                                  const Tooltip(
                                    message: '副キャプテン',
                                    child: CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Colors.blueGrey,
                                      child: Text('VC',
                                          style: TextStyle(
                                              fontSize: 8,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                                if (p.isLoan) ...[
                                  const SizedBox(width: 6),
                                  const Tooltip(
                                    message: 'ローン加入中',
                                    child: Icon(Icons.swap_horiz,
                                        size: 16, color: Colors.indigo),
                                  ),
                                ],
                                if (p.wantsTransfer) ...[
                                  const SizedBox(width: 6),
                                  const Tooltip(
                                    message: '移籍を希望している',
                                    child: Icon(Icons.sentiment_dissatisfied,
                                        size: 16, color: Colors.redAccent),
                                  ),
                                ],
                                if (p.isOnInternationalDuty) ...[
                                  const SizedBox(width: 6),
                                  const Tooltip(
                                    message: '代表召集中',
                                    child: Icon(Icons.flag,
                                        size: 16, color: Colors.blueAccent),
                                  ),
                                ],
                                if (p.isSuspended) ...[
                                  const SizedBox(width: 6),
                                  const Tooltip(
                                    message: '出場停止中',
                                    child: Icon(Icons.block,
                                        size: 16, color: Colors.redAccent),
                                  ),
                                ],
                                if (p.isLoanedOut) ...[
                                  const SizedBox(width: 6),
                                  const Tooltip(
                                    message: 'ローンで放出中',
                                    child: Icon(Icons.flight_takeoff,
                                        size: 16, color: Colors.deepPurple),
                                  ),
                                ],
                                if (p.isTransferListed) ...[
                                  const SizedBox(width: 6),
                                  const Tooltip(
                                    message: '移籍リストに登録済み',
                                    child: Icon(Icons.sell_outlined,
                                        size: 16, color: Colors.orange),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              p.isInjured
                                  ? '負傷中（あと${p.injuryWeeks}週）'
                                  : p.isSuspended
                                      ? '出場停止（あと${p.suspendedMatches}試合）'
                                      : p.isOnInternationalDuty
                                          ? '代表召集中（あと${p.internationalDutyWeeksRemaining}週）'
                                          : p.isLoanedOut
                                              ? '${p.loanedOutToClubName}へローン放出中（あと${p.loanedOutWeeksRemaining}週）'
                                              : '${p.age}歳 / ${p.position.label} / 総合 ${p.overall}'
                                                  '${lastRatings?[p.id] != null ? ' / 前節 ${lastRatings![p.id]!.toStringAsFixed(1)}' : ''}'
                                                  '${p.isLoan ? '' : ' / ${ContractEngine.yearsLabel(p.contractYearsRemaining)}'}',
                              style: (p.isInjured ||
                                      p.isSuspended ||
                                      p.isOnInternationalDuty ||
                                      p.isLoanedOut)
                                  ? const TextStyle(color: Colors.redAccent)
                                  : null,
                            ),
                            trailing: _compareMode
                                ? Text('${p.overall}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium)
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      p.fatigue > 70
                                          ? const Icon(Icons.battery_alert,
                                              color: Colors.orange)
                                          : Text('${p.overall}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                      if (!p.isLoan && !p.isLoanedOut) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.description_outlined,
                                              size: 20),
                                          tooltip: '契約を操作',
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
                                          builder: (_) => PlayerDetailScreen(
                                              playerId: p.id)),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryItem(label: '人数', value: '$count'),
              _SummaryItem(label: '平均総合', value: '$avgOverall'),
              _SummaryItem(label: '平均年齢', value: '$avgAge歳'),
              _SummaryItem(label: '週俸総額', value: '$wageBill万円'),
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

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LegendRow(
      {required this.icon, required this.color, required this.label});

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
