import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/pitch_game.dart';
import '../logic/cup_engine.dart';
import '../logic/match_engine.dart';
import '../models/attributes.dart';
import '../models/formation.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/team_talk.dart';
import '../models/weather.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/match_widgets.dart';
import '../widgets/player_face_avatar.dart';
import '../l10n/tr.dart';

enum _Phase { firstHalf, halfTime, secondHalf, finished }

/// 自クラブの試合をハーフタイム対応(前半→ハーフタイム指示・交代→後半)で
/// 進行する試合画面。カップ戦など非対話的な試合は引き続きMatchScreenを使う。
class LiveMatchScreen extends StatefulWidget {
  const LiveMatchScreen({super.key});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  _Phase _phase = _Phase.firstHalf;
  final List<MatchEvent> _revealed = [];
  int _currentMinute = 0;
  int _segmentStartMinute = 0;
  MatchResult? _finalResult;
  late PitchGame _game;
  late final String _userTeamId;
  MatchEvent? _goalFlash;
  Timer? _goalFlashTimer;
  bool _decisionDialogShowing = false;

  /// カップ戦のライブ観戦時の大会名(リーグ戦ならnullで「第X節」を表示)。
  /// 試合終了後はliveCupDescriptorがクリアされるため、開始時に控えておく。
  String? _competitionTitle;

  @override
  void dispose() {
    _goalFlashTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final gameState = context.read<GameState>();
    _userTeamId = gameState.userTeam.id;
    _competitionTitle = gameState.liveCupDescriptor?.competitionLabel;
    _segmentStartMinute = 0;
    _game = _buildSegmentGame(gameState, isSecondHalf: false);
  }

  /// 現在のセグメント(判断待ちが発生した分、なければハーフ終了分まで)の
  /// PitchGameを組み立てる。判断待ちが1件もなければ従来通りハーフ全体を
  /// 1つのセグメントとして扱う。
  PitchGame _buildSegmentGame(GameState gameState,
      {required bool isSecondHalf}) {
    final pending = gameState.pendingChanceDecision;
    final halfEnd = isSecondHalf ? 90 : 45;
    final segmentEnd = pending?.minute ?? halfEnd;
    final allEventsSoFar = isSecondHalf
        ? gameState.liveSecondHalfEventsSoFar
        : gameState.liveFirstHalfEventsSoFar;
    final segmentEvents = allEventsSoFar
        .where((e) => e.minute > _segmentStartMinute && e.minute <= segmentEnd)
        .toList();
    final segmentStart = _segmentStartMinute + 1;
    final span = (segmentEnd - _segmentStartMinute).clamp(1, 45);
    final durationSeconds = (span / 45 * 6).clamp(0.6, 6.0);
    return PitchGame(
      events: segmentEvents,
      startMinute: segmentStart,
      endMinute: segmentEnd,
      durationSeconds: durationSeconds,
      onEvent: _handleEvent,
      onFinished: () => _handleSegmentFinished(isSecondHalf: isSecondHalf),
      onMinuteTick: (m) => setState(() => _currentMinute = m),
    );
  }

  void _handleSegmentFinished({required bool isSecondHalf}) {
    _segmentStartMinute = _game.endMinute;
    final gameState = context.read<GameState>();
    final pending = gameState.pendingChanceDecision;
    if (pending != null) {
      _showChanceDecisionDialog(pending);
      return;
    }
    if (!isSecondHalf) {
      setState(() => _phase = _Phase.halfTime);
    } else {
      _handleFullTime();
    }
  }

