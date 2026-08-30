/// クラブニュース(お知らせ履歴)の1件。SnackBarやダイアログで一度だけ
/// 流れて消えていた通知を、あとから時系列で見返せるようにセーブデータへ
/// 保存する。[context]は発生時点の文脈ラベル(「第12節」「シーズン開始」
/// 「カップ戦」など)。
class NewsItem {
  final int season;
  final String context;
  final String text;

  const NewsItem({
    required this.season,
    required this.context,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'season': season,
        'context': context,
        'text': text,
      };

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        season: json['season'] as int? ?? 1,
        context: json['context'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );
}
