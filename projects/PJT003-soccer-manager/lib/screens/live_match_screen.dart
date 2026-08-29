import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/pitch_game.dart';
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
  MatchResult? _finalResult;
  late PitchGame _game;
  late final String _userTeamId;
  MatchEvent? _goalFlash;
  Timer? _goalFlashTimer;

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
    final firstHalf = gameState.liveFirstHalf!;
    _game = PitchGame(
      events: firstHalf.events,
      startMinute: 1,
      endMinute: 45,
      durationSeconds: 6,
      onEvent: _handleEvent,
      onFinished: () => setState(() => _phase = _Phase.halfTime),
      onMinuteTick: (m) => setState(() => _currentMinute = m),
    );
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
    final matchday = fixture?.matchday ?? _finalResult?.matchday ?? 0;
    final homeId = fixture?.homeTeamId ?? _finalResult?.homeTeamId;
    final awayId = fixture?.awayTeamId ?? _finalResult?.awayTeamId;
    if (homeId == null || awayId == null) {
      return Scaffold(
        appBar:
            AppBar(title: const Text('試合'), automaticallyImplyLeading: false),
        body: const Center(child: Text('試合情報がありません')),
      );
    }
    final league = gameState.save!.league;
    final home = league.teams.firstWhere((t) => t.id == homeId);
    final away = league.teams.firstWhere((t) => t.id == awayId);
    final homeGoals = _revealed
        .where((e) => e.teamId == home.id && e.type == MatchEventType.goal)
        .length;
    final awayGoals = _revealed
        .where((e) => e.teamId == away.id && e.type == MatchEventType.goal)
        .length;
    final weather = fixture?.weather ?? _finalResult?.weather ?? Weather.clear;

    return Scaffold(
      appBar:
          AppBar(title: Text('第$matchday節'), automaticallyImplyLeading: false),
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

  Widget _buildMatchView(BuildContext context, Team home, Team away,
      int homeGoals, int awayGoals, Weather weather) {
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
                        finished ? '試合終了' : "$_currentMinute'",
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
                        child: Text('$homeGoals - $awayGoals',
                            style: Theme.of(context).textTheme.headlineMedium),
                      ),
                    ],
                  ),
                  Expanded(child: TeamHeader(team: away)),
                ],
              ),
            ),
            if (finished)
              FullTimeBanner(userTeamId: _userTeamId, result: _finalResult),
            if (finished)
              ManOfTheMatchBanner(
                  result: _finalResult,
                  teams: [home, away],
                  userTeamId: _userTeamId),
            if (finished && _finalResult != null)
              MatchStatsBar(
                  result: _finalResult!,
                  homeTeamName: home.name,
                  awayTeamName: away.name),
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
                    .map((e) => CommentaryTile(
                        event: e,
                        teamName: e.teamId == home.id ? home.name : away.name,
                        userTeam: home.id == _userTeamId ? home : away))
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
                    child: const Text('戻る'),
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
    final merged = await gameState.playSecondHalf();
    if (merged == null || !mounted) return;
    final secondHalfEvents = merged.events.where((e) => e.minute > 45).toList();
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
  }

  void _handleFullTime() {
    setState(() => _phase = _Phase.finished);
    final result = _finalResult;
    if (result == null) return;
    final userIsHome = result.homeTeamId == _userTeamId;
    final userGoals = userIsHome ? result.homeGoals : result.awayGoals;
    final oppGoals = userIsHome ? result.awayGoals : result.homeGoals;
    FeedbackService.matchResult(
        won: userGoals > oppGoals, drew: userGoals == oppGoals);
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
                    color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))
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
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                ),
                if (event.assistName != null)
                  Text(
                    'アシスト: ${event.assistName}',
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
                Text('ハーフタイム', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('$homeGoals - $awayGoals',
                    style: Theme.of(context).textTheme.headlineMedium),
                Text('${home.name} vs ${away.name}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Divider(height: 32),
          Text('檄を飛ばす', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('先発イレブンの士気を変動させる。選手の性格によって効果は変わる。',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
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
            title: const Text('逃げ切りモード'),
            subtitle: const Text('攻撃力がやや下がる代わりに守備が安定し、疲労蓄積も抑えられる。'),
            value: team.timeWastingMode,
            onChanged: (v) => gameState.setTimeWastingMode(v),
          ),
          const Divider(height: 32),
          Text('戦術指示', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('前半の展開を見て、後半だけフォーメーションを変更できる。',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 90, child: Text('フォーメーション')),
              Expanded(
                child: DropdownButton<Formation>(
                  isExpanded: true,
                  value: team.formation,
                  items: Formation.values
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.label),
                          ))
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
              const SizedBox(width: 90, child: Text('プレッシング')),
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
              const SizedBox(width: 90, child: Text('ライン高さ')),
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
              Text('交代', style: Theme.of(context).textTheme.titleMedium),
              Text('残り$remaining回'),
            ],
          ),
          const SizedBox(height: 8),
          for (final id in team.startingXI)
            _StartingPlayerTile(playerId: id, team: team),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child:
                FilledButton(onPressed: onContinue, child: const Text('後半開始')),
          ),
        ],
      ),
    );
  }
}

class _StartingPlayerTile extends StatelessWidget {
  final String playerId;
  final Team team;

  const _StartingPlayerTile({required this.playerId, required this.team});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final p = team.players.firstWhere((pl) => pl.id == playerId);
    final canSub = gameState.canMakeSubstitution;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: PlayerFaceAvatar(
            playerId: p.id, position: p.position, highlighted: true),
        title: Text(p.name),
        subtitle: Text(
          '${p.position.label} / 総合 ${p.overall}${p.fatigue > 70 ? ' / 疲労大' : ''}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.swap_horiz),
          tooltip: '交代',
          onPressed: canSub ? () => _showSubstituteSheet(context) : null,
        ),
      ),
    );
  }

  void _showSubstituteSheet(BuildContext context) {
    final gameState = context.read<GameState>();
    final out = team.players.firstWhere((pl) => pl.id == playerId);
    final candidates = team.players
        .where((p) =>
            !p.isInjured &&
            !p.isOnInternationalDuty &&
            !p.isSuspended &&
            !team.startingXI.contains(p.id))
        .where((p) =>
            p.position == out.position ||
            p.position.group == out.position.group)
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
              child: Text('${out.name} を交代',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final p in candidates)
              ListTile(
                leading: PlayerFaceAvatar(playerId: p.id, position: p.position),
                title: Text(p.name),
                subtitle: Text('${p.position.label} / 総合 ${p.overall}'),
                onTap: () {
                  Navigator.pop(ctx);
                  gameState.makeHalfTimeSubstitution(
                      outPlayerId: out.id, inPlayerId: p.id);
                },
              ),
            if (candidates.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16), child: Text('交代できる選手がいません')),
          ],
        ),
      ),
    );
  }
}
