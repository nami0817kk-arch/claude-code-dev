import 'formation.dart';

/// 名前を付けて保存・呼び出しできる戦術の一式(フォーメーション+各種スライダー+
/// セットプレー担当)。複数の戦術を使い分けたい場合に、その都度スライダーを
/// 調整し直さずに済むようにする。
class TacticPreset {
  String name;
  Formation formation;
  int pressing;
  int lineHeight;
  int width;
  int tempo;
  String? penaltyTakerId;
  String? freeKickTakerId;
  String? cornerTakerId;

  TacticPreset({
    required this.name,
    required this.formation,
    required this.pressing,
    required this.lineHeight,
    required this.width,
    required this.tempo,
    this.penaltyTakerId,
    this.freeKickTakerId,
    this.cornerTakerId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'formation': formation.name,
        'pressing': pressing,
        'lineHeight': lineHeight,
        'width': width,
        'tempo': tempo,
        'penaltyTakerId': penaltyTakerId,
        'freeKickTakerId': freeKickTakerId,
        'cornerTakerId': cornerTakerId,
      };

  factory TacticPreset.fromJson(Map<String, dynamic> json) => TacticPreset(
        name: json['name'] as String,
        formation: Formation.values.firstWhere(
          (f) => f.name == json['formation'],
          orElse: () => Formation.f442,
        ),
        pressing: json['pressing'] as int? ?? 50,
        lineHeight: json['lineHeight'] as int? ?? 50,
        width: json['width'] as int? ?? 50,
        tempo: json['tempo'] as int? ?? 50,
        penaltyTakerId: json['penaltyTakerId'] as String?,
        freeKickTakerId: json['freeKickTakerId'] as String?,
        cornerTakerId: json['cornerTakerId'] as String?,
      );
}
