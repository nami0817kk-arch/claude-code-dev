import 'dart:math';

import '../l10n/tr.dart';
import '../models/league_theme.dart';

class NamePool {
  static final Random _rng = Random();

  // i18n-ignore: 日本語表示のときに使う名前データ。UIの文言ではないので訳さない。
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

  // i18n-ignore: 日本語表示用の名前データ。
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

  // i18n-ignore: 日本語表示用の名前データ。
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

  // i18n-ignore: 日本語表示用の名前データ。
  static const _clubSuffixes = ['FC', 'SC', 'ユナイテッド', 'アスレチック', 'シティ'];

  /// リーグの国風テーマごとのクラブ名素材(単語・接尾辞)。
  // i18n-ignore: 日本語表示用の名前データ。
  static const Map<LeagueTheme, List<String>> _themedWords = {
    LeagueTheme.england: ['紅獅子', '王冠', '霧の丘', '河畔', '古城', '聖森', '鉄橋', '北風'],
    LeagueTheme.spain: ['太陽', '黄金', '南風', '闘牛', '橄欖', '紺碧', '城塞', '薔薇'],
    LeagueTheme.germany: ['鉄鋼', '黒森', '北方', '工業', '鷲峰', '灰色', '大河', '鋼鉄'],
    LeagueTheme.italy: ['古都', '水都', '紫紺', '山脈', '太陽海岸', '大理石', '鷹', '黒獅子'],
    LeagueTheme.france: ['青薔薇', '灯台', '南仏', '栄光', '鳶色', '鐘楼', '葡萄畑', '風車'],
  };

  // i18n-ignore: 日本語表示用の名前データ。
  static const Map<LeagueTheme, List<String>> _themedSuffixes = {
    LeagueTheme.england: [
      'ユナイテッド',
      'シティ',
      'アスレチック',
      'ローヴァーズ',
      'ウォンダラーズ',
      'タウン',
    ],
    LeagueTheme.spain: ['レアル', 'アトレティコ', 'デポルティボ', 'CF', 'ウニオン'],
    LeagueTheme.germany: ['SV', 'FC', 'ボルシア', 'ウニオン', 'アドラー'],
    LeagueTheme.italy: ['インテル', 'AC', 'カルチョ', 'レアーレ', 'スポルティーバ'],
    LeagueTheme.france: ['オランピック', 'AS', 'FC', 'レーシング', 'スタッド'],
  };

  // --- 英語表示のときに使う名前プール ---
  //
  // これは翻訳ではない。「佐藤」を英語に訳すことはできないし、訳せたとしても
  // サッカーゲームのクラブ名・選手名としては読めない。英語で遊ぶ人のために、
  // 別のデータを用意している。
  //
  // 生成された名前はセーブに保存されるため、日本語で始めたセーブは英語に
  // 切り替えても日本語の名前のまま残る。クラブ名や選手名は言語設定ではなく
  // そのセーブの一部だと考えているので、これは意図した挙動。

  static const _surnamesEn = [
    'Bennett',
    'Carter',
    'Doyle',
    'Ellis',
    'Fletcher',
    'Grant',
    'Hayes',
    'Ingram',
    'Jennings',
    'Keane',
    'Lawson',
    'Marsh',
    'Newton',
    'Oakley',
    'Pearce',
    'Quinn',
    'Reeves',
    'Sutton',
    'Thorne',
    'Underwood',
    'Vaughn',
    'Whitfield',
    'Ashworth',
    'Blackwood',
    'Crowley',
    'Dunbar',
    'Everett',
    'Fairbanks',
    'Gallagher',
    'Hollis',
  ];

  static const _givenNamesEn = [
    'Alfie',
    'Blake',
    'Callum',
    'Declan',
    'Elliot',
    'Finley',
    'Gareth',
    'Harvey',
    'Isaac',
    'Jude',
    'Kieran',
    'Louis',
    'Marcus',
    'Nathan',
    'Oscar',
    'Patrick',
    'Reuben',
    'Sebastian',
    'Theo',
    'Vincent',
    'Wesley',
    'Adam',
    'Bruno',
    'Cole',
    'Dominic',
    'Ezra',
    'Felix',
    'Gabriel',
    'Hugo',
    'Ivan',
  ];

  static const _clubWordsEn = [
    'Ashfield',
    'Blackmoor',
    'Cliffton',
    'Dunhill',
    'Eastgate',
    'Fernvale',
    'Greystone',
    'Harborough',
    'Ironbridge',
    'Kingsmead',
    'Larkfield',
    'Millbrook',
    'Northgate',
    'Oakhaven',
    'Ravenswood',
  ];

  static const _clubSuffixesEn = ['FC', 'SC', 'United', 'Athletic', 'City'];

  static const Map<LeagueTheme, List<String>> _themedWordsEn = {
    LeagueTheme.england: [
      'Red Lion',
      'Crown',
      'Mistyhill',
      'Riverside',
      'Old Castle',
      'Holy Wood',
      'Ironbridge',
      'Northwind',
    ],
    LeagueTheme.spain: [
      'Sol',
      'Oro',
      'Viento Sur',
      'Toro',
      'Olivar',
      'Azul',
      'Alcazar',
      'Rosa',
    ],
    LeagueTheme.germany: [
      'Eisen',
      'Schwarzwald',
      'Nord',
      'Industrie',
      'Adlerberg',
      'Grau',
      'Grossstrom',
      'Stahl',
    ],
    LeagueTheme.italy: [
      'Citta Antica',
      'Laguna',
      'Violetto',
      'Montagna',
      'Costa del Sole',
      'Marmo',
      'Falco',
      'Leone Nero',
    ],
    LeagueTheme.france: [
      'Rose Bleue',
      'Phare',
      'Midi',
      'Gloire',
      'Fauve',
      'Clocher',
      'Vignoble',
      'Moulin',
    ],
  };

