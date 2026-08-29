import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attributes.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../logic/lineup_utils.dart';
import '../logic/match_engine.dart';
import '../logic/rotation_engine.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/formation_layout.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';

class LineupScreen extends StatelessWidget {
  const LineupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('スタメン・戦術'),
          bottom: const TabBar(tabs: [Tab(text: 'フォーメーション'), Tab(text: '戦術')]),
        ),
        drawer: const QuickAccessDrawer(),
        body: const ResponsiveBody(
          child: TabBarView(
            children: [_FormationTab(), _TacticsTab()],
          ),
        ),
      ),
    );
  }
}

/// スタメン編成・ピッチ表示・ベンチを扱うタブ。「誰が、どこで出るか」に集中する。
class _FormationTab extends StatelessWidget {
  const _FormationTab();

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final formation = team.formation;
    final bench = team.players
        .where((p) => !team.startingXI.contains(p.id))
        .toList()
      ..sort((a, b) => a.position.index.compareTo(b.position.index));

    final squadFull = team.startingXI.length == 11;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<Formation>(
                    value: formation,
                    items: Formation.values
                        .map((f) =>
                            DropdownMenuItem(value: f, child: Text(f.label)))
                        .toList(),
                    onChanged: (f) {
                      if (f != null) {
                        FeedbackService.tap();
                        context.read<GameState>().setFormation(f);
                      }
                    },
                  ),
                  Chip(
                    label:
                        Text('攻撃 x${formation.attackBias.toStringAsFixed(2)}'),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label:
                        Text('守備 x${formation.defenseBias.toStringAsFixed(2)}'),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text('${team.startingXI.length}/11人'),
                    avatar: Icon(
                      squadFull ? Icons.check_circle : Icons.error_outline,
                      size: 18,
                      color: squadFull
                          ? SemanticColors.positive(context)
                          : SemanticColors.negative(context),
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: squadFull
                        ? SemanticColors.positive(context)
                            .withValues(alpha: 0.12)
                        : SemanticColors.negative(context)
                            .withValues(alpha: 0.12),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (gameState.rotationSuggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _RotationSuggestionsCard(
                suggestions: gameState.rotationSuggestions),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_fix_high, size: 18),
                onPressed: () {
                  FeedbackService.tap();
                  context.read<GameState>().autoFillStartingXI();
                },
                label: const Text('自動編成'),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('選手をタップして入れ替え',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: _PitchView(team: team, formation: formation),
            ),
          ),
        ),
        const SizedBox(height: 24),
        DragTarget<String>(
          onWillAcceptWithDetails: (details) =>
              team.startingXI.contains(details.data),
          onAcceptWithDetails: (details) {
            FeedbackService.tap();
            context.read<GameState>().toggleStartingPlayer(details.data);
          },
          builder: (context, candidateData, rejectedData) {
            final isDragOver = candidateData.isNotEmpty;
            return Container(
              decoration: BoxDecoration(
                color: isDragOver
                    ? SemanticColors.positive(context).withValues(alpha: 0.08)
                    : null,
                border: isDragOver
                    ? Border.all(color: SemanticColors.positive(context))
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text('ベンチ',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(width: 6),
                        Text('${bench.length}人',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const Spacer(),
                        Text(
                          isDragOver ? 'ここに離してベンチへ' : 'ドラッグで入れ替え可能',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDragOver
                                ? SemanticColors.positive(context)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (bench.isEmpty)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('ベンチに選手がいません',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    )
                  else
                    for (final p in bench) _BenchTile(playerId: p.id),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// 各種スライダー・セットプレー担当・戦術プリセット・デプスチャートを扱う
/// タブ。「どう戦うか」に集中する。
class _TacticsTab extends StatelessWidget {
  const _TacticsTab();

  @override
  Widget build(BuildContext context) {
    final team = context.watch<GameState>().userTeam;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 90, child: Text('プレッシング')),
                    Expanded(
                      child: Slider(
                        value: team.pressing.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '${team.pressing}',
                        onChanged: (v) =>
                            context.read<GameState>().setPressing(v.round()),
                      ),
                    ),
                    SizedBox(width: 32, child: Text('${team.pressing}')),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 90, child: Text('ライン高さ')),
                    Expanded(
                      child: Slider(
                        value: team.lineHeight.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '${team.lineHeight}',
                        onChanged: (v) =>
                            context.read<GameState>().setLineHeight(v.round()),
                      ),
                    ),
                    SizedBox(width: 32, child: Text('${team.lineHeight}')),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 90, child: Text('攻撃の幅')),
                    Expanded(
                      child: Slider(
                        value: team.width.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '${team.width}',
                        onChanged: (v) =>
                            context.read<GameState>().setWidth(v.round()),
                      ),
                    ),
                    SizedBox(width: 32, child: Text('${team.width}')),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 90, child: Text('テンポ')),
                    Expanded(
                      child: Slider(
                        value: team.tempo.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '${team.tempo}',
                        onChanged: (v) =>
                            context.read<GameState>().setTempo(v.round()),
                      ),
                    ),
                    SizedBox(width: 32, child: Text('${team.tempo}')),
                  ],
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'プレッシングは守備を高めるが疲労が増えやすい。ラインを上げると攻撃的になるが裏を突かれやすい。\n'
                    '幅を広げると攻撃力が増すが中央の守備が薄くなる。テンポを上げると攻撃的だが疲労が増えやすい。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                _TacticalImpactSummary(team: team),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SetPieceTakersCard(team: team),
        const SizedBox(height: 8),
        _TacticPresetsCard(team: team),
        const SizedBox(height: 8),
        _DepthChartSection(team: team),
      ],
    );
  }
}

/// 現在の戦術スライダー設定が攻撃力・守備力・疲労蓄積に与える倍率を数値で示す。
/// 「上げたら実際どれだけ変わるのか」を定量的に判断できるようにするための表示。
class _TacticalImpactSummary extends StatelessWidget {
  final Team team;
  const _TacticalImpactSummary({required this.team});

