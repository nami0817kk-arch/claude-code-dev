import 'enum_json.dart';
import 'formation.dart';
import 'player.dart';
import 'tactic_preset.dart';
import 'training_focus.dart';

/// 保存できる戦術プリセットの上限数。
const int maxTacticPresets = 5;

class Team {
  final String id;
  String name;
  List<Player> players;
  Formation formation;

  /// 現在の先発11人（Player.id）。フォーメーションの人数配分と一致する。
  List<String> startingXI;

  /// 個別方針を設定していない選手に適用されるチーム既定のトレーニング方針。
  TrainingFocus defaultTrainingFocus;

  /// トレーニングの強度(軽め/通常/追い込み)。成長速度と疲労・怪我リスクの
  /// トレードオフを調整する。
  TrainingIntensity trainingIntensity;

  /// 週の中で重点的にトレーニングを行う曜日(1=月〜5=金、既定は火曜)。
  /// カレンダー画面での表示専用で、試合日と重ならない前提。
  int trainingDayOfWeek;

  /// 有効にすると、毎節の進行時に未実施であれば自動的に週次トレーニングを
  /// 実施する(既定の方針・強度に従う)。
  bool autoTrainingEnabled;

  /// プレッシングの強度（0-100）。高いほど守備が強まるが疲労が増えやすい。
  int pressing;

  /// 守備ラインの高さ（0-100）。高いほど攻撃的だが裏を突かれやすい。
  int lineHeight;

  /// 攻撃の幅（0-100）。高いほどサイドを広く使い攻撃力が上がるが、中央の守備が薄くなる。
  int width;

  /// プレーのテンポ（0-100）。高いほど攻撃的だが疲労が溜まりやすい。
  int tempo;

  /// キャプテン・副キャプテンの選手ID(未指名の場合はnull)。
  String? captainId;
  String? viceCaptainId;

  /// セットプレー担当の選手ID(未指名の場合はnull)。指名されていれば
  /// 該当する場面で優先的にボールに関わる(PK・FKは優先的に打ち、
  /// CKはキッカーの精度がチャンスの質に反映される)。
  String? penaltyTakerId;
  String? freeKickTakerId;
  String? cornerTakerId;

  /// 相手の攻撃時の要注意選手(キープレイヤー)にマンマークを付ける自チームの
  /// 選手ID(未指名の場合はnull)。マーク対象は試合ごとにスカウティングレポートの
  /// キープレイヤーとして動的に決まる。マーカーが出場している間、相手キー
  /// プレイヤーの攻撃力への貢献が抑えられる。
  String? manMarkerId;

  /// 相手のセットプレー(コーナーキック・フリーキック)を守る担当の選手ID
  /// (未指名の場合はnull)。指名されていて出場している場合、ヘディング・
  /// ジャンプ力に応じて相手のセットプレー由来のチャンスの質を下げる。
  String? setPieceDefenderId;

  /// 逃げ切りモード。有効にすると自チームの攻撃力がやや下がる代わりに
  /// 守備が安定し、時間を使うぶん疲労の蓄積も抑えられる。リードした
  /// 終盤の采配として使う想定。
  bool timeWastingMode;

  /// 保存済みの戦術プリセット(最大[maxTacticPresets]件)。
  List<TacticPreset> tacticPresets;

  /// デプスチャートの手動並び替え結果(Position.name → 選手IDの優先順)。
  /// 未設定のポジションは総合力順で自動表示する。
  Map<String, List<String>> depthChartOrder;

  /// 戦術ミーティングの再実施までの残り週数(0なら実施可能)。連発による
  /// 効果の形骸化を防ぐためのクールダウン。
  int tacticalMeetingCooldownWeeks;

  Team({
    required this.id,
    required this.name,
    required this.players,
    this.formation = Formation.f442,
    List<String>? startingXI,
    this.defaultTrainingFocus = TrainingFocus.rest,
    this.trainingIntensity = TrainingIntensity.normal,
    this.trainingDayOfWeek = DateTime.tuesday,
    this.autoTrainingEnabled = false,
    this.pressing = 50,
    this.lineHeight = 50,
    this.width = 50,
    this.tempo = 50,
    this.captainId,
    this.viceCaptainId,
    this.penaltyTakerId,
    this.freeKickTakerId,
    this.cornerTakerId,
    this.manMarkerId,
    this.setPieceDefenderId,
    this.timeWastingMode = false,
    List<TacticPreset>? tacticPresets,
    Map<String, List<String>>? depthChartOrder,
    this.tacticalMeetingCooldownWeeks = 0,
  })  : startingXI = startingXI ?? [],
        tacticPresets = tacticPresets ?? [],
        depthChartOrder = depthChartOrder ?? {};

