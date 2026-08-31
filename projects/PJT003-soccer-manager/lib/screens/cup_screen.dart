import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/continental_cup_engine.dart';
import '../logic/cup_engine.dart';
import '../models/continental_cup.dart';
import '../models/cup.dart';
import '../models/team.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'live_match_screen.dart';
import 'match_screen.dart';
import '../l10n/tr.dart';

/// カップ戦のクイック消化後に、自クラブが賞金を獲得していればSnackBarで
/// 知らせる(表示した通知は消費してnullへ戻す)。ライブ観戦はフルタイム
/// 画面側で表示するため、こちらはクイック消化の各導線から呼ぶ。
void showCupPrizeSnackBar(BuildContext context, GameState gameState) {
  final note = gameState.lastCupPrizeNote;
  if (note == null) return;
  gameState.lastCupPrizeNote = null;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
}

/// 自クラブのカップ試合をライブ観戦で開始し、試合画面へ遷移する。
/// リーグ戦のライブ観戦と同じ画面・同じ操作(決定機の判断・交代・采配)で
/// 戦える。開始できなかった場合はSnackBarで知らせる。
Future<void> playCupMatchLive(BuildContext context, LiveCupKind kind) async {
  FeedbackService.tap();
  final gameState = context.read<GameState>();
  final started = await gameState.startCupMatchLive(kind);
  if (!context.mounted) return;
  if (!started) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              Tr.pick('今はライブで開始できません', 'You cannot start it live right now'))),
    );
    return;
  }
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const LiveMatchScreen()));
}

class CupScreen extends StatelessWidget {
  const CupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(Tr.pick('カップ戦', 'Cups')),
          leading: const BackButton(),
          actions: const [QuickAccessMenuButton()],
          bottom: TabBar(
            tabs: [
              Tab(text: Tr.pick('国内カップ', 'Domestic Cup')),
              Tab(text: Tr.pick('大陸カップ', 'Continental Cup')),
            ],
          ),
        ),
        drawer: const QuickAccessDrawer(),
        body: const ResponsiveBody(
          child: TabBarView(
            children: [_DomesticCupTab(), _ContinentalCupTab()],
          ),
        ),
      ),
    );
  }
}

class _DomesticCupTab extends StatelessWidget {
  const _DomesticCupTab();

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final cup = gameState.domesticCup;

    if (cup == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
              Tr.pick('カップ戦の情報がありません。', 'There is no cup information yet.'),
              textAlign: TextAlign.center),
        ),
      );
    }

    final userId = gameState.userTeam.id;
    final teams = gameState.allTeamsForCups;
    String nameOf(String id) =>
        teams.firstWhere((t) => t.id == id, orElse: () => teams.first).name;
    final totalRounds = cup.rounds.length;
    final nextMatch = cup.nextUnplayedMatch;
    final userEliminated = cup.isEliminated(userId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cup.isComplete)
          Card(
            color: cup.championId == userId
                ? SemanticColors.positive(context).withValues(alpha: 0.15)
                : null,
            child: ListTile(
              leading: Icon(
                Icons.emoji_events,
                color: cup.championId == userId
                    ? SemanticColors.positive(context)
                    : null,
              ),
              title: Text(Tr.pick('優勝: ${nameOf(cup.championId!)}',
                  'Winners: ${nameOf(cup.championId!)}')),
            ),
          )
        else if (userEliminated)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.info_outline,
                color: SemanticColors.negative(context),
              ),
              title: Text(Tr.pick('自クラブは敗退しました', 'You are out')),
              subtitle: Text(Tr.pick(
                  '他クラブの結果は引き続き更新されます', 'The other results keep coming in')),
            ),
          ),
        if (nextMatch != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                if (gameState.canPlayNextDomesticCupMatchLive)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          playCupMatchLive(context, LiveCupKind.domestic),
                      icon: const Icon(Icons.sports_soccer),
                      label: Text(
                          Tr.pick('自クラブの試合をライブで戦う', 'Watch your tie live')),
                    ),
                  ),
                if (gameState.canPlayNextDomesticCupMatchLive)
                  const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: gameState.canPlayNextDomesticCupMatchLive
                      ? OutlinedButton(
                          onPressed: () => _playNext(context),
                          child: Text(Tr.pick(
                              '観戦せず結果だけ確定(クイック消化)', 'Just settle the result')),
                        )
                      : FilledButton(
                          onPressed: gameState.canPlayNextDomesticCupMatch
                              ? () => _playNext(context)
                              : null,
                          child: Text(Tr.pick('次の試合を消化', 'Play the next tie')),
                        ),
                ),
                if (!gameState.canPlayNextDomesticCupMatch)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      Tr.pick('リーグ戦を1節進めると次の試合を消化できます',
                          'Play one more league matchday and you can take the next tie'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        for (final round in cup.rounds) ...[
          _RoundSection(
            title: CupEngine.roundLabel(round.first.round, totalRounds),
            initiallyExpanded:
                round.any((m) => m.result == null) || round == cup.rounds.last,
            children: [
              for (final m in round)
                _BracketMatchCard(match: m, nameOf: nameOf, userId: userId),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _playNext(BuildContext context) async {
    final gameState = context.read<GameState>();
    final userId = gameState.userTeam.id;
    final List<Team> teams = gameState.allTeamsForCups;
    final match = gameState.domesticCup?.nextUnplayedMatch;
    final isUserMatch = match != null &&
        (match.homeTeamId == userId || match.awayTeamId == userId);
    final result = await gameState.playNextCupMatch();
    if (!context.mounted) return;
    showCupPrizeSnackBar(context, gameState);
    if (result != null && isUserMatch) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MatchScreen(
              result: result,
              teams: teams,
              title: Tr.pick('国内カップ', 'Domestic Cup')),
        ),
      );
    }
  }
}

