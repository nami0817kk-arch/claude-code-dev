import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/scout_report_engine.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/club_emblem.dart';
import '../widgets/responsive_body.dart';
import '../widgets/stat_bar.dart';
import '../l10n/tr.dart';

/// アシスタントコーチによる次節対戦相手のスカウティングレポート(試合プレビュー)画面。
class ScoutReportScreen extends StatelessWidget {
  final Team opponent;
  final Team userTeam;

  const ScoutReportScreen({
    super.key,
    required this.opponent,
    required this.userTeam,
  });

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final report = ScoutReportEngine.generateFor(
      opponent: opponent,
      userTeam: userTeam,
    );

    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('スカウティングレポート', 'Scout report'))),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClubEmblem(
                      teamId: opponent.id,
                      teamName: opponent.name,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.opponentName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            Tr.pick('平均総合力: ${report.opponentOverall}',
                                'Average overall: ${report.opponentOverall}'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
                Tr.pick('スタメン想定の平均能力', 'Average attributes of their likely XI'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            StatBar(
                label: Tr.pick('攻撃力', 'Attack'), value: report.opponentAttack),
            StatBar(
                label: Tr.pick('守備力', 'Defence'),
                value: report.opponentDefense),
            StatBar(
                label: Tr.pick('技術', 'Technical'),
                value: report.opponentTechnique),
            StatBar(
                label: Tr.pick('スタミナ', 'Stamina'),
                value: report.opponentStamina),
            const Divider(height: 32),
            if (report.strengths.isNotEmpty) ...[
              Text(Tr.pick('相手の強み', 'Their strengths'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in report.strengths)
                    Chip(
                      label: Text(s),
                      backgroundColor: SemanticColors.negative(context),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (report.weaknesses.isNotEmpty) ...[
              Text(Tr.pick('相手の弱み', 'Their weaknesses'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final w in report.weaknesses)
                    Chip(
                      label: Text(w),
                      backgroundColor: SemanticColors.positive(context),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (report.keyPlayerName != null) ...[
              Text(Tr.pick('注意すべき選手', 'The man to watch'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: Text(report.keyPlayerName!),
                      subtitle: Text(report.keyPlayerDetail ?? ''),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              userTeam.manMarkerId == null
                                  ? Tr.pick('マンマーク: 指名なし',
                                      'Man-marking: nobody assigned')
                                  : Tr.pick(
                                      'マンマーク: ${_playerName(userTeam, userTeam.manMarkerId!)}',
                                      'Man-marking: ${_playerName(userTeam, userTeam.manMarkerId!)}'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _showMarkerPicker(context, gameState, report),
                            child: Text(
                                Tr.pick('マンマークを指名', 'Assign a man-marker')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              Tr.pick('アシスタントコーチからの提言', "Your assistant's view"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline),
                        const SizedBox(width: 12),
                        Expanded(child: Text(report.recommendation)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.style_outlined, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            report.counterStyle == null
                                ? Tr.pick(
                                    '予想スタイル: ${report.opponentStyle.label}。型のない相手なので、こちらの得意な形で戦えます。',
                                    'Expected style: ${report.opponentStyle.label}. They have no fixed shape, so you can play your own game.')
                                : Tr.pick(
                                    '予想スタイル: ${report.opponentStyle.label}。相性で有利を取るなら「${report.counterStyle!.label}」が刺さります。',
                                    'Expected style: ${report.opponentStyle.label}. To get the matchup in your favour, ${report.counterStyle!.label} hurts them.'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _playerName(Team team, String playerId) {
    for (final p in team.players) {
      if (p.id == playerId) return p.name;
    }
    return Tr.pick('(退団済み)', ' (has left the club)');
  }

  void _showMarkerPicker(
    BuildContext context,
    GameState gameState,
    ScoutReport report,
  ) {
    final candidates = userTeam.players
        .where(
          (p) =>
              p.position.group == PositionGroup.def ||
              p.position.group == PositionGroup.mid,
        )
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                Tr.pick('${report.keyPlayerName}へのマンマーク役を選択',
                    'Pick who man-marks ${report.keyPlayerName}'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              title: Text(Tr.pick('指名を解除する', 'Clear the assignment')),
              onTap: () {
                gameState.setManMarker(null);
                Navigator.pop(ctx);
              },
            ),
            for (final p in candidates)
              ListTile(
                title: Text(p.name),
                subtitle: Text(Tr.pick('${p.position.label} / 総合 ${p.overall}',
                    '${p.position.label} / overall ${p.overall}')),
                trailing: userTeam.manMarkerId == p.id
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
                onTap: () {
                  gameState.setManMarker(p.id);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}
