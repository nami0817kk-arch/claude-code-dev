import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../l10n/tr.dart';

/// シーズン終了時に一括生成されたユースインテーク候補を選抜する画面。
class YouthIntakeScreen extends StatelessWidget {
  const YouthIntakeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final candidates = gameState.pendingYouthIntake;
    final slotsLeft =
        gameState.maxYouthProspects - gameState.save!.youthProspects.length;

    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('ユースインテーク', 'Youth intake'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                Tr.pick(
                    '今季のアカデミーから${candidates.length}名の新人が入団を希望しています。引き取る選手を選んでください(残り枠: ${slotsLeft.clamp(0, 999)})。',
                    "${candidates.length} youngsters from this year's academy intake want to join. Choose who you take on (places left: ${slotsLeft.clamp(0, 999)})."),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          Expanded(
            child: candidates.isEmpty
                ? Center(
                    child: Text(
                        Tr.pick('選抜は完了しました', 'You have finished choosing')))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: candidates.length,
                    itemBuilder: (context, i) {
                      final p = candidates[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: PlayerFaceAvatar(
                            playerId: p.id,
                            position: p.position,
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            Tr.pick(
                                '${p.age}歳 / 総合 ${p.overall} / 潜在 ${p.potential}',
                                'Age ${p.age} / overall ${p.overall} / potential ${p.potential}'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: Tr.pick('解雇', 'Release'),
                                onPressed: () =>
                                    _confirmRelease(context, p.id, p.name),
                              ),
                              FilledButton(
                                onPressed: slotsLeft <= 0
                                    ? null
                                    : () async {
                                        final ok = await gameState
                                            .keepYouthIntakePlayer(p.id);
                                        ok
                                            ? FeedbackService.success()
                                            : FeedbackService.error();
                                      },
                                child: Text(Tr.pick('引き取る', 'Take him on')),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(Tr.pick('完了', 'Done')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmRelease(BuildContext context, String playerId, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('この新人を解雇しますか？', 'Turn this youngster away?')),
        content: Text(Tr.pick('$nameは入団せず解雇されます。この操作は元に戻せません。',
            '$name will not join the club. This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<GameState>().releaseYouthIntakePlayer(
                    playerId,
                  );
              FeedbackService.tap();
            },
            child: Text(Tr.pick('解雇する', 'Release him')),
          ),
        ],
      ),
    );
  }
}
