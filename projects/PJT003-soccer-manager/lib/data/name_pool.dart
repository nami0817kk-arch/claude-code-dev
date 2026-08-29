import 'dart:math';
import '../models/league_theme.dart';

class NamePool {
  static final Random _rng = Random();

  static const _surnames = [
    '佐藤',
    '鈴木',
    '高橋',
    '田中',
    '伊藤',
    '渡辺',
    '山本',
    '中村',
    '小林',
    '加藤',
    '吉田',
    '山田',
    '佐々木',
    '山口',
    '松本',
    '井上',
    '木村',
    '林',
    '斎藤',
    '清水',
    '森',
    '池田',
    '橋本',
    '阿部',
    '石川',
    '山下',
    '中島',
    '石井',
    '小川',
    '前田',
  ];

  static const _givenNames = [
    '翔太',
    '大輝',
    '蓮',
    '陽翔',
    '悠斗',
    '颯太',
    '大和',
    '健太',
    '直樹',
    '拓海',
    '智也',
    '亮太',
    '涼太',
    '康平',
    '大樹',
    '雄大',
    '誠',
    '秀樹',
    '一輝',
    '隼人',
    '航',
    '葵',
    '駿',
    '律',
    '湊',
    '悠真',
    '俊介',
    '和也',
    '龍之介',
    '直希',
  ];

  static const _clubWords = [
    '蒼海',
    '白鷺',
    '紅葉',
    '北斗',
    '旭丘',
    '月見坂',
    '常盤',
    '緑陰',
    '朝霧',
    '東雲',
    '青嵐',
    '丘陵',
    '潮風',
    '桜坂',
    '若鮎',
  ];

  static const _clubSuffixes = ['FC', 'SC', 'ユナイテッド', 'アスレチック', 'シティ'];

  /// リーグの国風テーマごとのクラブ名素材(単語・接尾辞)。
  static const Map<LeagueTheme, List<String>> _themedWords = {
    LeagueTheme.england: [
      '紅獅子',
      '王冠',
      '霧の丘',
      '河畔',
      '古城',
      '聖森',
      '鉄橋',
      '北風',
    ],
    LeagueTheme.spain: [
      '太陽',
      '黄金',
      '南風',
      '闘牛',
      '橄欖',
      '紺碧',
      '城塞',
      '薔薇',
    ],
    LeagueTheme.germany: [
      '鉄鋼',
      '黒森',
      '北方',
      '工業',
      '鷲峰',
      '灰色',
      '大河',
      '鋼鉄',
    ],
    LeagueTheme.italy: [
      '古都',
      '水都',
      '紫紺',
      '山脈',
      '太陽海岸',
      '大理石',
      '鷹',
      '黒獅子',
    ],
    LeagueTheme.france: [
      '青薔薇',
      '灯台',
      '南仏',
      '栄光',
      '鳶色',
      '鐘楼',
      '葡萄畑',
      '風車',
    ],
  };

  static const Map<LeagueTheme, List<String>> _themedSuffixes = {
    LeagueTheme.england: [
      'ユナイテッド',
      'シティ',
      'アスレチック',
      'ローヴァーズ',
      'ウォンダラーズ',
      'タウン'
    ],
    LeagueTheme.spain: ['レアル', 'アトレティコ', 'デポルティボ', 'CF', 'ウニオン'],
    LeagueTheme.germany: ['SV', 'FC', 'ボルシア', 'ウニオン', 'アドラー'],
    LeagueTheme.italy: ['インテル', 'AC', 'カルチョ', 'レアーレ', 'スポルティーバ'],
    LeagueTheme.france: ['オランピック', 'AS', 'FC', 'レーシング', 'スタッド'],
  };

  static String randomPlayerName() {
    final s = _surnames[_rng.nextInt(_surnames.length)];
    final g = _givenNames[_rng.nextInt(_givenNames.length)];
    return '$s $g';
  }

  static List<String> clubNames(int count) {
    final combos = <String>{};
    while (combos.length < count) {
      final w = _clubWords[_rng.nextInt(_clubWords.length)];
      final suf = _clubSuffixes[_rng.nextInt(_clubSuffixes.length)];
      combos.add('$w$suf');
    }
    return combos.toList();
  }

  /// 指定したリーグテーマの雰囲気に合わせたクラブ名を[count]件、重複なく生成する。
  static List<String> themedClubNames(LeagueTheme theme, int count) {
    final words = _themedWords[theme]!;
    final suffixes = _themedSuffixes[theme]!;
    final combos = <String>{};
    var guard = 0;
    final maxAttempts = count * 50;
    while (combos.length < count && guard < maxAttempts) {
      final w = words[_rng.nextInt(words.length)];
      final suf = suffixes[_rng.nextInt(suffixes.length)];
      combos.add('$w$suf');
      guard++;
    }
    // words×suffixesの組み合わせ数(テーマによっては40通り程度)を超える件数を
    // 要求された場合、上のランダム試行だけでは[count]件に届かないことがある。
    // 連番を付けて確実に埋め、要求件数を必ず満たす(連番は既出と衝突しない)。
    var n = 2;
    while (combos.length < count) {
      for (final w in words) {
        for (final suf in suffixes) {
          if (combos.length >= count) break;
          combos.add('$w$suf$n');
        }
        if (combos.length >= count) break;
      }
      n++;
    }
    return combos.take(count).toList();
  }
}
