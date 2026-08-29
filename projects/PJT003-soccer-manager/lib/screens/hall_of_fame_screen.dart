import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';

/// 高齢により正式に引退した選手(殿堂)の一覧画面。契約満了で単に自由契約に
/// なった選手とは異なり、再契約はできない。
class HallOfFameScreen extends StatelessWidget {
  const HallOfFameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final legends = [...gameState.save!.retiredLegends]
      ..sort((a, b) => b.careerGoals.compareTo(a.careerGoals));

    return Scaffold(
      appBar: AppBar(
        title: const Text('殿堂'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: legends.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('まだ引退した選手はいません', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: legends.length,
                itemBuilder: (context, i) => _LegendCard(player: legends[i]),
              ),
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  final Player player;
  const _LegendCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading:
            PlayerFaceAvatar(playerId: player.id, position: player.position),
        title: Text(player.name),
        subtitle: Text(
            '${player.position.fullLabel} ・ 引退時${player.age}歳 ・ 総合${player.overall}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${player.careerAppearances}試合',
                style: const TextStyle(fontSize: 12)),
            Text('${player.careerGoals}得点',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
