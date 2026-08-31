import 'package:flutter/material.dart';

import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/weather.dart';
import '../screens/player_detail_screen.dart';
import '../theme/semantic_colors.dart';
import 'club_emblem.dart';
import '../l10n/tr.dart';

/// 試合当日の天候を表示するバッジ。晴天以外は攻守・チャンス数への
/// 影響があることを示すため色を変えて目立たせる。
class WeatherBadge extends StatelessWidget {
  final Weather weather;

  const WeatherBadge({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final isClear = weather == Weather.clear;
    final color = isClear ? Colors.grey.shade600 : Colors.blueGrey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(weather.icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            weather.label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 試合画面上部に表示するチームの見出し(エンブレム付きの名称)。
class TeamHeader extends StatelessWidget {
  final Team team;

  const TeamHeader({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClubEmblem(teamId: team.id, teamName: team.name, size: 36),
        const SizedBox(height: 4),
        Text(
          team.name,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

/// [event]の分数・選手名などから、テンプレートを一意に選び安定した実況文を
/// 生成する(乱数を使わず内容から決定するため、再描画されても同じ文になる)。
String matchCommentaryText(MatchEvent event, String teamName) {
  final scorer = event.scorerName ?? Tr.pick('選手', 'Players');
  final assist = event.assistName;
  final seed = event.minute * 31 +
      scorer.length * 7 +
      teamName.length * 3 +
      (assist?.length ?? 0) * 11;

  List<String> templates;
  switch (event.type) {
    case MatchEventType.goal:
      if (assist != null) {
        templates = [
          Tr.pick('$assistのスルーパスに抜け出した$scorerが流し込む！$teamNameゴール！',
              "$scorer runs onto $assist's through ball and slots it home. Goal for $teamName!"),
          Tr.pick('$assistの絶妙なクロスに$scorerが合わせた！$teamNameが加点！',
              '$assist whips it in and $scorer meets it. $teamName add another!'),
          Tr.pick('$assistからのパスを受けた$scorerが冷静に決めた！',
              "$scorer takes $assist's pass and finishes calmly."),
          Tr.pick('$scorer、$assistとの見事なコンビネーションでゴール！',
              "A lovely one-two between $scorer and $assist, and it's a goal!"),
          Tr.pick('$assistが作った決定機を$scorerが確実に仕留める！',
              '$assist makes the chance and $scorer takes it.'),
          Tr.pick('$teamNameお得意の形！$assistのお膳立てに$scorerが応えた！',
              'Classic $teamName. $assist lays it on and $scorer obliges!'),
          Tr.pick('一瞬の隙を突いた$assistのパス、$scorerが逃さず沈める！',
              '$assist spots the gap, and $scorer makes no mistake!'),
          Tr.pick('$scorerと$assistの息の合った崩しから$teamNameが突き放す！',
              '$scorer and $assist carve them open, and $teamName pull clear!'),
        ];
      } else {
        templates = [
          Tr.pick('$teamName!! $scorerが値千金の一撃！これはゴラッソだ！',
              '$teamName!! What a strike from $scorer. That is a golazo!'),
          Tr.pick('$scorerが冷静にゴールを射抜く！$teamNameに勢いが生まれる！',
              '$scorer picks his spot coolly. $teamName have their tails up!'),
          Tr.pick('$teamNameのチャンス、こぼれ球を$scorerが押し込んだ！',
              'It breaks for $teamName, and $scorer bundles it in!'),
          Tr.pick('$scorer、値千金の一撃！$teamNameが加点！',
              'A priceless goal from $scorer. $teamName extend it!'),
          Tr.pick('$scorer、個の力でねじ込んだ！$teamNameスタンドが沸く！',
              '$scorer forces it home on his own. The $teamName end erupts!'),
          Tr.pick('誰も予想しなかった一撃、$scorerが決めた！',
              'Nobody saw that coming. $scorer scores!'),
          Tr.pick('$teamName会心の攻撃！$scorerが仕留めた！',
              'A perfect $teamName move, finished by $scorer!'),
          Tr.pick('$scorer、執念のゴール！$teamNameに流れを引き寄せる一撃！',
              "$scorer refuses to give up on it. That could turn the game $teamName's way!"),
        ];
      }
      break;
    case MatchEventType.chance:
      templates = [
        Tr.pick('$scorerのシュートが枠をとらえるもGKが好セーブ！',
            '$scorer hits the target, but the keeper saves well!'),
        Tr.pick(
            '$scorer、惜しい！ポストに嫌われた！', 'So close from $scorer, off the post!'),
        Tr.pick('$teamName、$scorerのシュートは決めきれず。',
            '$scorer shoots for $teamName, but cannot finish it.'),
        Tr.pick('$scorerのシュートはわずかに枠の外へ…', "$scorer's effort drifts just wide…"),
        Tr.pick('$teamNameに決定機！$scorerが放つもGKの正面…',
            'A big chance for $teamName, but $scorer shoots straight at the keeper…'),
        Tr.pick('$scorer渾身の一撃、クロスバーに跳ね返される！',
            '$scorer lets fly, and the crossbar keeps it out!'),
        Tr.pick('惜しい！$scorerのシュートはブロックに阻まれた。',
            "So close. $scorer's shot is blocked."),
      ];
      break;
    case MatchEventType.yellowCard:
      templates = [
        Tr.pick('$scorerに主審からイエローカード。$teamNameは規律が問われる場面。',
            'A yellow for $scorer. $teamName need to keep their discipline.'),
        Tr.pick('$scorer、荒いプレーで警告を受ける。',
            '$scorer is booked for a rough challenge.'),
        Tr.pick('$teamNameの$scorerにカード提示。',
            '$scorer of $teamName goes into the book.'),
        Tr.pick('$scorer、抗議のあまり警告を受けてしまう。',
            '$scorer argues once too often and is booked.'),
        Tr.pick('際どいタックルの$scorerに主審が笛、イエローが提示される。',
            "The referee whistles for $scorer's late tackle and shows yellow."),
      ];
      break;
    case MatchEventType.redCard:
      templates = [
        Tr.pick('$scorerに一発退場が言い渡された！$teamNameは数的不利に…',
            'A straight red for $scorer! $teamName are down to ten…'),
        Tr.pick('$scorer、看過できないプレーで退場処分！',
            '$scorer goes for a challenge the referee cannot ignore!'),
        Tr.pick('$teamNameにとって痛恨の退場、$scorerがピッチを去る。',
            'A costly red card for $teamName as $scorer walks.'),
        Tr.pick('まさかの一発レッド！$scorerが涙のピッチ退場。',
            'A straight red out of nowhere. $scorer leaves the pitch in tears.'),
        Tr.pick('$scorer、この試合最大の誤算…退場でチームに大きな痛手。',
            'The moment that decides it: $scorer is sent off, and the team is in trouble.'),
      ];
      break;
  }
  return templates[seed % templates.length];
}

/// 実況イベント1件分の表示行(得点・警告・退場など)。
/// [userTeam]を渡すと、選手が現在も自クラブに在籍している場合に限り
/// タップして選手詳細画面へ遷移できる。
class CommentaryTile extends StatelessWidget {
  final MatchEvent event;
  final String teamName;
  final Team? userTeam;

  const CommentaryTile({
    super.key,
    required this.event,
    required this.teamName,
    this.userTeam,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (event.type) {
      MatchEventType.goal => (
          Icons.sports_soccer,
          SemanticColors.positive(context),
        ),
      MatchEventType.chance => (Icons.flash_on, Colors.orange),
      MatchEventType.yellowCard => (Icons.warning_amber, Colors.amber),
      MatchEventType.redCard => (Icons.dangerous, Colors.redAccent),
    };
    final text = matchCommentaryText(event, teamName);
    String? playerId;
    if (userTeam != null && event.teamId == userTeam!.id) {
      for (final p in userTeam!.players) {
        if (p.id == event.scorerId) {
          playerId = p.id;
          break;
        }
      }
    }
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${event.minute}'"),
            const SizedBox(width: 4),
            Icon(icon, size: 16, color: color),
          ],
        ),
      ),
      title: Text(text),
      onTap: playerId == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerDetailScreen(playerId: playerId!),
                ),
              ),
    );
  }
}

/// ポゼッション率・シュート数・枠内シュート数を表示するスタッツバー。
/// 旧セーブデータ由来などでスタッツが記録されていない試合では何も表示しない。
class MatchStatsBar extends StatelessWidget {
  final MatchResult result;
  final String homeTeamName;
  final String awayTeamName;

  const MatchStatsBar({
    super.key,
    required this.result,
    required this.homeTeamName,
    required this.awayTeamName,
  });

  @override
  Widget build(BuildContext context) {
    final hp = result.homePossession;
    final ap = result.awayPossession;
    if (hp == null || ap == null) return const SizedBox.shrink();
    final barHp = hp.clamp(1, 99);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          _statRow(context, '$hp%', Tr.pick('ポゼッション', 'Possession'), '$ap%'),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: barHp,
                    child: Container(color: SemanticColors.positive(context)),
                  ),
                  Expanded(
                    flex: 100 - barHp,
                    child: Container(color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _statRow(
            context,
            '${result.homeShots ?? 0}',
            Tr.pick('シュート', 'Shot'),
            '${result.awayShots ?? 0}',
          ),
          const SizedBox(height: 4),
          _statRow(
            context,
            '${result.homeShotsOnTarget ?? 0}',
            Tr.pick('枠内シュート', 'Shots on target'),
            '${result.awayShotsOnTarget ?? 0}',
          ),
        ],
      ),
    );
  }

  Widget _statRow(
    BuildContext context,
    String homeValue,
    String label,
    String awayValue,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            homeValue,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          width: 90,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            awayValue,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// 試合終了時の勝敗を色分けして示すバナー(ユース目線での勝敗)。
class FullTimeBanner extends StatelessWidget {
  final String userTeamId;
  final MatchResult? result;

  const FullTimeBanner({
    super.key,
    required this.userTeamId,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const SizedBox.shrink();
    final userIsHome = r.homeTeamId == userTeamId;
    final userGoals = userIsHome ? r.homeGoals : r.awayGoals;
    final oppGoals = userIsHome ? r.awayGoals : r.homeGoals;

    final String label;
    final Color color;
    final IconData icon;
    if (userGoals > oppGoals) {
      label = Tr.pick('勝利', 'Win');
      color = SemanticColors.positive(context);
      icon = Icons.emoji_events;
    } else if (userGoals < oppGoals) {
      label = Tr.pick('敗北', 'Defeat');
      color = SemanticColors.negative(context);
      icon = Icons.sentiment_dissatisfied;
    } else {
      label = Tr.pick('引き分け', 'Draw');
      color = SemanticColors.neutral(context);
      icon = Icons.handshake;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 試合終了時に、その試合で最も採点の高かった選手をマン・オブ・ザ・マッチ
/// として表示するバナー。選手が自クラブ所属の場合はタップで選手詳細へ遷移できる。
class ManOfTheMatchBanner extends StatelessWidget {
  final MatchResult? result;
  final List<Team> teams;
  final String? userTeamId;

  const ManOfTheMatchBanner({
    super.key,
    required this.result,
    required this.teams,
    this.userTeamId,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const SizedBox.shrink();
    final motmId = r.manOfTheMatchId;
    if (motmId == null) return const SizedBox.shrink();
    Player? motm;
    bool isOwnClub = false;
    for (final t in teams) {
      for (final p in t.players) {
        if (p.id == motmId) {
          motm = p;
          isOwnClub = t.id == userTeamId;
          break;
        }
      }
      if (motm != null) break;
    }
    if (motm == null) return const SizedBox.shrink();
    final rating = r.playerRatings[motmId];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: !isOwnClub
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlayerDetailScreen(playerId: motmId),
                    ),
                  ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Tr.pick('マン・オブ・ザ・マッチ: ${motm.name}',
                        'Man of the match: ${motm.name}'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (rating != null)
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 試合終了時に、自クラブ選手の特性がこの試合で発動した(好調・不調の
/// 補正がかかった)ことを可視化するバナー。[MatchEngine]が試合開始時に
/// 算出した[Player.matchFormMultiplier]を読み、1.0から外れた選手を
/// チップで並べる。誰も発動していなければ何も表示しない。
class TraitActivationBanner extends StatelessWidget {
  final Team userTeam;

  const TraitActivationBanner({super.key, required this.userTeam});

  @override
  Widget build(BuildContext context) {
    final activated = userTeam.players
        .where(
          (p) =>
              p.trait != null &&
              p.matchFormRolledThisMatch &&
              (p.matchFormMultiplier - 1.0).abs() >= 0.005,
        )
        .toList()
      ..sort(
        (a, b) => b.matchFormMultiplier.compareTo(a.matchFormMultiplier),
      );
    if (activated.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Tr.pick('特性発動', 'Traits that fired'),
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in activated)
                Semantics(
                  label: Tr.pick(
                      '${p.name}の特性${p.trait!.label}が${p.matchFormMultiplier > 1.0 ? 'プラス' : 'マイナス'}に発動',
                      "${p.name}'s ${p.trait!.label} worked ${p.matchFormMultiplier > 1.0 ? 'for' : 'against'} him"),
                  child: Chip(
                    avatar: Icon(
                      p.matchFormMultiplier > 1.0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 16,
                      color: p.matchFormMultiplier > 1.0
                          ? Colors.green
                          : Colors.redAccent,
                    ),
                    label: Text(
                      '${p.name}: ${p.trait!.label}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: scheme.surfaceContainerHighest,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
