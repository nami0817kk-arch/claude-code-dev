import 'dart:math';
import '../data/name_pool.dart';
import '../models/league_theme.dart';
import '../models/player.dart';
import 'player_generator.dart';

class TransferMarket {
  static final Random _rng = Random();

  /// フリーエージェント風の移籍候補選手を生成する。海外の他リーグからスカウトして
  /// きた体で、現所属クラブ名(表示専用)も付与する。
  static List<Player> generate({int count = 24}) {
    final players = <Player>[];
    for (int i = 0; i < count; i++) {
      final position = Position.values[_rng.nextInt(Position.values.length)];
      final tier = 40 + _rng.nextInt(45);
      final player =
          PlayerGenerator.generate(position: position, strengthTier: tier);
      final theme = LeagueTheme.values[_rng.nextInt(LeagueTheme.values.length)];
      player.originClubName = NamePool.themedClubNames(theme, 1).first;
      players.add(player);
    }
    return players;
  }
}
