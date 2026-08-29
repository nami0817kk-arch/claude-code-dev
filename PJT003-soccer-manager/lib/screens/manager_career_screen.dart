import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/manager_career_engine.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';

/// 監督としての通算成績・獲得タイトル・指揮したクラブの履歴を表示する画面。
class ManagerCareerScreen extends StatelessWidget {
  const ManagerCareerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final record = gameState.careerRecordSoFar;
    final totalMatches = record.wins + record.draws + record.losses;
    final winRate =
        totalMatches == 0 ? 0 : (record.wins / totalMatches * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('監督キャリア'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('通算成績',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    const Text('進行中のシーズンの成績もここに含まれます',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatColumn(
                            label: '指揮シーズン数', value: '${save.careerSeasons}'),
                        _StatColumn(
                            label: '勝',
                            value: '${record.wins}',
                            color: SemanticColors.positive(context)),
                        _StatColumn(
                            label: '分',
                            value: '${record.draws}',
                            color: Colors.grey),
                        _StatColumn(
                            label: '敗',
                            value: '${record.losses}',
                            color: SemanticColors.negative(context)),
                        _StatColumn(label: '勝率', value: '$winRate%'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('生涯成長',
                            style: Theme.of(context).textTheme.titleMedium),
                        Chip(
                          label: Text('Lv.${gameState.managerCareerLevel}'
                              '${gameState.managerCareerLevel >= ManagerCareerEngine.maxLevel ? ' (MAX)' : ''}'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '通算勝敗・獲得タイトル・実績解除数の積み重ねで監督として'
                      '成長し、選手の成長効率がわずかに上がり続ける',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (gameState.managerCareerLevel <
                        ManagerCareerEngine.maxLevel) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: gameState.managerCareerProgressFraction,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                          '次のレベルまであとXP ${gameState.managerCareerXpToNextLevel}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '選手成長効率 x${gameState.managerCareerGrowthBonus.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: SemanticColors.positive(context),
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('トロフィーキャビネット', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (save.trophyHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('まだタイトルを獲得していません',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              for (final trophy in save.trophyHistory.reversed)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        const Icon(Icons.emoji_events, color: Colors.amber),
                    title: Text(trophy),
                  ),
                ),
            const SizedBox(height: 20),
            Text('指揮したクラブ', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (int i = save.clubHistory.length - 1; i >= 0; i--)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(save.clubHistory[i]),
                  trailing: i == save.clubHistory.length - 1
                      ? const Chip(label: Text('現職'))
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatColumn({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