class _ContinentalCupTab extends StatelessWidget {
  const _ContinentalCupTab();

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final cup = gameState.continentalCup;

    if (cup == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            Tr.pick('前シーズンをリーグ2位以内で終えると、翌シーズンは大陸カップに出場できます。',
                'Finish in the top two and you qualify for the Continental Cup next season.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final userId = gameState.userTeam.id;
    final teams = gameState.allTeamsForCups;
    String nameOf(String id) =>
        teams.firstWhere((t) => t.id == id, orElse: () => teams.first).name;
    final userEliminated = cup.isEliminated(userId);
    final groupStageDone = cup.isGroupStageComplete;
    final nextGroupMatch = ContinentalCupEngine.nextGroupMatch(cup);
    final knockoutPending = cup.knockoutRounds.isNotEmpty &&
        cup.knockoutRounds.last.any((t) => !t.isComplete);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cup.isComplete)
          Card(
            color: cup.championId == userId
                ? SemanticColors.positive(context).withValues(alpha: 0.15)
                : null,
            child: ListTile(
              leading: Icon(
                Icons.emoji_events,
                color: cup.championId == userId
                    ? SemanticColors.positive(context)
                    : null,
              ),
              title: Text(Tr.pick('優勝: ${nameOf(cup.championId!)}',
                  'Winners: ${nameOf(cup.championId!)}')),
            ),
          )
        else if (userEliminated)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.info_outline,
                color: SemanticColors.negative(context),
              ),
              title: Text(Tr.pick('自クラブは敗退しました', 'You are out')),
              subtitle: Text(Tr.pick(
                  '他クラブの結果は引き続き更新されます', 'The other results keep coming in')),
            ),
          ),
        if (nextGroupMatch != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                if (gameState.canPlayNextContinentalMatchLive)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => playCupMatchLive(
                          context, LiveCupKind.continentalGroup),
                      icon: const Icon(Icons.sports_soccer),
                      label: Text(
                          Tr.pick('自クラブの試合をライブで戦う', 'Watch your tie live')),
                    ),
                  ),
                if (gameState.canPlayNextContinentalMatchLive)
                  const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: gameState.canPlayNextContinentalMatchLive
                      ? OutlinedButton(
                          onPressed: () => _playNextGroup(context),
                          child: Text(Tr.pick(
                              '観戦せず結果だけ確定(クイック消化)', 'Just settle the result')),
                        )
                      : FilledButton(
                          onPressed: gameState.canPlayNextContinentalMatch
                              ? () => _playNextGroup(context)
                              : null,
                          child: Text(Tr.pick(
                              '次のグループステージの試合を消化', 'Play the next group match')),
                        ),
                ),
                if (!gameState.canPlayNextContinentalMatch)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      Tr.pick('リーグ戦を1節進めると次の試合を消化できます',
                          'Play one more league matchday and you can take the next tie'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          )
        else if (knockoutPending)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                if (gameState.canPlayNextContinentalMatchLive)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => playCupMatchLive(
                          context, LiveCupKind.continentalKnockout),
                      icon: const Icon(Icons.sports_soccer),
                      label: Text(
                          Tr.pick('自クラブのレグをライブで戦う', 'Watch your leg live')),
                    ),
                  ),
                if (gameState.canPlayNextContinentalMatchLive)
                  const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: gameState.canPlayNextContinentalMatchLive
                      ? OutlinedButton(
                          onPressed: () => _playNextKnockoutLeg(context),
                          child: Text(Tr.pick(
                              '観戦せず結果だけ確定(クイック消化)', 'Just settle the result')),
                        )
                      : FilledButton(
                          onPressed: gameState.canPlayNextContinentalMatch
                              ? () => _playNextKnockoutLeg(context)
                              : null,
                          child: Text(Tr.pick('次の決勝トーナメントのレグを消化',
                              'Play the next knockout leg')),
                        ),
                ),
                if (!gameState.canPlayNextContinentalMatch)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      Tr.pick('リーグ戦を1節進めると次の試合を消化できます',
                          'Play one more league matchday and you can take the next tie'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        _RoundSection(
          title: Tr.pick('グループステージ', 'Group stage'),
          initiallyExpanded: !groupStageDone,
          children: [
            for (int g = 0; g < cup.groups.length; g++)
              _GroupTable(
                label: Tr.pick('グループ${String.fromCharCode(65 + g)}',
                    'Group ${String.fromCharCode(65 + g)}'),
                groupIndex: g,
                cup: cup,
                teams: teams,
                userId: userId,
              ),
          ],
        ),
        if (cup.knockoutRounds.isNotEmpty)
          for (final round in cup.knockoutRounds)
            _RoundSection(
              title: ContinentalCupEngine.roundLabel(
                round.first.round,
                cup.knockoutRounds.length,
              ),
              initiallyExpanded: round == cup.knockoutRounds.last,
              children: [
                for (final tie in round)
                  _TieCard(tie: tie, nameOf: nameOf, userId: userId),
              ],
            ),
      ],
    );
  }

  Future<void> _playNextGroup(BuildContext context) async {
    final gameState = context.read<GameState>();
    final userId = gameState.userTeam.id;
    final List<Team> teams = gameState.allTeamsForCups;
    final match = ContinentalCupEngine.nextGroupMatch(
      gameState.continentalCup!,
    );
    final isUserMatch = match != null &&
        (match.homeTeamId == userId || match.awayTeamId == userId);
    final result = await gameState.playNextContinentalGroupMatch();
    if (!context.mounted) return;
    showCupPrizeSnackBar(context, gameState);
    if (result != null && isUserMatch) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MatchScreen(
            result: result,
            teams: teams,
            title: Tr.pick('大陸カップ グループステージ', 'Continental Cup group stage'),
          ),
        ),
      );
    }
  }

  Future<void> _playNextKnockoutLeg(BuildContext context) async {
    final gameState = context.read<GameState>();
    final userId = gameState.userTeam.id;
    final List<Team> teams = gameState.allTeamsForCups;
    final round = gameState.continentalCup!.knockoutRounds.last;
    final tie = round.firstWhere(
      (t) => !t.isComplete,
      orElse: () => round.first,
    );
    final isUserTie = tie.teamAId == userId || tie.teamBId == userId;
    final result = await gameState.playNextContinentalKnockoutLeg();
    if (!context.mounted) return;
    showCupPrizeSnackBar(context, gameState);
    if (result != null && isUserTie) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MatchScreen(
            result: result,
            teams: teams,
            title: Tr.pick('大陸カップ 決勝トーナメント', 'Continental Cup knockout stage'),
          ),
        ),
      );
    }
  }
}

