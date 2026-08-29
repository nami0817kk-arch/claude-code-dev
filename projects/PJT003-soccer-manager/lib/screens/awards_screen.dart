import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'player_detail_screen.dart';

/// シーズンごとに確定した個人タイトル(得点王・年間MVP)の履歴を表示する画面。
class AwardsScreen extends StatelessWidget {
  const AwardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final awards = gameState.seasonAwards.reversed.toList();
    final clubName = gameState.userTeam.name;
    final userTeamId = gameState.save!.userTeamId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('個人タイトル'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: awards.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('まだ表彰記録がありません(シーズン終了時に確定します)',
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: awards.length,
                itemBuilder: (context, i) {
                  final a = awards[i];
                  // teamIdを持たない旧セーブのレコードのみ、クラブ名の一致で代用する。
                  final scorerIsOwnClub = a.topScorerTeamId != null
                      ? a.topScorerTeamId == userTeamId
                      : a.topScorerTeamName == clubName;
                  final mvpIsOwnClub = a.mvpTeamId != null
                      ? a.mvpTeamId == userTeamId
                      : a.mvpTeamName == clubName;
                  final gloveIsOwnClub = a.goldenGloveTeamId == userTeamId;
                  String? routablePlayerId(String? id) {
                    if (id == null) return null;
                    return gameState.userTeam.players.any((p) => p.id == id)
                        ? id
                        : null;
                  }

                  final scorerPlayerId =
                      scorerIsOwnClub ? routablePlayerId(a.topScorerId) : null;
                  final mvpPlayerId =
                      mvpIsOwnClub ? routablePlayerId(a.mvpId) : null;
                  final glovePlayerId =
                      gloveIsOwnClub ? routablePlayerId(a.goldenGloveId) : null;
                  void openPlayer(String id) =>
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PlayerDetailScreen(playerId: id)));
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('シーズン${a.season}',
                              style: Theme.of(context).textTheme.titleMedium),
                          const Divider(height: 20),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.sports_soccer,
                                color: Colors.green),
                            title: Row(
                              children: [
                                const Text('得点王'),
                                if (scorerIsOwnClub) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.shield,
                                      size: 14, color: Colors.blueAccent),
                                ],
                              ],
                            ),
                            subtitle: a.topScorerName == null
                                ? const Text('該当者なし')
                                : Text(
                                    '${a.topScorerName}（${a.topScorerTeamName}） - ${a.topScorerGoals}得点'),
                            onTap: scorerPlayerId == null
                                ? null
                                : () => openPlayer(scorerPlayerId),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.emoji_events,
                                color: Colors.amber),
                            title: Row(
                              children: [
                                const Text('年間MVP'),
                                if (mvpIsOwnClub) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.shield,
                                      size: 14, color: Colors.blueAccent),
                                ],
                              ],
                            ),
                            subtitle: a.mvpName == null
                                ? const Text('該当者なし')
                                : Text('${a.mvpName}（${a.mvpTeamName}）'),
                            onTap: mvpPlayerId == null
                                ? null
                                : () => openPlayer(mvpPlayerId),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading:
                                const Icon(Icons.sports, color: Colors.indigo),
                            title: Row(
                              children: [
                                const Text('ゴールデングラブ'),
                                if (gloveIsOwnClub) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.shield,
                                      size: 14, color: Colors.blueAccent),
                                ],
                              ],
                            ),
                            subtitle: a.goldenGloveName == null
                                ? const Text('該当者なし')
                                : Text(
                                    '${a.goldenGloveName}（${a.goldenGloveTeamName}） - '
                                    '無失点${a.goldenGloveCleanSheets}試合'),
                            onTap: glovePlayerId == null
                                ? null
                                : () => openPlayer(glovePlayerId),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
