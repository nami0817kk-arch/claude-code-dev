import 'package:flutter/material.dart';
import '../models/player.dart';

/// ガイド内の1トピック(見出し + 説明文)。
class GuideTopic {
  final String title;
  final String description;

  const GuideTopic({required this.title, required this.description});
}

/// ガイドの1セクション。アプリ内のある画面・機能領域に対応し、その画面が
/// 何をする場所かという概要と、そこに登場する用語・仕組みのトピック群を持つ。
/// 用語集([glossaryEntries])が用語ごとのフラットな辞書であるのに対し、
/// こちらは「どの画面で何ができるか」という視点で情報をまとめ、初めて
/// その画面を触るときに読む導入ガイドとして使う。
class GuideSection {
  final IconData icon;
  final String title;
  final String overview;
  final List<GuideTopic> topics;

  const GuideSection({
    required this.icon,
    required this.title,
    required this.overview,
    required this.topics,
  });
}

/// 選手の性格(パーソナリティ)を説明するトピック一覧。[PlayerPersonality]側の
/// label/descriptionをそのまま使うことで、実際のゲームロジックの説明と
/// ガイドの記述が食い違わないようにしている。
List<GuideTopic> _personalityTopics() => [
      for (final p in PlayerPersonality.values)
        GuideTopic(title: p.label, description: p.description),
    ];

/// 選手のプレースタイル(ロール)を説明するトピック一覧。standard(標準)は
/// 「特定のロールを指定しない」という意味しか持たないため、ガイドでは
/// 個性のある残り7種類のみを紹介する。
List<GuideTopic> _roleTopics() => [
      for (final r in PlayerRole.values)
        if (r != PlayerRole.standard)
          GuideTopic(title: r.label, description: r.description),
    ];

List<GuideTopic> _dutyTopics() => [
      for (final d in PlayerDuty.values)
        GuideTopic(title: d.label, description: d.description),
    ];

/// 選手特性を説明するトピック一覧。持たない選手も多い。
List<GuideTopic> _traitTopics() => [
      for (final t in PlayerTrait.values)
        GuideTopic(title: t.label, description: t.description),
    ];

/// 選手の成長タイプを説明するトピック一覧。
List<GuideTopic> _growthTypeTopics() => [
      for (final g in PlayerGrowthType.values)
        GuideTopic(title: g.label, description: g.description),
    ];

