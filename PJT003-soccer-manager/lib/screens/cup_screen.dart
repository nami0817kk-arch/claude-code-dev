import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/continental_cup_engine.dart';
import '../logic/cup_engine.dart';
import '../models/continental_cup.dart';
import '../models/cup.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'match_screen.dart';

class CupScreen extends StatelessWidget {
  const CupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('カップ戦'),
          leading: const BackButton(),
          actions: const [QuickAccessMenuButton()],
          bottom: const TabBar(tabs: [Tab(text: '国内カップ'), Tab(text: '大陸カップ')]),
        ),
        drawer: const QuickAccessDrawer(),
        body: const ResponsiveBody(
          child: TabBarView(
            children: [
              _DomesticCupTab(),
              _ContinentalCupTab(),
            ],
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('カップ戦の情報がありません。', textAlign: TextAlign.center),
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
              title: Text('優勝: ${nameOf(cup.championId!)}'),
            ),
          )
        else if (userEliminated)
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline,
                  color: SemanticColors.negative(context)),
              title: const Text('自クラブは敗退しました'),
              subtitle: const Text('他クラブの結果は引き続き更新されます'),
            ),
          ),
        if (nextMatch != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: gameState.canPlayNextDomesticCupMatch
                        ? () => _playNext(context)
                        : null,
                    child: const Text('次の試合を消化'),
                  ),
                ),
                if (!gameState.canPlayNextDomesticCupMatch)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('リーグ戦を1節進めると次の試合を消化できます',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
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
    if (result != null && isUserMatch) {
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) =>
                MatchScreen(result: result, teams: teams, title: '国内カップ')),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('前シーズンをリーグ2位以内で終えると、翌シーズンは大陸カップに出場できます。',
              textAlign: TextAlign.center),
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
              title: Text('優勝: ${nameOf(cup.championId!)}'),
            ),
          )
        else if (userEliminated)
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline,
                  color: SemanticColors.negative(context)),
              title: const Text('自クラブは敗退しました'),
              subtitle: const Text('他クラブの結果は引き続き更新されます'),
            ),
          ),
        if (nextGroupMatch != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: gameState.canPlayNextContinentalMatch
                        ? () => _playNextGroup(context)
                        : null,
                    child: const Text('次のグループステージの試合を消化'),
                  ),
                ),
                if (!gameState.canPlayNextContinentalMatch)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('リーグ戦を1節進めると次の試合を消化できます',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ],
            ),
          )
        else if (knockoutPending)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: gameState.canPlayNextContinentalMatch
                        ? () => _playNextKnockoutLeg(context)
                        : null,
                    child: const Text('次の決勝トーナメントのレグを消化'),
                  ),
                ),
                if (!gameState.canPlayNextContinentalMatch)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('リーグ戦を1節進めると次の試合を消化できます',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ],
            ),
          ),
        _RoundSection(
          title: 'グループステージ',
          initiallyExpanded: !groupStageDone,
          children: [
            for (int g = 0; g < cup.groups.length; g++)
              _GroupTable(
                label: 'グループ${String.fromCharCode(65 + g)}',
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
                  round.first.round, cup.knockoutRounds.length),
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
    final match =
        ContinentalCupEngine.nextGroupMatch(gameState.continentalCup!);
    final isUserMatch = match != null &&
        (match.homeTeamId == userId || match.awayTeamId == userId);
    final result = await gameState.playNextContinentalGroupMatch();
    if (!context.mounted) return;
    if (result != null && isUserMatch) {
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => MatchScreen(
                result: result, teams: teams, title: '大陸カップ グループステージ')),
      );
    }
  }

  Future<void> _playNextKnockoutLeg(BuildContext context) async {
    final gameState = context.read<GameState>();
    final userId = gameState.userTeam.id;
    final List<Team> teams = gameState.allTeamsForCups;
    final round = gameState.continentalCup!.knockoutRounds.last;
    final tie =
        round.firstWhere((t) => !t.isComplete, orElse: () => round.first);
    final isUserTie = tie.teamAId == userId || tie.teamBId == userId;
    final result = await gameState.playNextContinentalKnockoutLeg();
    if (!context.mounted) return;
    if (result != null && isUserTie) {
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => MatchScreen(
                result: result, teams: teams, title: '大陸カップ 決勝トーナメント')),
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

  const _BracketMatchCard(
      {required this.match, required this.nameOf, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isUserMatch =
        match.homeTeamId == userId || match.awayTeamId == userId;
    final resultLabel = match.result == null
        ? '未消化'
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
        title:
            Text('${nameOf(match.homeTeamId)} vs ${nameOf(match.awayTeamId)}'),
        subtitle: match.penaltyWinnerId != null
            ? Text('PK戦: ${nameOf(match.penaltyWinnerId!)}が勝利')
            : null,
        trailing: match.result == null
            ? const Text('未消化')
            : Text(resultLabel, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
    if (!isUserMatch) return card;
    return Semantics(
      label: '自クラブの試合。'
          '${nameOf(match.homeTeamId)} vs ${nameOf(match.awayTeamId)}、$resultLabel'
          '${match.penaltyWinnerId != null ? '、PK戦: ${nameOf(match.penaltyWinnerId!)}が勝利' : ''}',
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
    final standings =
        ContinentalCupEngine.groupStandings(cup, groupIndex, teams);
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
                child:
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
              ),
              for (int i = 0; i < standings.length; i++)
                Builder(builder: (context) {
                  final isUserRow = standings[i].teamId == userId;
                  final teamName = teams
                      .firstWhere((t) => t.id == standings[i].teamId,
                          orElse: () => teams.first)
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
                          '${standings[i].points}pt (${standings[i].played}試合)'),
                    ),
                  );
                  if (!isUserRow) return row;
                  return Semantics(
                    label: '自クラブ。${i + 1}位: $teamName、'
                        '${standings[i].points}pt (${standings[i].played}試合)',
                    child: ExcludeSemantics(child: row),
                  );
                }),
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

  const _TieCard(
      {required this.tie, required this.nameOf, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isUserTie = tie.teamAId == userId || tie.teamBId == userId;
    final legsLabel = tie.legs.isEmpty
        ? '未消化'
        : tie.legs.map((r) => '${r.homeGoals}-${r.awayGoals}').join(' / ');
    final scoreLabel = tie.singleLeg
        ? '1試合制: $legsLabel'
        : '合計スコア: ${tie.goalsFor(tie.teamAId)} - ${tie.goalsFor(tie.teamBId)} ($legsLabel)';
    final resultLabel =
        tie.winnerId == null ? '対戦中' : '${nameOf(tie.winnerId!)}が勝利';
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
            ? const Text('対戦中')
            : Text(resultLabel, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
    if (!isUserTie) return card;
    return Semantics(
      label: '自クラブの対戦。${nameOf(tie.teamAId)} vs ${nameOf(tie.teamBId)}、'
          '$scoreLabel、$resultLabel',
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
