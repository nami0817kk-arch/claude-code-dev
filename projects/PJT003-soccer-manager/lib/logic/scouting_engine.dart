import 'dart:math';

import '../models/player.dart';
import 'player_generator.dart';

class ScoutingEngine {
  static final Random _rng = Random();

  static const int scoutCost = 300;
  static const int maxProspects = 6;
  static const int baseScoutCandidates = 5;
  static const int refreshCost = 120;

  /// スカウトのレベルが高いほど費用は下がる。
  static int scoutCostFor(int scoutLevel) =>
      (scoutCost - (scoutLevel - 1) * 20).clamp(150, scoutCost);

  /// スカウト網の手動更新(候補選手の顔ぶれの一新)1回あたりの費用。
  /// これがないと「良い候補が出るまで無償で更新し続ける」だけの作業に
  /// なってしまうため、更新にも実際の費用を発生させる。スカウトのレベルが
  /// 高いほど情報網が整っており安く済む。
  static int refreshCostFor(int scoutLevel) =>
      (refreshCost - (scoutLevel - 1) * 10).clamp(60, refreshCost);

  /// 未獲得のスカウト候補について、スカウトレベルに応じた潜在能力の
  /// 推定レンジ(下限・上限)を返す。実際の値([Player.potential])は
  /// スカウトして獲得するまで確定情報として開示しない(フォグ・オブ・
  /// ウォー)。これにより、更新を繰り返して確実に当たりを引くという
  /// プレイが成立しなくなり、スカウトのレベル(=推定精度)そのものに
  /// 投資する価値が生まれる。
  static (int low, int high) estimatedPotentialRange(
    Player prospect, {
    int scoutLevel = 1,
  }) {
    final uncertainty = (18 - (scoutLevel - 1) * 1.5).clamp(6, 18).round();
    final low = (prospect.potential - uncertainty).clamp(1, 99);
    final high = (prospect.potential + uncertainty).clamp(1, 99);
    return (low, high);
  }

  /// ユース施設のレベルが高いほど昇格候補の受け入れ枠が増える。
  static int maxProspectsFor(int youthFacilityLevel) =>
      maxProspects + (youthFacilityLevel - 1);

  /// スカウトのレベルが高いほど、一度に閲覧できる候補選手(スカウト網)が広がる。
  static int scoutCandidateCountFor(int scoutLevel) =>
      baseScoutCandidates + (scoutLevel - 1);

  static Player _generateProspect({
    required int tierMin,
    required int tierMax,
  }) {
    final position = Position.values[_rng.nextInt(Position.values.length)];
    final tier = tierMin + _rng.nextInt(tierMax - tierMin + 1);
    final age = 16 + _rng.nextInt(4);
    return PlayerGenerator.generate(
      position: position,
      strengthTier: tier,
      ageOverride: age,
    );
  }

  /// シーズン終了時にアカデミーから無償で昇格候補が生まれる。ユースコーチのレベルが質を高める。
  static Player generateAcademyGraduate({int youthCoachLevel = 1}) {
    final bonus = (youthCoachLevel - 1) * 3;
    return _generateProspect(tierMin: 40 + bonus, tierMax: 70 + bonus);
  }

  /// 資金を払ってスカウトした有望株。アカデミー生より粒ぞろいで、スカウトの
  /// レベルが質を高める。レベルが上がるほど下限が底上げされるだけでなく、
  /// 当たり外れの幅(下限-上限の差)も狭まり、優秀なスカウト網ほど確実に
  /// 良い選手を見つけてくるという体感に近づける。
  static Player generateScoutedProspect({int scoutLevel = 1}) {
    final bonus = (scoutLevel - 1) * 4;
    final rangeWidth = (30 - (scoutLevel - 1) * 2).clamp(14, 30);
    final tierMin = 55 + bonus;
    return _generateProspect(tierMin: tierMin, tierMax: tierMin + rangeWidth);
  }
}