final List<GuideSection> guideSections = [
  const GuideSection(
    icon: Icons.home,
    title: 'ホーム画面',
    overview: 'クラブの現状をひと目で確認できるダッシュボード。次の試合・理事会目標・資金繰りなど、'
        '毎週まず最初に見るべき情報がまとまっている。',
    topics: [
      GuideTopic(
        title: '理事会の目標順位',
        description: 'シーズン開始時に理事会から示される目標順位。これを下回る成績が続くと監督への信頼度が下がり、'
            '0になると解任される。ホーム画面の順位表示と見比べて、順位が目標に届いているか確認する。',
      ),
      GuideTopic(
        title: '通知バッジ',
        description: '各タブのアイコンに付くバッジは、その画面で確認すべき新しい出来事(移籍オファー・契約満了間近・'
            '負傷の回復など)がある合図。バッジが消えるまで一度は該当画面を開いて確認するとよい。',
      ),
      GuideTopic(
        title: 'スーパーカップ',
        description: 'リーグ優勝クラブとカップ優勝クラブが対戦する単発の一戦。開催条件を満たすとホーム画面に'
            '専用カードが表示される。',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.groups,
    title: 'スカッド・選手詳細画面',
    overview: '保有選手の一覧と、選手1人ごとの詳細なステータス・契約・個性を確認する画面。誰をスタメンに'
        '据えるか、誰を鍛えるか、誰を放出するかを判断する材料がここに集まっている。',
    topics: [
      const GuideTopic(
        title: '総合力・潜在能力',
        description: '総合力は現在の実力を1つの数値にまとめたもの。潜在能力は将来到達しうる総合力の上限で、'
            '若い選手ほど潜在能力との差(伸びしろ)が大きい傾向にある。',
      ),
      const GuideTopic(
        title: '性格(パーソナリティ)',
        description: '選手の気質。不満度の変動しやすさや移籍希望の出やすさに影響する。以下の20種類がある。',
      ),
      ..._personalityTopics(),
      const GuideTopic(
        title: 'デューティ(攻守の重心)',
        description: 'スタメン・戦術画面で選手ごとに設定する、攻撃/守備どちらに比重を置くかの指定。',
      ),
      ..._dutyTopics(),
      const GuideTopic(
        title: 'ロール(プレースタイル)',
        description: 'どの能力値を活かしたプレーを得意とするかという設定。ロールが重視する能力値が高い選手に'
            '割り当てるとボーナスが、低い選手に割り当てるとペナルティが付くため、選手の得意な能力に合わせて選ぶ。',
      ),
      ..._roleTopics(),
      const GuideTopic(
        title: '特性',
        description: '性格とは別に、試合の相手や当日の調子によってパフォーマンスが変わる選手固有の個性。'
            '持たない選手も多く、能力値が近い選手同士でも試合結果に差が生まれる要因になる。',
      ),
      ..._traitTopics(),
      const GuideTopic(
        title: '成長タイプ',
        description: '年齢による伸びやすさ・衰え始める時期の傾向。標準タイプの選手は選手詳細画面では'
            '表示されず、以下の2種類が該当する場合のみ表示される。',
      ),
      ..._growthTypeTopics(),
      const GuideTopic(
        title: '才能開花(ブレイクスルー)',
        description: '週次トレーニングの際、まれに複数の能力値が一気に伸びる特別な瞬間が起きることがある。'
            '発生した週はトレーニング結果ダイアログと選手詳細画面に「★ 才能開花」と表示される。'
            '闘志(determination)が高い選手や、成長タイプの伸び盛りの年齢に該当する選手ほど起きやすい。',
      ),
    ],
  ),
  const GuideSection(
    icon: Icons.sports_soccer,
    title: 'スタメン・戦術画面',
    overview: 'フォーメーションと先発11人、控えの並び順(デプスチャート)、そしてチーム全体の戦術方針を'
        '設定する画面。',
    topics: [
      GuideTopic(
        title: 'フォーメーション・ドラッグ配置',
        description: 'フォーメーションを選ぶとピッチ上に各ポジションの枠が表示される。選手をドラッグして'
            '枠に配置することでスタメンを組める。',
      ),
      GuideTopic(
        title: 'デプスチャート',
        description: '同じポジションを兼ねられる選手の優先順位。上位の選手が出場できない場合に、次に誰を'
            'そのポジションで起用するかの控え順を手動で並び替えられる。',
      ),
      GuideTopic(
        title: 'プレッシング・ラインの高さ・攻撃の幅・テンポ',
        description: 'いずれも0-100のスライダーで設定するチーム全体の方針。プレッシングは寄せの強度、'
            'ラインの高さは守備ラインの位置、攻撃の幅はサイド展開の広さ、テンポはプレー速度を表す。'
            '攻撃的な値ほど攻撃力にプラスに働く一方、疲労やリスクとのトレードオフがある。',
      ),
      GuideTopic(
        title: 'マンマーク・セットプレー担当',
        description: 'マンマークは相手のキープレイヤーを専任で抑える指示。セットプレー担当は自チームの'
            'コーナー・フリーキック(攻撃)や、相手のセットプレーを守る役割(守備)を選手に割り当てる設定。',
      ),
      GuideTopic(
        title: '逃げ切りモード',
        description: '有効にすると攻撃力がやや下がる代わりに守備が安定し、疲労の蓄積も抑えられる。'
            'リードした終盤の時間の使い方として使う。',
      ),
    ],
  ),
  const GuideSection(
    icon: Icons.fitness_center,
    title: 'トレーニング画面',
    overview: '選手の成長を促す週次の練習を管理する画面。方針・強度・個別の特訓を組み合わせて、'
        'チームや個々の選手を鍛える。',
    topics: [
      GuideTopic(
        title: 'トレーニング方針',
        description: 'チーム全体、または選手個別に設定する練習の重点分野。設定した分野に関連する能力値が'
            '伸びやすくなる。',
      ),
      GuideTopic(
        title: '特訓ドリル',
        description: 'チーム/個別の方針とは別に、特定の1能力値だけを狙い撃ちで伸ばす個別設定。'
            '同時に指定できる人数には上限がある。',
      ),
      GuideTopic(
        title: 'メンター制度',
        description: '若手選手に28歳以上のベテランを指導役として付ける制度。メンティー(教わる側)の'
            '成長率にボーナスが付き、メンター自身も指導のやりがいから士気が少し上がる。',
      ),
      GuideTopic(
        title: '練習強度',
        description: '軽め/通常/追い込みの3段階。強くするほど成長速度が上がる代わりに、疲労の蓄積と'
            '練習中の怪我リスクが増す。',
      ),
      GuideTopic(
        title: 'ポジションコンバート特訓',
        description: '本職ではないポジションへの転向を目指す特訓。目標ポジションを明示的に指定することで、'
            'そのポジションの適性・慣れを重点的に高められる。',
      ),
    ],
  ),
  const GuideSection(
    icon: Icons.swap_horiz,
    title: '移籍市場画面',
    overview: '他クラブの選手を獲得したり、自クラブの選手を放出したりする画面。交渉の駆け引きや'
        'ローン移籍など、実際の移籍市場に近い要素を扱う。',
    topics: [
      GuideTopic(
        title: '想定移籍金',
        description: '年齢・現在の総合力・伸びしろから概算した市場価値。交渉時のオファー額の目安になる。',
      ),
      GuideTopic(
        title: 'リリース条項',
        description: '設定されている場合、他クラブがこの金額を提示すると交渉なしで自動的に移籍が成立する。',
      ),
      GuideTopic(
        title: 'ローン(期限付き移籍)',
        description: '一定期間だけ選手を貸し出す/借り受ける制度。ローン中の週俸は貸出先が負担し、期間満了で'
            '自動的に元クラブへ復帰する。買取オプション付きなら期間中に完全移籍へ切り替えられる。',
      ),
      GuideTopic(
        title: '移籍リスト登録',
        description: '登録すると他クラブからの獲得オファーが届きやすくなる。放出したい選手に活用できる。',
      ),
      GuideTopic(
        title: '移籍ウィンドウ',
        description: '移籍市場が開いている期間。ウィンドウが閉じている間は新規の移籍交渉ができない。',
      ),
    ],
  ),
  const GuideSection(
    icon: Icons.emoji_people,
    title: 'ユース・スカウト画面',
    overview: '将来性のある若手選手を獲得するための画面。スカウトによる個別発掘と、シーズンごとの'
        'ユースインテークの両方を扱う。',
    topics: [
      GuideTopic(
        title: 'スカウト候補',
        description: 'スカウトに費用を払って探してもらう若手選手の候補。スタッフの「スカウト」レベルが'
            '高いほど、一度に提示される候補の人数が増える。',
      ),
      GuideTopic(
        title: 'ユースインテーク',
        description: 'シーズンの節目に自クラブの下部組織から一括で入団してくる若手選手たち。まとめて'
            '確認し、昇格させたい選手を選抜する。',
      ),
    ],
  ),
  const GuideSection(
    icon: Icons.account_balance,
    title: 'クラブ経営(ファイナンス)画面',
    overview: 'クラブの資金繰りを管理する画面。収入(観客動員・スポンサー)と支出(週俸・ローン返済)を'
        '見ながら、融資や投資の判断を行う。',
    topics: [
      GuideTopic(
        title: '銀行ローン',
        description: '資金が不足した際に借り入れられる融資。借りた分は利息付きで分割返済していく必要がある。',
      ),
      GuideTopic(
        title: '定期預金・資金運用',
        description: '余剰資金を一定期間預けて増やす仕組み。すぐには引き出せない代わりに、置いておくだけの'
            '資金より効率よく増やせる。',
      ),
      GuideTopic(
        title: 'スポンサー契約',
        description: '年単位で結ぶ契約で、契約期間中は毎週安定した収入が得られる。契約満了が近づくと'
            '更新や新規オファーの検討が必要になる。',
      ),
      GuideTopic(
        title: '財政破綻ペナルティ',
        description: '資金がマイナスの状態が長期間続くと、理事会からの信頼度低下などのペナルティが課される。',
      ),
    ],
  ),
  const GuideSection(
    icon: Icons.apartment,
    title: '施設・スタッフ画面',
    overview: 'クラブの設備とスタッフを強化する画面。ここへの投資は選手の成長・怪我のしにくさ・'
        '収入に長期的な効果をもたらす。',
    topics: [
      GuideTopic(
        title: 'トレーニング施設',
        description: 'レベルが高いほど選手の成長速度にボーナスが付く。',
      ),
      GuideTopic(
        title: 'スタジアム',
        description: 'レベルが高いほど収容人数が増え、観客動員による収入が伸びる。',
      ),
      GuideTopic(
        title: 'ユース施設',
        description: 'レベルが高いほどユースインテークで入ってくる選手の質(潜在能力)が上がりやすくなる。',
      ),
      GuideTopic(
        title: '商業施設',
        description: 'レベルに応じて観客収入とスポンサー収入の両方をまとめて底上げする。',
      ),
      GuideTopic(
        title: 'スタッフ(スカウト等)',
        description: 'スタッフのレベルはそれぞれの担当領域(スカウトなら候補選手の発掘力など)に影響する。',
      ),
    ],
  ),
  const GuideSection(
    icon: Icons.emoji_events,
    title: '日程・カップ戦・カレンダー画面',
    overview: 'リーグ戦の日程と順位表、国内・大陸カップ戦の進行、そして週ごとの予定を確認する画面群。',
    topics: [
      GuideTopic(
        title: '順位表と昇格・降格',
        description: '自クラブの所属ディビジョン以外の順位表も閲覧できる。上位陣は自動昇格または'
            '昇格プレーオフ進出、下位陣は降格の対象になる。',
      ),
      GuideTopic(
        title: '昇格プレーオフ',
        description: '自動昇格枠を逃した中位クラブ同士で行われる、上位ディビジョンへの最後の昇格枠を'
            '懸けたノックアウト方式のトーナメント。',
      ),
      GuideTopic(
        title: '国内カップ・大陸カップ',
        description: '国内カップは同ディビジョン内外を問わないノックアウト方式。大陸カップは上位成績クラブ'
            'のみが参加し、グループステージの後にノックアウトで優勝を争う。',
      ),
      GuideTopic(
        title: 'カレンダー',
        description: 'リーグ戦・カップ戦の実際の日付と、週の重点トレーニング日を一覧できる。試合が詰まる'
            '週の見通しを立てるのに使う。',
      ),
    ],
  ),
  const GuideSection(
    icon: Icons.workspace_premium,
    title: 'シーズン成績・実績・監督キャリア画面',
    overview: '過去の記録を振り返るための画面群。うまくいった/いかなかったシーズンを見返し、'
        '次のシーズンの方針決めに活かす。',
    topics: [
      GuideTopic(
        title: 'シーズン成績アーカイブ',
        description: 'シーズンごとの最終順位・勝敗・昇降格・カップ優勝歴をまとめて振り返れる。',
      ),
      GuideTopic(
        title: '実績(アチーブメント)',
        description: 'タイトル獲得や通算記録など、特定の条件を満たすと解除されるやり込み要素。',
      ),
      GuideTopic(
        title: '監督への信頼度・監督としての評価',
        description: '信頼度は理事会からの評価で、目標順位を下回る成績が続くと下がり0で解任される。'
            '評価は世間からの監督評価で、解任・移籍後も引き継がれ、他クラブからの就任オファーの'
            '受けやすさに影響する。',
      ),
    ],
  ),
];