/// 国内カップの1試合分カード。自クラブの試合は背景色に加えて、
/// スクリーンリーダー向けにもその旨を読み上げる。
class _BracketMatchCard extends StatelessWidget {
  final CupMatch match;
  final String Function(String) nameOf;
  final String userId;

  const _BracketMatchCard({
    required this.match,
    required this.nameOf,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final isUserMatch =
        match.homeTeamId == userId || match.awayTeamId == userId;
    final resultLabel = match.result == null
        ? Tr.pick('未消化', 'Not played')
        : '${match.result!.homeGoals} - ${match.result!.awayGoals}';
    final card = Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        tileColor: isUserMatch
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.25)
            : null,
        title: Text(
          '${nameOf(match.homeTeamId)} vs ${nameOf(match.awayTeamId)}',
        ),
        subtitle: match.penaltyWinnerId != null
            ? Text(Tr.pick('PK戦: ${nameOf(match.penaltyWinnerId!)}が勝利',
                'Shootout: ${nameOf(match.penaltyWinnerId!)} go through'))
            : null,
        trailing: match.result == null
            ? Text(Tr.pick('未消化', 'Not played'))
            : Text(resultLabel, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
    if (!isUserMatch) return card;
    return Semantics(
      label: Tr.pick(
          '自クラブの試合。${nameOf(match.homeTeamId)} vs ${nameOf(match.awayTeamId)}、$resultLabel${match.penaltyWinnerId != null ? '、PK戦: ${nameOf(match.penaltyWinnerId!)}が勝利' : ''}',
          "Your match. ${nameOf(match.homeTeamId)} vs ${nameOf(match.awayTeamId)}, $resultLabel${match.penaltyWinnerId != null ? ', shootout won by ${nameOf(match.penaltyWinnerId!)}' : ''}"),
      child: ExcludeSemantics(child: card),
    );
  }
}

class _GroupTable extends StatelessWidget {
  final String label;
  final int groupIndex;
  final ContinentalCup cup;
  final List<Team> teams;
  final String userId;

