import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/pitch_game.dart';
import '../models/match_result.dart';
import '../models/team.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/match_widgets.dart';

class MatchScreen extends StatefulWidget {
  final MatchResult result;
  final List<Team> teams;

  /// 画面上部に表示する見出し(省略時は「第N節」)。カップ戦ではラウンド名を渡す。
  final String? title;

  const MatchScreen({
    super.key,
    required this.result,
    required this.teams,
    this.title,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final List<MatchEvent> _revealed = [];
  bool _finished = false;
  int _currentMinute = 0;
  late final PitchGame _game;
  late final String _userTeamId;

  @override
  void initState() {
    super.initState();
    _userTeamId = context.read<GameState>().userTeam.id;
    _game = PitchGame(
      events: widget.result.events,
      onEvent: (e) => setState(() => _revealed.add(e)),
      onFinished: _handleFinished,
      onMinuteTick: (m) => setState(() => _currentMinute = m),
    );
  }

  void _handleFinished() {
    setState(() => _finished = true);
    final r = widget.result;
    final userIsHome = r.homeTeamId == _userTeamId;
    final userGoals = userIsHome ? r.homeGoals : r.awayGoals;
    final oppGoals = userIsHome ? r.awayGoals : r.homeGoals;
    FeedbackService.matchResult(
      won: userGoals > oppGoals,
      drew: userGoals == oppGoals,
    );
  }

  @override
  Widget build(BuildContext context) {
    final teams = widget.teams;
    final home = teams.firstWhere((t) => t.id == widget.result.homeTeamId);
    final away = teams.firstWhere((t) => t.id == widget.result.awayTeamId);
    final homeGoalsSoFar = _revealed
        .where((e) => e.teamId == home.id && e.type == MatchEventType.goal)
        .length;
    final awayGoalsSoFar = _revealed
        .where((e) => e.teamId == away.id && e.type == MatchEventType.goal)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '第${widget.result.matchday}節'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: WeatherBadge(weather: widget.result.weather),
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
                      _finished ? '試合終了' : "$_currentMinute'",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: _finished ? Colors.redAccent : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$homeGoalsSoFar - $awayGoalsSoFar',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                Expanded(child: TeamHeader(team: away)),
              ],
            ),
          ),
          if (_finished)
            FullTimeBanner(userTeamId: _userTeamId, result: widget.result),
          if (_finished)
            ManOfTheMatchBanner(
              result: widget.result,
              teams: teams,
              userTeamId: _userTeamId,
            ),
          if (_finished)
            MatchStatsBar(
              result: widget.result,
              homeTeamName: home.name,
              awayTeamName: away.name,
            ),
          if (_finished)
            TraitActivationBanner(userTeam: context.read<GameState>().userTeam),
          const SizedBox(height: 8),
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
              children: _buildCommentary(teams),
            ),
          ),
          if (_finished)
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
    );
  }

  List<Widget> _buildCommentary(List<Team> teams) {
    final items = <Widget>[];
    var halfTimeShown = false;
    final userTeam = teams.firstWhere(
      (t) => t.id == _userTeamId,
      orElse: () => teams.first,
    );
    for (final e in _revealed) {
      if (!halfTimeShown && e.minute > 45) {
        items.add(const _HalfTimeDivider());
        halfTimeShown = true;
      }
      items.add(
        CommentaryTile(
          event: e,
          teamName: teams.firstWhere((t) => t.id == e.teamId).name,
          userTeam: userTeam,
        ),
      );
    }
    if (!halfTimeShown && _currentMinute >= 45) {
      items.add(const _HalfTimeDivider());
    }
    return items;
  }
}

class _HalfTimeDivider extends StatelessWidget {
  const _HalfTimeDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '前半終了',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