  int get overallRating {
    if (players.isEmpty) return 0;
    final sum = players.fold<int>(0, (s, p) => s + p.overall);
    return (sum / players.length).round();
  }

  /// 指定ポジションを主戦場とする選手を、控え順(デプスチャート)の順で返す。
  /// 手動で並び替えた順序があればそれを優先し、未設定なら総合力の高い順。
  /// 並び替え後にチームを離れた選手は自動的に除外され、新加入者は
  /// 総合力順で末尾に追加される。
  List<Player> depthChartFor(Position position) {
    final owned = players.where((p) => p.position == position).toList();
    final overrideIds = depthChartOrder[position.name];
    if (overrideIds == null) {
      owned.sort((a, b) => b.overall.compareTo(a.overall));
      return owned;
    }
    final byId = {for (final p in owned) p.id: p};
    final ordered = <Player>[];
    for (final id in overrideIds) {
      final p = byId.remove(id);
      if (p != null) ordered.add(p);
    }
    final remaining = byId.values.toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    ordered.addAll(remaining);
    return ordered;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'formation': formation.name,
        'startingXI': startingXI,
        'defaultTrainingFocus': defaultTrainingFocus.name,
        'trainingIntensity': trainingIntensity.name,
        'trainingDayOfWeek': trainingDayOfWeek,
        'autoTrainingEnabled': autoTrainingEnabled,
        'pressing': pressing,
        'lineHeight': lineHeight,
        'width': width,
        'tempo': tempo,
        'captainId': captainId,
        'viceCaptainId': viceCaptainId,
        'penaltyTakerId': penaltyTakerId,
        'freeKickTakerId': freeKickTakerId,
        'cornerTakerId': cornerTakerId,
        'manMarkerId': manMarkerId,
        'setPieceDefenderId': setPieceDefenderId,
        'timeWastingMode': timeWastingMode,
        'tacticPresets': tacticPresets.map((t) => t.toJson()).toList(),
        'depthChartOrder': depthChartOrder,
        'tacticalMeetingCooldownWeeks': tacticalMeetingCooldownWeeks,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        formation: _parseFormation(json['formation'] as String?),
        startingXI:
            (json['startingXI'] as List?)?.map((e) => e as String).toList() ??
                [],
        defaultTrainingFocus: enumFromName(
          TrainingFocus.values,
          json['defaultTrainingFocus'] as String?,
          TrainingFocus.rest,
        ),
        trainingIntensity: enumFromName(
          TrainingIntensity.values,
          json['trainingIntensity'] as String?,
          TrainingIntensity.normal,
        ),
        trainingDayOfWeek:
            json['trainingDayOfWeek'] as int? ?? DateTime.tuesday,
        autoTrainingEnabled: json['autoTrainingEnabled'] as bool? ?? false,
        pressing: json['pressing'] as int? ?? 50,
        lineHeight: json['lineHeight'] as int? ?? 50,
        width: json['width'] as int? ?? 50,
        tempo: json['tempo'] as int? ?? 50,
        captainId: json['captainId'] as String?,
        viceCaptainId: json['viceCaptainId'] as String?,
        penaltyTakerId: json['penaltyTakerId'] as String?,
        freeKickTakerId: json['freeKickTakerId'] as String?,
        cornerTakerId: json['cornerTakerId'] as String?,
        manMarkerId: json['manMarkerId'] as String?,
        setPieceDefenderId: json['setPieceDefenderId'] as String?,
        timeWastingMode: json['timeWastingMode'] as bool? ?? false,
        tacticPresets: (json['tacticPresets'] as List?)
                ?.map((e) => TacticPreset.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        depthChartOrder: (json['depthChartOrder'] as Map?)?.map(
              (k, v) => MapEntry(
                k as String,
                (v as List).map((e) => e as String).toList(),
              ),
            ) ??
            {},
        tacticalMeetingCooldownWeeks:
            json['tacticalMeetingCooldownWeeks'] as int? ?? 0,
        players: (json['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// 廃止されたフォーメーション名（旧f532など）のセーブでもクラッシュしないようにする。
  static Formation _parseFormation(String? name) {
    if (name == null) return Formation.f442;
    for (final f in Formation.values) {
      if (f.name == name) return f;
    }
    return Formation.f442;
  }
}
