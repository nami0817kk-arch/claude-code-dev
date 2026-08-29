import 'dart:math';

import '../models/player.dart';
import '../models/team.dart';
import 'player_generator.dart';

/// シーズン終了時の高齢選手の引退判定。
class RetirementEngine {
  static final Random _rng = Random();

  /// 31歳未満は引退しない。以降は年齢とともに引退確率が上がるが、
  /// 総合力が高い選手ほど現役を長く続けやすい。
  static double retirementChance(Player p) {
    if (p.age < 32) return 0.0;
    final ageFactor = (p.age - 31) * 0.12;
    final skillRelief = (p.overall - 50).clamp(0, 40) * 0.005;
    return (ageFactor - skillRelief).clamp(0.0, 0.9);
  }

  /// チームの引退対象者を判定し、スカッドから除外して返す(呼び出し側で
  /// 殿堂入りの記録などに使う)。
  static List<Player> resolveRetirements(Team team) {
    final retirees = <Player>[];
    for (final p in List<Player>.from(team.players)) {
      if (_rng.nextDouble() < retirementChance(p)) {
        retirees.add(p);
      }
    }
    for (final p in retirees) {
      team.players.remove(p);
      team.startingXI.remove(p.id);
    }
    return retirees;
  }

  /// CPU/2部クラブの世代交代。ユーザークラブと違って移籍市場で自ら補強
  /// しないため、引退した分をそのまま若手選手で穴埋めして、スカッドが
  /// 何シーズンも高齢化し続けたり選手数が枯渇したりしないようにする。
  ///
  /// 補充選手は18歳前後で生成すると現在能力がポテンシャルの6割程度に
  /// なり(PlayerGeneratorの年齢係数)、退団者より大幅に弱い選手ばかりが
  /// 入ってチーム力が下がり続ける(10シーズン実測で平均総合力51→40の
  /// デフレを確認)。世代交代でリーグ全体が弱体化しないよう、20〜26歳の
  /// 「若手〜即戦力」で補充し、生成基準もチーム力より少し上乗せして
  /// 年齢係数による目減りを相殺する。
  static List<Player> resolveAndReplaceForCpu(Team team) {
    final retirees = resolveRetirements(team);
    for (final p in retirees) {
      team.players.add(_generateCpuRecruit(team, p.position));
    }

    // 引退だけに頼るとスカッド全体が少しずつ高齢化し、衰えが若手の成長を
    // 上回ってリーグ平均戦力が漸減する(長期実測で確認)。実際のクラブの
    // ように、シーズンごとに30歳以上の下位1〜2人を放出して若手に入れ
    // 替え、世代のバランスを保つ。
    final elders = team.players.where((p) => p.age >= 30).toList()
      ..sort((a, b) => a.overall.compareTo(b.overall));
    final turnover = min(elders.length, 1 + _rng.nextInt(2));
    for (int i = 0; i < turnover; i++) {
      final leaver = elders[i];
      team.players.remove(leaver);
      team.startingXI.remove(leaver.id);
      if (team.captainId == leaver.id) team.captainId = null;
      if (team.viceCaptainId == leaver.id) team.viceCaptainId = null;
      team.players.add(_generateCpuRecruit(team, leaver.position));
    }
    return retirees;
  }

  /// CPUクラブの補充選手を生成する。年齢は21〜27歳(若手〜脂の乗り始め)、
  /// 生成基準はチーム力+6。PlayerGeneratorの年齢係数(この年齢帯で平均
  /// 約0.88)と掛け合わせると、入団時の現在能力がほぼチーム平均と釣り合い、
  /// リーグ平均戦力が世代交代のたびに漸減も漸増もしない(長期実測で調整)。
  static Player _generateCpuRecruit(Team team, Position position) =>
      PlayerGenerator.generate(
        position: position,
        strengthTier: team.overallRating + 6,
        ageOverride: 21 + _rng.nextInt(7),
      );
}