  Future<void> _showChanceDecisionDialog(PendingChanceDecision pending) async {
    if (_decisionDialogShowing) return;
    _decisionDialogShowing = true;
    final gameState = context.read<GameState>();
    final isAttack = pending.context == ChanceContext.attack;
    final choice = await showDialog<ChanceDecision>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isAttack
            ? Tr.pick('決定機!', 'Big chance!')
            : Tr.pick('相手の決定機!', 'They have a big chance!')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAttack
                  ? Tr.pick('${pending.shooter!.name}がチャンス。狙うプレーを選ぼう。',
                      '${pending.shooter!.name} is in. Choose what he does.')
                  : Tr.pick('${pending.attacker!.name}にチャンス。守り方を選ぼう。',
                      '${pending.attacker!.name} is in on goal. Choose how you defend.'),
            ),
            const SizedBox(height: 10),
            _buildDuelCard(pending),
            const SizedBox(height: 6),
            Text(
              isAttack
                  ? Tr.pick(
                      '(カッコ内は成功率の目安)', '(the figures are rough success rates)')
                  : Tr.pick('(カッコ内は相手の成功率の目安)',
                      '(the figures are their rough success rates)'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: isAttack
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ChanceDecision.shoot),
                  child: Text(
                    Tr.pick('シュート(${_pctText(pending.shootChance)})',
                        'Shoot (${_pctText(pending.shootChance)})'),
                  ),
                ),
                if (pending.passTarget != null)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, ChanceDecision.pass),
                    child: Text(
                      Tr.pick(
                          'パス: ${pending.passTarget!.name}(${_pctText(pending.passChance)})',
                          'Pass to ${pending.passTarget!.name} (${_pctText(pending.passChance)})'),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ChanceDecision.longShot),
                  child: Text(
                    Tr.pick('ロングシュート(${_pctText(pending.longShotChance)})',
                        'Shoot from distance (${_pctText(pending.longShotChance)})'),
                  ),
                ),
              ]
            : [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, ChanceDecision.aggressiveTackle),
                  child: Text(
                    Tr.pick(
                        '積極的にタックル(相手${_pctText(pending.aggressiveChanceAgainst)} / カード注意)',
                        'Go in hard (${_pctText(pending.aggressiveChanceAgainst)} for them / risks a card)'),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, ChanceDecision.coverSpace),
                  child: Text(
                    Tr.pick(
                        'カバーリングに専念(相手${_pctText(pending.safeChanceAgainst)})',
                        'Hold your shape (${_pctText(pending.safeChanceAgainst)} for them)'),
                  ),
                ),
              ],
      ),
    );
    _decisionDialogShowing = false;
    if (!mounted) return;
    final decision =
        choice ?? (isAttack ? ChanceDecision.shoot : ChanceDecision.coverSpace);
    final result = await gameState.resolveChanceDecision(decision);
    if (!mounted) return;

    // 選んだ結果を、アニメーションの再生を待たず即座に反映・演出する。
    final event = result.decisionEvent;
    if (event != null) _handleEvent(event);
    final message = _describeDecisionOutcome(pending, decision, event);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 2600),
        ),
      );

    final merged = result.merged;
    if (merged != null) {
      // この選択で試合(後半)がちょうど完了した。決定機自身のイベントは
      // 直前に_handleEventで既に反映済みのため、残りの分だけを再生する。
      final segmentEvents = merged.events
          .where((e) => e.minute > pending.minute && e.minute <= 90)
          .toList();
      final span = (90 - pending.minute).clamp(1, 45);
      setState(() {
        _finalResult = merged;
        _segmentStartMinute = pending.minute;
        _game = PitchGame(
          events: segmentEvents,
          startMinute: pending.minute + 1,
          endMinute: 90,
          durationSeconds: (span / 45 * 6).clamp(0.6, 6.0),
          onEvent: _handleEvent,
          onFinished: _handleFullTime,
          onMinuteTick: (m) => setState(() => _currentMinute = m),
        );
      });
      return;
    }
    final isSecondHalf = _phase == _Phase.secondHalf;
    setState(() {
      _segmentStartMinute = pending.minute;
      _game = _buildSegmentGame(gameState, isSecondHalf: isSecondHalf);
    });
  }

  String _pctText(double? chance) =>
      chance == null ? '-' : '${(chance * 100).round()}%';

  /// 決定機で実際に勝負する両者の名前と能力値を並べた「対戦カード」。
  /// 攻撃側はシューター(決定力) vs 相手GK(反応速度)、守備側は
  /// 自チーム守備者(タックル) vs 相手選手(ドリブル)を表示する。
  Widget _buildDuelCard(PendingChanceDecision pending) {
    final String leftName;
    final String leftLabel;
    final int leftValue;
    final String rightName;
    final String rightLabel;
    final int rightValue;
    if (pending.context == ChanceContext.attack) {
      final shooter = pending.shooter!;
      final keeper = pending.keeper;
      leftName = shooter.name;
      leftLabel = AttributeKeys.labelOf(AttributeKeys.finishing);
      leftValue = shooter.attributeValue(AttributeKeys.finishing);
      rightName = keeper?.name ?? '-';
      rightLabel = 'GK ${AttributeKeys.labelOf(AttributeKeys.reflexes)}';
      rightValue = keeper?.attributeValue(AttributeKeys.reflexes) ?? 0;
    } else {
      final defender = pending.defender;
      final attacker = pending.attacker!;
      leftName = defender?.name ?? '-';
      leftLabel = AttributeKeys.labelOf(AttributeKeys.tackling);
      leftValue = defender?.attributeValue(AttributeKeys.tackling) ?? 0;
      rightName = attacker.name;
      rightLabel = AttributeKeys.labelOf(AttributeKeys.dribbling);
      rightValue = attacker.attributeValue(AttributeKeys.dribbling);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text('$leftLabel $leftValue',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('vs', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rightName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text('$rightLabel $rightValue',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 選んだプレーの表示名(結果メッセージ・ダイアログ共通)。
  String _choiceLabel(PendingChanceDecision pending, ChanceDecision decision) {
    if (pending.context == ChanceContext.attack) {
      switch (decision) {
        case ChanceDecision.pass:
          return Tr.pick('パス(${pending.passTarget?.name ?? "?"})',
              'Pass (${pending.passTarget?.name ?? "?"})');
        case ChanceDecision.longShot:
          return Tr.pick('ロングシュート', 'Shot from distance');
        default:
          return Tr.pick('シュート', 'Shot');
      }
    }
    return decision == ChanceDecision.aggressiveTackle
        ? Tr.pick('積極的タックル', 'Went in hard')
        : Tr.pick('カバーリング', 'Held shape');
  }

  /// 選択直後に短く表示する結果フィードバック文言。成功率とともに
  /// 「選んだプレーがどうなったか」を明示し、選択の手応えを演出する。
  String _describeDecisionOutcome(
    PendingChanceDecision pending,
    ChanceDecision decision,
    MatchEvent? event,
  ) {
    final label = _choiceLabel(pending, decision);
    if (pending.context == ChanceContext.attack) {
      final pct = _pctText(
        decision == ChanceDecision.pass
            ? pending.passChance
            : decision == ChanceDecision.longShot
                ? pending.longShotChance
                : pending.shootChance,
      );
      if (event?.type == MatchEventType.goal) {
        return Tr.pick('$label($pct)→ ゴール!', '$label ($pct) → Goal!');
      }
      if (event?.type == MatchEventType.chance) {
        return Tr.pick(
            '$label($pct)→ 惜しい!枠の外へ', '$label ($pct) → So close, just wide');
      }
      return Tr.pick('$label($pct)→ 相手に読まれてボールを失った',
          '$label ($pct) → Read it, and the ball is lost');
    }
    final pct = _pctText(
      decision == ChanceDecision.aggressiveTackle
          ? pending.aggressiveChanceAgainst
          : pending.safeChanceAgainst,
    );
    if (event?.type == MatchEventType.goal) {
      return Tr.pick('$label(相手$pct)→ 失点…', '$label (them $pct) → They score…');
    }
    if (event?.type == MatchEventType.redCard) {
      return Tr.pick('$labelでボールは奪ったが、${event?.scorerName}が退場に…',
          '$label won the ball, but ${event?.scorerName} is sent off…');
    }
    if (event?.type == MatchEventType.yellowCard) {
      return Tr.pick('$labelでボールは奪ったが、${event?.scorerName}に警告',
          '$label won the ball, but ${event?.scorerName} is booked');
    }
    if (event?.type == MatchEventType.chance) {
      return Tr.pick('$label(相手$pct)→ 危なかったが凌いだ',
          '$label (them $pct) → Close, but you survive');
    }
    return Tr.pick(
        '$label(相手$pct)→ 攻撃を防いだ!', '$label (them $pct) → Attack snuffed out!');
  }

  /// AppBarに表示する試合中交代ボタン。残り交代枠を表示し、タップで
  /// 出場中イレブンの一覧シートを開く(枠切れ時は無効化)。
  Widget _buildSubstitutionAction(GameState gameState) {
    final remaining =
        GameState.maxSubstitutionsPerMatch - gameState.substitutionsUsed;
    return TextButton.icon(
      onPressed: remaining > 0 ? () => _showLiveSubstitutionSheet() : null,
      icon: Icon(
        Icons.swap_horiz,
        color: remaining > 0 ? Colors.white : Colors.white38,
      ),
      label: Text(
        Tr.pick('交代$remaining', 'Subs $remaining'),
        style: TextStyle(color: remaining > 0 ? Colors.white : Colors.white38),
      ),
    );
  }

  void _showLiveSubstitutionSheet() {
    final gameState = context.read<GameState>();
    final team = gameState.userTeam;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                Tr.pick('試合中の交代(交代する選手を選択)',
                    'Make a substitution (pick who comes off)'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final id in team.startingXI)
              _StartingPlayerTile(playerId: id, team: team, isLive: true),
          ],
        ),
      ),
    );
  }

  /// AppBarに表示する采配方針ボタン。現在の方針をラベル表示し、タップで
  /// 変更ダイアログを開く(通常/リスクを取る/安全に下がる)。
  Widget _buildInstructionAction(GameState gameState) {
    final current = gameState.currentMatchInstruction;
    return TextButton.icon(
      onPressed: () => _showInstructionDialog(gameState),
      icon: const Icon(Icons.campaign, color: Colors.white),
      label: Text(current.label, style: const TextStyle(color: Colors.white)),
    );
  }

  Future<void> _showInstructionDialog(GameState gameState) async {
    final current = gameState.currentMatchInstruction;
    final choice = await showDialog<MatchInstruction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('采配方針', 'Approach')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MatchInstruction.values
              .map(
                (instruction) => ListTile(
                  leading: Icon(
                    instruction == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(instruction.label),
                  subtitle: Text(instruction.description),
                  onTap: () => Navigator.pop(ctx, instruction),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('閉じる', 'Close')),
          ),
        ],
      ),
    );
    if (choice != null && mounted) {
      gameState.setMatchInstruction(choice);
    }
  }

  void _handleEvent(MatchEvent e) {
    setState(() => _revealed.add(e));
    if (e.type == MatchEventType.goal) {
      FeedbackService.goal(isUserGoal: e.teamId == _userTeamId);
      _goalFlashTimer?.cancel();
      setState(() => _goalFlash = e);
      _goalFlashTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _goalFlash = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final fixture = gameState.liveFixture;
    final cup = gameState.liveCupDescriptor;
    final matchday = fixture?.matchday ?? _finalResult?.matchday ?? 0;
    final homeId =
        fixture?.homeTeamId ?? cup?.homeTeamId ?? _finalResult?.homeTeamId;
    final awayId =
        fixture?.awayTeamId ?? cup?.awayTeamId ?? _finalResult?.awayTeamId;
    if (homeId == null || awayId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(Tr.pick('試合', 'Match')),
          automaticallyImplyLeading: false,
        ),
        body: Center(child: Text(Tr.pick('試合情報がありません', 'No match to show'))),
      );
    }
    // カップ戦(特に大陸カップ)ではリーグ順位表に存在しないチームと
    // 対戦しうるため、リーグ限定ではなく全チームから探す。
    final home = gameState.teamById(homeId)!;
    final away = gameState.teamById(awayId)!;
    final homeGoals = _revealed
        .where((e) => e.teamId == home.id && e.type == MatchEventType.goal)
        .length;
    final awayGoals = _revealed
        .where((e) => e.teamId == away.id && e.type == MatchEventType.goal)
        .length;
    final weather = fixture?.weather ??
        cup?.weather ??
        _finalResult?.weather ??
        Weather.clear;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _competitionTitle ?? Tr.pick('第$matchday節', 'Matchday $matchday')),
        automaticallyImplyLeading: false,
        actions: (_phase == _Phase.firstHalf || _phase == _Phase.secondHalf)
            ? [
                _buildSubstitutionAction(gameState),
                _buildInstructionAction(gameState),
              ]
            : null,
      ),
      body: _phase == _Phase.halfTime
          ? _HalfTimePanel(
              home: home,
              away: away,
              homeGoals: homeGoals,
              awayGoals: awayGoals,
              onContinue: () => _startSecondHalf(),
            )
          : _buildMatchView(context, home, away, homeGoals, awayGoals, weather),
    );
  }

  Widget _buildMatchView(
    BuildContext context,
    Team home,
    Team away,
    int homeGoals,
    int awayGoals,
    Weather weather,
  ) {
    final finished = _phase == _Phase.finished;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: WeatherBadge(weather: weather),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: TeamHeader(team: home)),
                  Column(
                    children: [
                      Text(
                        finished
                            ? Tr.pick('試合終了', 'Full time')
                            : "$_currentMinute'",
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: finished ? Colors.redAccent : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$homeGoals - $awayGoals',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ],
                  ),
                  Expanded(child: TeamHeader(team: away)),
                ],
              ),
            ),
            if (!finished)
              _MomentumBar(
                valueForHome:
                    context.read<GameState>().liveMomentumForHome ?? 0,
              ),
            if (finished)
              FullTimeBanner(userTeamId: _userTeamId, result: _finalResult),
            if (finished && context.read<GameState>().lastShootout != null)
              _PenaltyShootoutBoard(
                shootout: context.read<GameState>().lastShootout!,
                home: home,
                away: away,
              ),
            if (finished && context.read<GameState>().lastLiveCupNote != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  context.read<GameState>().lastLiveCupNote!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            if (finished && context.read<GameState>().lastCupPrizeNote != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  context.read<GameState>().lastCupPrizeNote!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            if (finished)
              ManOfTheMatchBanner(
                result: _finalResult,
                teams: [home, away],
                userTeamId: _userTeamId,
              ),
            if (finished && _finalResult != null)
              MatchStatsBar(
                result: _finalResult!,
                homeTeamName: home.name,
                awayTeamName: away.name,
              ),
            if (finished)
              TraitActivationBanner(
                userTeam: context.read<GameState>().userTeam,
              ),
            AspectRatio(
              aspectRatio: 3 / 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: GameWidget(game: _game),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _revealed
                    .map(
                      (e) => CommentaryTile(
                        event: e,
                        teamName: e.teamId == home.id ? home.name : away.name,
                        userTeam: home.id == _userTeamId ? home : away,
                      ),
                    )
                    .toList(),
              ),
            ),
            if (finished)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(Tr.pick('戻る', 'Back')),
                  ),
                ),
              ),
          ],
        ),
        if (_goalFlash != null)
          _GoalFlashBanner(
            key: ValueKey(_goalFlash),
            event: _goalFlash!,
            scoringTeamName:
                _goalFlash!.teamId == home.id ? home.name : away.name,
            scorerName: _scorerNameFor(_goalFlash!, home, away),
          ),
      ],
    );
  }

  String? _scorerNameFor(MatchEvent event, Team home, Team away) {
    final scorerId = event.scorerId;
    if (scorerId == null) return null;
    final team = event.teamId == home.id ? home : away;
    for (final p in team.players) {
      if (p.id == scorerId) return p.name;
    }
    return null;
  }

  Future<void> _startSecondHalf() async {
    final gameState = context.read<GameState>();
    final merged = await gameState.playSecondHalf(interactive: true);
    if (!mounted) return;
    _segmentStartMinute = 45;
    if (merged != null) {
      // 後半にオープンプレーの決定機が1件もなく、即座に試合が確定した。
      final secondHalfEvents =
          merged.events.where((e) => e.minute > 45).toList();
      setState(() {
        _finalResult = merged;
        _phase = _Phase.secondHalf;
        _game = PitchGame(
          events: secondHalfEvents,
          startMinute: 46,
          endMinute: 90,
          durationSeconds: 6,
          onEvent: _handleEvent,
          onFinished: _handleFullTime,
          onMinuteTick: (m) => setState(() => _currentMinute = m),
        );
      });
      return;
    }
    setState(() {
      _phase = _Phase.secondHalf;
      _game = _buildSegmentGame(gameState, isSecondHalf: true);
    });
  }

  void _handleFullTime() {
    setState(() => _phase = _Phase.finished);
    final result = _finalResult;
    if (result == null) return;
    final userIsHome = result.homeTeamId == _userTeamId;
    final userGoals = userIsHome ? result.homeGoals : result.awayGoals;
    final oppGoals = userIsHome ? result.awayGoals : result.homeGoals;
    FeedbackService.matchResult(
      won: userGoals > oppGoals,
      drew: userGoals == oppGoals,
    );
  }
}

