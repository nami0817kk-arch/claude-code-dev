import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/promotion_engine.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../models/team.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/achievement_unlock_notifier.dart';
import '../widgets/club_emblem.dart';
import '../widgets/match_widgets.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'scout_report_screen.dart';

/// 大陸カップ出場資格が得られる順位(GameState.startNextSeasonの`finalRank <= 2`と一致)。
const int _continentalQualifyCount = 2;

class FixturesScreen extends StatelessWidget {
  const FixturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final league = gameState.save!.league;
    final userTeamId = gameState.userTeam.id;
    final seasonComplete = league.isSeasonComplete;
    final divisionTier = gameState.save!.currentDivisionTier;
    final otherDivisions = <(int tier, League league)>[
      for (int tier = 1; tier <= totalDivisionTiers; tier++)
        if (tier != divisionTier &&
            gameState.save!.otherDivisionLeagues[tier - 1] != null)
          (tier, gameState.save!.otherDivisionLeagues[tier - 1]!),
    ];

    return DefaultTabController(
      length: 2 + otherDivisions.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('日程・順位表'),
          bottom: TabBar(
            isScrollable: otherDivisions.isNotEmpty,
            tabs: [
              const Tab(text: '順位表'),
              const Tab(text: '日程'),
              for (final (tier, _) in otherDivisions) Tab(text: '$tier部順位表'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.query_stats),
              tooltip: '順位予測シミュレーション',
              onPressed:
                  seasonComplete ? null : () => _showProjectionSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.fast_forward),
              tooltip: 'まとめてシミュレーション',
              onPressed:
                  seasonComplete ? null : () => _showQuickSimDialog(context),
            ),
          ],
        ),
        drawer: const QuickAccessDrawer(),
        body: ResponsiveBody(
          child: TabBarView(
            children: [
              _StandingsTab(
                league: league,
                userTeamId: userTeamId,
                divisionTier: divisionTier,
              ),
              _ScheduleTab(league: league, userTeamId: userTeamId),
              for (final (tier, otherLeague) in otherDivisions)
                _StandingsTab(
                  league: otherLeague,
                  userTeamId: userTeamId,
                  divisionTier: tier,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showQuickSimDialog(BuildContext context) async {
    final gameState = context.read<GameState>();
    final remainingMatchdays = gameState.save!.league.fixtures
        .where((f) => f.result == null)
        .map((f) => f.matchday)
        .toSet()
        .length;

    final choice = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('まとめてシミュレーション'),
        children: [
          for (final n in [1, 3, 5])
            if (n < remainingMatchdays)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, n),
                child: Text('$n節先まで進める'),
              ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, remainingMatchdays),
            child: const Text('シーズン終了まで進める'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
    if (choice == null || choice <= 0 || !context.mounted) return;

    FeedbackService.tap();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('$choice節分をシミュレーションしています…'),
              ],
            ),
          ),
        ),
      ),
    );
    final results = await gameState.simulateAheadMatchdays(choice);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final league = gameState.save!.league;
    final userTeamId = gameState.userTeam.id;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('シミュレーション結果'),
        content: SizedBox(
          width: double.maxFinite,
          child: results.isEmpty
              ? const Text('進行できる試合がありませんでした')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final r = results[i];
                    final isHome = r.homeTeamId == userTeamId;
                    final opponentId = isHome ? r.awayTeamId : r.homeTeamId;
                    final opponentName =
                        league.teams.firstWhere((t) => t.id == opponentId).name;
                    final userGoals = isHome ? r.homeGoals : r.awayGoals;
                    final oppGoals = isHome ? r.awayGoals : r.homeGoals;
                    return ListTile(
                      dense: true,
                      title: Text('第${r.matchday}節 vs $opponentName'),
                      trailing: Text(
                        '$userGoals - $oppGoals',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
    if (context.mounted) showAchievementUnlockNotification(context, gameState);
  }

  Future<void> _showProjectionSheet(BuildContext context) async {
    final gameState = context.read<GameState>();
    final projections = gameState.seasonProjection;
    final league = gameState.save!.league;
    final userTeamId = gameState.userTeam.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '順位予測シミュレーション',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '現在の総合力をもとに残り試合を簡易シミュレーションした見込みです。実際の結果を保証するものではありません。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: projections.length,
                  itemBuilder: (context, i) {
                    final p = projections[i];
                    final team = league.teams.firstWhere(
                      (t) => t.id == p.teamId,
                    );
                    final isUser = p.teamId == userTeamId;
                    final tile = Container(
                      color: isUser
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.3)
                          : null,
                      child: ListTile(
                        dense: true,
                        leading: SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        title: Text(team.name),
                        subtitle: Text(
                          '予測勝点 ${p.avgFinalPoints.toStringAsFixed(1)}',
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (p.titleProbability >= 0.01)
                              Text(
                                '優勝 ${(p.titleProbability * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (p.continentalProbability >= 0.01)
                              Text(
                                'カップ圏 ${(p.continentalProbability * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 11),
                              ),
                            if (p.relegationProbability >= 0.01)
                              Text(
                                '降格 ${(p.relegationProbability * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SemanticColors.negative(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (!isUser) return tile;
                    return Semantics(
                      label: '自クラブ。${i + 1}位予測: ${team.name}、'
                          '予測勝点 ${p.avgFinalPoints.toStringAsFixed(1)}',
                      child: ExcludeSemantics(child: tile),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingsTab extends StatelessWidget {
  final League league;
  final String userTeamId;
  final int divisionTier;

  const _StandingsTab({
    required this.league,
    required this.userTeamId,
    required this.divisionTier,
  });

  @override
  Widget build(BuildContext context) {
    final rows = league.sortedStandings;
    final showContinental = divisionTier == 1;
    final showPromotion = divisionTier > 1;
    final showRelegation = divisionTier < totalDivisionTiers;
    final maxOverall = league.teams.fold<int>(
      1,
      (m, t) => t.overallRating > m ? t.overallRating : m,
    );
    final relegationStart = rows.length - PromotionEngine.swapCount;
    const autoPromotionEnd = PromotionEngine.automaticPromotionCount;
    const playoffEnd = autoPromotionEnd + PromotionEngine.playoffPoolSize;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (showContinental)
                _ZoneLegend(color: Colors.amber.shade700, label: '大陸カップ出場圏'),
              if (showPromotion) ...[
                _ZoneLegend(
                  color: SemanticColors.positive(context),
                  label: '自動昇格圏',
                ),
                _ZoneLegend(
                  color: Colors.deepPurple.shade300,
                  label: '昇格プレーオフ圏',
                ),
              ],
              if (showRelegation)
                _ZoneLegend(
                  color: SemanticColors.negative(context),
                  label: '降格圏',
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final team = league.teams.firstWhere((t) => t.id == r.teamId);
              final isUser = r.teamId == userTeamId;
              Color? zoneColor;
              if (showContinental && i < _continentalQualifyCount) {
                zoneColor = Colors.amber.shade700;
              } else if (showPromotion && i < autoPromotionEnd) {
                zoneColor = SemanticColors.positive(context);
              } else if (showPromotion && i < playoffEnd) {
                zoneColor = Colors.deepPurple.shade300;
              } else if (showRelegation && i >= relegationStart) {
                zoneColor = SemanticColors.negative(context);
              }
              final row = Container(
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4)
                      : null,
                  border: zoneColor == null
                      ? null
                      : Border(left: BorderSide(color: zoneColor, width: 4)),
                ),
                child: ListTile(
                  leading: SizedBox(
                    width: 48,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 20, child: Text('${i + 1}')),
                        const SizedBox(width: 6),
                        ClubEmblem(
                          teamId: team.id,
                          teamName: team.name,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                  title: Text(team.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.played}試合 勝${r.won} 分${r.draw} 敗${r.lost} 得失点差${r.goalDiff}',
                      ),
                      const SizedBox(height: 4),
                      _FormGuide(results: league.recentFormFor(r.teamId)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: team.overallRating / maxOverall,
                                minHeight: 5,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '戦力${team.overallRating}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${r.points}pt',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              );
              if (!isUser) return row;
              return Semantics(
                label: '自クラブ。${i + 1}位: ${team.name}、'
                    '${r.played}試合 勝${r.won} 分${r.draw} 敗${r.lost} 得失点差${r.goalDiff}、'
                    '${r.points}pt、戦力${team.overallRating}',
                child: ExcludeSemantics(child: row),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 直近5試合の勝敗(W/D/L)を古い順→新しい順の丸アイコンで示すフォームガイド。
class _FormGuide extends StatelessWidget {
  final List<String> results;

  const _FormGuide({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    Color colorFor(String r) => switch (r) {
          'W' => SemanticColors.positive(context),
          'L' => SemanticColors.negative(context),
          _ => SemanticColors.neutral(context),
        };
    return Semantics(
      label: '直近${results.length}試合のフォーム: ${results.join('、')}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in results)
              Container(
                margin: const EdgeInsets.only(right: 3),
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorFor(r),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  r,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 消化済みの試合をタップした際に表示する、得点者・MOTMを含む簡易結果ダイアログ。
Future<void> _showFixtureResultDialog(
  BuildContext context,
  MatchResult result,
  Team home,
  Team away,
) {
  String? nameOf(String? playerId) {
    if (playerId == null) return null;
    for (final t in [home, away]) {
      for (final p in t.players) {
        if (p.id == playerId) return p.name;
      }
    }
    return null;
  }

  final goals = result.events
      .where((e) => e.type == MatchEventType.goal)
      .toList()
    ..sort((a, b) => a.minute.compareTo(b.minute));
  final motmName = nameOf(result.manOfTheMatchId);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        '${home.name} ${result.homeGoals} - ${result.awayGoals} ${away.name}',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (goals.isEmpty)
              const Text('得点者はいませんでした', style: TextStyle(color: Colors.grey))
            else ...[
              Text('得点者', style: Theme.of(dialogContext).textTheme.titleSmall),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final g in goals)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${g.minute}\' ${g.scorerName ?? '不明'}'
                          '${g.assistName != null ? '（アシスト: ${g.assistName}）' : ''}'
                          '（${g.teamId == home.id ? home.name : away.name}）',
                        ),
                      ),
                  ],
                ),
              ),
            ],
            MatchStatsBar(
              result: result,
              homeTeamName: home.name,
              awayTeamName: away.name,
            ),
            if (motmName != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Expanded(child: Text('マン・オブ・ザ・マッチ: $motmName')),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

class _ZoneLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ZoneLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _ScheduleTab extends StatefulWidget {
  final League league;
  final String userTeamId;

  const _ScheduleTab({required this.league, required this.userTeamId});

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  bool _showFullSchedule = false;
  late int _selectedMatchday;
  final _chipScrollController = ScrollController();

  int get _totalMatchdays => widget.league.fixtures
      .map((f) => f.matchday)
      .reduce((a, b) => a > b ? a : b);

  int? get _nextMatchday => widget.league.nextUnplayedFixture?.matchday;

  @override
  void initState() {
    super.initState();
    _selectedMatchday = _nextMatchday ?? _totalMatchdays;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chipScrollController.hasClients) return;
      final offset = ((_selectedMatchday - 1) * 76.0).clamp(
        0.0,
        _chipScrollController.position.maxScrollExtent,
      );
      _chipScrollController.jumpTo(offset);
    });
  }

  @override
  void dispose() {
    _chipScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final userTeamId = widget.userTeamId;

    final gameState = context.watch<GameState>();
    return Column(
      children: [
        if (gameState.isUserDomesticCupMatchUpNext)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: const ListTile(
                leading: Icon(Icons.emoji_events_outlined),
                title: Text('国内カップ戦の出番です'),
                subtitle: Text('カップ戦画面で次の試合を消化できます'),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('自分の日程')),
              ButtonSegment(value: true, label: Text('全日程')),
            ],
            selected: {_showFullSchedule},
            onSelectionChanged: (s) =>
                setState(() => _showFullSchedule = s.first),
          ),
        ),
        if (_showFullSchedule) ...[
          SizedBox(
            height: 44,
            child: ListView.builder(
              controller: _chipScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _totalMatchdays,
              itemBuilder: (context, i) {
                final md = i + 1;
                final isNext = md == _nextMatchday;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(isNext ? '第$md節 •' : '第$md節'),
                    selected: _selectedMatchday == md,
                    onSelected: (_) => setState(() => _selectedMatchday = md),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _MatchdayList(
              league: league,
              matchday: _selectedMatchday,
              userTeamId: userTeamId,
            ),
          ),
        ] else
          Expanded(
            child: _UserFixtureList(league: league, userTeamId: userTeamId),
          ),
      ],
    );
  }
}

class _MatchdayList extends StatelessWidget {
  final League league;
  final int matchday;
  final String userTeamId;

  const _MatchdayList({
    required this.league,
    required this.matchday,
    required this.userTeamId,
  });

  @override
  Widget build(BuildContext context) {
    final fixtures =
        league.fixtures.where((f) => f.matchday == matchday).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: fixtures.length,
      itemBuilder: (context, i) {
        final f = fixtures[i];
        final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
        final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);
        final isUserMatch =
            f.homeTeamId == userTeamId || f.awayTeamId == userTeamId;
        final isDerby = context.read<GameState>().isRivalFixture(f);
        final result = f.result;
        final row = Container(
          color: isUserMatch
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3)
              : null,
          child: ListTile(
            onTap: result == null
                ? null
                : () => _showFixtureResultDialog(context, result, home, away),
            leading: isDerby
                ? const Icon(
                    Icons.local_fire_department,
                    color: Colors.redAccent,
                  )
                : null,
            title: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          home.name,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ClubEmblem(
                        teamId: home.id,
                        teamName: home.name,
                        size: 22,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    result == null
                        ? 'vs'
                        : '${result.homeGoals} - ${result.awayGoals}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      ClubEmblem(
                        teamId: away.id,
                        teamName: away.name,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(away.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        if (!isUserMatch) return row;
        return Semantics(
          label: '自クラブの試合。${home.name} vs ${away.name}、'
              '${result == null ? '未消化' : '${result.homeGoals} - ${result.awayGoals}'}',
          child: ExcludeSemantics(child: row),
        );
      },
    );
  }
}

class _UserFixtureList extends StatelessWidget {
  final League league;
  final String userTeamId;

  const _UserFixtureList({required this.league, required this.userTeamId});

  @override
  Widget build(BuildContext context) {
    final userFixtures = league.fixtures
        .where(
          (f) => f.homeTeamId == userTeamId || f.awayTeamId == userTeamId,
        )
        .toList()
      ..sort((a, b) => a.matchday.compareTo(b.matchday));
    final nextMatchday = league.nextUnplayedFixture?.matchday;

    return ListView.builder(
      itemCount: userFixtures.length,
      itemBuilder: (context, i) {
        final f = userFixtures[i];
        final home = league.teams.firstWhere((t) => t.id == f.homeTeamId).name;
        final away = league.teams.firstWhere((t) => t.id == f.awayTeamId).name;
        final opponentId =
            f.homeTeamId == userTeamId ? f.awayTeamId : f.homeTeamId;
        final opponent = league.teams.firstWhere((t) => t.id == opponentId);
        final result = f.result;
        final isNext = f.matchday == nextMatchday;
        final isDerby = context.read<GameState>().isRivalFixture(f);
        return Container(
          color: isNext
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3)
              : null,
          child: ListTile(
            onTap: () {
              if (result != null) {
                final home = league.teams.firstWhere(
                  (t) => t.id == f.homeTeamId,
                );
                final away = league.teams.firstWhere(
                  (t) => t.id == f.awayTeamId,
                );
                _showFixtureResultDialog(context, result, home, away);
              } else {
                final userTeam = league.teams.firstWhere(
                  (t) => t.id == userTeamId,
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScoutReportScreen(
                      opponent: opponent,
                      userTeam: userTeam,
                    ),
                  ),
                );
              }
            },
            leading: SizedBox(
              width: 76,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 44, child: Text('第${f.matchday}節')),
                  ClubEmblem(
                    teamId: opponent.id,
                    teamName: opponent.name,
                    size: 24,
                  ),
                ],
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    '$home vs $away',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDerby) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.local_fire_department,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                ],
              ],
            ),
            trailing: result == null
                ? Text(
                    isNext ? '次節' : '未消化',
                    style: isNext
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  )
                : Text(
                    '${result.homeGoals} - ${result.awayGoals}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _resultColor(
                            context,
                            result,
                            userTeamId,
                            f.homeTeamId,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
          ),
        );
      },
    );
  }

  Color? _resultColor(
    BuildContext context,
    MatchResult result,
    String userTeamId,
    String homeTeamId,
  ) {
    final userIsHome = homeTeamId == userTeamId;
    final userGoals = userIsHome ? result.homeGoals : result.awayGoals;
    final oppGoals = userIsHome ? result.awayGoals : result.homeGoals;
    if (userGoals > oppGoals) return SemanticColors.positive(context);
    if (userGoals < oppGoals) return SemanticColors.negative(context);
    return SemanticColors.neutral(context);
  }
}