  @override
  Widget build(BuildContext context) {
    final impact = MatchEngine.tacticalImpact(team);
    final lineup = MatchEngine.lineupOf(team);
    final avgWorkRate = lineup.isEmpty
        ? 50.0
        : lineup.fold<double>(
                0, (s, p) => s + p.attributeValue(AttributeKeys.workRate)) /
            lineup.length;
    final avgStamina = lineup.isEmpty
        ? 50.0
        : lineup.fold<double>(
                0, (s, p) => s + p.attributeValue(AttributeKeys.stamina)) /
            lineup.length;
    final pressingFit = MatchEngine.tacticalFitFactor(avgWorkRate);
    final tempoFit = MatchEngine.tacticalFitFactor(avgStamina);
    String pct(double multiplier) {
      final delta = ((multiplier - 1) * 100).round();
      return delta >= 0 ? '+$delta%' : '$delta%';
    }

    Color colorFor(double multiplier, {bool higherIsWorse = false}) {
      final positive = multiplier >= 1;
      final good = higherIsWorse ? !positive : positive;
      if (multiplier == 1) return Colors.grey;
      return good
          ? SemanticColors.positive(context)
          : SemanticColors.negative(context);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('現在の戦術設定による影響(定量)',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _ImpactRow(
              label: '攻撃力補正',
              text: pct(impact.attackMultiplier),
              color: colorFor(impact.attackMultiplier)),
          _ImpactRow(
              label: '守備力補正',
              text: pct(impact.defenseMultiplier),
              color: colorFor(impact.defenseMultiplier)),
          _ImpactRow(
              label: '疲労蓄積',
              text: pct(impact.fatigueMultiplier),
              color: colorFor(impact.fatigueMultiplier, higherIsWorse: true)),
          const SizedBox(height: 4),
          Text(
            'スカッド適性: プレッシング x${pressingFit.toStringAsFixed(2)}'
            '(労働量平均${avgWorkRate.round()}) / '
            'テンポ x${tempoFit.toStringAsFixed(2)}(スタミナ平均${avgStamina.round()})',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  const _ImpactRow(
      {required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

/// 疲労が溜まったスタメンを、より疲労の少ないベンチ選手に入れ替える
/// ことを提案するカード。
class _RotationSuggestionsCard extends StatelessWidget {
  final List<RotationSuggestion> suggestions;
  const _RotationSuggestionsCard({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_alert,
                    size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 6),
                Text('疲労ローテーション提案',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Colors.orange.shade900)),
              ],
            ),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${s.tiredPlayerName}(疲労${s.tiredFatigue}) → '
                        '${s.replacementName}(疲労${s.replacementFatigue})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        FeedbackService.tap();
                        context.read<GameState>().swapStartingPlayer(
                            outPlayerId: s.tiredPlayerId,
                            inPlayerId: s.replacementId);
                      },
                      child: const Text('入れ替える'),
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

/// PK・直接FK・CKの担当選手を指名するカード。指名するとその場面で優先的に
/// 関わり、専門の能力値(PK・FK・CK)がチャンスの質に反映される。
class _SetPieceTakersCard extends StatelessWidget {
  final Team team;
  const _SetPieceTakersCard({required this.team});

  @override
  Widget build(BuildContext context) {
    final players = [...team.players]
      ..sort((a, b) => b.overall.compareTo(a.overall));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('セットプレー担当', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _TakerDropdown(
              label: 'PK',
              players: players,
              attributeKey: AttributeKeys.penalties,
              selectedId: team.penaltyTakerId,
              onChanged: (id) {
                FeedbackService.tap();
                context.read<GameState>().setPenaltyTaker(id);
              },
            ),
            _TakerDropdown(
              label: 'FK',
              players: players,
              attributeKey: AttributeKeys.freeKick,
              selectedId: team.freeKickTakerId,
              onChanged: (id) {
                FeedbackService.tap();
                context.read<GameState>().setFreeKickTaker(id);
              },
            ),
            _TakerDropdown(
              label: 'CK',
              players: players,
              attributeKey: AttributeKeys.corners,
              selectedId: team.cornerTakerId,
              onChanged: (id) {
                FeedbackService.tap();
                context.read<GameState>().setCornerTaker(id);
              },
            ),
            const Divider(height: 24),
            Text('守備セットプレー担当', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text('相手のCK・FKの得点確率を、ヘディング・ジャンプ力に応じて下げる。',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 40, child: Text('守備')),
                Expanded(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: team.setPieceDefenderId,
                    hint: const Text('未指名'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('未指名')),
                      for (final p in players)
                        DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(
                              '${p.name}（空中戦 ${(p.attributeValue(AttributeKeys.heading) + p.attributeValue(AttributeKeys.jumpingReach)) ~/ 2}）',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) {
                      FeedbackService.tap();
                      context.read<GameState>().setSetPieceDefender(id);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TakerDropdown extends StatelessWidget {
  final String label;
  final List<Player> players;
  final String attributeKey;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _TakerDropdown({
    required this.label,
    required this.players,
    required this.attributeKey,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label)),
        Expanded(
          child: DropdownButton<String?>(
            isExpanded: true,
            value: selectedId,
            hint: const Text('未指名'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('未指名')),
              for (final p in players)
                DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(
                      '${p.name}（$label ${p.attributeValue(attributeKey)}）',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// 現在の戦術一式(フォーメーション・スライダー・セットプレー担当)を
/// 名前を付けて保存し、後から呼び出せるカード。
class _TacticPresetsCard extends StatelessWidget {
  final Team team;
  const _TacticPresetsCard({required this.team});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('戦術プリセット', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('現在の設定を保存'),
                  onPressed: () => _showSaveDialog(context),
                ),
              ],
            ),
            if (team.tacticPresets.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('保存済みのプリセットはありません',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final preset in team.tacticPresets)
                    InputChip(
                      label: Text('${preset.name}（${preset.formation.label}）'),
                      onPressed: () {
                        FeedbackService.tap();
                        context
                            .read<GameState>()
                            .applyTacticPreset(preset.name);
                      },
                      onDeleted: () {
                        FeedbackService.tap();
                        context
                            .read<GameState>()
                            .deleteTacticPreset(preset.name);
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSaveDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('戦術プリセットを保存'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名前(例: 守備固め)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;
    FeedbackService.tap();
    context.read<GameState>().saveTacticPreset(name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$name」を保存しました')),
      );
    }
  }
}

/// ポジションごとの控え順(デプスチャート)を一覧表示するセクション。
/// 既定では主戦場とする選手を総合力順に並べるが、ドラッグして手動で
/// 控え順を入れ替えることもできる(入れ替えた順序はセーブデータに保存される)。
class _DepthChartSection extends StatelessWidget {
  final Team team;
  const _DepthChartSection({required this.team});

  @override
  Widget build(BuildContext context) {
    final positions = Position.values
        .where((pos) => team.players.any((p) => p.position == pos))
        .toList();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('デプスチャート(ポジション別控え順)',
            style: Theme.of(context).textTheme.titleSmall),
        subtitle: const Text('ドラッグハンドルで控え順を入れ替えられます',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        children: [
          for (final pos in positions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pos.fullLabel,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  _DepthChartReorderableList(team: team, position: pos),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DepthChartReorderableList extends StatelessWidget {
  final Team team;
  final Position position;
  const _DepthChartReorderableList(
      {required this.team, required this.position});

  @override
  Widget build(BuildContext context) {
    final players = team.depthChartFor(position);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: players.length,
      onReorderItem: (oldIndex, newIndex) {
        FeedbackService.tap();
        context
            .read<GameState>()
            .reorderDepthChart(position, oldIndex, newIndex);
      },
      itemBuilder: (context, i) => _DepthChartPlayerRow(
        key: ValueKey(players[i].id),
        rank: i + 1,
        player: players[i],
        index: i,
      ),
    );
  }
}

class _DepthChartPlayerRow extends StatelessWidget {
  final int rank;
  final Player player;
  final int index;
  const _DepthChartPlayerRow({
    super.key,
    required this.rank,
    required this.player,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final unavailable = player.isInjured
        ? '負傷中'
        : player.isSuspended
            ? '出場停止'
            : player.isOnInternationalDuty
                ? '代表招集中'
                : player.isLoanedOut
                    ? 'ローン中'
                    : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
              width: 18,
              child: Text('$rank.', style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Text('${player.name}（総合${player.overall}）',
                style: const TextStyle(fontSize: 12)),
          ),
          if (unavailable != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(unavailable,
                  style: TextStyle(
                      fontSize: 11, color: SemanticColors.negative(context))),
            ),
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, size: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _PitchView extends StatelessWidget {
  final Team team;
  final Formation formation;

  const _PitchView({required this.team, required this.formation});

  @override
  Widget build(BuildContext context) {
    final slots = formation.slots;
    final offsets = FormationLayout.offsetsFor(formation);
    final assignments = LineupUtils.resolveSlotAssignments(team);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return CustomPaint(
            painter: _PitchPainter(),
            child: Stack(
              children: [
                for (int i = 0; i < slots.length; i++)
                  Positioned(
                    left: (offsets[i].dx * w - 26).clamp(0, w - 52),
                    top: (offsets[i].dy * h - 26).clamp(0, h - 52),
                    child: _SlotChip(
                      team: team,
                      slotPosition: slots[i],
                      player: assignments[i],
                      onTap: () =>
                          _showSlotSheet(context, slots[i], assignments[i]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSlotSheet(
      BuildContext context, Position slotPosition, Player? current) {
    final gameState = context.read<GameState>();
    final candidates = team.players
        .where((p) => p.id != current?.id)
        .where((p) => _canFillSlot(p, slotPosition))
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
              child: Text('${slotPosition.fullLabel}(${slotPosition.label})に配置',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            if (current != null) ...[
              ListTile(
                leading: const Icon(Icons.remove_circle_outline,
                    color: Colors.redAccent),
                title: const Text('この枠を空ける'),
                onTap: () {
                  Navigator.pop(ctx);
                  FeedbackService.tap();
                  gameState.toggleStartingPlayer(current.id);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final duty in PlayerDuty.values)
                      ChoiceChip(
                        label: Text(duty.label),
                        selected: current.duty == duty,
                        onSelected: (_) {
                          Navigator.pop(ctx);
                          FeedbackService.tap();
                          gameState.setPlayerDuty(current.id, duty);
                        },
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('ロール',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final role in PlayerRole.values.where((r) =>
                        r == PlayerRole.standard ||
                        r.allowedGroups.contains(current.position.group)))
                      ChoiceChip(
                        label: Text(role.label),
                        selected: current.role == role,
                        onSelected: (_) {
                          Navigator.pop(ctx);
                          FeedbackService.tap();
                          gameState.setPlayerRole(current.id, role);
                        },
                      ),
                  ],
                ),
              ),
              if (slotPosition != current.position)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    current.secondaryPositions.contains(slotPosition)
                        ? '本職外のポジションです(慣れ度 '
                            '${current.familiarityFor(slotPosition)}%。出場を重ねると上がります)'
                        : '本職から離れたポジションです(慣れ度 '
                            '${current.familiarityFor(slotPosition)}%。パフォーマンスが低下します)',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              const Divider(),
            ],
            for (final p in candidates)
              ListTile(
                leading: PlayerFaceAvatar(playerId: p.id, position: p.position),
                title: Text(p.name),
                subtitle: Text('${p.position.label} / 総合 ${p.overall}'),
                onTap: () {
                  Navigator.pop(ctx);
                  FeedbackService.tap();
                  gameState.swapStartingPlayer(
                      outPlayerId: current?.id, inPlayerId: p.id);
                },
              ),
            if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('交代できる選手がいません'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dark = Color(0xFF2E7D32);
    const light = Color(0xFF34893A);
    const stripeCount = 8;
    final stripeHeight = size.height / stripeCount;
    for (var i = 0; i < stripeCount; i++) {
      final stripe = Paint()..color = i.isEven ? dark : light;
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeHeight, size.width, stripeHeight),
        stripe,
      );
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(4, 4, size.width - 8, size.height - 8), line);
    canvas.drawLine(Offset(4, size.height / 2),
        Offset(size.width - 4, size.height / 2), line);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width * 0.16, line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2,
        Paint()..color = line.color);

    final boxW = size.width * 0.55;
    final boxH = size.height * 0.12;
    canvas.drawRect(
        Rect.fromLTWH(size.width / 2 - boxW / 2, 4, boxW, boxH), line);
    canvas.drawRect(
      Rect.fromLTWH(
          size.width / 2 - boxW / 2, size.height - 4 - boxH, boxW, boxH),
      line,
    );

    const cornerRadius = 10.0;
    const halfPi = 1.5708;
    final corners = [
      (const Offset(4, 4), 0.0), // top-left
      (Offset(size.width - 4, 4), halfPi), // top-right
      (Offset(size.width - 4, size.height - 4), halfPi * 2), // bottom-right
      (Offset(4, size.height - 4), halfPi * 3), // bottom-left
    ];
    for (final (center, start) in corners) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: cornerRadius),
        start,
        halfPi,
        false,
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Color _dutyColor(PlayerDuty duty) => switch (duty) {
      PlayerDuty.defend => Colors.blue.shade300,
      PlayerDuty.support => Colors.grey.shade400,
      PlayerDuty.attack => Colors.orange.shade400,
    };

/// 選手[p]が[slotPosition]の枠に配置可能か(出場不可状態でなく、
/// 本職・準本職・同系統ポジションのいずれかに該当する)。
bool _canFillSlot(Player p, Position slotPosition) =>
    !p.isInjured &&
    !p.isOnInternationalDuty &&
    !p.isSuspended &&
    (p.position == slotPosition ||
        p.secondaryPositions.contains(slotPosition) ||
        p.position.group == slotPosition.group);

class _SlotChip extends StatelessWidget {
  final Team team;
  final Position slotPosition;
  final Player? player;
  final VoidCallback onTap;

  const _SlotChip({
    required this.team,
    required this.slotPosition,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = player;
    final outOfPosition = p != null && p.position != slotPosition;
    final roleSuffix =
        (p != null && p.role != PlayerRole.standard) ? '・${p.role.label}' : '';
    final content = Semantics(
      button: true,
      label: p == null
          ? '${slotPosition.fullLabel}: 空き枠'
          : '${slotPosition.fullLabel}: ${p.name}（${p.duty.label}$roleSuffix）'
              '${outOfPosition ? '。本職外(慣れ度${p.familiarityFor(slotPosition)}%)' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  p == null
                      ? CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          child: Text(slotPosition.label,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white)),
                        )
                      : PlayerFaceAvatar(
                          playerId: p.id,
                          position: p.position,
                          size: 36,
                          highlighted: true),
                  if (p != null)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Tooltip(
                        message: '${p.duty.label}$roleSuffix',
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _dutyColor(p.duty),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                    ),
                  if (outOfPosition)
                    Positioned(
                      left: -2,
                      top: -2,
                      child: Tooltip(
                        message: '本職外(慣れ度${p.familiarityFor(slotPosition)}%)',
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(Icons.priority_high,
                              size: 8, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  p == null ? '空き' : p.name.split(' ').last,
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final draggable = p == null
        ? content
        : Draggable<String>(
            data: p.id,
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(opacity: 0.85, child: content),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: content),
            child: content,
          );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        if (details.data == p?.id) return false;
        final matches = team.players.where((pl) => pl.id == details.data);
        if (matches.isEmpty) return false;
        return _canFillSlot(matches.first, slotPosition);
      },
      onAcceptWithDetails: (details) {
        FeedbackService.tap();
        context
            .read<GameState>()
            .swapStartingPlayer(outPlayerId: p?.id, inPlayerId: details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty;
        return Container(
          decoration: isDragOver
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: SemanticColors.positive(context), width: 2),
                )
              : null,
          child: draggable,
        );
      },
    );
  }
}

class _BenchTile extends StatelessWidget {
  final String playerId;

  const _BenchTile({required this.playerId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final p = team.players.firstWhere((pl) => pl.id == playerId);
    final quota = team.formation.quotaFor(p.position);
    final currentInPosition = team.startingXI
        .map((id) => team.players.firstWhere((pl) => pl.id == id))
        .where((pl) => pl.position == p.position)
        .length;
    final canAdd = !p.isInjured &&
        !p.isOnInternationalDuty &&
        !p.isSuspended &&
        currentInPosition < quota;

    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        leading: PlayerFaceAvatar(playerId: p.id, position: p.position),
        title: Text(p.name),
        subtitle: Text(
          p.isInjured
              ? '負傷中（あと${p.injuryWeeks}週）'
              : p.isSuspended
                  ? '出場停止（あと${p.suspendedMatches}試合）'
                  : p.isOnInternationalDuty
                      ? '代表召集中（あと${p.internationalDutyWeeksRemaining}週）'
                      : '${p.age}歳 / 総合 ${p.overall}'
                          '${p.secondaryPositions.isEmpty ? '' : ' / 対応: ${p.secondaryPositions.map((s) => s.label).join(', ')}'}',
          style: (p.isInjured || p.isOnInternationalDuty || p.isSuspended)
              ? const TextStyle(color: Colors.redAccent)
              : null,
        ),
        trailing: OutlinedButton(
          onPressed: canAdd
              ? () {
                  FeedbackService.tap();
                  context.read<GameState>().toggleStartingPlayer(p.id);
                }
              : null,
          child: const Text('スタメンへ'),
        ),
      ),
    );

    if (p.isInjured || p.isOnInternationalDuty || p.isSuspended) {
      return card;
    }

    return Draggable<String>(
      data: p.id,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 260,
          child: Opacity(opacity: 0.85, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }
}
