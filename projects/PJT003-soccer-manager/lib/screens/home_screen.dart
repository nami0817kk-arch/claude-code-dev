import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/quick_access_destinations.dart';
import '../logic/calendar_engine.dart';
import '../logic/match_engine.dart' show HalfResult;
import '../models/formation.dart';
import '../models/incoming_offer.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import '../services/feedback_service.dart';
import '../theme/semantic_colors.dart';
import '../widgets/achievement_unlock_notifier.dart';
import '../widgets/busy_overlay.dart';
import '../widgets/club_emblem.dart';
import '../widgets/match_widgets.dart';
import '../widgets/first_run_guide_card.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'calendar_screen.dart';
import 'cup_screen.dart';
import 'finance_screen.dart';
import 'lineup_screen.dart';
import 'live_match_screen.dart';
import 'match_screen.dart';
import 'player_detail_screen.dart';
import 'scout_report_screen.dart';
import 'start_screen.dart';
import 'youth_intake_screen.dart';
import '../l10n/tr.dart';

/// 移籍オファーを選手ごとにグループ化し、各グループ内は金額の高い順に並べる
/// (複数クラブが競合している場合、最高額が先頭に来る)。
List<List<IncomingOffer>> _groupOffersByPlayer(GameState gameState) {
  final byPlayer = <String, List<IncomingOffer>>{};
  for (final o in gameState.incomingOffers) {
    byPlayer.putIfAbsent(o.playerId, () => []).add(o);
  }
  for (final group in byPlayer.values) {
    group.sort((a, b) => b.amount.compareTo(a.amount));
  }
  return byPlayer.values.toList();
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gameState.isDismissed) {
      return _DismissalScreen(clubName: save.clubName);
    }

    final scheme = Theme.of(context).colorScheme;
    final league = save.league;
    final userTeam = gameState.userTeam;
    final standings = league.sortedStandings;
    final userRank = standings.indexWhere((r) => r.teamId == userTeam.id) + 1;
    final next = league.nextUnplayedFixture;
    final seasonComplete = league.isSeasonComplete;
    final net = _netWeekly(gameState);

    return BusyOverlay(
      visible: gameState.isBusy,
      label: Tr.pick('シーズンを更新しています…', 'Rolling the season over…'),
      child: Scaffold(
        appBar: AppBar(title: Text(save.clubName)),
        drawer: const QuickAccessDrawer(),
        body: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 初見の人を週次サイクルに一周させるガイド。
              // 4ステップ終えるか閉じられると自動的に消える。
              const FirstRunGuideCard(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // リーグ名は英語だと長くなりがちなので、余った幅を
                          // 与えて折り返させる。Chipは内容ぶんの幅を保つ。
                          Expanded(
                            child: Text(
                              Tr.pick(
                                  '${gameState.leagueDisplayName} シーズン${league.season}',
                                  '${gameState.leagueDisplayName}, season ${league.season}'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(label: Text(userTeam.formation.label)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Tr.pick(
                            '目標: ${save.boardTargetRank}位以内${gameState.boardCupTargetLabel != null ? '・カップ${gameState.boardCupTargetLabel}進出' : ''}',
                            "Target: top ${save.boardTargetRank}${gameState.boardCupTargetLabel != null ? ' · reach the ${gameState.boardCupTargetLabel} in the cup' : ''}"),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: constraints.maxWidth > 500 ? 3 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // 縦横比で高さを決めると、補足行やプログレスバーを持つ
                  // タイルだけ中身がはみ出す。必要な高さを直接指定し、
                  // 文字サイズ設定に合わせて伸ばす。
                  mainAxisExtent: MediaQuery.textScalerOf(context).scale(104),
                  children: [
                    _StatTile(
                      icon: Icons.emoji_events,
                      label: Tr.pick('順位', 'Position'),
                      value: '$userRank / ${standings.length}',
                      color: Colors.amber.shade800,
                    ),
                    _StatTile(
                      icon: Icons.account_balance_wallet,
                      label: Tr.pick('資金', 'Funds'),
                      value: Tr.pick('${save.budget}万円', '${save.budget}'),
                      sub: Tr.pick('週収支 ${net >= 0 ? '+' : ''}$net万円',
                          "Weekly ${net >= 0 ? '+' : ''}$net"),
                      color: net >= 0
                          ? SemanticColors.positive(context)
                          : SemanticColors.negative(context),
                    ),
                    _StatTile(
                      icon: Icons.bar_chart,
                      label: Tr.pick('平均総合力', 'Average overall'),
                      value: '${userTeam.overallRating}',
                      color: Colors.blue.shade700,
                    ),
                    _StatTile(
                      icon: Icons.shield,
                      label: Tr.pick('監督への信頼度', 'Board confidence'),
                      value: '${save.confidence}',
                      progress: save.confidence / 100,
                      color: save.confidence <= 25
                          ? Colors.redAccent
                          : Colors.teal.shade700,
                    ),
                    _StatTile(
                      icon: Icons.star,
                      label: Tr.pick('監督としての評価', 'Your reputation'),
                      value: '${gameState.managerReputation}',
                      progress: gameState.managerReputation / 100,
                      color: Colors.deepPurple,
                    ),
                    _StatTile(
                      icon: Icons.groups,
                      label: Tr.pick('観客動員', 'Attendance'),
                      value: Tr.pick(
                          '${gameState.lastMatchAttendance ?? gameState.expectedAttendance}人',
                          '${gameState.lastMatchAttendance ?? gameState.expectedAttendance}'),
                      sub: Tr.pick('収容人数 ${gameState.stadiumCapacity}人',
                          'Capacity ${gameState.stadiumCapacity}'),
                      color: Colors.brown.shade600,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ThisWeekCard(gameState: gameState, next: next, league: league),
              const SizedBox(height: 12),
              if (gameState.pendingBoardReviewMessage != null)
                Card(
                  color: Colors.indigo.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.gavel, color: Colors.indigo.shade700),
                            const SizedBox(width: 8),
                            Text(
                              Tr.pick(
                                  'シーズン中盤 理事会レビュー', 'Mid-season board review'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.indigo.shade900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(gameState.pendingBoardReviewMessage!),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              FeedbackService.tap();
                              gameState.dismissBoardReview();
                            },
                            child: Text(Tr.pick('了解した', 'Understood')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (gameState.pendingPressConference != null)
                _PressConferenceCard(gameState: gameState),
              if (gameState.pendingJobOfferTeam != null)
                _JobOfferCard(gameState: gameState),
              if (gameState.pendingSuperCup != null)
                _SuperCupCard(gameState: gameState),
              if (gameState.isUserDomesticCupMatchUpNext)
                Card(
                  color: scheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events_outlined),
                    title: Text(Tr.pick(
                        '国内カップ戦の出番です', 'You are up in the domestic cup')),
                    subtitle: Text(Tr.pick('ブラケットの次の試合が自クラブの対戦になっています',
                        'The next tie in the bracket is yours')),
                    trailing: FilledButton(
                      onPressed: () {
                        FeedbackService.tap();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CupScreen()),
                        );
                      },
                      child: Text(Tr.pick('カップ戦へ', 'Go to the cup')),
                    ),
                  ),
                ),
              if (gameState.pendingYouthIntake.isNotEmpty)
                Card(
                  color: scheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.emoji_people),
                    title: Text(Tr.pick('ユースインテーク', 'Youth intake')),
                    subtitle: Text(
                      Tr.pick(
                          '${gameState.pendingYouthIntake.length}名の新人候補が加入を待っています',
                          '${gameState.pendingYouthIntake.length} young hopefuls are waiting to join'),
                    ),
                    trailing: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const YouthIntakeScreen(),
                        ),
                      ),
                      child: Text(Tr.pick('選抜する', 'Pick them')),
                    ),
                  ),
                ),
              if (gameState.incomingOffers.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Tr.pick('移籍オファー', 'Transfer offer'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        for (final entry in _groupOffersByPlayer(gameState))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (entry.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      Tr.pick(
                                          '${entry.first.playerName}に競合オファー',
                                          'Rival bids for ${entry.first.playerName}'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                for (int i = 0; i < entry.length; i++)
                                  Row(
                                    children: [
                                      if (entry.length > 1 && i == 0)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.star,
                                            size: 14,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          Tr.pick(
                                              '${entry[i].buyerClubName}が${entry[i].playerName}に${entry[i].amount}万円',
                                              '${entry[i].buyerClubName} bid ${entry[i].amount} for ${entry[i].playerName}'),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          FeedbackService.tap();
                                          gameState.declineIncomingOffer(
                                            entry[i].id,
                                          );
                                        },
                                        child: Text(Tr.pick('拒否', 'Reject')),
                                      ),
                                      FilledButton(
                                        onPressed:
                                            !gameState.isTransferWindowOpen
                                                ? null
                                                : () => _confirmAcceptOffer(
                                                      context,
                                                      entry[i],
                                                    ),
                                        child: Text(Tr.pick('承諾', 'Accept')),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (!seasonComplete &&
                  save.friendlies.any((f) => f.result == null))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Tr.pick('親善試合', 'Friendly'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        for (int i = 0; i < save.friendlies.length; i++)
                          if (save.friendlies[i].result == null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _fixtureLabel(league, save.friendlies[i]),
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _playFriendly(context, i),
                                    child: Text(Tr.pick('開催', 'Play it')),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              // スタメンに出場できない選手が混ざっていると、試合では無言で
              // 除外されて人数の足りない布陣で戦うことになるため、事前に
              // 警告して編成画面へ誘導する。
              if (!seasonComplete)
                Builder(builder: (context) {
                  final byId = {for (final p in userTeam.players) p.id: p};
                  final unavailable = [
                    for (final id in userTeam.startingXI)
                      if (byId[id] != null &&
                          (byId[id]!.isInjured ||
                              byId[id]!.isSuspended ||
                              byId[id]!.isOnInternationalDuty ||
                              byId[id]!.isLoanedOut))
                        byId[id]!,
                  ];
                  if (unavailable.isEmpty) return const SizedBox.shrink();
                  String reasonOf(Player p) => p.isInjured
                      ? Tr.pick('負傷', 'Injured')
                      : p.isSuspended
                          ? Tr.pick('出場停止', 'Suspended')
                          : p.isOnInternationalDuty
                              ? Tr.pick('代表召集', 'International duty')
                              : Tr.pick('ローン中', 'Out on loan');
                  return Card(
                    color: scheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.personal_injury),
                      title: Text(Tr.pick(
                          'スタメンに出場できない選手が${unavailable.length}人います',
                          '${unavailable.length} of your XI cannot play')),
                      subtitle: Text(
                        Tr.pick(
                            '${unavailable.map((p) => '${p.name}(${reasonOf(p)})').join('、')}。このままでは人数の欠けた布陣で試合に臨みます。',
                            "${unavailable.map((p) => '${p.name} (${reasonOf(p)})').join(', ')}. As things stand you go into the match short-handed."),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LineupScreen(),
                        ),
                      ),
                    ),
                  );
                }),
              // スポンサー未契約のまま気づかず収入を取りこぼすことが多いため、
              // オファーが届いている間はホームに警告カードを常設する。
              if (save.sponsorDeal == null &&
                  save.pendingSponsorOffers.isNotEmpty)
                Card(
                  color: scheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.handshake),
                    title: Text(Tr.pick('スポンサー未契約', 'No sponsor')),
                    subtitle: Text(
                      Tr.pick(
                          'スポンサーオファーが${save.pendingSponsorOffers.length}件届いています。契約すると毎週の収入が増えます。',
                          '${save.pendingSponsorOffers.length} sponsorship offers are waiting. Signing one raises your weekly income.'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FinanceScreen()),
                    ),
                  ),
                ),
              if (seasonComplete)
                Card(
                  color: scheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.flag),
                    title: Text(Tr.pick('シーズン終了！', 'Season over.')),
                    subtitle: Text(Tr.pick(
                        '最終順位: $userRank位', 'Final position: $userRank')),
                    trailing: FilledButton(
                      onPressed: () => _startNextSeason(context),
                      child: Text(Tr.pick('次のシーズンへ', 'On to next season')),
                    ),
                  ),
                )
              else if (next != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            ClubEmblem(
                              teamId: next.homeTeamId == userTeam.id
                                  ? next.awayTeamId
                                  : next.homeTeamId,
                              teamName: league.teams
                                  .firstWhere(
                                    (t) =>
                                        t.id ==
                                        (next.homeTeamId == userTeam.id
                                            ? next.awayTeamId
                                            : next.homeTeamId),
                                  )
                                  .name,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(Tr.pick('第${next.matchday}節',
                                          'Matchday ${next.matchday}')),
                                      if (gameState.isRivalFixture(next)) ...[
                                        const SizedBox(width: 6),
                                        Chip(
                                          label: Text(
                                            Tr.pick('ダービー', 'Derby'),
                                            style:
                                                const TextStyle(fontSize: 11),
                                          ),
                                          backgroundColor: Colors.redAccent,
                                          labelStyle: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    _fixtureLabel(league, next),
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  // 対戦相手の現在の順位・戦力・直近フォームを
                                  // 一目で確認できるようにする(詳細な分析は
                                  // 従来通りスカウティングレポートで)。
                                  Builder(builder: (context) {
                                    final oppId = next.homeTeamId == userTeam.id
                                        ? next.awayTeamId
                                        : next.homeTeamId;
                                    final opp = league.teams
                                        .firstWhere((t) => t.id == oppId);
                                    final oppRank = standings.indexWhere(
                                          (r) => r.teamId == oppId,
                                        ) +
                                        1;
                                    final form = league.recentFormFor(oppId);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Text(
                                            Tr.pick(
                                                '$oppRank位・総合${opp.overallRating}',
                                                '$oppRank in the table · overall ${opp.overallRating}'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          for (final r in form)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 1,
                                              ),
                                              child: Container(
                                                width: 16,
                                                height: 16,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: r == 'W'
                                                      ? SemanticColors.positive(
                                                          context,
                                                        )
                                                      : r == 'L'
                                                          ? SemanticColors
                                                              .negative(
                                                              context,
                                                            )
                                                          : Colors
                                                              .grey.shade500,
                                                ),
                                                child: Text(
                                                  r,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => _playMatch(context),
                          child: Text(Tr.pick('試合を行う', 'Play the match')),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _quickSimNextMatch(context, next),
                              child: Text(
                                Tr.pick('結果だけ見る', 'Just the result'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showScoutReport(context, next),
                              child: Text(
                                Tr.pick('偵察レポート', 'Scout report'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(Tr.pick('クラブ運営', 'Running the club'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: constraints.maxWidth > 500 ? 3 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    for (final dest in quickAccessDestinations)
                      _ActionTile(
                        icon: dest.icon,
                        label: dest.label,
                        color: dest.color,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: dest.builder)),
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

  int _netWeekly(GameState gameState) {
    final loanRepayment = gameState.bankLoans.fold<int>(
      0,
      (s, l) => s + l.weeklyRepayment,
    );
    final team = gameState.userTeam;
    final appearanceFees = team.players
        .where((p) => team.startingXI.contains(p.id))
        .fold<int>(0, (s, p) => s + p.appearanceFee);
    return gameState.weeklyIncomeFor(team.id) -
        gameState.weeklyWageBill -
        loanRepayment -
        appearanceFees;
  }

  String _fixtureLabel(League league, Fixture f) {
    final home = league.teams.firstWhere((t) => t.id == f.homeTeamId).name;
    final away = league.teams.firstWhere((t) => t.id == f.awayTeamId).name;
    return '$home vs $away';
  }

  void _showScoutReport(BuildContext context, Fixture fixture) {
    final gameState = context.read<GameState>();
    final userTeam = gameState.userTeam;
    final league = gameState.save!.league;
    final opponentId = fixture.homeTeamId == userTeam.id
        ? fixture.awayTeamId
        : fixture.homeTeamId;
    final opponent = league.teams.firstWhere((t) => t.id == opponentId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ScoutReportScreen(opponent: opponent, userTeam: userTeam),
      ),
    );
  }

  Future<void> _playMatch(BuildContext context) async {
    FeedbackService.tap();
    final gameState = context.read<GameState>();
    final HalfResult? firstHalf;
    try {
      firstHalf = await gameState.playNextMatchday(interactive: true);
    } catch (e) {
      if (context.mounted) _showProgressFailedSnackBar(context, e);
      return;
    }
    if (!context.mounted) return;
    _showMatchdayNotifications(context, gameState);

    if (firstHalf != null) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LiveMatchScreen()));
    }
    if (context.mounted) _showMonthlyAwardNotification(context, gameState);
    if (context.mounted) showAchievementUnlockNotification(context, gameState);
  }

  /// ライブ観戦せず、次節の結果だけを一括で確定させる(クイックシム)。
  Future<void> _quickSimNextMatch(BuildContext context, Fixture next) async {
    FeedbackService.tap();
    final gameState = context.read<GameState>();
    final userTeamId = gameState.userTeam.id;
    final isHome = next.homeTeamId == userTeamId;
    final opponentId = isHome ? next.awayTeamId : next.homeTeamId;
    final teams = gameState.save!.league.teams;
    final opponentName = teams.firstWhere((t) => t.id == opponentId).name;
    final userTeamName = gameState.userTeam.name;

    final MatchResult? result;
    try {
      result = await gameState.playNextMatchdayQuickSim();
    } catch (e) {
      if (context.mounted) _showProgressFailedSnackBar(context, e);
      return;
    }
    if (!context.mounted || result == null) return;

    await _showQuickSimResultDialog(
      context,
      result: result,
      userTeamId: userTeamId,
      userTeamName: userTeamName,
      opponentName: opponentName,
      teams: teams,
    );
    if (!context.mounted) return;
    _showMatchdayNotifications(context, gameState);
    _showMonthlyAwardNotification(context, gameState);
    showAchievementUnlockNotification(context, gameState);
  }

  /// 節送り処理中に予期しない例外が発生した場合、ボタンが無反応に見える
  /// (何もフィードバックがないまま処理が失敗する)事態を避けるための通知。
  void _showProgressFailedSnackBar(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Tr.pick(
            '節の進行に失敗しました: $error', 'The matchday could not be played: $error')),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// クイックシム結果を、スコアだけでなく得点者・MVPまで含めたダイアログで表示する。
  Future<void> _showQuickSimResultDialog(
    BuildContext context, {
    required MatchResult result,
    required String userTeamId,
    required String userTeamName,
    required String opponentName,
    required List<Team> teams,
  }) async {
    final isHome = result.homeTeamId == userTeamId;
    final userGoals = isHome ? result.homeGoals : result.awayGoals;
    final oppGoals = isHome ? result.awayGoals : result.homeGoals;
    final resultLabel = userGoals > oppGoals
        ? Tr.pick('勝利', 'Win')
        : userGoals < oppGoals
            ? Tr.pick('敗北', 'Defeat')
            : Tr.pick('引き分け', 'Draw');
    String teamNameOf(String teamId) =>
        teamId == userTeamId ? userTeamName : opponentName;
    String? scorerNameOf(String? playerId) {
      if (playerId == null) return null;
      for (final t in teams) {
        for (final p in t.players) {
          if (p.id == playerId) return p.name;
        }
      }
      return null;
    }

    /// 自クラブの選手がまだ在籍している場合のみ、選手詳細へ遷移可能なIDを返す。
    String? ownPlayerIdOf(String? playerId) {
      if (playerId == null) return null;
      final userTeam = teams.firstWhere(
        (t) => t.id == userTeamId,
        orElse: () => teams.first,
      );
      for (final p in userTeam.players) {
        if (p.id == playerId) return p.id;
      }
      return null;
    }

    final goals = result.events
        .where((e) => e.type == MatchEventType.goal)
        .toList()
      ..sort((a, b) => a.minute.compareTo(b.minute));
    final motmName = scorerNameOf(result.manOfTheMatchId);
    final motmOwnPlayerId = ownPlayerIdOf(result.manOfTheMatchId);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final resultColor = userGoals > oppGoals
            ? SemanticColors.positive(dialogContext)
            : userGoals < oppGoals
                ? SemanticColors.negative(dialogContext)
                : SemanticColors.neutral(dialogContext);
        return AlertDialog(
          title: Text(Tr.pick('結果: $resultLabel', 'Result: $resultLabel')),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$userTeamName $userGoals - $oppGoals $opponentName',
                  style:
                      Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                            color: resultColor,
                            fontWeight: FontWeight.bold,
                          ),
                ),
                const SizedBox(height: 12),
                if (goals.isEmpty)
                  Text(
                    Tr.pick('得点者はいませんでした', 'Nobody scored'),
                    style: const TextStyle(color: Colors.grey),
                  )
                else ...[
                  Text(
                    Tr.pick('得点者', 'Scorers'),
                    style: Theme.of(dialogContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final g in goals)
                          _buildGoalRow(
                            context,
                            dialogContext,
                            g,
                            ownPlayerIdOf(g.scorerId),
                            teamNameOf,
                          ),
                      ],
                    ),
                  ),
                ],
                MatchStatsBar(
                  result: result,
                  homeTeamName: teamNameOf(result.homeTeamId),
                  awayTeamName: teamNameOf(result.awayTeamId),
                ),
                if (motmName != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: motmOwnPlayerId == null
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PlayerDetailScreen(
                                  playerId: motmOwnPlayerId,
                                ),
                              ),
                            );
                          },
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(Tr.pick('マン・オブ・ザ・マッチ: $motmName',
                                'Man of the match: $motmName'))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(Tr.pick('閉じる', 'Close')),
            ),
          ],
        );
      },
    );
  }

  /// クイックシム結果ダイアログ内の得点者1行。自クラブ選手が在籍中の場合のみ
  /// タップして選手詳細へ遷移できる。
  Widget _buildGoalRow(
    BuildContext context,
    BuildContext dialogContext,
    MatchEvent g,
    String? playerId,
    String Function(String) teamNameOf,
  ) {
    return InkWell(
      onTap: playerId == null
          ? null
          : () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerDetailScreen(playerId: playerId),
                ),
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          Tr.pick(
              '${g.minute}\' ${g.scorerName ?? '不明'}${g.assistName != null ? '（アシスト: ${g.assistName}）' : ''}（${teamNameOf(g.teamId)}）',
              "${g.minute}' ${g.scorerName ?? 'Unknown'}${g.assistName != null ? ' (assist: ${g.assistName})' : ''} (${teamNameOf(g.teamId)})"),
        ),
      ),
    );
  }

  /// 節送り時に発生しうる複数の通知(契約満了・リリース条項発動・代表召集・
  /// ローン復帰・CPU移籍ニュース・資金危機警告)をまとめて表示する。1件だけ
  /// なら従来通りSnackBarで、複数同時に発生した場合はスナックバーの
  /// 連続表示で見落とさないよう1つの要約ダイアログにまとめる。
  void _showMatchdayNotifications(BuildContext context, GameState gameState) {
    final messages = <(String text, bool isWarning)>[];

    final expired = gameState.lastContractExpirations;
    if (expired.isNotEmpty) {
      messages.add((
        Tr.pick('ローン期間満了で契約元クラブへ復帰: ${expired.join('、')}',
            "Loan spells ended, returned to their parent clubs: ${expired.join(', ')}"),
        false
      ));
      gameState.lastContractExpirations = [];
    }
    final autoSold = gameState.lastReleaseClauseSales;
    if (autoSold.isNotEmpty) {
      messages.add((
        Tr.pick('リリース条項が発動し移籍が成立: ${autoSold.join('、')}',
            "Release clauses triggered, transfers completed: ${autoSold.join(', ')}"),
        false
      ));
      gameState.lastReleaseClauseSales = [];
    }
    final calledUp = gameState.lastInternationalCallUps;
    if (calledUp.isNotEmpty) {
      messages.add((
        Tr.pick('代表召集: ${calledUp.join('、')}',
            "Called up for international duty: ${calledUp.join(', ')}"),
        false
      ));
      gameState.lastInternationalCallUps = [];
    }
    final loanReturns = gameState.lastLoanReturns;
    if (loanReturns.isNotEmpty) {
      messages.add((
        Tr.pick('ローン放出から復帰: ${loanReturns.join('、')}',
            "Back from loan: ${loanReturns.join(', ')}"),
        false
      ));
      gameState.lastLoanReturns = [];
    }
    final maturedDeposits = gameState.lastMaturedDeposits;
    if (maturedDeposits.isNotEmpty) {
      final total = maturedDeposits.fold<int>(0, (s, d) => s + d.maturityValue);
      messages.add((
        Tr.pick('定期預金が満期を迎え、$total万円が払い戻されました',
            'Your deposit matured and $total was paid back'),
        false
      ));
      gameState.lastMaturedDeposits = [];
    }
    final aiTransferNews = gameState.lastAiTransferNews;
    if (aiTransferNews != null) {
      messages.add((
        Tr.pick('移籍市場: $aiTransferNews', 'Transfer market: $aiTransferNews'),
        false
      ));
      gameState.lastAiTransferNews = null;
    }
    final budgetCrisis = gameState.lastBudgetCrisisWarning;
    if (budgetCrisis != null) {
      messages.add((budgetCrisis, true));
      gameState.lastBudgetCrisisWarning = null;
    }

    if (messages.isEmpty) return;
    if (messages.length == 1) {
      final (text, isWarning) = messages.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isWarning ? Colors.red.shade700 : null,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Tr.pick('今節のお知らせ', 'This matchday')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (text, isWarning) in messages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isWarning ? Icons.warning_amber : Icons.info_outline,
                        size: 18,
                        color: isWarning ? Colors.red.shade700 : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(Tr.pick('閉じる', 'Close')),
          ),
        ],
      ),
    );
  }

  void _confirmAcceptOffer(BuildContext context, IncomingOffer offer) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('この移籍オファーを承諾しますか？', 'Accept this transfer offer?')),
        content: Text(
          Tr.pick(
              '${offer.playerName}が${offer.buyerClubName}へ${offer.amount}万円で移籍します。この操作は元に戻せません。',
              '${offer.playerName} joins ${offer.buyerClubName} for ${offer.amount}. This cannot be undone.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              FeedbackService.success();
              context.read<GameState>().acceptIncomingOffer(offer.id);
            },
            child: Text(Tr.pick('承諾する', 'Accept')),
          ),
        ],
      ),
    );
  }

  void _showMonthlyAwardNotification(
    BuildContext context,
    GameState gameState,
  ) {
    final monthlyAward = gameState.lastMonthlyManagerAward;
    if (monthlyAward != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
          content: Text(Tr.pick('$monthlyAward 月間最優秀監督賞を受賞しました！',
              'You won Manager of the Month for $monthlyAward.'))));
      gameState.lastMonthlyManagerAward = null;
    }
  }

  Future<void> _playFriendly(BuildContext context, int index) async {
    final gameState = context.read<GameState>();
    final result = await gameState.playFriendly(index);
    if (context.mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Tr.pick(
              '親善試合結果: ${result.homeGoals} - ${result.awayGoals}',
              'Friendly: ${result.homeGoals} - ${result.awayGoals}')),
        ),
      );
    }
  }

  /// シーズン開始時の通知(昇降格・報奨金・引退・契約満了・契約警告・
  /// 緊急補強・年間監督賞・スーパーカップ)をまとめて表示する。従来は
  /// SnackBarを最大8件連続表示しており(1件5秒のキューで長時間流れ続け、
  /// 途中のものを見落としやすかった)、複数件あるときは1つのレポート
  /// ダイアログへ集約する。1件だけなら従来通りSnackBarで軽く流す。
  Future<void> _showSeasonStartReport(
    BuildContext context,
    GameState gameState,
  ) async {
    final messages = <(String text, bool isHighlight)>[];

    final message = gameState.lastDivisionChangeMessage;
    if (message != null) {
      messages.add((message, true));
      gameState.lastDivisionChangeMessage = null;
    }
    final boardBonus = gameState.lastBoardBonusNote;
    if (boardBonus != null) {
      messages.add((boardBonus, true));
      gameState.lastBoardBonusNote = null;
    }
    final contractNote = gameState.lastManagerContractNote;
    if (contractNote != null) {
      messages.add((contractNote, true));
      gameState.lastManagerContractNote = null;
    }
    if (gameState.lastSeasonManagerAwardWon) {
      messages.add(
          (Tr.pick('年間最優秀監督賞を受賞しました！', 'You won Manager of the Year.'), true));
      gameState.lastSeasonManagerAwardWon = false;
    }
    final superCupNews = gameState.lastSuperCupNews;
    if (superCupNews != null) {
      messages.add((superCupNews, true));
      gameState.lastSuperCupNews = null;
    }
    final retirees = gameState.lastRetirements;
    if (retirees.isNotEmpty) {
      messages.add((
        Tr.pick('引退: ${retirees.join('、')}', "Retired: ${retirees.join(', ')}"),
        false
      ));
      gameState.lastRetirements = [];
    }
    final contractExpired = gameState.lastContractExpirations;
    if (contractExpired.isNotEmpty) {
      messages.add((
        Tr.pick('契約満了で退団: ${contractExpired.join('、')}',
            "Left on a free at the end of their contract: ${contractExpired.join(', ')}"),
        false
      ));
      gameState.lastContractExpirations = [];
    }
    final contractWarnings = gameState.lastContractWarnings;
    if (contractWarnings.isNotEmpty) {
      messages.add((
        Tr.pick('契約最終年に突入: ${contractWarnings.join('、')}',
            "Into the final year of their contract: ${contractWarnings.join(', ')}"),
        false
      ));
      gameState.lastContractWarnings = [];
    }
    final emergencySignings = gameState.lastEmergencySignings;
    if (emergencySignings.isNotEmpty) {
      messages.add((
        Tr.pick('緊急補強: ${emergencySignings.join('、')}',
            "Emergency signings: ${emergencySignings.join(', ')}"),
        false
      ));
      gameState.lastEmergencySignings = [];
    }

    if (messages.isEmpty) return;
    if (messages.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messages.first.$1),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Tr.pick('シーズン開始レポート', 'Pre-season report')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (text, isHighlight) in messages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isHighlight ? Icons.celebration : Icons.info_outline,
                        size: 18,
                        color:
                            isHighlight ? Colors.amber.shade700 : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(Tr.pick('閉じる', 'Close')),
          ),
        ],
      ),
    );
  }

  Future<void> _startNextSeason(BuildContext context) async {
    final gameState = context.read<GameState>();
    try {
      await gameState.startNextSeason();
    } catch (e) {
      if (context.mounted) _showProgressFailedSnackBar(context, e);
      return;
    }
    if (context.mounted) {
      await _showSeasonStartReport(context, gameState);
    }
    if (context.mounted &&
        gameState.userInvolvedInLastPromotionPlayoff &&
        gameState.lastPromotionPlayoffResults.isNotEmpty) {
      final results = gameState.lastPromotionPlayoffResults;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(Tr.pick('昇格プレーオフ結果', 'Promotion play-off results')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in results)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(line),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(Tr.pick('閉じる', 'Close')),
            ),
          ],
        ),
      );
      gameState.lastPromotionPlayoffResults = [];
      gameState.userInvolvedInLastPromotionPlayoff = false;
    }
    if (context.mounted && gameState.lastSeasonGrowthSummary.isNotEmpty) {
      final summary = List.of(gameState.lastSeasonGrowthSummary)
        ..sort((a, b) => b.overallDelta.compareTo(a.overallDelta));
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(Tr.pick('シーズン成長サマリー', 'Season growth summary')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: summary.length,
              itemBuilder: (context, index) {
                final s = summary[index];
                final delta = s.overallDelta;
                final deltaLabel = delta > 0 ? '+$delta' : '$delta';
                final deltaColor = delta > 0
                    ? SemanticColors.positive(context)
                    : delta < 0
                        ? SemanticColors.negative(context)
                        : Theme.of(context).disabledColor;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(s.playerName)),
                      Text('${s.overallBefore} → ${s.overallAfter}'),
                      const SizedBox(width: 8),
                      Text(
                        deltaLabel,
                        style: TextStyle(
                          color: deltaColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(Tr.pick('閉じる', 'Close')),
            ),
          ],
        ),
      );
    }
    if (context.mounted) showAchievementUnlockNotification(context, gameState);
  }
}

