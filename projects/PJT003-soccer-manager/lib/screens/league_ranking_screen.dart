import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/awards_engine.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';

/// リーグの個人ランキング(得点・アシスト)画面。シーズン終了を待たず、
/// いつでも現時点の順位を確認できる(得点王・MVPの表彰自体は従来通り
/// シーズン終了時に確定する)。
class LeagueRankingScreen extends StatelessWidget {
  const LeagueRankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final league = gameState.save?.league;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(Tr.pick('リーグランキング', 'League rankings')),
          leading: const BackButton(),
          actions: const [QuickAccessMenuButton()],
          bottom: TabBar(
            tabs: [
              Tab(text: Tr.pick('得点', 'Goals')),
              Tab(text: Tr.pick('アシスト', 'Assists')),
            ],
          ),
        ),
        drawer: const QuickAccessDrawer(),
        body: league == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _RankingList(
                    entries: AwardsEngine.goalRanking(league),
                    countLabel: Tr.pick('得点', 'Goals'),
                    gameState: gameState,
                  ),
                  _RankingList(
                    entries: AwardsEngine.assistRanking(league),
                    countLabel: Tr.pick('アシスト', 'Assists'),
                    gameState: gameState,
                  ),
                ],
              ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  final List<PlayerRankingEntry> entries;
  final String countLabel;
  final GameState gameState;

  const _RankingList({
    required this.entries,
    required this.countLabel,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            Tr.pick('まだ記録がありません。\n節を進めると現時点のランキングが表示されます。',
                'Nothing recorded yet.\nPlay a few matchdays and the standings appear here.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    final league = gameState.save!.league;
    final userTeamId = gameState.userTeam.id;
    String teamNameOf(String teamId) {
      for (final t in league.teams) {
        if (t.id == teamId) return t.name;
      }
      return '---';
    }

    return ResponsiveBody(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final e = entries[index];
          final isUser = e.teamId == userTeamId;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color:
                isUser ? Theme.of(context).colorScheme.primaryContainer : null,
            child: ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor:
                    index < 3 ? Colors.amber.shade700 : Colors.grey.shade400,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              title: Text(
                e.name,
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                teamNameOf(e.teamId),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                '${e.count} $countLabel',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}