/// 得点発生時に一時的に表示される演出バナー。
class _GoalFlashBanner extends StatelessWidget {
  final MatchEvent event;
  final String scoringTeamName;
  final String? scorerName;

  const _GoalFlashBanner({
    super.key,
    required this.event,
    required this.scoringTeamName,
    required this.scorerName,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24,
      left: 24,
      right: 24,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GOAL!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                ),
                Text(
                  scorerName != null
                      ? '$scoringTeamName / $scorerName'
                      : scoringTeamName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                if (event.assistName != null)
                  Text(
                    Tr.pick('アシスト: ${event.assistName}',
                        'Assist: ${event.assistName}'),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimary
                          .withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「試合の流れ」(モメンタム)をホーム/アウェイの綱引きバーとして表示する。
/// [valueForHome]はホーム視点で-1.0〜+1.0(正ならホーム側が優勢)。
/// 直近の得点で流れをつかんだ側のバーが伸び、時間経過で中央へ戻っていく。
class _MomentumBar extends StatelessWidget {
  final double valueForHome;

  const _MomentumBar({required this.valueForHome});

  @override
  Widget build(BuildContext context) {
    // 完全に0/100になると帯そのものが見えなくなるため5〜95%に留める。
    final homeShare = (((valueForHome + 1) / 2) * 100).round().clamp(5, 95);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Semantics(
        label: Tr.pick('試合の流れ: ホーム側$homeShare%', 'Momentum: home $homeShare%'),
        child: Column(
          children: [
            Text(
              Tr.pick('試合の流れ', 'Momentum'),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    Expanded(
                      flex: homeShare,
                      child: Container(color: Colors.indigo),
                    ),
                    Expanded(
                      flex: 100 - homeShare,
                      child: Container(color: Colors.deepOrange),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HalfTimePanel extends StatelessWidget {
  final Team home;
  final Team away;
  final int homeGoals;
  final int awayGoals;
  final VoidCallback onContinue;

  const _HalfTimePanel({
    required this.home,
    required this.away,
    required this.homeGoals,
    required this.awayGoals,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final remaining =
        GameState.maxSubstitutionsPerMatch - gameState.substitutionsUsed;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(Tr.pick('ハーフタイム', 'Half time'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '$homeGoals - $awayGoals',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  '${home.name} vs ${away.name}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          Text(Tr.pick('檄を飛ばす', 'Give them a rocket'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            Tr.pick('先発イレブンの士気を変動させる。選手の性格によって効果は変わる。',
                "Shifts the morale of your starting XI. How it lands depends on each player's personality."),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final tone in TeamTalkTone.values)
                Tooltip(
                  message: tone.description,
                  child: OutlinedButton(
                    onPressed: () => gameState.giveTeamTalk(tone),
                    child: Text(tone.label),
                  ),
                ),
            ],
          ),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(Tr.pick('逃げ切りモード', 'See out the game')),
            subtitle: Text(Tr.pick('攻撃力がやや下がる代わりに守備が安定し、疲労蓄積も抑えられる。',
                'A little less attacking threat, but a steadier defence and less fatigue.')),
            value: team.timeWastingMode,
            onChanged: (v) => gameState.setTimeWastingMode(v),
          ),
          const Divider(height: 32),
          Text(Tr.pick('戦術指示', 'Tactical instructions'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            Tr.pick('前半の展開を見て、後半だけフォーメーションを変更できる。',
                'Having seen the first half, you can change formation for the second.'),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                  width: 90, child: Text(Tr.pick('フォーメーション', 'Formation'))),
              Expanded(
                child: DropdownButton<Formation>(
                  isExpanded: true,
                  value: team.formation,
                  items: Formation.values
                      .map(
                        (f) => DropdownMenuItem(value: f, child: Text(f.label)),
                      )
                      .toList(),
                  onChanged: (f) {
                    if (f != null) {
                      FeedbackService.tap();
                      gameState.setFormation(f);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 90, child: Text(Tr.pick('プレッシング', 'Pressing'))),
              Expanded(
                child: Slider(
                  value: team.pressing.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  label: '${team.pressing}',
                  onChanged: (v) => gameState.setPressing(v.round()),
                ),
              ),
              SizedBox(width: 32, child: Text('${team.pressing}')),
            ],
          ),
          Row(
            children: [
              SizedBox(
                  width: 90, child: Text(Tr.pick('ライン高さ', 'Defensive line'))),
              Expanded(
                child: Slider(
                  value: team.lineHeight.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  label: '${team.lineHeight}',
                  onChanged: (v) => gameState.setLineHeight(v.round()),
                ),
              ),
              SizedBox(width: 32, child: Text('${team.lineHeight}')),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(Tr.pick('交代', 'Substitution'),
                  style: Theme.of(context).textTheme.titleMedium),
              Text(Tr.pick('残り$remaining回', '$remaining left')),
            ],
          ),
          const SizedBox(height: 8),
          for (final id in team.startingXI)
            _StartingPlayerTile(playerId: id, team: team),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: Text(Tr.pick('後半開始', 'Start the second half')),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartingPlayerTile extends StatelessWidget {
  final String playerId;
  final Team team;

  /// trueなら試合進行中のライブ交代([GameState.makeLiveSubstitution])、
  /// falseならハーフタイム交代として扱う。
  final bool isLive;

  const _StartingPlayerTile({
    required this.playerId,
    required this.team,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final p = team.players.firstWhere((pl) => pl.id == playerId);
    final canSub = gameState.canMakeSubstitution;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: PlayerFaceAvatar(
          playerId: p.id,
          position: p.position,
          highlighted: true,
        ),
        title: Text(p.name),
        subtitle: Text(
          Tr.pick(
              '${p.position.label} / 総合 ${p.overall}${p.fatigue > 70 ? ' / 疲労大' : ''}',
              "${p.position.label} / overall ${p.overall}${p.fatigue > 70 ? ' / very tired' : ''}"),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.swap_horiz),
          tooltip: Tr.pick('交代', 'Substitution'),
          onPressed: canSub ? () => _showSubstituteSheet(context) : null,
        ),
      ),
    );
  }

  void _showSubstituteSheet(BuildContext context) {
    final gameState = context.read<GameState>();
    final out = team.players.firstWhere((pl) => pl.id == playerId);
    final candidates = team.players
        .where(
          (p) =>
              !p.isInjured &&
              !p.isOnInternationalDuty &&
              !p.isSuspended &&
              !team.startingXI.contains(p.id),
        )
        .where(
          (p) =>
              p.position == out.position ||
              p.position.group == out.position.group,
        )
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
              child: Text(
                Tr.pick('${out.name} を交代', 'Take ${out.name} off'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final p in candidates)
              ListTile(
                leading: PlayerFaceAvatar(playerId: p.id, position: p.position),
                title: Text(p.name),
                subtitle: Text(Tr.pick('${p.position.label} / 総合 ${p.overall}',
                    '${p.position.label} / overall ${p.overall}')),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isLive) {
                    final ok = gameState.makeLiveSubstitution(
                      outPlayerId: out.id,
                      inPlayerId: p.id,
                    );
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(Tr.pick(
                              '今は交代できません(目前の決定機に関わる選手か、交代枠切れ)',
                              'You cannot make a change right now (the player is in the middle of a chance, or you are out of subs)')),
                        ),
                      );
                    }
                  } else {
                    gameState.makeHalfTimeSubstitution(
                      outPlayerId: out.id,
                      inPlayerId: p.id,
                    );
                  }
                },
              ),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    Tr.pick('交代できる選手がいません', 'Nobody available to come on')),
              ),
          ],
        ),
      ),
    );
  }
}

/// フルタイム画面でPK戦を1本ずつ順番に明かしていく演出ボード。
/// [GameState.lastShootout]の記録を、一定間隔で1キックずつ表示する。
class _PenaltyShootoutBoard extends StatefulWidget {
  final PenaltyShootoutResult shootout;
  final Team home;
  final Team away;

