import 'dart:math';

import '../data/name_pool.dart';
import '../models/league_theme.dart';
import '../models/player.dart';
import 'player_generator.dart';

class TransferMarket {
  static final Random _rng = Random();

  /// フリーエージェント風の移籍候補選手を生成する。海外の他リーグからスカウトして
  /// きた体で、現所属クラブ名(表示専用)も付与する。
  static List<Player> generate({int count = 24}) =>
      [for (int i = 0; i < count; i++) _generateOne()];

  static Player _generateOne() {
    final position = Position.values[_rng.nextInt(Position.values.length)];
    final tier = 40 + _rng.nextInt(45);
    final player = PlayerGenerator.generate(
      position: position,
      strengthTier: tier,
    );
    final theme = LeagueTheme.values[_rng.nextInt(LeagueTheme.values.length)];
    player.originClubName = NamePool.themedClubNames(theme, 1).first;
    return player;
  }

  /// 既存の市場を1週分ローテーションする。数人が市場から去り(他クラブへ
  /// 移籍した扱い)、新しい選手が加わって[targetCount]人に戻る。
  /// 全員を作り直さないことで「狙っていた選手を翌週も追える」持続的な
  /// 市場になる。
  static List<Player> rotate(List<Player> current, {int targetCount = 24}) {
    final next = [...current];
    final leavers = min(next.length, 3 + _rng.nextInt(4));
    for (int i = 0; i < leavers; i++) {
      next.removeAt(_rng.nextInt(next.length));
    }
    while (next.length < targetCount) {
      next.add(_generateOne());
    }
    return next;
  }
}
