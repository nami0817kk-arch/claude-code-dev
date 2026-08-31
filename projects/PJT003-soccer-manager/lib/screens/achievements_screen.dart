import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';

/// 実績(アチーブメント)一覧画面。カテゴリごとに達成済み・未達成の実績を
/// まとめて表示し、長期的なやり込み目標を可視化する。
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final all = gameState.allAchievements;
    final unlockedCount = gameState.unlockedAchievementCount;
    const categories = AchievementCategory.values;

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('実績', 'Achievement')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Colors.amber.shade700,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Tr.pick('達成状況', 'Progress'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Tr.pick('${all.length}件中 $unlockedCount件達成',
                                  '$unlockedCount of ${all.length} unlocked'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value:
                                  all.isEmpty ? 0 : unlockedCount / all.length,
                              strokeWidth: 4,
                              backgroundColor: Colors.grey.shade300,
                            ),
                            Text(
                              all.isEmpty
                                  ? '0%'
                                  : '${(unlockedCount / all.length * 100).round()}%',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final category in categories)
                    _CategorySection(
                      category: category,
                      achievements:
                          all.where((a) => a.category == category).toList(),
                      gameState: gameState,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final AchievementCategory category;
  final List<Achievement> achievements;
  final GameState gameState;

  const _CategorySection({
    required this.category,
    required this.achievements,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            category.label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (final a in achievements)
          _AchievementTile(achievement: a, gameState: gameState),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final GameState gameState;

  const _AchievementTile({required this.achievement, required this.gameState});

  @override
  Widget build(BuildContext context) {
    final unlocked = gameState.isAchievementUnlocked(achievement.id);
    final season = gameState.achievementUnlockedSeason(achievement.id);
    // 未達成の閾値型実績には「現在値/目標」のプログレスバーを添えて、
    // あとどれくらいで達成できるのかを一目で分かるようにする。
    (int, int)? progress;
    if (!unlocked && achievement.progress != null && gameState.save != null) {
      progress = achievement.progress!(gameState.save!, gameState.userTeam);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: unlocked ? null : Theme.of(context).colorScheme.surfaceContainer,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              unlocked ? Colors.amber.shade700 : Colors.grey.shade400,
          child: Icon(
            unlocked ? Icons.emoji_events : Icons.lock,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          achievement.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: unlocked ? null : Colors.grey.shade600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              unlocked && season != null
                  ? Tr.pick('${achievement.description}(シーズン$season達成)',
                      '${achievement.description} (unlocked in season $season)')
                  : achievement.description,
              style: TextStyle(
                color: unlocked ? Colors.grey.shade700 : Colors.grey,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress.$2 <= 0
                            ? 0
                            : (progress.$1 / progress.$2).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${progress.$1.clamp(0, progress.$2)} / ${progress.$2}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
