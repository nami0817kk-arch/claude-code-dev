import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/season_award.dart';
import '../models/season_record.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';

/// シーズンごとの最終成績(順位・勝敗・昇降格・カップ優勝歴)を振り返る画面。
class SeasonHistoryScreen extends StatelessWidget {
  const SeasonHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final history = gameState.seasonHistory;
    final awards = gameState.save!.seasonAwards;
    SeasonAward? awardFor(int season) {
      for (final a in awards) {
        if (a.season == season) return a;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('シーズン成績アーカイブ', 'Season archive')),
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
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        Tr.pick('まだ記録がありません(シーズン終了時に確定します)',
                            'Nothing recorded yet. Seasons are archived when they finish'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, i) => _SeasonRecordCard(
                  record: history[i],
                  award: awardFor(history[i].season),
                ),
              ),
      ),
    );
  }
}

class _SeasonRecordCard extends StatelessWidget {
  final SeasonRecord record;
  final SeasonAward? award;
  const _SeasonRecordCard({required this.record, this.award});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  Tr.pick('シーズン${record.season}', 'Season ${record.season}'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                if (record.wonLeague)
                  _Badge(
                      label: Tr.pick('優勝', 'Champions'), color: Colors.amber),
                if (record.promoted)
                  _Badge(
                      label: Tr.pick('昇格', 'Promote'),
                      color: SemanticColors.positive(context)),
                if (record.relegated)
                  _Badge(
                      label: Tr.pick('降格', 'Relegated'),
                      color: SemanticColors.negative(context)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '${record.leagueName}${record.divisionTier != 1 ? '(${record.divisionTier}部)' : ''} ${record.finalRank}位 / ${record.teamCount}クラブ中',
                  "${record.leagueName}${record.divisionTier != 1 ? ' (tier ${record.divisionTier})' : ''} — ${record.finalRank} of ${record.teamCount}"),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              Tr.pick(
                  '${record.played}試合 ${record.won}勝${record.draw}分${record.lost}敗 (得点差 ${record.goalDiff >= 0 ? '+' : ''}${record.goalDiff}) 勝点${record.points}',
                  "P${record.played} W${record.won} D${record.draw} L${record.lost} (GD ${record.goalDiff >= 0 ? '+' : ''}${record.goalDiff}), ${record.points} pts"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (record.cupsWon.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: record.cupsWon
                    .map(
                      (name) => Chip(
                        avatar: const Icon(
                          Icons.emoji_events,
                          size: 16,
                          color: Colors.amber,
                        ),
                        label: Text(Tr.pick('$name 優勝', '$name winners')),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (award != null &&
                (award!.topScorerName != null ||
                    award!.mvpName != null ||
                    award!.goldenGloveName != null)) ...[
              const Divider(height: 20),
              if (award!.topScorerName != null)
                Text(
                  Tr.pick(
                      '得点王: ${award!.topScorerName}（${award!.topScorerTeamName ?? '不明'}） ${award!.topScorerGoals}得点',
                      "Top scorer: ${award!.topScorerName} (${award!.topScorerTeamName ?? 'unknown'}) — ${award!.topScorerGoals} goals"),
                  style: const TextStyle(fontSize: 12),
                ),
              if (award!.mvpName != null)
                Text(
                  Tr.pick(
                      'シーズンMVP: ${award!.mvpName}（${award!.mvpTeamName ?? '不明'}）',
                      "Player of the season: ${award!.mvpName} (${award!.mvpTeamName ?? 'unknown'})"),
                  style: const TextStyle(fontSize: 12),
                ),
              if (award!.goldenGloveName != null)
                Text(
                  Tr.pick(
                      'ゴールデングラブ: ${award!.goldenGloveName}（${award!.goldenGloveTeamName ?? '不明'}） ${award!.goldenGloveCleanSheets}試合無失点',
                      "Golden Glove: ${award!.goldenGloveName} (${award!.goldenGloveTeamName ?? 'unknown'}) — ${award!.goldenGloveCleanSheets} clean sheets"),
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
