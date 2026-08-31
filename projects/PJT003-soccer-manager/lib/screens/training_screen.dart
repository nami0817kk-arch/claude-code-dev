import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/calendar_engine.dart';
import '../logic/development_advisor.dart';
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
import '../l10n/tr.dart';

/// 技術特訓ピッカーで表示するカテゴリ分け(技術カテゴリの特性のみ)。
const Map<({String ja, String en}), List<PlayerTrait>>
    _technicalTraitCategoriesForPicker = {
  (ja: 'シュート・フィニッシュ', en: 'Shooting & finishing'): [
    PlayerTrait.sharpShooter,
    PlayerTrait.clinicalFinisher,
    PlayerTrait.distanceShooter,
    PlayerTrait.setPieceMaestro,
  ],
  (ja: 'パス・組み立て', en: 'Passing & build-up'): [
    PlayerTrait.visionary,
    PlayerTrait.playmakerTrait,
    PlayerTrait.sureTouch,
  ],
  (ja: 'ドリブル・スピード', en: 'Dribbling & pace'): [
    PlayerTrait.silkyDribbler,
    PlayerTrait.paceMerchant,
    PlayerTrait.explosiveStart,
  ],
  (ja: '守備・フィジカル', en: 'Defending & physicality'): [
    PlayerTrait.ballWinner,
    PlayerTrait.shadowMarker,
    PlayerTrait.powerhouse,
    PlayerTrait.tirelessRunner,
    PlayerTrait.enginesRunning,
  ],
  (ja: '空中戦・クロス', en: 'Aerial play & crossing'): [
    PlayerTrait.aerialThreat,
    PlayerTrait.crossSpecialist
  ],
  (ja: '予測・判断', en: 'Anticipation & decisions'): [PlayerTrait.clockwork],
};

/// 性格の指導ピッカーで表示するカテゴリ分け(性格カテゴリの特性のみ)。
const Map<({String ja, String en}), List<PlayerTrait>>
    _personalityTraitCategoriesForPicker = {
  (ja: '対戦相手への向き合い方', en: 'How they approach opponents'): [
    PlayerTrait.giantKiller,
    PlayerTrait.frontRunner,
    PlayerTrait.underdogSpirit,
    PlayerTrait.dominantForce,
    PlayerTrait.bigGameHunter,
    PlayerTrait.bullyBall,
  ],
  (ja: 'ホーム/アウェイ・心の状態', en: 'Home/away and state of mind'): [
    PlayerTrait.homeBoy,
    PlayerTrait.roadWarrior,
    PlayerTrait.confidentMind,
    PlayerTrait.clutchNerves,
    PlayerTrait.contentPlayer,
  ],
  (ja: '闘志・統率・判断', en: 'Determination, leadership, decisions'): [
    PlayerTrait.warriorSpirit,
    PlayerTrait.calmHead,
    PlayerTrait.leaderOnPitch,
    PlayerTrait.decisiveMind,
    PlayerTrait.teamPlayer,
    PlayerTrait.fearlessDefender,
  ],
  (ja: '個性', en: 'Character'): [PlayerTrait.showman],
};

