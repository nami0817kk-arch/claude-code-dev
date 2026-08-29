import '../models/attributes.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';

class LineupUtils {
  /// フォーメーションの各スロットに、負傷者を除く総合力上位の選手を自動で割り当てる。
  /// スロットと同じポジションの選手を優先し、いなければ副ポジションが一致する選手、
  /// それも足りなければ同じ大分類(GK/DEF/MID/ATT)の選手、それでも足りなければ
  /// 残りの中で総合力が最も高い選手で埋める。
  static void autoFill(Team team) {
    final formation = team.formation;
    final available = team.players
        .where((p) =>
            !p.isInjured &&
            !p.isOnInternationalDuty &&
            !p.isLoanedOut &&
            !p.isSuspended)
        .toList();
    final used = <Player>{};

    List<Player> candidatesFor(Position slot) {
      final exact = available
          .where((p) => !used.contains(p) && p.position == slot)
          .toList();
      if (exact.isNotEmpty) return exact;
      final secondary = available
          .where(
              (p) => !used.contains(p) && p.secondaryPositions.contains(slot))
          .toList();
      if (secondary.isNotEmpty) return secondary;
      final sameGroup = available
          .where((p) => !used.contains(p) && p.position.group == slot.group)
          .toList();
      if (sameGroup.isNotEmpty) return sameGroup;
      return available.where((p) => !used.contains(p)).toList();
    }

    final xi = <Player>[];
    for (final slot in formation.slots) {
      final candidates = candidatesFor(slot)
        ..sort((a, b) => b.overall.compareTo(a.overall));
      if (candidates.isEmpty) continue;
      final chosen = candidates.first;
      used.add(chosen);
      xi.add(chosen);
    }
    team.startingXI = xi.map((p) => p.id).toList();
  }

  /// スタメン11人をフォーメーションのスロット順に割り当てる。
  /// 完全一致がいない枠(グループ代用など)は残りの先発から総合力順に補う。
  /// スタメン画面のピッチ表示と、試合エンジンのポジション適性判定の
  /// 両方から共通で使う。
  static List<Player?> resolveSlotAssignments(Team team) {
    final byId = {for (final p in team.players) p.id: p};
    final startingPlayers =
        team.startingXI.map((id) => byId[id]).whereType<Player>().toList();

    final remainingByPosition = <Position, List<Player>>{};
    for (final p in startingPlayers) {
      remainingByPosition.putIfAbsent(p.position, () => []).add(p);
    }
    for (final list in remainingByPosition.values) {
      list.sort((a, b) => b.overall.compareTo(a.overall));
    }

    final slots = team.formation.slots;
    final assignments = <Player?>[];
    for (final slotPos in slots) {
      final list = remainingByPosition[slotPos];
      if (list != null && list.isNotEmpty) {
        assignments.add(list.removeAt(0));
      } else {
        assignments.add(null);
      }
    }

    final leftovers = remainingByPosition.values.expand((l) => l).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));

    // 空きスロットのうち、副ポジションとして合致する控えがいれば優先して
    // 割り当てる(autoFillが副ポジション適性で選出した選手を、総合力順の
    // 無関係なスロットに誤帰属させないため)。
    for (int i = 0; i < assignments.length; i++) {
      if (assignments[i] != null) continue;
      final slotPos = slots[i];
      final match = leftovers
          .where((p) => p.secondaryPositions.contains(slotPos))
          .toList();
      if (match.isNotEmpty) {
        assignments[i] = match.first;
        leftovers.remove(match.first);
      }
    }

    for (int i = 0; i < assignments.length; i++) {
      if (assignments[i] == null && leftovers.isNotEmpty) {
        assignments[i] = leftovers.removeAt(0);
      }
    }
    return assignments;
  }

  /// [resolveSlotAssignments]の結果を、選手ID→実際に配置されたスロットの
  /// ポジションのマップに変換する。
  static Map<String, Position> assignedSlotByPlayerId(Team team) {
    final assignments = resolveSlotAssignments(team);
    final slots = team.formation.slots;
    final map = <String, Position>{};
    for (int i = 0; i < assignments.length; i++) {
      final p = assignments[i];
      if (p != null) map[p.id] = slots[i];
    }
    return map;
  }

  /// CPUクラブ向けに、PK・直接FK・CK・守備セットプレー担当を能力値の
  /// 最も高い選手へ自動的に割り当てる(ユーザーは戦術画面で手動指名する)。
  /// これがないとCPUは常にセットプレー担当不在のままになり、チャンスの
  /// 約4分の1を占めるセットプレーの得点力・失点抑止力で一方的に不利になる。
  static void autoAssignSetPieceRoles(Team team) {
    if (team.players.isEmpty) return;
    String bestBy(int Function(Player) score) {
      var best = team.players.first;
      var bestScore = score(best);
      for (final p in team.players.skip(1)) {
        final s = score(p);
        if (s > bestScore) {
          best = p;
          bestScore = s;
        }
      }
      return best.id;
    }

    team.penaltyTakerId =
        bestBy((p) => p.attributeValue(AttributeKeys.penalties));
    team.freeKickTakerId =
        bestBy((p) => p.attributeValue(AttributeKeys.freeKick));
    team.cornerTakerId = bestBy((p) => p.attributeValue(AttributeKeys.corners));
    team.setPieceDefenderId = bestBy((p) =>
        p.attributeValue(AttributeKeys.heading) +
        p.attributeValue(AttributeKeys.jumpingReach));
  }
}
