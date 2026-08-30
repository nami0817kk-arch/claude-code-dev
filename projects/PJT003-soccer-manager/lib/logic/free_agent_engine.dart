import 'dart:math';

import '../models/player.dart';
import 'player_generator.dart';

/// 移籍金なし(週俸のみ)で獲得できるフリーエージェントのプールを管理する。
class FreeAgentEngine {
  static final Random _rng = Random();

  /// プールの上限。契約切れで加わった選手が多い場合はそちらを優先し、
  /// 生成で埋めるのはこの上限まで。
  static const int maxPoolSize = 12;

  /// シーズン終了時に生成する、ベテラン中心のフリーエージェント。
  static Player generateVeteran() {
    final position = Position.values[_rng.nextInt(Position.values.length)];
    final tier = 40 + _rng.nextInt(36);
    final age = 27 + _rng.nextInt(9);
    final player = PlayerGenerator.generate(
      position: position,
      strengthTier: tier,
      ageOverride: age,
    );
    player.contractYearsRemaining = 0;
    return player;
  }

  /// スカッドが最低人数を割り込んだときの緊急補強で使う選手。
  /// ベテラン中心の通常FA([generateVeteran])をそのまま使い続けると、
  /// 契約満了のたびに30代が入ってくるためスカッドが際限なく高齢化する
  /// (長期実測で平均年齢が26→31歳まで上がることを確認)。緊急補強は
  /// 「クラブが慌てて確保する即戦力」なので、若手〜中堅(21〜29歳)から
  /// 拾ってくる。
  static Player generateEmergencySigning() {
    final position = Position.values[_rng.nextInt(Position.values.length)];
    final tier = 40 + _rng.nextInt(36);
    final age = 21 + _rng.nextInt(9);
    final player = PlayerGenerator.generate(
      position: position,
      strengthTier: tier,
      ageOverride: age,
    );
    player.contractYearsRemaining = 0;
    return player;
  }

  /// プールが上限に達するまでベテランフリーエージェントを補充する。
  static void topUp(List<Player> pool, {int target = 6}) {
    while (pool.length < target && pool.length < maxPoolSize) {
      pool.add(generateVeteran());
    }
  }
}
