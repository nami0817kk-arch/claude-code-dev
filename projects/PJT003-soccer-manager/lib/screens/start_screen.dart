import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league_theme.dart';
import '../state/game_state.dart';
import '../widgets/busy_overlay.dart';
import 'main_shell.dart';

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
      label: 'クラブを創設しています…',
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
                    'サッカー経営マネージャー',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'クラブを率いてリーグ優勝を目指そう',
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('セーブデータの読み込みに失敗しました')));
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
      await gameState.startNewGame(result.clubName, theme: result.theme);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('クラブの作成に失敗しました。もう一度お試しください')),
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
        title: Text('スロット${slot.slot + 1}を削除しますか？'),
        content: Text('「${slot.clubName}」のセーブデータは完全に削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<GameState>().deleteSlot(slot.slot);
              if (mounted) _refreshSlots();
            },
            child: const Text('削除する'),
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
                          'スロット${slot.slot + 1}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          slot.clubName!,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '第${slot.season ?? 1}シーズン'
                          '${slot.divisionTier != null && slot.divisionTier != 1 ? ' ・ ${slot.divisionTier}部' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '削除',
                  ),
                  FilledButton(onPressed: onContinue, child: const Text('続ける')),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'スロット${slot.slot + 1}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          '空きスロット',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('新規クラブ作成'),
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
  _NewClubInput(this.clubName, this.theme);
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('スロット${widget.slotLabel}に新規クラブを作成'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'クラブ名',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text('所属リーグ', style: Theme.of(context).textTheme.titleSmall),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, _NewClubInput(name, _theme));
          },
          child: const Text('創設する'),
        ),
      ],
    );
  }
}
