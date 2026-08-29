import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/calendar_engine.dart';
import '../logic/player_generator.dart';
import '../logic/training_engine.dart';
import '../models/attributes.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/training_result.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/busy_overlay.dart';
import '../widgets/position_filter_bar.dart';
import '../widgets/quick_access_drawer.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  PositionGroup? _filter;
  bool _isRunningTraining = false;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final players = team.players
        .where((p) => _filter == null || p.position.group == _filter)
        .toList()
      ..sort((a, b) => a.position.index.compareTo(b.position.index));

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: BusyOverlay(
        visible: _isRunningTraining,
        label: 'トレーニングを実施しています…',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('チーム既定方針',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    const Text('個別方針を設定していない選手にはこの方針が適用される。',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: TrainingFocus.values
                          .map(
                            (focus) => ChoiceChip(
                              label: Text(focus.label),
                              selected: team.defaultTrainingFocus == focus,
                              onSelected: (_) => context
                                  .read<GameState>()
                                  .setTeamTrainingFocus(focus),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text('トレーニング強度',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(team.trainingIntensity.description,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: TrainingIntensity.values
                          .map(
                            (intensity) => ChoiceChip(
                              label: Text(intensity.label),
                              selected: team.trainingIntensity == intensity,
                              onSelected: (_) => context
                                  .read<GameState>()
                                  .setTrainingIntensity(intensity),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text('重点トレーニング日',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    const Text('カレンダー画面でこの曜日が重点トレーニング日として表示される。',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final weekday in const [
                          DateTime.monday,
                          DateTime.tuesday,
                          DateTime.wednesday,
                          DateTime.thursday,
                          DateTime.friday,
                        ])
                          ChoiceChip(
                            label: Text(CalendarEngine.weekdayLabel(weekday)),
                            selected: team.trainingDayOfWeek == weekday,
                            onSelected: (_) => context
                                .read<GameState>()
                                .setTrainingDayOfWeek(weekday),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                title: const Text('トレーニングの自動実施'),
                subtitle: const Text('有効にすると、節を進めるたびに未実施であれば既定の方針で自動的に実施する。'),
                value: team.autoTrainingEnabled,
                onChanged: (v) =>
                    context.read<GameState>().setAutoTrainingEnabled(v),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_isRunningTraining ||
                        gameState.trainingDoneThisWeek ||
                        team.autoTrainingEnabled)
                    ? null
                    : () => _runTraining(context),
                child: Text(team.autoTrainingEnabled
                    ? '自動実施が有効です'
                    : gameState.trainingDoneThisWeek
                        ? '今週は実施済み(次の節で再実施可能)'
                        : '今週のトレーニングを実施'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: const Text('戦術ミーティング'),
                subtitle: const Text('スカッド全体の判断力・位置取り・チームワークを小幅に伸ばす。'),
                trailing: OutlinedButton(
                  onPressed: team.tacticalMeetingCooldownWeeks > 0
                      ? null
                      : () => _holdTacticalMeeting(context),
                  child: Text(team.tacticalMeetingCooldownWeeks > 0
                      ? 'あと${team.tacticalMeetingCooldownWeeks}週'
                      : '実施する'),
                ),
              ),
            ),
            const Divider(height: 32),
            Text('個別方針', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            PositionFilterBar(
                value: _filter, onChanged: (v) => setState(() => _filter = v)),
            const SizedBox(height: 8),
            for (final p in players)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    ListTile(
                      title: Row(
                        children: [
                          Flexible(
                              child: Text(p.name,
                                  overflow: TextOverflow.ellipsis)),
                          if (p.individualFocus != null) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.push_pin,
                                size: 14, color: Colors.deepPurple),
                          ],
                        ],
                      ),
                      subtitle: Text('${p.position.label} / 総合 ${p.overall}'),
                      trailing: DropdownButton<TrainingFocus?>(
                        value: p.individualFocus,
                        hint: const Text('既定に従う'),
                        items: [
                          const DropdownMenuItem<TrainingFocus?>(
                              value: null, child: Text('既定に従う')),
                          ...TrainingFocus.values.map(
                            (f) => DropdownMenuItem<TrainingFocus?>(
                                value: f, child: Text(f.label)),
                          ),
                        ],
                        onChanged: (focus) => context
                            .read<GameState>()
                            .setPlayerTrainingFocus(p.id, focus),
                      ),
                    ),
                    if (p.focusRotation != null && p.focusRotation!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                        child: Text(
                          'ローテーション中: ${p.focusRotation!.map((f) => f.label).join(' → ')}'
                          '(次回: ${p.focusRotation![p.rotationWeekIndex % p.focusRotation!.length].label})',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.deepPurple),
                        ),
                      )
                    else if ((p.individualFocus ?? team.defaultTrainingFocus) ==
                        TrainingFocus.positionSwitch)
                      _PositionConvertPicker(player: p),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.mentorId == null
                                ? 'メンター: なし'
                                : 'メンター: ${_mentorName(team.players, p.mentorId!)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _showMentorPicker(context, team, p),
                                child: const Text('メンター'),
                              ),
                              TextButton(
                                onPressed: () => _showDrillPicker(context, p),
                                child: Text(p.drillAttributeKey == null
                                    ? '特訓ドリル'
                                    : '特訓: ${AttributeKeys.labelOf(p.drillAttributeKey!)}'),
                              ),
                              TextButton(
                                onPressed: () => _showDrillPicker2(context, p),
                                child: Text(p.drillAttributeKey2 == null
                                    ? '特訓ドリル2'
                                    : '特訓2: ${AttributeKeys.labelOf(p.drillAttributeKey2!)}'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _showRotationPicker(context, p),
                                child: const Text('ローテーション'),
                              ),
                              TextButton(
                                onPressed: p.talkCooldownWeeks > 0
                                    ? null
                                    : () => _talkToPlayer(context, p),
                                child: Text(p.talkCooldownWeeks > 0
                                    ? '声かけ(あと${p.talkCooldownWeeks}週)'
                                    : '声かけ'),
                              ),
                              if (p.trait == null)
                                FilterChip(
                                  label: const Text('特性特訓'),
                                  selected: p.traitTrainingEnabled,
                                  onSelected: (v) => context
                                      .read<GameState>()
                                      .setTraitTraining(p.id, v),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTraining(BuildContext context) async {
    final gameState = context.read<GameState>();
    setState(() => _isRunningTraining = true);
    final ok = await gameState.runWeeklyTraining();
    if (mounted) setState(() => _isRunningTraining = false);
    if (!context.mounted) return;
    if (ok) {
      FeedbackService.success();
      _showTrainingResultDialog(context, gameState.lastTrainingResults);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今週のトレーニングは実施済みです')),
      );
    }
  }

  void _showTrainingResultDialog(
      BuildContext context, List<PlayerGrowthSummary> results) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('トレーニング結果'),
        content: SizedBox(
          width: double.maxFinite,
          child: results.isEmpty
              ? const Text('今週は目立った変化のあった選手はいませんでした。')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in results)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (r.isBreakthrough)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '★ 才能開花！',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (r.acquiredTrait != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '☆ 特性「${r.acquiredTrait!.label}」を獲得！',
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(r.playerName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                Text(
                                  '総合 ${r.overallBefore} → ${r.overallAfter}'
                                  '${r.overallDelta > 0 ? ' (+${r.overallDelta})' : r.overallDelta < 0 ? ' (${r.overallDelta})' : ''}',
                                  style: TextStyle(
                                    color: r.overallDelta > 0
                                        ? Colors.green
                                        : r.overallDelta < 0
                                            ? Colors.redAccent
                                            : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            if (r.attributeDeltas.isNotEmpty)
                              Text(
                                r.attributeDeltas.entries
                                    .map((e) =>
                                        '${AttributeKeys.labelOf(e.key)}${e.value > 0 ? '+' : ''}${e.value}')
                                    .join(' / '),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }

  Future<void> _holdTacticalMeeting(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.holdTacticalMeeting();
    if (!context.mounted) return;
    FeedbackService.tap();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '戦術ミーティングを実施した。' : '戦術ミーティングは実施できなかった。'),
      ),
    );
  }

  Future<void> _talkToPlayer(BuildContext context, Player p) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.talkToPlayer(p.id);
    if (!context.mounted) return;
    FeedbackService.tap();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '${p.name}に声をかけ、士気が上がった。' : '声かけに失敗した。'),
      ),
    );
  }

  String _mentorName(List<Player> players, String mentorId) {
    for (final p in players) {
      if (p.id == mentorId) return p.name;
    }
    return '(退団済み)';
  }

  void _showMentorPicker(BuildContext context, Team team, Player mentee) {
    final candidates = team.players
        .where((p) => p.id != mentee.id && p.age >= TrainingEngine.minMentorAge)
        .toList()
      ..sort((a, b) => b.age.compareTo(a.age));
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('メンターを解除する'),
              onTap: () {
                context.read<GameState>().setMentor(mentee.id, null);
                Navigator.of(sheetContext).pop();
              },
            ),
            if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('${TrainingEngine.minMentorAge}歳以上の選手がいないため指名できません',
                    style: TextStyle(color: Colors.grey)),
              ),
            for (final c in candidates)
              ListTile(
                title: Text(c.name),
                subtitle:
                    Text('${c.age}歳 / ${c.position.label} / 総合 ${c.overall}'),
                trailing: mentee.mentorId == c.id
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
                onTap: () {
                  context.read<GameState>().setMentor(mentee.id, c.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDrillPicker(BuildContext context, Player p) {
    final gameState = context.read<GameState>();
    final activeCount = gameState.userTeam.players
        .where((x) => x.drillAttributeKey != null)
        .length;
    final maxSlots = gameState.maxDrillSlots;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                  '特訓ドリル指定中: $activeCount / $maxSlots人'
                  '（ヘッドコーチのレベルを上げると上限が増える）',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            ListTile(
              title: const Text('特訓ドリルを解除する'),
              onTap: () {
                gameState.setDrillAttribute(p.id, null);
                Navigator.of(sheetContext).pop();
              },
            ),
            for (final key in AttributeKeys.all)
              ListTile(
                title: Text(AttributeKeys.labelOf(key)),
                trailing: p.drillAttributeKey == key
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
                onTap: () {
                  final ok = gameState.setDrillAttribute(p.id, key);
                  Navigator.of(sheetContext).pop();
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('特訓ドリルは同時に$maxSlots人までしか指定できません')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDrillPicker2(BuildContext context, Player p) {
    final gameState = context.read<GameState>();
    final activeCount = gameState.userTeam.players
        .where((x) => x.drillAttributeKey2 != null)
        .length;
    final maxSlots = gameState.maxDrillSlots;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                  '2つ目の特訓ドリル指定中: $activeCount / $maxSlots人'
                  '（1つ目より成長率は控えめ）',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            ListTile(
              title: const Text('2つ目の特訓ドリルを解除する'),
              onTap: () {
                gameState.setDrillAttribute2(p.id, null);
                Navigator.of(sheetContext).pop();
              },
            ),
            for (final key in AttributeKeys.all)
              ListTile(
                title: Text(AttributeKeys.labelOf(key)),
                trailing: p.drillAttributeKey2 == key
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
                onTap: () {
                  final ok = gameState.setDrillAttribute2(p.id, key);
                  Navigator.of(sheetContext).pop();
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('2つ目の特訓ドリルは同時に$maxSlots人までしか指定できません')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showRotationPicker(BuildContext context, Player p) {
    final gameState = context.read<GameState>();
    var rotation = List<TrainingFocus>.from(p.focusRotation ?? const []);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'タップした順に方針が並び、週次トレーニングのたびに'
                  '上から順番へ自動的に切り替わる。1件も選ばなければ従来通り'
                  '個別方針/既定方針に従う。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              if (rotation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '現在の順番: ${rotation.map((f) => f.label).join(' → ')}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              for (final focus in TrainingFocus.values)
                CheckboxListTile(
                  title: Text(focus.label),
                  subtitle: rotation.contains(focus)
                      ? Text('順番: ${rotation.indexOf(focus) + 1}番目')
                      : null,
                  value: rotation.contains(focus),
                  onChanged: (checked) => setSheetState(() {
                    if (checked == true) {
                      rotation.add(focus);
                    } else {
                      rotation.remove(focus);
                    }
                  }),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheetState(() => rotation = []),
                        child: const Text('クリア'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          gameState.setPlayerFocusRotation(p.id, rotation);
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ポジションコンバート特訓の目標ポジションを選ぶピッカー。
/// 生成時に偶然割り当てられた副ポジションとは関係なく、任意のポジションへの
/// 転向を目指せるようにする(慣れ度が上限に達すると実際に起用可能になる)。
class _PositionConvertPicker extends StatelessWidget {
  final Player player;

  const _PositionConvertPicker({required this.player});

  @override
  Widget build(BuildContext context) {
    final candidates = PlayerGenerator.secondaryCandidatesFor(player.position)
        .where((pos) => !player.secondaryPositions.contains(pos))
        .toList();
    final target = player.trainingConvertTargetPosition == null
        ? null
        : Position.values
            .firstWhere((v) => v.name == player.trainingConvertTargetPosition);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              target == null
                  ? '転向先ポジション: 未設定'
                  : '転向先: ${target.label}(慣れ度${player.familiarityFor(target)}/100)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownButton<Position?>(
            value: target,
            hint: const Text('選択'),
            items: [
              const DropdownMenuItem<Position?>(value: null, child: Text('なし')),
              ...candidates.map((pos) => DropdownMenuItem<Position?>(
                  value: pos, child: Text(pos.label))),
            ],
            onChanged: (pos) => context
                .read<GameState>()
                .setPlayerTrainingConvertTarget(player.id, pos),
          ),
        ],
      ),
    );
  }
}