  const _PenaltyShootoutBoard({
    required this.shootout,
    required this.home,
    required this.away,
  });

  @override
  State<_PenaltyShootoutBoard> createState() => _PenaltyShootoutBoardState();
}

class _PenaltyShootoutBoardState extends State<_PenaltyShootoutBoard> {
  int _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (!mounted) return;
      setState(() => _shown++);
      if (_shown >= widget.shootout.kicks.length) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _kickIcons(String teamId) {
    final kicks = widget.shootout.kicks
        .take(_shown)
        .where((k) => k.teamId == teamId)
        .toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final k in kicks)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              k.scored ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: k.scored ? Colors.green : Colors.redAccent,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shootout;
    final done = _shown >= s.kicks.length;
    final last =
        _shown > 0 && _shown <= s.kicks.length ? s.kicks[_shown - 1] : null;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            done
                ? Tr.pick('PK戦 ${s.homeScore} - ${s.awayScore}',
                    'Shootout ${s.homeScore} - ${s.awayScore}')
                : Tr.pick('PK戦', 'Penalty shootout'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          for (final t in [widget.home, widget.away])
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                _kickIcons(t.id),
              ],
            ),
          const SizedBox(height: 4),
          if (!done && last != null)
            Text(
              last.scored
                  ? Tr.pick(
                      '${last.kickerName}が決めた!', '${last.kickerName} scores!')
                  : Tr.pick(
                      '${last.kickerName}は失敗…', '${last.kickerName} misses…'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
