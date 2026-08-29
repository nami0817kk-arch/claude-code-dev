import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/player_face_avatar.dart';

/// 自クラブの選手2名を選び、能力値を並べて比較する画面。
class PlayerCompareScreen extends StatelessWidget {
  final String playerAId;
  final String playerBId;

  const PlayerCompareScreen(
      {super.key, required this.playerAId, required this.playerBId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final a = team.players.firstWhere((p) => p.id == playerAId);
    final b = team.players.firstWhere((p) => p.id == playerBId);

    return Scaffold(
      appBar: AppBar(title: const Text('選手比較')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _PlayerHeader(player: a)),
              const SizedBox(width: 8),
              Expanded(child: _PlayerHeader(player: b)),
            ],
          ),
          const Divider(height: 32),
          _CompareRow(label: '総合力', left: a.overall, right: b.overall),
          _CompareRow(label: '攻撃力', left: a.attack, right: b.attack),
          _CompareRow(label: '守備力', left: a.defense, right: b.defense),
          _CompareRow(label: '技術', left: a.technique, right: b.technique),
          _CompareRow(label: 'スタミナ', left: a.stamina, right: b.stamina),
          _CompareRow(label: 'ポテンシャル', left: a.potential, right: b.potential),
          _CompareRow(
              label: '年齢', left: a.age, right: b.age, lowerIsBetter: true),
          _CompareRow(
              label: '週俸(万円)',
              left: a.wage,
              right: b.wage,
              lowerIsBetter: true),
          _CompareRow(
              label: '市場価値(万円)',
              left: a.marketValue,
              right: b.marketValue,
              max: 20000),
        ],
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  final Player player;

  const _PlayerHeader({required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PlayerFaceAvatar(
            playerId: player.id,
            position: player.position,
            size: 56,
            highlighted: true),
        const SizedBox(height: 8),
        Text(player.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall),
        Text(player.position.label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final int left;
  final int right;
  final int max;
  final bool lowerIsBetter;

  const _CompareRow({
    required this.label,
    required this.left,
    required this.right,
    this.max = 99,
    this.lowerIsBetter = false,
  });

  @override
  Widget build(BuildContext context) {
    final leftWins = lowerIsBetter ? left < right : left > right;
    final rightWins = lowerIsBetter ? right < left : right > left;
    final winColor = SemanticColors.positive(context);

    Widget valueText(int value, bool wins) => Text(
          '$value',
          style: TextStyle(
            fontWeight: wins ? FontWeight.bold : FontWeight.normal,
            color: wins ? winColor : null,
            fontSize: 16,
          ),
        );

    final total = (left + right) == 0 ? 1 : (left + right);
    final leftRatio = left / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              valueText(left, leftWins),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        Expanded(
                          flex: (leftRatio * 100).round().clamp(1, 99),
                          child: Container(
                              color: leftWins
                                  ? winColor
                                  : Colors.blueGrey.shade300),
                        ),
                        Expanded(
                          flex: 100 - (leftRatio * 100).round().clamp(1, 99),
                          child: Container(
                              color: rightWins
                                  ? winColor
                                  : Colors.orange.shade300),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              valueText(right, rightWins),
            ],
          ),
        ],
      ),
    );
  }
}