  static const Map<LeagueTheme, List<String>> _themedSuffixesEn = {
    LeagueTheme.england: [
      'United',
      'City',
      'Athletic',
      'Rovers',
      'Wanderers',
      'Town',
    ],
    LeagueTheme.spain: ['Real', 'Atletico', 'Deportivo', 'CF', 'Union'],
    LeagueTheme.germany: ['SV', 'FC', 'Borussia', 'Union', 'Adler'],
    LeagueTheme.italy: ['Inter', 'AC', 'Calcio', 'Reale', 'Sportiva'],
    LeagueTheme.france: ['Olympique', 'AS', 'FC', 'Racing', 'Stade'],
  };

  // 表示言語に応じてどちらのプールを使うかを選ぶ。
  static List<String> get _surnamePool =>
      Tr.isEnglish ? _surnamesEn : _surnames;
  static List<String> get _givenNamePool =>
      Tr.isEnglish ? _givenNamesEn : _givenNames;
  static List<String> get _clubWordPool =>
      Tr.isEnglish ? _clubWordsEn : _clubWords;
  static List<String> get _clubSuffixPool =>
      Tr.isEnglish ? _clubSuffixesEn : _clubSuffixes;
  static List<String> _themedWordPool(LeagueTheme t) =>
      (Tr.isEnglish ? _themedWordsEn : _themedWords)[t]!;
  static List<String> _themedSuffixPool(LeagueTheme t) =>
      (Tr.isEnglish ? _themedSuffixesEn : _themedSuffixes)[t]!;

  /// 語と接尾辞のつなぎ方。日本語は「蒼海FC」と続けるが、英語は
  /// 「Ashfield United」のように空白で区切らないと読めない。
  static String _joinClubName(String word, String suffix) =>
      Tr.isEnglish ? '$word $suffix' : '$word$suffix';

  /// 英語のクラブ名で、語より前に置くべき語。
  ///
  /// 日本語版は「太陽レアル」のように後ろへ付けても読めるが、英語では
  /// Real Madrid / AC Milan / Olympique Lyonnais のように前に来るのが自然で、
  /// 「Sol Real」と並べると誰も知らない語順になってしまう。
  static const _englishClubPrefixes = {
    'Real',
    'Atletico',
    'Deportivo',
    'Union',
    'SV',
    'FC',
    'Borussia',
    'Adler',
    'Inter',
    'AC',
    'Olympique',
    'AS',
    'Racing',
    'Stade',
  };

  /// テーマ付きクラブ名の連結。英語のときだけ前置・後置を語ごとに選ぶ。
  static String _joinThemedClubName(String word, String token) {
    if (!Tr.isEnglish) return '$word$token';
    return _englishClubPrefixes.contains(token)
        ? '$token $word'
        : '$word $token';
  }

  static String randomPlayerName({Set<String>? avoid}) {
    String pick() {
      final surnames = _surnamePool;
      final givens = _givenNamePool;
      final s = surnames[_rng.nextInt(surnames.length)];
      final g = givens[_rng.nextInt(givens.length)];
      // 日本語は姓→名、英語は名→姓。順序を揃えてしまうと、どちらかの言語で
      // 「Whitfield Dominic」のような不自然な並びになる。
      return Tr.isEnglish ? '$g $s' : '$s $g';
    }

    if (avoid == null || avoid.isEmpty) return pick();
    // 同じスカッド内に同姓同名が並ぶと、スタメン編成や交代で誰を選んで
    // いるのか分からなくなる。姓名の組合せは十分に多いので、数回引き直せば
    // ほぼ確実に衝突を避けられる(それでも駄目なら諦めて返す)。
    for (var attempt = 0; attempt < 12; attempt++) {
      final name = pick();
      if (!avoid.contains(name)) return name;
    }
    return pick();
  }

  static List<String> clubNames(int count) {
    final combos = <String>{};
    while (combos.length < count) {
      final words = _clubWordPool;
      final suffixes = _clubSuffixPool;
      final w = words[_rng.nextInt(words.length)];
      final suf = suffixes[_rng.nextInt(suffixes.length)];
      combos.add(_joinClubName(w, suf));
    }
    return combos.toList();
  }

  /// 指定したリーグテーマの雰囲気に合わせたクラブ名を[count]件、重複なく生成する。
  static List<String> themedClubNames(LeagueTheme theme, int count) {
    final words = _themedWordPool(theme);
    final suffixes = _themedSuffixPool(theme);
    final combos = <String>{};
    var guard = 0;
    final maxAttempts = count * 50;
    while (combos.length < count && guard < maxAttempts) {
      final w = words[_rng.nextInt(words.length)];
      final suf = suffixes[_rng.nextInt(suffixes.length)];
      combos.add(_joinThemedClubName(w, suf));
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
          combos.add('${_joinThemedClubName(w, suf)} $n');
        }
        if (combos.length >= count) break;
      }
      n++;
    }
    return combos.take(count).toList();
  }
}