  const _GroupTable({
    required this.label,
    required this.groupIndex,
    required this.cup,
    required this.teams,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final standings = ContinentalCupEngine.groupStandings(
      cup,
      groupIndex,
      teams,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (int i = 0; i < standings.length; i++)
                Builder(
                  builder: (context) {
                    final isUserRow = standings[i].teamId == userId;
                    final teamName = teams
                        .firstWhere(
                          (t) => t.id == standings[i].teamId,
                          orElse: () => teams.first,
                        )
                        .name;
                    final row = Container(
                      color: isUserRow
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.25)
                          : null,
                      child: ListTile(
                        dense: true,
                        leading: SizedBox(width: 20, child: Text('${i + 1}')),
                        title: Text(teamName),
                        trailing: Text(
                          Tr.pick(
                              '${standings[i].points}pt (${standings[i].played}試合)',
                              '${standings[i].points} pts (${standings[i].played} played)'),
                        ),
                      ),
                    );
                    if (!isUserRow) return row;
                    return Semantics(
                      label: Tr.pick(
                          '自クラブ。${i + 1}位: $teamName、${standings[i].points}pt (${standings[i].played}試合)',
                          'Your club. ${i + 1}: $teamName, ${standings[i].points} pts (${standings[i].played} played)'),
                      child: ExcludeSemantics(child: row),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TieCard extends StatelessWidget {
  final CupTie tie;
  final String Function(String) nameOf;
  final String userId;

  const _TieCard({
    required this.tie,
    required this.nameOf,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final isUserTie = tie.teamAId == userId || tie.teamBId == userId;
    final legsLabel = tie.legs.isEmpty
        ? Tr.pick('未消化', 'Not played')
        : tie.legs.map((r) => '${r.homeGoals}-${r.awayGoals}').join(' / ');
    final scoreLabel = tie.singleLeg
        ? Tr.pick('1試合制: $legsLabel', 'Single leg: $legsLabel')
        : Tr.pick(
            '合計スコア: ${tie.goalsFor(tie.teamAId)} - ${tie.goalsFor(tie.teamBId)} ($legsLabel)',
            'Aggregate: ${tie.goalsFor(tie.teamAId)} - ${tie.goalsFor(tie.teamBId)} ($legsLabel)');
    final resultLabel = tie.winnerId == null
        ? Tr.pick('対戦中', 'In progress')
        : Tr.pick('${nameOf(tie.winnerId!)}が勝利',
            '${nameOf(tie.winnerId!)} go through');
    final card = Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        tileColor: isUserTie
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.25)
            : null,
        title: Text('${nameOf(tie.teamAId)} vs ${nameOf(tie.teamBId)}'),
        subtitle: Text(scoreLabel),
        trailing: tie.winnerId == null
            ? Text(Tr.pick('対戦中', 'In progress'))
            : Text(resultLabel, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
    if (!isUserTie) return card;
    return Semantics(
      label: Tr.pick(
          '自クラブの対戦。${nameOf(tie.teamAId)} vs ${nameOf(tie.teamBId)}、$scoreLabel、$resultLabel',
          'Your tie. ${nameOf(tie.teamAId)} vs ${nameOf(tie.teamBId)}, $scoreLabel, $resultLabel'),
      child: ExcludeSemantics(child: card),
    );
  }
}

/// カップ戦の1ラウンド分をまとめる折りたたみ可能なセクション。
/// 消化済みの過去ラウンドはデフォルトで畳んでおき、画面のスクロール量を抑える。
class _RoundSection extends StatelessWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _RoundSection({
    required this.title,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        children: children,
      ),
    );
  }
}