/// 特訓成功率への倍率([TrainingEngine.traitSuitability])を、選手詳細
/// ピッカーで一目で分かる短いラベルと色に変換する。
({String label, Color color}) _suitabilityBadge(double multiplier) {
  if (multiplier >= 1.3) {
    return (label: Tr.pick('◎ 適性高い', '◎ Strong fit'), color: Colors.green);
  }
  if (multiplier <= 0.7) {
    return (label: Tr.pick('△ 適性低い', '△ Poor fit'), color: Colors.grey);
  }
  return (label: Tr.pick('○ 適性普通', '○ Average fit'), color: Colors.blueGrey);
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
        title: Text(Tr.pick('トレーニング', 'Training')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: BusyOverlay(
        visible: _isRunningTraining,
        label: Tr.pick('トレーニングを実施しています…', 'Running the session…'),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Builder(
              builder: (context) {
                final advices = DevelopmentAdvisor.advise(team);
                if (advices.isEmpty) return const SizedBox.shrink();
                return Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tips_and_updates_outlined,
                                size: 18),
                            const SizedBox(width: 6),
                            Text(
                              Tr.pick('育成アドバイザー', 'Development adviser'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Tr.pick('コーチ陣が育成面で手を打つべき選手を挙げています。',
                              'Your coaches have flagged players who need attention.'),
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        for (final a in advices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              Tr.pick(
                                  '・[${a.kind.label}] ${a.playerName}: ${a.message}',
                                  '• [${a.kind.label}] ${a.playerName}: ${a.message}'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Tr.pick('チーム既定方針', 'Squad default'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Tr.pick('個別方針を設定していない選手にはこの方針が適用される。',
                          'Applies to every player without an individual focus.'),
                      style: const TextStyle(color: Colors.grey),
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
                      Tr.pick('トレーニング強度', 'Training intensity'),
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
                      Tr.pick('重点トレーニング日', 'Main training day'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Tr.pick('カレンダー画面でこの曜日が重点トレーニング日として表示される。',
                          'This weekday is shown as the main training day on the calendar.'),
                      style: const TextStyle(color: Colors.grey),
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
                title: Text(Tr.pick('トレーニングの自動実施', 'Train automatically')),
                subtitle: Text(Tr.pick('有効にすると、節を進めるたびに未実施であれば既定の方針で自動的に実施する。',
                    'When on, each matchday runs the session on the default focus if you have not done it yourself.')),
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
                      ? Tr.pick('自動実施が有効です', 'Automatic training is on')
                      : gameState.trainingDoneThisWeek
                          ? Tr.pick('今週は実施済み(次の節で再実施可能)',
                              'Done for this week (available again next matchday)')
                          : Tr.pick('今週のトレーニングを実施', "Run this week's session"),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(Tr.pick('戦術ミーティング', 'Tactical meeting')),
                subtitle: Text(Tr.pick('スカッド全体の判断力・位置取り・チームワークを小幅に伸ばす。',
                    'A small lift to decisions, positioning and teamwork across the squad.')),
                trailing: OutlinedButton(
                  onPressed: team.tacticalMeetingCooldownWeeks > 0
                      ? null
                      : () => _holdTacticalMeeting(context),
                  child: Text(
                    team.tacticalMeetingCooldownWeeks > 0
                        ? Tr.pick('あと${team.tacticalMeetingCooldownWeeks}週',
                            '${team.tacticalMeetingCooldownWeeks} weeks to go')
                        : Tr.pick('実施する', 'Hold it'),
                  ),
                ),
              ),
            ),
            const Divider(height: 32),
            Text(Tr.pick('個別方針', 'Individual focus'),
                style: Theme.of(context).textTheme.titleMedium),
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
      _showTrainingResultDialog(
        context,
        gameState.lastTrainingResults,
        practiceMatchCount: gameState.lastPracticeMatchCount,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Tr.pick(
              '今週のトレーニングは実施済みです', 'You have already trained this week'))));
    }
  }

  void _showTrainingResultDialog(
    BuildContext context,
    List<PlayerGrowthSummary> results, {
    int practiceMatchCount = 0,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('トレーニング結果', 'Training report')),
        content: SizedBox(
          width: double.maxFinite,
          child: results.isEmpty && practiceMatchCount == 0
              ? Text(Tr.pick('今週は目立った変化のあった選手はいませんでした。',
                  'No player changed noticeably this week.'))
              : ListView(
                  shrinkWrap: true,
                  children: [
                    if (practiceMatchCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.sports_soccer,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                Tr.pick(
                                    '紅白戦: スタメン外の$practiceMatchCount人が実戦感覚を維持しました',
                                    'Practice match: $practiceMatchCount players outside the XI kept their sharpness'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (results.isEmpty)
                      Text(Tr.pick('今週は目立った変化のあった選手はいませんでした。',
                          'No player changed noticeably this week.')),
                    for (final r in results)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (r.isBreakthrough)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  Tr.pick('★ 才能開花！', '★ Breakthrough!'),
                                  style: const TextStyle(
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
                                  Tr.pick('☆ 特性「${r.acquiredTrait!.label}」を獲得！',
                                      '☆ Picked up the trait "${r.acquiredTrait!.label}"!'),
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
                                  Tr.pick(
                                      '総合 ${r.overallBefore} → ${r.overallAfter}${r.overallDelta > 0 ? ' (+${r.overallDelta})' : r.overallDelta < 0 ? ' (${r.overallDelta})' : ''}',
                                      "Overall ${r.overallBefore} → ${r.overallAfter}${r.overallDelta > 0 ? ' (+${r.overallDelta})' : r.overallDelta < 0 ? ' (${r.overallDelta})' : ''}"),
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
            child: Text(Tr.pick('閉じる', 'Close')),
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
      SnackBar(
          content: Text(ok
              ? Tr.pick('戦術ミーティングを実施した。', 'You held the tactical meeting.')
              : Tr.pick('戦術ミーティングは実施できなかった。',
                  'You could not hold the tactical meeting.'))),
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
      return Tr.pick(
          'ローテーション(次回: ${next.label})', 'Rotation (next: ${next.label})');
    }
    if (p.individualFocus != null) {
      return Tr.pick('${p.individualFocus!.label}(個別)',
          '${p.individualFocus!.label} (individual)');
    }
    return Tr.pick('${team.defaultTrainingFocus.label}(既定)',
        '${team.defaultTrainingFocus.label} (default)');
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
          Tr.pick(
              '${p.position.label} / 総合 ${p.overall} / 方針: ${_effectiveFocusLabel()}${p.trait != null ? ' / 特性: ${p.trait!.label}' : ''}',
              "${p.position.label} / overall ${p.overall} / focus: ${_effectiveFocusLabel()}${p.trait != null ? ' / trait: ${p.trait!.label}' : ''}"),
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
                    Text(Tr.pick('トレーニング方針: ', 'Training focus: ')),
                    DropdownButton<TrainingFocus?>(
                      value: p.individualFocus,
                      hint: Text(Tr.pick('既定に従う', 'Use the default')),
                      items: [
                        DropdownMenuItem<TrainingFocus?>(
                          value: null,
                          child: Text(Tr.pick('既定に従う', 'Use the default')),
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
                      Tr.pick(
                          'ローテーション中: ${p.focusRotation!.map((f) => f.label).join(' → ')}(次回: ${p.focusRotation![p.rotationWeekIndex % p.focusRotation!.length].label})',
                          "Rotating: ${p.focusRotation!.map((f) => f.label).join(' → ')} (next: ${p.focusRotation![p.rotationWeekIndex % p.focusRotation!.length].label})"),
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
                Text(Tr.pick('育成サポート', 'Development support'),
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.school, size: 18),
                      label: Text(
                        p.mentorId == null
                            ? Tr.pick('メンター: なし', 'Mentor: none')
                            : Tr.pick(
                                'メンター: ${_mentorName(team.players, p.mentorId!)}',
                                'Mentor: ${_mentorName(team.players, p.mentorId!)}'),
                      ),
                      onPressed: () => _showMentorPicker(context, team, p),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.fitness_center, size: 18),
                      label: Text(
                        p.drillAttributeKey == null
                            ? Tr.pick('特訓ドリル1', 'Focus drill 1')
                            : Tr.pick(
                                'ドリル1: ${AttributeKeys.labelOf(p.drillAttributeKey!)}',
                                'Drill 1: ${AttributeKeys.labelOf(p.drillAttributeKey!)}'),
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
                            ? Tr.pick('特訓ドリル2', 'Focus drill 2')
                            : Tr.pick(
                                'ドリル2: ${AttributeKeys.labelOf(p.drillAttributeKey2!)}',
                                'Drill 2: ${AttributeKeys.labelOf(p.drillAttributeKey2!)}'),
                      ),
                      onPressed: () => _showDrillPicker2(context, p),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.autorenew, size: 18),
                      label: Text(Tr.pick('ローテーション', 'Rotation')),
                      onPressed: () => _showRotationPicker(context, p),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.flag, size: 18),
                      label: Text(
                        p.developmentTargetRole == null
                            ? Tr.pick('育成プラン', 'Development plan')
                            : Tr.pick('目標: ${p.developmentTargetRole!.label}',
                                'Target: ${p.developmentTargetRole!.label}'),
                      ),
                      onPressed: () => _showDevelopmentPlanPicker(context, p),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  Tr.pick('モチベーション・特性', 'Motivation & traits'),
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
                            ? Tr.pick('声かけ(あと${p.talkCooldownWeeks}週)',
                                'Have a word (${p.talkCooldownWeeks} weeks to go)')
                            : Tr.pick('声かけ', 'Have a word'),
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
                              ? Tr.pick('技術特訓', 'Trait training')
                              : Tr.pick('特訓中: ${p.traitTrainingTarget!.label}',
                                  'Working on: ${p.traitTrainingTarget!.label}'),
                        ),
                        onPressed: () =>
                            _showTechnicalTraitTrainingPicker(context, p),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.diversity_3, size: 18),
                        label: Text(
                          p.personalityTraitTrainingTarget == null
                              ? Tr.pick('性格の指導', 'Personality coaching')
                              : Tr.pick(
                                  '指導中: ${p.personalityTraitTrainingTarget!.label}',
                                  'Coaching: ${p.personalityTraitTrainingTarget!.label}'),
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

  /// 育成プラン(目標ロール)を選ぶピッカー。選手のポジション大分類で
  /// 選択できるロールのみを表示する。
  void _showDevelopmentPlanPicker(BuildContext context, Player p) {
    final gameState = context.read<GameState>();
    final candidates = PlayerRole.values
        .where((r) =>
            r != PlayerRole.standard &&
            r.allowedGroups.contains(p.position.group))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                Tr.pick('${p.name} の育成プラン(目標ロール)',
                    'Development plan for ${p.name}'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                Tr.pick('設定したロールの重視能力値が、週次トレーニングで優先的に伸びるようになる。',
                    'The attributes that matter for the chosen role improve first in weekly training.'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            if (p.developmentTargetRole != null)
              ListTile(
                leading: const Icon(Icons.clear),
                title:
                    Text(Tr.pick('育成プランを解除する', 'Clear the development plan')),
                onTap: () {
                  gameState.setDevelopmentTargetRole(p.id, null);
                  Navigator.pop(ctx);
                },
              ),
            for (final r in candidates)
              ListTile(
                leading: Icon(
                  p.developmentTargetRole == r
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(r.label),
                subtitle: Text(
                  Tr.pick(
                      '${r.description}\n重視: ${r.keyAttributes.map(AttributeKeys.labelOf).join('・')}',
                      "${r.description}\nKey attributes: ${r.keyAttributes.map(AttributeKeys.labelOf).join(', ')}"),
                ),
                isThreeLine: true,
                onTap: () {
                  gameState.setDevelopmentTargetRole(p.id, r);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _mentorName(List<Player> players, String mentorId) {
    for (final p in players) {
      if (p.id == mentorId) return p.name;
    }
    return Tr.pick('(退団済み)', ' (has left the club)');
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
              title: Text(Tr.pick('メンターを解除する', 'Clear the mentor')),
              onTap: () {
                context.read<GameState>().setMentor(mentee.id, null);
                Navigator.of(sheetContext).pop();
              },
            ),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  Tr.pick('${TrainingEngine.minMentorAge}歳以上の選手がいないため指名できません',
                      'Nobody is ${TrainingEngine.minMentorAge} or older, so no mentor can be named'),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            for (final c in candidates)
              ListTile(
                title: Text(c.name),
                subtitle: Text(
                  Tr.pick('${c.age}歳 / ${c.position.label} / 総合 ${c.overall}',
                      'Age ${c.age} / ${c.position.label} / overall ${c.overall}'),
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
                Tr.pick(
                    '特訓ドリル指定中: $activeCount / $maxSlots人（ヘッドコーチのレベルを上げると上限が増える）',
                    'Focus drills in use: $activeCount / $maxSlots (a higher head coach level raises the cap)'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            ListTile(
              title: Text(Tr.pick('特訓ドリルを解除する', 'Clear the focus drill')),
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
                      SnackBar(
                          content: Text(Tr.pick(
                              '特訓ドリルは同時に$maxSlots人までしか指定できません',
                              'You can only run focus drills for $maxSlots players at once'))),
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
                Tr.pick('2つ目の特訓ドリル指定中: $activeCount / $maxSlots人（1つ目より成長率は控えめ）',
                    'Second focus drills in use: $activeCount / $maxSlots (they grow more slowly than the first)'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            ListTile(
              title: Text(
                  Tr.pick('2つ目の特訓ドリルを解除する', 'Clear the second focus drill')),
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
                        content: Text(Tr.pick(
                            '2つ目の特訓ドリルは同時に$maxSlots人までしか指定できません',
                            'You can only run a second focus drill for $maxSlots players at once')),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  Tr.pick(
                      'タップした順に方針が並び、週次トレーニングのたびに上から順番へ自動的に切り替わる。1件も選ばなければ従来通り個別方針/既定方針に従う。',
                      'The focuses queue up in the order you tap them, and each weekly session moves to the next one. Choose none and the player keeps their individual or default focus.'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              if (rotation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    Tr.pick(
                        '現在の順番: ${rotation.map((f) => f.label).join(' → ')}',
                        "Current order: ${rotation.map((f) => f.label).join(' → ')}"),
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
                      ? Text(Tr.pick('順番: ${rotation.indexOf(focus) + 1}番目',
                          'Position ${rotation.indexOf(focus) + 1}'))
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
                        child: Text(Tr.pick('クリア', 'Clear')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          gameState.setPlayerFocusRotation(p.id, rotation);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(Tr.pick('保存', 'Save')),
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
      SnackBar(
          content: Text(ok
              ? Tr.pick('${p.name}に声をかけ、士気が上がった。',
                  'You had a word with ${p.name}, and morale rose.')
              : Tr.pick('声かけに失敗した。', 'The word did not land.'))),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  Tr.pick(
                      '狙いたい技術特性を選ぶと、以後の週次トレーニングで低確率に獲得を目指す特訓を行う。能力値・年齢がその特性に合っているほど成功率が上がる(適性表示を参考に)。',
                      "Pick a technical trait and each weekly session works towards it, with a small chance of picking it up. The better the player's attributes and age suit the trait, the better the odds (see the fit marks)."),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              if (p.traitTrainingTarget != null)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: Text(Tr.pick('技術特訓を解除する', 'Stop the trait training')),
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
                  title: Tr.pick(entry.key.ja, entry.key.en),
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
                  Tr.pick(
                      '性格特性は練習では身につかない。メンター(チームメイト)を指名しているか、監督が今週この選手に声をかけていた週にのみ、低確率で選んだ特性を獲得する。${p.mentorId == null && p.talkCooldownWeeks == 0 ? '(現在はどちらの条件も満たしていない)' : ''}',
                      "Personality traits cannot be trained. The player only has a small chance of picking one up in a week where he has a mentor among his team-mates, or where you had a word with him.${p.mentorId == null && p.talkCooldownWeeks == 0 ? ' (neither applies right now)' : ''}"),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              if (p.personalityTraitTrainingTarget != null)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: Text(
                      Tr.pick('性格の指導を解除する', 'Stop the personality coaching')),
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
                  title: Tr.pick(entry.key.ja, entry.key.en),
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
                  ? Tr.pick('転向先ポジション: 未設定', 'Retraining to: not set')
                  : Tr.pick(
                      '転向先: ${target.label}(慣れ度${player.familiarityFor(target)}/100)',
                      'Retraining to ${target.label} (familiarity ${player.familiarityFor(target)}/100)'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownButton<Position?>(
            value: target,
            hint: Text(Tr.pick('選択', 'Choose')),
            items: [
              DropdownMenuItem<Position?>(
                  value: null, child: Text(Tr.pick('なし', 'None'))),
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
