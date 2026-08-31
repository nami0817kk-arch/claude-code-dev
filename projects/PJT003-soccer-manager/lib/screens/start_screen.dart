import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league_theme.dart';
import '../models/save_game.dart';
import '../state/game_state.dart';
import '../widgets/busy_overlay.dart';
import 'main_shell.dart';
import '../l10n/l10n_ext.dart';
import '../l10n/tr.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late Future<List<SaveSlotSummary>> _slotsFuture;

  @override
  void initState() {
    super.initState();
    _slotsFuture = _loadSlots();
  }

  Future<List<SaveSlotSummary>> _loadSlots() {
    return context.read<GameState>().listSaveSlots();
  }

  void _refreshSlots() {
    setState(() => _slotsFuture = _loadSlots());
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    if (!gameState.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BusyOverlay(
      visible: gameState.isBusy,
      label: Tr.pick('クラブを創設しています…', 'Founding your club…'),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.appTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.startTagline,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FutureBuilder<List<SaveSlotSummary>>(
                    future: _slotsFuture,
                    builder: (context, snapshot) {
                      final slots = snapshot.data;
                      if (slots == null) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        );
                      }
                      return Column(
                        children: [
                          for (final slot in slots) ...[
                            _SlotCard(
                              slot: slot,
                              onContinue: () => _continueSlot(context, slot),
                              onCreate: () => _createInSlot(context, slot),
                              onDelete: () => _confirmDeleteSlot(context, slot),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueSlot(BuildContext context, SaveSlotSummary slot) async {
    final gameState = context.read<GameState>();
    try {
      await gameState.loadSlot(slot.slot);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(Tr.pick(
                'セーブデータの読み込みに失敗しました', 'The save could not be loaded'))));
      }
      return;
    }
    if (context.mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  Future<void> _createInSlot(BuildContext context, SaveSlotSummary slot) async {
    final result = await showDialog<_NewClubInput>(
      context: context,
      builder: (ctx) => _NewClubDialog(slotLabel: slot.slot + 1),
    );
    if (result == null || !context.mounted) return;
    final gameState = context.read<GameState>();
    try {
      await gameState.loadSlot(slot.slot);
      await gameState.startNewGame(
        result.clubName,
        theme: result.theme,
        difficulty: result.difficulty,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(Tr.pick('クラブの作成に失敗しました。もう一度お試しください',
                  'The club could not be created. Please try again'))),
        );
      }
      return;
    }
    if (context.mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  void _confirmDeleteSlot(BuildContext context, SaveSlotSummary slot) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.startDeleteSlot(slot.slot + 1)),
        content: Text(Tr.pick('「${slot.clubName}」のセーブデータは完全に削除されます。',
            'The save for "${slot.clubName}" will be deleted for good.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<GameState>().deleteSlot(slot.slot);
              if (mounted) _refreshSlots();
            },
            child: Text(Tr.pick('削除する', 'Delete')),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final SaveSlotSummary slot;
  final VoidCallback onContinue;
  final VoidCallback onCreate;
  final VoidCallback onDelete;

  const _SlotCard({
    required this.slot,
    required this.onContinue,
    required this.onCreate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: slot.hasSave
            ? Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.startSlotLabel(slot.slot + 1),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          slot.clubName!,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          Tr.pick(
                              '第${slot.season ?? 1}シーズン${slot.divisionTier != null && slot.divisionTier != 1 ? ' ・ ${slot.divisionTier}部' : ''}',
                              "Season ${slot.season ?? 1}${slot.divisionTier != null && slot.divisionTier != 1 ? ' · tier ${slot.divisionTier}' : ''}"),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: Tr.pick('削除', 'Delete'),
                  ),
                  FilledButton(
                      onPressed: onContinue,
                      child: Text(Tr.pick('続ける', 'Continue'))),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.startSlotLabel(slot.slot + 1),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          context.l10n.startEmptySlot,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // 言語によってラベルの長さが変わる (日本語より英語が長い)。
                  // ボタンをFlexibleにすると行幅を左右で等分してしまい、
                  // 英語ラベルではボタンが内容より狭く潰されて左右の余白が
                  // 消え、文字が枠線に接してしまう。ボタンは必要な幅を
                  // そのまま取らせ、代わりに左のテキスト列(Expanded)を
                  // 縮ませる。省略指定は極端に長い訳語への保険。
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: Text(
                      context.l10n.startCreateClub,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NewClubInput {
  final String clubName;
  final LeagueTheme theme;
  final GameDifficulty difficulty;
  _NewClubInput(this.clubName, this.theme, this.difficulty);
}

class _NewClubDialog extends StatefulWidget {
  final int slotLabel;
  const _NewClubDialog({required this.slotLabel});

  @override
  State<_NewClubDialog> createState() => _NewClubDialogState();
}

class _NewClubDialogState extends State<_NewClubDialog> {
  final _controller = TextEditingController();
  LeagueTheme _theme = LeagueTheme.england;
  GameDifficulty _difficulty = GameDifficulty.normal;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.startNewClubIn(widget.slotLabel)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: context.l10n.startClubNameLabel,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(context.l10n.startLeagueLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LeagueTheme.values
                  .map(
                    (theme) => ChoiceChip(
                      label: Text('${theme.label}（${theme.flavorLabel}）'),
                      selected: _theme == theme,
                      onSelected: (_) => setState(() => _theme = theme),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(context.l10n.startDifficultyLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GameDifficulty.values
                  .map(
                    (d) => ChoiceChip(
                      label: Text(d.label),
                      selected: _difficulty == d,
                      onSelected: (_) => setState(() => _difficulty = d),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
            Text(
              _difficulty.description,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, _NewClubInput(name, _theme, _difficulty));
          },
          child: Text(context.l10n.startCreate),
        ),
      ],
    );
  }
}
