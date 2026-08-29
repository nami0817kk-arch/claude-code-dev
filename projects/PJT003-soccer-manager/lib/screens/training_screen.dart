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

/// 技術特訓ピッカーで表示するカテゴリ分け(技術カテゴリの特性のみ)。
const Map<String, List<PlayerTrait>> _technicalTraitCategoriesForPicker = {
  'シュート・フィニッシュ': [
    PlayerTrait.sharpShooter,
    PlayerTrait.clinicalFinisher,
    PlayerTrait.distanceShooter,
    PlayerTrait.setPieceMaestro,
  ],
  'パス・組み立て': [
    PlayerTrait.visionary,
    PlayerTrait.playmakerTrait,
    PlayerTrait.sureTouch,
  ],
  'ドリブル・スピード': [
    PlayerTrait.silkyDribbler,
    PlayerTrait.paceMerchant,
    PlayerTrait.explosiveStart,
  ],
  '守備・フィジカル': [
    PlayerTrait.ballWinner,
    PlayerTrait.shadowMarker,
    PlayerTrait.powerhouse,
    PlayerTrait.tirelessRunner,
    PlayerTrait.enginesRunning,
  ],
  '空中戦・クロス': [PlayerTrait.aerialThreat, PlayerTrait.crossSpecialist],
  '予測・判断': [PlayerTrait.clockwork],
};

/// 性格の指導ピッカーで表示するカテゴリ分け(性格カテゴリの特性のみ)。
const Map<String, List<PlayerTrait>> _personalityTraitCategoriesForPicker = {
  '対戦相手への向き合い方': [
    PlayerTrait.giantKiller,
    PlayerTrait.frontRunner,
    PlayerTrait.underdogSpirit,
    PlayerTrait.dominantForce,
    PlayerTrait.bigGameHunter,
    PlayerTrait.bullyBall,
  ],
  'ホーム/アウェイ・心の状態': [
    PlayerTrait.homeBoy,
    PlayerTrait.roadWarrior,
    PlayerTrait.confidentMind,
    PlayerTrait.clutchNerves,
    PlayerTrait.contentPlayer,
  ],
  '闘志・統率・判断': [
    PlayerTrait.warriorSpirit,
    PlayerTrait.calmHead,
    PlayerTrait.leaderOnPitch,
    PlayerTrait.decisiveMind,
    PlayerTrait.teamPlayer,
    PlayerTrait.fearlessDefender,
  ],
  '個性': [PlayerTrait.showman],
};

/// 特訓成功率への倍率([TrainingEngine.traitSuitability])を、選手詳細
/// ピッカーで一目で分かる短いラベルと色に変換する。
({String label, Color color}) _suitabilityBadge(double multiplier) {
  if (multiplier >= 1.3) return (label: '◎ 適性高い', color: Colors.green);
  if (multiplier <= 0.7) return (label: '△ 適性低い', color: Colors.grey);
  return (label: '○ 適性普通', color: Colors.blueGrey);
}

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
                    Text(
                      'チーム既定方針',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '個別方針を設定していない選手にはこの方針が適用される。',
                      style: TextStyle(color: Colors.grey),
                    ),
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
                    Text(
                      'トレーニング強度',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      team.trainingIntensity.description,
                      style: const TextStyle(color: Colors.grey),
                    ),
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
                    Text(
                      '重点トレーニング日',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'カレンダー画面でこの曜日が重点トレーニング日として表示される。',
                      style: TextStyle(color: Colors.grey),
                    ),
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
                child: Text(
                  team.autoTrainingEnabled
                      ? '自動実施が有効です'
                      : gameState.trainingDoneThisWeek
                          ? '今週は実施済み(次の節で再実施可能)'
                          : '今週のトレーニングを実施',
                ),
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
                  child: Text(
                    team.tacticalMeetingCooldownWeeks > 0
                        ? 'あと${team.tacticalMeetingCooldownWeeks}週'
                        : '実施する',
                  ),
                ),
              ),
            ),
            const Divider(height: 32),
            Text('個別方針', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            PositionFilterBar(
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 8),
            for (final p in players) _PlayerTrainingCard(player: p, team: team),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('今週のトレーニングは実施済みです')));
    }
  }

  void _showTrainingResultDialog(
    BuildContext context,
    List<PlayerGrowthSummary> results,
  ) {
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
                                  child: Text(
                                    r.playerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                                    .map(
                                      (e) =>
                                          '${AttributeKeys.labelOf(e.key)}${e.value > 0 ? '+' : ''}${e.value}',
                                    )
                                    .join(' / '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
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
      SnackBar(content: Text(ok ? '戦術ミーティングを実施した。' : '戦術ミーティングは実施できなかった。')),
    );
  }
}