class _PressConferenceCard extends StatelessWidget {
  final GameState gameState;

  const _PressConferenceCard({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final question = gameState.pendingPressConference!;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, size: 18),
                const SizedBox(width: 6),
                Text(Tr.pick('記者会見', 'Press conference'),
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(question.prompt),
            const SizedBox(height: 8),
            for (int i = 0; i < question.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      FeedbackService.tap();
                      gameState.answerPressConference(i);
                    },
                    child: Text(
                      question.options[i].label,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JobOfferCard extends StatelessWidget {
  final GameState gameState;

  const _JobOfferCard({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final team = gameState.pendingJobOfferTeam!;
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('他クラブからのオファー', 'An offer from another club'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(Tr.pick(
                '${team.name}の監督就任オファーが届いています(総合力 ${team.overallRating})',
                '${team.name} want you as their manager (overall ${team.overallRating})')),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    FeedbackService.tap();
                    gameState.declineJobOffer();
                  },
                  child: Text(Tr.pick('断る', 'Turn it down')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    FeedbackService.success();
                    gameState.acceptJobOffer();
                  },
                  child: Text(Tr.pick('就任する', 'Take the job')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuperCupCard extends StatelessWidget {
  final GameState gameState;

  const _SuperCupCard({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final match = gameState.pendingSuperCup!;
    final teams = gameState.save!.allTeams;
    final userId = gameState.userTeam.id;
    final opponentId =
        match.homeTeamId == userId ? match.awayTeamId : match.homeTeamId;
    final opponentName = teams.firstWhere((t) => t.id == opponentId).name;
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('スーパーカップ', 'Super Cup'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(Tr.pick('開幕前特別マッチ: $opponentNameと対戦します',
                'The curtain-raiser: you face $opponentName')),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  if (gameState.canPlaySuperCupLive)
                    FilledButton.icon(
                      onPressed: () =>
                          playCupMatchLive(context, LiveCupKind.superCup),
                      icon: const Icon(Icons.sports_soccer),
                      label: Text(Tr.pick('ライブで戦う', 'Watch it live')),
                    ),
                  OutlinedButton(
                    onPressed: () => _play(context),
                    child: Text(Tr.pick('クイック消化', 'Sim it')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _play(BuildContext context) async {
    FeedbackService.tap();
    final teams = gameState.save!.allTeams;
    final result = await gameState.playSuperCup();
    if (!context.mounted || result == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchScreen(
            result: result,
            teams: teams,
            title: Tr.pick('スーパーカップ', 'Super Cup')),
      ),
    );
  }
}

/// 「今週」に何をすべきかを一目でまとめるカード。試合(リーグ/カップ)の
/// 予定とトレーニングの実施状況を、カレンダーの代わりに凝縮して見せる。
class _ThisWeekCard extends StatelessWidget {
  final GameState gameState;
  final Fixture? next;
  final League league;

  const _ThisWeekCard({
    required this.gameState,
    required this.next,
    required this.league,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = gameState.currentDate;
    final dateLabel =
        '${today.month}/${today.day}(${CalendarEngine.weekdayLabel(today.weekday)})';
    String matchLine;
    if (next == null) {
      matchLine = Tr.pick('リーグ戦は今シーズン終了しています', 'The league season is over');
    } else {
      final userId = gameState.userTeam.id;
      final isHome = next!.homeTeamId == userId;
      final opponentId = isHome ? next!.awayTeamId : next!.homeTeamId;
      final opponent = league.teams.firstWhere(
        (t) => t.id == opponentId,
        orElse: () => league.teams.first,
      );
      final derby = gameState.isRivalFixture(next!);
      matchLine = Tr.pick(
          '第${next!.matchday}節 ${isHome ? '(H)' : '(A)'} vs ${opponent.name}${derby ? ' ・ダービー' : ''}',
          "Matchday ${next!.matchday} ${isHome ? '(H)' : '(A)'} vs ${opponent.name}${derby ? ' · derby' : ''}");
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Tr.pick('今週の予定 ($dateLabel)', 'This week ($dateLabel)'),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: Text(Tr.pick('カレンダー', 'Calendar')),
                  onPressed: () {
                    FeedbackService.tap();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CalendarScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.sports_soccer, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(matchLine)),
              ],
            ),
            if (gameState.isUserDomesticCupMatchUpNext) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 18,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(Tr.pick('国内カップ戦の出番も控えています',
                          'You also have a domestic cup tie coming up'))),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  gameState.trainingDoneThisWeek
                      ? Icons.check_circle
                      : Icons.fitness_center,
                  size: 18,
                  color: gameState.trainingDoneThisWeek
                      ? SemanticColors.positive(context)
                      : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  gameState.trainingDoneThisWeek
                      ? Tr.pick('今週のトレーニングは実施済み', 'You have trained this week')
                      : Tr.pick(
                          '今週のトレーニングは未実施', 'You have not trained this week'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final double? progress;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color),
            ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DismissalScreen extends StatelessWidget {
  final String clubName;

  const _DismissalScreen({required this.clubName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gavel, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  Tr.pick('$clubName の監督を解任されました',
                      'You have been sacked by $clubName'),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                    Tr.pick(
                        '理事会からの信頼を失いました。', "You lost the board's confidence."),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await context.read<GameState>().deleteSave();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const StartScreen()),
                        (route) => false,
                      );
                    }
                  },
                  child: Text(
                      Tr.pick('新しいクラブで再出発する', 'Start again at a new club')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
