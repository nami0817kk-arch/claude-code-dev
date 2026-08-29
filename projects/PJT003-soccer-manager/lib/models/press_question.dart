/// 記者会見での回答選択肢。信頼度・選手士気への影響を持つ。
class PressOption {
  final String label;
  final int confidenceDelta;
  final int moraleDelta;

  PressOption(
      {required this.label,
      required this.confidenceDelta,
      required this.moraleDelta});

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidenceDelta': confidenceDelta,
        'moraleDelta': moraleDelta,
      };

  factory PressOption.fromJson(Map<String, dynamic> json) => PressOption(
        label: json['label'] as String,
        confidenceDelta: json['confidenceDelta'] as int,
        moraleDelta: json['moraleDelta'] as int,
      );
}

/// 試合後などに提示される記者会見の質問と回答選択肢。
class PressQuestion {
  final String prompt;
  final List<PressOption> options;

  PressQuestion({required this.prompt, required this.options});

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'options': options.map((o) => o.toJson()).toList(),
      };

  factory PressQuestion.fromJson(Map<String, dynamic> json) => PressQuestion(
        prompt: json['prompt'] as String,
        options: (json['options'] as List)
            .map((e) => PressOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