/// 選手1人分のトレーニング設定をまとめたカード。折りたたみ式にして、
/// 普段は名前・ポジション・総合力・現在の方針だけを一覧でき、詳細な
/// 育成アクション(メンター・特訓ドリル・ローテーション・声かけ・技術特訓・
/// 性格の指導)は
/// タップして展開したときだけ表示する。
class _PlayerTrainingCard extends StatelessWidget {
  final Player player;
  final Team team;

  const _PlayerTrainingCard({required this.player, required this.team});

  String _effectiveFocusLabel() {
    final p = player;
    if (p.focusRotation != null && p.focusRotation!.isNotEmpty) {
      final next =
          p.focusRotation![p.rotationWeekIndex % p.focusRotation!.length];
      return 'ローテーション(次回: ${next.label})';
    }
    if (p.individualFocus != null) return '${p.individualFocus!.label}(個別)';
    return '${team.defaultTrainingFocus.label}(既定)';
  }

  @override
  Widget build(BuildContext context) {
    final p = player;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
            if (p.individualFocus != null ||
                (p.focusRotation?.isNotEmpty ?? false)) ...[
              const SizedBox(width: 6),
              const Icon(Icons.push_pin, size: 14, color: Colors.deepPurple),
            ],
            if (p.traitTrainingTarget != null ||
                p.personalityTraitTrainingTarget != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.deepOrange,
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${p.position.label} / 総合 ${p.overall} / 方針: ${_effectiveFocusLabel()}'
          '${p.trait != null ? ' / 特性: ${p.trait!.label}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('トレーニング方針: '),
                    DropdownButton<TrainingFocus?>(
                      value: p.individualFocus,
                      hint: const Text('既定に従う'),
                      items: [
                        const DropdownMenuItem<TrainingFocus?>(
                          value: null,
                          child: Text('既定に従う'),
                        ),
                        ...TrainingFocus.values.map(
                          (f) => DropdownMenuItem<TrainingFocus?>(
                            value: f,
                            child: Text(f.label),
                          ),
                        ),
                      ],
                      onChanged: (focus) => context
                          .read<GameState>()
                          .setPlayerTrainingFocus(p.id, focus),
                    ),
                  ],
                ),
                if (p.focusRotation != null && p.focusRotation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'ローテーション中: ${p.focusRotation!.map((f) => f.label).join(' → ')}'
                      '(次回: ${p.focusRotation![p.rotationWeekIndex % p.focusRotation!.length].label})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.deepPurple,
                      ),
                    ),
                  )
                else if ((p.individualFocus ?? team.defaultTrainingFocus) ==
                    TrainingFocus.positionSwitch)
                  _PositionConvertPicker(player: p),
                const Divider(height: 20),
                Text('育成サポート', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.school, size: 18),
                      label: Text(
                        p.mentorId == null
                            ? 'メンター: なし'
                            : 'メンター: ${_mentorName(team.players, p.mentorId!)}',
                      ),
                      onPressed: () => _showMentorPicker(context, team, p),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.fitness_center, size: 18),
                      label: Text(
                        p.drillAttributeKey == null
                            ? '特訓ドリル1'
                            : 'ドリル1: ${AttributeKeys.labelOf(p.drillAttributeKey!)}',
                      ),
                      onPressed: () => _showDrillPicker(context, p),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.fitness_center_outlined,
                        size: 18,
                      ),
                      label: Text(
                        p.drillAttributeKey2 == null
                            ? '特訓ドリル2'
                            : 'ドリル2: ${AttributeKeys.labelOf(p.drillAttributeKey2!)}',
                      ),
                      onPressed: () => _showDrillPicker2(context, p),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.autorenew, size: 18),
                      label: const Text('ローテーション'),
                      onPressed: () => _showRotationPicker(context, p),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'モチベーション・特性',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.forum, size: 18),
                      label: Text(
                        p.talkCooldownWeeks > 0
                            ? '声かけ(あと${p.talkCooldownWeeks}週)'
                            : '声かけ',
                      ),
                      onPressed: p.talkCooldownWeeks > 0
                          ? null
                          : () => _talkToPlayer(context, p),
                    ),
                    if (p.trait == null) ...[
                      ActionChip(
                        avatar: const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          p.traitTrainingTarget == null
                              ? '技術特訓'
                              : '特訓中: ${p.traitTrainingTarget!.label}',
                        ),
                        onPressed: () =>
                            _showTechnicalTraitTrainingPicker(context, p),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.diversity_3, size: 18),
                        label: Text(
                          p.personalityTraitTrainingTarget == null
                              ? '性格の指導'
                              : '指導中: ${p.personalityTraitTrainingTarget!.label}',
                        ),
                        onPressed: () =>
                            _showPersonalityTraitTrainingPicker(context, p),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
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
        .where(
          (p) => p.id != mentee.id && p.age >= TrainingEngine.minMentorAge,
        )
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
                child: Text(
                  '${TrainingEngine.minMentorAge}歳以上の選手がいないため指名できません',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            for (final c in candidates)
              ListTile(
                title: Text(c.name),
                subtitle: Text(
                  '${c.age}歳 / ${c.position.label} / 総合 ${c.overall}',
                ),
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
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
                        content: Text('2つ目の特訓ドリルは同時に$maxSlots人までしか指定できません'),
                      ),
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
                      fontWeight: FontWeight.bold,
                    ),
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

  Future<void> _talkToPlayer(BuildContext context, Player p) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.talkToPlayer(p.id);
    if (!context.mounted) return;
    FeedbackService.tap();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '${p.name}に声をかけ、士気が上がった。' : '声かけに失敗した。')),
    );
  }

  void _showTechnicalTraitTrainingPicker(BuildContext context, Player p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (sheetContext, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '狙いたい技術特性を選ぶと、以後の週次トレーニングで低確率に'
                  '獲得を目指す特訓を行う。能力値・年齢がその特性に合っているほど'
                  '成功率が上がる(適性表示を参考に)。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              if (p.traitTrainingTarget != null)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('技術特訓を解除する'),
                  onTap: () {
                    context.read<GameState>().setTraitTrainingTarget(
                          p.id,
                          null,
                        );
                    Navigator.of(sheetContext).pop();
                  },
                ),
              for (final entry in _technicalTraitCategoriesForPicker.entries)
                ..._traitPickerSection(
                  context: context,
                  sheetContext: sheetContext,
                  title: entry.key,
                  traits: entry.value,
                  p: p,
                  currentTarget: p.traitTrainingTarget,
                  onPick: (trait) =>
                      context.read<GameState>().setTraitTrainingTarget(
                            p.id,
                            trait,
                          ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPersonalityTraitTrainingPicker(BuildContext context, Player p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (sheetContext, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '性格特性は練習では身につかない。メンター(チームメイト)を'
                  '指名しているか、監督が今週この選手に声をかけていた週にのみ、'
                  '低確率で選んだ特性を獲得する。'
                  '${p.mentorId == null && p.talkCooldownWeeks == 0 ? '(現在はどちらの条件も満たしていない)' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              if (p.personalityTraitTrainingTarget != null)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('性格の指導を解除する'),
                  onTap: () {
                    context
                        .read<GameState>()
                        .setPersonalityTraitTrainingTarget(p.id, null);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              for (final entry in _personalityTraitCategoriesForPicker.entries)
                ..._traitPickerSection(
                  context: context,
                  sheetContext: sheetContext,
                  title: entry.key,
                  traits: entry.value,
                  p: p,
                  currentTarget: p.personalityTraitTrainingTarget,
                  onPick: (trait) => context
                      .read<GameState>()
                      .setPersonalityTraitTrainingTarget(p.id, trait),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 特性ピッカー内の1カテゴリ分(見出し + 各特性のListTile)を組み立てる。
  /// 技術特訓・性格の指導の両ピッカーで共通のレイアウトを使い回す。
  List<Widget> _traitPickerSection({
    required BuildContext context,
    required BuildContext sheetContext,
    required String title,
    required List<PlayerTrait> traits,
    required Player p,
    required PlayerTrait? currentTarget,
    required void Function(PlayerTrait trait) onPick,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      for (final trait in traits)
        Builder(
          builder: (context) {
            final badge = _suitabilityBadge(
              TrainingEngine.traitSuitability(p, trait),
            );
            return ListTile(
              title: Text(trait.label),
              subtitle: Text(
                trait.description,
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    badge.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: badge.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (currentTarget == trait)
                    const Icon(
                      Icons.check,
                      color: Colors.deepPurple,
                      size: 18,
                    ),
                ],
              ),
              onTap: () {
                onPick(trait);
                Navigator.of(sheetContext).pop();
              },
            );
          },
        ),
    ];
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
        : Position.values.firstWhere(
            (v) => v.name == player.trainingConvertTargetPosition,
          );
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
              ...candidates.map(
                (pos) => DropdownMenuItem<Position?>(
                  value: pos,
                  child: Text(pos.label),
                ),
              ),
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
