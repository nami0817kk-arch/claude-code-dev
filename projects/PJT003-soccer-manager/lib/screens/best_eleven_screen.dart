import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/best_eleven.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import '../widgets/position_colors.dart';
import '../widgets/position_filter_bar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'player_detail_screen.dart';

/// シーズンごとに選出されたベストイレブン(GK1・DF4・MF4・FW2)の履歴を表示する画面。
class BestElevenScreen extends StatelessWidget {
  const BestElevenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final history = gameState.bestElevenHistory;
    final clubName = gameState.userTeam.name;
    final userTeamId = gameState.save!.userTeamId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('シーズンベストイレブン'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: history.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.groups, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('まだ記録がありません(シーズン終了時に確定します)',
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, i) => _BestElevenCard(
                    seasonEleven: history[i],
                    clubName: clubName,
                    userTeamId: userTeamId),
              ),
      ),
    );
  }
}

class _BestElevenCard extends StatelessWidget {
  final SeasonBestEleven seasonEleven;
  final String clubName;
  final String userTeamId;
  const _BestElevenCard(
      {required this.seasonEleven,
      required this.clubName,
      required this.userTeamId});

  @override
  Widget build(BuildContext context) {
    final byGroup = <PositionGroup, List<BestElevenEntry>>{
      for (final g in PositionGroup.values)
        g: seasonEleven.entries.where((e) => e.group == g).toList(),
    };
    final userPlayerIds =
        context.watch<GameState>().userTeam.players.map((p) => p.id).toSet();
    final userSelections = seasonEleven.entries
        .where((e) =>
            e.teamId != null ? e.teamId == userTeamId : e.teamName == clubName)
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('シーズン${seasonEleven.season}',
                    style: Theme.of(context).textTheme.titleMedium),
                if (userSelections > 0)
                  Text('自クラブから$userSelections名選出',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            for (final g in PositionGroup.values)
              if (byGroup[g]!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(PositionFilterBar.labelFor(g),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: g.color, fontWeight: FontWeight.bold)),
                ),
                for (final e in byGroup[g]!)
                  InkWell(
                    onTap: !userPlayerIds.contains(e.playerId)
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                PlayerDetailScreen(playerId: e.playerId))),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${e.playerName}（${e.teamName}）',
                              style: TextStyle(
                                fontWeight: (e.teamId != null
                                        ? e.teamId == userTeamId
                                        : e.teamName == clubName)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('平均${e.avgRating.toStringAsFixed(1)}',
                                  style: Theme.of(context).textTheme.bodySmall),
                              Text('${e.appearances}試合',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}
