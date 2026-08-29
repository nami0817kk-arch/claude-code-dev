import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/save_game.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/position_filter_bar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';

enum TransferSortOption { overall, potential, marketValue, age }

extension on TransferSortOption {
  String get label => switch (this) {
        TransferSortOption.overall => '総合力',
        TransferSortOption.potential => 'ポテンシャル',
        TransferSortOption.marketValue => '移籍金(安い順)',
        TransferSortOption.age => '年齢(若い順)',
      };
}

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  /// フィルタ・検索・並び替えを適用した移籍市場選手リストを返す。UIから切り離してテスト可能にしてある。
  static List<Player> filterAndSort(
    List<Player> all, {
    PositionGroup? group,
    String query = '',
    TransferSortOption sort = TransferSortOption.overall,
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
      case TransferSortOption.overall:
        players.sort((a, b) => b.overall.compareTo(a.overall));
        break;
      case TransferSortOption.potential:
        players.sort((a, b) => b.potential.compareTo(a.potential));
        break;
      case TransferSortOption.marketValue:
        players.sort((a, b) => a.marketValue.compareTo(b.marketValue));
        break;
      case TransferSortOption.age:
        players.sort((a, b) => a.age.compareTo(b.age));
        break;
    }
    return players;
  }

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with SingleTickerProviderStateMixin {
  PositionGroup? _filter;
  TransferSortOption _sort = TransferSortOption.overall;
  final _searchController = TextEditingController();
  String _query = '';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final squadFull = gameState.userTeam.players.length >= maxSquadSize;
    final players = TransferScreen.filterAndSort(
      gameState.transferMarket,
      group: _filter,
      query: _query,
      sort: _sort,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('移籍市場'),
        leading: const BackButton(),
        actions: [
          PopupMenuButton<TransferSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: '並び替え',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => [
              for (final option in TransferSortOption.values)
                PopupMenuItem(value: option, child: Text(option.label)),
            ],
          ),
          const QuickAccessMenuButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: '市場'),
            Tab(text: 'フリーエージェント (${gameState.freeAgents.length})'),
          ],
        ),
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMarketTab(context, gameState, save, squadFull, players),
            _buildFreeAgentTab(context, gameState, squadFull),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketTab(BuildContext context, GameState gameState,
      SaveGame save, bool squadFull, List<Player> players) {
    final windowOpen = gameState.isTransferWindowOpen;
    return Column(
      children: [
        _TransferWindowBanner(
            open: windowOpen, label: gameState.transferWindowStatusLabel),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('資金: ${save.budget}万円',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('スカッド: ${gameState.userTeam.players.length}/$maxSquadSize'),
            ],
          ),
        ),
        if (squadFull)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('スカッドが上限のため、獲得するには誰かを放出してください。',
                style: TextStyle(color: Colors.orange)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PositionFilterBar(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
              ? const Center(child: Text('該当する選手はいません'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: players.length,
                  itemBuilder: (context, i) {
                    final p = players[i];
                    final affordable = save.budget >= p.marketValue;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: PlayerFaceAvatar(
                            playerId: p.id, position: p.position),
                        title: Row(
                          children: [
                            Flexible(
                                child: Text(p.name,
                                    overflow: TextOverflow.ellipsis)),
                            if (!affordable) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: '資金不足で獲得できません',
                                child: Icon(Icons.lock_outline,
                                    size: 14, color: Colors.grey.shade600),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${p.originClubName ?? '所属不明'} / ${p.age}歳 / ${p.position.label} / '
                          '総合 ${p.overall} / 潜在 ${p.potential} / 移籍金 ${p.marketValue}万',
                        ),
                        trailing: FilledButton(
                          onPressed: (squadFull || !windowOpen)
                              ? null
                              : () => _showAcquireSheet(context, p),
                          child: const Text('獲得する'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFreeAgentTab(
      BuildContext context, GameState gameState, bool squadFull) {
    final freeAgents = [...gameState.freeAgents]
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final windowOpen = gameState.isTransferWindowOpen;

    return Column(
      children: [
        _TransferWindowBanner(
            open: windowOpen, label: gameState.transferWindowStatusLabel),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '移籍金なし・週俸のみで獲得できる選手です。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
        if (squadFull)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('スカッドが上限のため、獲得するには誰かを放出してください。',
                style: TextStyle(color: Colors.orange)),
          ),
        Expanded(
          child: freeAgents.isEmpty
              ? const Center(child: Text('現在フリーエージェントはいません'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: freeAgents.length,
                  itemBuilder: (context, i) {
                    final p = freeAgents[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: PlayerFaceAvatar(
                            playerId: p.id, position: p.position),
                        title: Text(p.name, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${p.age}歳 / ${p.position.label} / 総合 ${p.overall} / 週俸 ${p.wage}万円',
                        ),
                        trailing: FilledButton(
                          onPressed: (squadFull || !windowOpen)
                              ? null
                              : () => _signFreeAgent(context, p),
                          child: const Text('獲得する'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _signFreeAgent(BuildContext context, Player player) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.signFreeAgent(player.id);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '${player.name}と契約しました' : '契約できませんでした')),
      );
    }
  }

  void _showAcquireSheet(BuildContext context, Player player) {
    final gameState = context.read<GameState>();
    final save = gameState.save!;
    final total = player.marketValue;
    final downPayment = (total * 0.3).round();
    final loanFee = (total * GameState.loanFeeRatioPercent / 100).round();
    final buyOptionFee = (total * GameState.loanBuyOptionRatio).round();

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${player.name}を獲得',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.payments),
                title: const Text('一括で獲得'),
                subtitle: Text('$total万円を即座に支払う'),
                enabled: save.budget >= total,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(context, () => gameState.buyPlayer(player.id),
                      player.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_week),
                title: const Text('分割払いで獲得'),
                subtitle: Text('頭金$downPayment万円 + 残額を4週で均等払い'),
                enabled: save.budget >= downPayment,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(
                      context,
                      () => gameState.buyPlayerOnInstallments(player.id),
                      player.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('ローンで獲得'),
                subtitle: Text(
                    '契約金$loanFee万円・週俸6割・${GameState.loanDurationWeeks}週で契約終了'),
                enabled: save.budget >= loanFee,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(context, () => gameState.signLoanPlayer(player.id),
                      player.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.request_quote),
                title: const Text('買取オプション付きローンで獲得'),
                subtitle: Text(
                    '契約金$loanFee万円・週俸6割・ローン期間中いつでも$buyOptionFee万円で完全移籍化可能'),
                enabled: save.budget >= loanFee,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(
                      context,
                      () => gameState.signLoanPlayer(player.id,
                          withBuyOption: true),
                      player.name);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acquire(
      BuildContext context, Future<bool> Function() action, String name) async {
    final ok = await action();
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '$nameを獲得しました' : '獲得できませんでした')),
      );
    }
  }
}

/// 移籍ウィンドウの開閉状態を示すバナー。閉じている間は選手の獲得・放出ができない。
class _TransferWindowBanner extends StatelessWidget {
  final bool open;
  final String label;
  const _TransferWindowBanner({required this.open, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = open ? Colors.green.shade700 : Colors.grey.shade700;
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(open ? Icons.lock_open : Icons.lock, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
