import 'package:flutter/material.dart';

import '../models/player.dart';
import '../l10n/tr.dart';

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
/// 個性のある残りの全種類のみを紹介する(一覧は実際のenumから生成する
/// ため、ロールが増減してもこのガイドは自動的に追随する)。
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
        GuideTopic(
          title: '${t.label}(${t.category.label})',
          description: t.description,
        ),
    ];

/// 選手の成長タイプを説明するトピック一覧。
List<GuideTopic> _growthTypeTopics() => [
      for (final g in PlayerGrowthType.values)
        GuideTopic(title: g.label, description: g.description),
    ];

// final ではなくゲッター。final だと最初のアクセス時にガイド全文が
// 組み立てられ、そのときの言語で固定されてしまう。
List<GuideSection> get guideSections => [
      GuideSection(
        icon: Icons.home,
        title: Tr.pick('ホーム画面', 'Home'),
        overview: Tr.pick(
            'クラブの現状をひと目で確認できるダッシュボード。次の試合・理事会目標・資金繰りなど、毎週まず最初に見るべき情報がまとまっている。',
            "The dashboard for where the club stands. The next match, the board's target, the state of the finances — everything worth checking first each week."),
        topics: [
          GuideTopic(
            title: Tr.pick('理事会の目標順位', "The board's target"),
            description: Tr.pick(
                'シーズン開始時に理事会から示される目標順位。これを下回る成績が続くと監督への信頼度が下がり、0になると解任される。ホーム画面の順位表示と見比べて、順位が目標に届いているか確認する。',
                'The finishing position the board asks for at the start of the season. Sitting below it for long costs you their confidence, and at zero you are sacked. Check it against the position shown on the home screen.'),
          ),
          GuideTopic(
            title: Tr.pick('通知バッジ', 'Notification badges'),
            description: Tr.pick(
                '各タブのアイコンに付くバッジは、その画面で確認すべき新しい出来事(移籍オファー・契約満了間近・負傷の回復など)がある合図。バッジが消えるまで一度は該当画面を開いて確認するとよい。',
                'A badge on a tab means something there needs your attention: a transfer offer, a contract running down, a player back from injury. Open the screen once and the badge clears.'),
          ),
          GuideTopic(
            title: Tr.pick('スーパーカップ', 'Super Cup'),
            description: Tr.pick(
                'リーグ優勝クラブとカップ優勝クラブが対戦する単発の一戦。開催条件を満たすとホーム画面に専用カードが表示される。',
                'A single match between the league champions and the cup winners. When it is on, a card for it appears on the home screen.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.groups,
        title: Tr.pick('スカッド・選手詳細画面', 'Squad and player pages'),
        overview: Tr.pick(
            '保有選手の一覧と、選手1人ごとの詳細なステータス・契約・個性を確認する画面。誰をスタメンに据えるか、誰を鍛えるか、誰を放出するかを判断する材料がここに集まっている。',
            "Your full squad, and each player's attributes, contract and character. Everything you need to decide who starts, who you develop and who you let go."),
        topics: [
          GuideTopic(
            title: Tr.pick('総合力・潜在能力', 'Overall and potential'),
            description: Tr.pick(
                '総合力は現在の実力を1つの数値にまとめたもの。潜在能力は将来到達しうる総合力の上限で、若い選手ほど潜在能力との差(伸びしろ)が大きい傾向にある。',
                'Overall is one number for how good he is now. Potential is the ceiling he could reach, and younger players tend to have more room between the two.'),
          ),
          GuideTopic(
            title: Tr.pick('性格(パーソナリティ)', 'Personality'),
            description: Tr.pick('選手の気質。不満度の変動しやすさや移籍希望の出やすさに影響する。以下の20種類がある。',
                'His temperament. It governs how easily he becomes unsettled and how readily he asks to leave. There are twenty in all.'),
          ),
          ..._personalityTopics(),
          GuideTopic(
            title: Tr.pick('デューティ(攻守の重心)', 'Duty'),
            description: Tr.pick('スタメン・戦術画面で選手ごとに設定する、攻撃/守備どちらに比重を置くかの指定。',
                'Set per player on the tactics screen: whether he leans towards attacking or defending.'),
          ),
          ..._dutyTopics(),
          GuideTopic(
            title: Tr.pick('ロール(プレースタイル)', 'Role'),
            description: Tr.pick(
                'どの能力値を活かしたプレーを得意とするかという設定。ロールが重視する能力値が高い選手に割り当てるとボーナスが、低い選手に割り当てるとペナルティが付くため、選手の得意な能力に合わせて選ぶ。',
                'What kind of player he is asked to be. Give a role to someone strong in the attributes it values and he gains; give it to someone weak in them and he suffers. Pick it to match his strengths.'),
          ),
          ..._roleTopics(),
          GuideTopic(
            title: Tr.pick('特性', 'Traits'),
            description: Tr.pick(
                '性格(パーソナリティ)とは別に、試合の相手や当日の調子によってパフォーマンスが変わる選手固有の個性。持たない選手も多く、能力値が近い選手同士でも試合結果に差が生まれる要因になる。習得経路によって3つに分類される。\n・技術: 特定の能力値と結びついており、トレーニング画面の「技術特訓」で狙って練習できる。\n・性格: 対戦相手や状況への向き合い方などメンタル面の資質。練習では身につかず、メンター(チームメイト)や監督の個別声かけを通じて「性格の指導」で育っていく。\n・才能: 天候・年齢・調子の波など生まれ持った資質。特訓や指導では後天的に習得できず、ユース昇格やスカウトで加入した時点で持っているかどうかが決まる。',
                'Separate from personality: quirks that change how a player performs depending on the opponent and how the day is going. Plenty of players have none, and they are a reason two players with similar attributes can produce different results. They come in three kinds, by how they are acquired.\n• Technical: tied to specific attributes, and trainable on purpose through trait training.\n• Personality: mental qualities, such as how he approaches an opponent or a situation. These cannot be trained; they grow through a mentor among his team-mates, or through your own personality coaching.\n• Natural: innate things like weather, age and streakiness. These cannot be acquired at all — whether he has one is settled when he comes through the academy or is scouted.'),
          ),
          ..._traitTopics(),
          GuideTopic(
            title: Tr.pick('成長タイプ', 'Growth type'),
            description: Tr.pick(
                '年齢による伸びやすさ・衰え始める時期の傾向。標準タイプの選手は選手詳細画面では表示されず、以下の2種類が該当する場合のみ表示される。',
                'How his development runs with age, and when the decline starts. Standard is not shown on his page; only the two below appear.'),
          ),
          ..._growthTypeTopics(),
          GuideTopic(
            title: Tr.pick('才能開花(ブレイクスルー)', 'Breakthroughs'),
            description: Tr.pick(
                '週次トレーニングの際、まれに複数の能力値が一気に伸びる特別な瞬間が起きることがある。発生した週はトレーニング結果ダイアログと選手詳細画面に「★ 才能開花」と表示される。闘志(determination)が高い選手や、成長タイプの伸び盛りの年齢に該当する選手ほど起きやすい。',
                "Now and then a weekly session produces a moment where several attributes jump at once. In that week the training report and the player's page both show a breakthrough. It happens more often to players with high determination, and to those at the age their growth type favours."),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.sports_soccer,
        title: Tr.pick('スタメン・戦術画面', 'Tactics screen'),
        overview: Tr.pick(
            'フォーメーションと先発11人、控えの並び順(デプスチャート)、そしてチーム全体の戦術方針を設定する画面。',
            'Where you set the formation and the starting eleven, order the backups on the depth chart, and choose how the side plays.'),
        topics: [
          GuideTopic(
            title: Tr.pick('フォーメーション・ドラッグ配置', 'Formation and drag to place'),
            description: Tr.pick(
                'フォーメーションを選ぶとピッチ上に各ポジションの枠が表示される。選手をドラッグして枠に配置することでスタメンを組める。',
                'Choose a formation and the slots appear on the pitch. Drag players into them to build your eleven.'),
          ),
          GuideTopic(
            title: Tr.pick('デプスチャート', 'Depth chart'),
            description: Tr.pick(
                '同じポジションを兼ねられる選手の優先順位。上位の選手が出場できない場合に、次に誰をそのポジションで起用するかの控え順を手動で並び替えられる。',
                'The pecking order for each position. When the man above cannot play, this is who steps in, and you can reorder it by hand.'),
          ),
          GuideTopic(
            title: Tr.pick(
                'プレッシング・ラインの高さ・攻撃の幅・テンポ', 'Pressing, line, width and tempo'),
            description: Tr.pick(
                'いずれも0-100のスライダーで設定するチーム全体の方針。プレッシングは寄せの強度、ラインの高さは守備ラインの位置、攻撃の幅はサイド展開の広さ、テンポはプレー速度を表す。攻撃的な値ほど攻撃力にプラスに働く一方、疲労やリスクとのトレードオフがある。',
                'Four sliders from 0 to 100 that set how the side plays: how hard you close down, how high the back line sits, how wide you go, and how quickly you play. More aggressive settings add attacking threat, at the cost of fatigue and risk.'),
          ),
          GuideTopic(
            title:
                Tr.pick('マンマーク・セットプレー担当', 'Man-marking and set piece duties'),
            description: Tr.pick(
                'マンマークは相手のキープレイヤーを専任で抑える指示。セットプレー担当は自チームのコーナー・フリーキック(攻撃)や、相手のセットプレーを守る役割(守備)を選手に割り当てる設定。',
                'Man-marking puts one of your players on their danger man. Set piece duties decide who takes your corners and free kicks, and who leads the defending of theirs.'),
          ),
          GuideTopic(
            title: Tr.pick('スカウティングレポート(試合プレビュー)', 'Scout report'),
            description: Tr.pick(
                '次の対戦相手の戦力・キープレイヤー・直近のフォームをまとめた事前情報。ここで判明したキープレイヤーにマンマークを付けるなど、試合前の戦術判断の材料になる。',
                'What you know about the next opponent: their strength, their key player and their recent form. Use it to prepare, for instance by putting a man-marker on the player it names.'),
          ),
          GuideTopic(
            title: Tr.pick('逃げ切りモード', 'Seeing out the game'),
            description: Tr.pick(
                '有効にすると攻撃力がやや下がる代わりに守備が安定し、疲労の蓄積も抑えられる。リードした終盤の時間の使い方として使う。',
                'Trades a little attacking threat for a steadier defence and less fatigue. What you turn on to protect a lead late.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.live_tv,
        title: Tr.pick('ライブ観戦(自クラブの試合)', 'Watching your matches live'),
        overview: Tr.pick(
            '自クラブの試合を「観戦して進める」と、要所要所で監督としての判断を求められる。リーグ戦だけでなく、国内カップ・大陸カップ・スーパーカップもライブで戦える(従来どおり結果だけを確定させるクイック消化も選べる)。',
            'Watch a match rather than simming it and you are asked to manage it at the key moments. It works for league matches and for the domestic cup, the continental cup and the Super Cup alike. Simming for the result alone is always available too.'),
        topics: [
          GuideTopic(
            title: Tr.pick('決定機の判断(攻撃側)', 'Big chances: attacking'),
            description: Tr.pick(
                '自クラブに決定機が訪れると試合が一時停止し、シュート/味方へのパス/ロングシュートを選べる。それぞれの成功率は関わる選手の能力値(シューターと相手GKの勝負など)から算出され、選択前に表示される。',
                'When a chance falls to you the match pauses and you choose: shoot, square it, or try one from distance. The odds on each come from the attributes of the players involved — the shooter against their keeper, say — and are shown before you decide.'),
          ),
          GuideTopic(
            title: Tr.pick('決定機の判断(守備側)', 'Big chances: defending'),
            description: Tr.pick(
                '相手の決定機では「積極的にタックル」か「カバーリングに専念」かを選ぶ。タックルは相手の成功率を大きく下げられるが、警告・退場のリスクを伴う。',
                'When they get in, you choose to go in hard or hold your shape. Going in hard cuts their chances sharply, but risks a card.'),
          ),
          GuideTopic(
            title: Tr.pick('采配方針(試合中の指示)', 'In-match approach'),
            description: Tr.pick(
                '通常/リスクを取る/安全に下がるの3方針を試合中いつでも切り替えられる。以降の決定機の成功率に、攻守それぞれへ方針に応じた補正がかかる。',
                'Normal, take risks, or sit back — switchable at any point. It shifts the odds on the chances that follow, at both ends.'),
          ),
          GuideTopic(
            title: Tr.pick('ライブ交代', 'Live substitutions'),
            description: Tr.pick(
                'ハーフタイムを待たず、決定機の合間に交代枠を使って選手を入れ替えられる。目前の決定機に関わっている選手は、その決定機が解決するまで交代できない。',
                'Change a player between chances rather than waiting for the break. Anyone caught up in the chance in front of you has to see it out first.'),
          ),
          GuideTopic(
            title: Tr.pick('モメンタム(試合の流れ)', 'Momentum'),
            description: Tr.pick(
                'スコアの下に表示される綱引きバー。ゴールなどで勢いづいた側に傾き、傾いている間はその側の決定機がわずかに決まりやすくなる。',
                'The tug-of-war bar under the scoreline. It swings towards whoever has just had a moment, and while it leans their way their chances go in a little more often.'),
          ),
          GuideTopic(
            title: Tr.pick('カップ戦のライブとPK戦', 'Cup ties and shootouts'),
            description: Tr.pick(
                'カップ戦をライブで戦って引き分けた場合はPK戦で決着し、フルタイム画面に結果が表示される。ライブでもクイック消化でも、疲労・負傷・警告累積・出場記録などの試合後効果は同じように適用される。',
                'A cup tie watched live and level at the end goes to penalties, with the result shown on the full-time screen. Live or simmed, everything that follows a match — fatigue, injuries, cards, appearances — applies the same.'),
          ),
          GuideTopic(
            title: Tr.pick('天候', 'Weather'),
            description: Tr.pick(
                '試合当日の天候(晴れ/雨/強風/猛暑/雪)。悪天候ほど攻撃力とチャンスの数が下がり、雨は守備側がやや優位、猛暑は疲労が溜まりやすいなど展開が変わる。雨男・雪国育ちなど特定の天候で輝く選手特性を持つ選手は、天気予報に合わせた起用が有効になる。',
                'What the day brings: clear, rain, wind, a heatwave or snow. The worse it is, the less attacking threat and the fewer chances. Rain slightly favours defending and heat tires players faster. Some players carry traits that make them shine in particular conditions, so it is worth picking with the forecast in mind.'),
          ),
          GuideTopic(
            title: Tr.pick('記者会見', 'Press conference'),
            description: Tr.pick(
                '試合後に記者の質問へ答えるイベント。回答の選択によってチームの士気が上下するため、試合結果に合ったコメントを選ぶこともマネジメントの一部になる。',
                "Facing the press after a match. What you say moves the squad's morale, so picking a line that fits the result is part of the job."),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.fitness_center,
        title: Tr.pick('トレーニング画面', 'Training screen'),
        overview: Tr.pick(
            '選手の成長を促す週次の練習を管理する画面。方針・強度・個別の特訓を組み合わせて、チームや個々の選手を鍛える。',
            'Where you run the weekly session. Combine a focus, an intensity and individual drills to develop the squad and the players in it.'),
        topics: [
          GuideTopic(
            title: Tr.pick('トレーニング方針', 'Training focus'),
            description: Tr.pick(
                'チーム全体、または選手個別に設定する練習の重点分野。設定した分野に関連する能力値が伸びやすくなる。既定は「全体練習」で、ポジションに応じて攻守をバランス良く伸ばす。攻撃強化・守備強化・体力強化はその分野に特化する代わりに伸びが速く、「休養」は疲労を大きく回復する代わりに能力値が伸びない。',
                'What the session concentrates on, set for the whole squad or per player. Attributes tied to that area improve faster. The default is general training, which develops attack and defence evenly by position. Attacking, defending and fitness each specialise and move faster within their area, while rest recovers a lot of fatigue but grows nothing.'),
          ),
          GuideTopic(
            title: Tr.pick('特訓ドリル', 'Focus drills'),
            description: Tr.pick(
                'チーム/個別の方針とは別に、狙った能力値を集中的に伸ばす個別設定。1人あたり2つまで指定でき、同時に指定できる人数にはヘッドコーチのレベルに応じた上限がある。',
                "Separate from the squad and individual focus, this drives one specific attribute hard. Up to two per player, with a cap on how many players at once that rises with your head coach's level."),
          ),
          GuideTopic(
            title: Tr.pick('メンター制度', 'Mentoring'),
            description: Tr.pick(
                '若手選手に28歳以上のベテランを指導役として付ける制度。メンティー(教わる側)の成長率にボーナスが付き、メンター自身も指導のやりがいから士気が少し上がる。',
                "Pairing a young player with someone 28 or over. The younger man grows faster, and the mentor's own morale lifts a little from the responsibility."),
          ),
          GuideTopic(
            title: Tr.pick('練習強度', 'Training intensity'),
            description: Tr.pick(
                '軽め/通常/追い込みの3段階。強くするほど成長速度が上がる代わりに、疲労の蓄積と練習中の怪我リスクが増す。',
                'Light, normal or intense. Harder means faster growth, at the cost of more fatigue and more injuries on the training ground.'),
          ),
          GuideTopic(
            title: Tr.pick('ポジションコンバート特訓', 'Position retraining'),
            description: Tr.pick(
                '本職ではないポジションへの転向を目指す特訓。目標ポジションを明示的に指定することで、そのポジションの適性・慣れを重点的に高められる。',
                'Working a player towards a position that is not his own. Name the target position and his familiarity with it climbs faster.'),
          ),
          GuideTopic(
            title: Tr.pick('育成プラン(目標ロール)', 'Development plans'),
            description: Tr.pick(
                '選手ごとに目標とするロール(プレースタイル)を設定すると、週次トレーニングでそのロールが重視する能力値が優先的に伸びる。ポジションの大分類に合うロールのみ設定できる。',
                'Set a target role for a player and weekly training favours the attributes that role values. Only roles that suit his position group are available.'),
          ),
          GuideTopic(
            title: Tr.pick('ローテーション方針', 'Rotating focuses'),
            description: Tr.pick(
                '選手個別のトレーニング方針を複数登録しておくと、週替わりで自動的に切り替わる。攻撃と守備を交互に鍛えるなど、毎週手動で切り替えなくてもバランス良く育成できる。',
                'Queue up several focuses for a player and he cycles through them week by week — alternating attack and defence, say — without you changing it by hand.'),
          ),
          GuideTopic(
            title: Tr.pick('個別声かけ・話し合い', 'Quiet words and talks'),
            description: Tr.pick(
                '個別声かけ(モチベーショントーク)は選手の士気を高め、話し合いは不満度を和らげる監督コマンド。効果は選手の性格による感応度で変わり、どちらも同じ選手には数週間のクールダウンがある。',
                "A quiet word lifts a player's morale; a talk eases his unhappiness. How far either moves depends on his personality, and both have a cooldown of a few weeks per player."),
          ),
          GuideTopic(
            title: Tr.pick('戦術ミーティング', 'Tactical meetings'),
            description: Tr.pick(
                'チーム全体の戦術理解を深め、判断力・ポジショニング・チームワークといったメンタル系能力値をわずかに伸ばす。連発はできず、数週間のクールダウンがある。',
                'Working through the tactics with the squad, improving decisions, positioning and teamwork a little. There is a cooldown of a few weeks.'),
          ),
          GuideTopic(
            title: Tr.pick('自動トレーニング', 'Automatic training'),
            description: Tr.pick(
                '有効にすると、節を進めた際に週次トレーニングが自動で実施される。細かく管理したい週だけ無効に戻して手動で行うこともできる。',
                'With this on, the weekly session runs itself as you play through the matchdays. Turn it off for any week you want to handle yourself.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.swap_horiz,
        title: Tr.pick('移籍市場画面', 'Transfer screen'),
        overview: Tr.pick(
            '他クラブの選手を獲得したり、自クラブの選手を放出したりする画面。交渉の駆け引きやローン移籍など、実際の移籍市場に近い要素を扱う。',
            'Where you sign players and move them on, with haggling, loans and the rest of what a real market involves.'),
        topics: [
          GuideTopic(
            title: Tr.pick('想定移籍金', 'Estimated fee'),
            description: Tr.pick('年齢・現在の総合力・伸びしろから概算した市場価値。交渉時のオファー額の目安になる。',
                'A rough valuation from his age, current overall and room to grow. The yardstick for what a bid should look like.'),
          ),
          GuideTopic(
            title: Tr.pick('リリース条項', 'Release clauses'),
            description: Tr.pick('設定されている場合、他クラブがこの金額を提示すると交渉なしで自動的に移籍が成立する。',
                'Where one is set, any club offering that amount takes him with no negotiation at all.'),
          ),
          GuideTopic(
            title: Tr.pick('ローン(期限付き移籍)', 'Loans'),
            description: Tr.pick(
                '一定期間だけ選手を貸し出す/借り受ける制度。ローン中の週俸は貸出先が負担し、期間満了で自動的に元クラブへ復帰する。買取オプション付きなら期間中に完全移籍へ切り替えられる。',
                'Sending a player elsewhere, or taking one in, for a fixed spell. The receiving club pays his wages, and he returns automatically when it ends. With an option to buy, it can be made permanent at any point.'),
          ),
          GuideTopic(
            title: Tr.pick('移籍リスト登録', 'Transfer listing'),
            description: Tr.pick('登録すると他クラブからの獲得オファーが届きやすくなる。放出したい選手に活用できる。',
                'Listing a player makes offers from other clubs arrive more often. Useful for anyone you want off the books.'),
          ),
          GuideTopic(
            title: Tr.pick('移籍ウィンドウ', 'Transfer window'),
            description: Tr.pick('移籍市場が開いている期間。ウィンドウが閉じている間は新規の移籍交渉ができない。',
                'The period the market is open. While it is shut you cannot open new negotiations.'),
          ),
          GuideTopic(
            title: Tr.pick('市場の入れ替わり(持続的な移籍市場)', 'How the market turns over'),
            description: Tr.pick(
                '移籍市場の顔ぶれは毎週数人だけが入れ替わる。狙っていた選手は翌週以降も追えるが、いつまでも市場に残っているとは限らない。',
                'Only a handful of names change each week. A target will usually still be there next week, though not forever.'),
          ),
          GuideTopic(
            title: Tr.pick('値切り交渉', 'Haggling'),
            description: Tr.pick(
                '想定移籍金より安い提示額で獲得を試みる交渉。提示額の割合が高いほど成立しやすく、55%以下では必ず決裂する。決裂した選手とはその週は再交渉できない。',
                "Bidding below a player's valuation. The closer to the asking price, the likelier it is accepted; at 55% or under it always fails, and once talks break down you cannot go back to him that week."),
          ),
          GuideTopic(
            title: Tr.pick('放出選手の行き先', 'Where sold players go'),
            description: Tr.pick(
                '放出した選手は消えるのではなく、リーグ内の他クラブへ実際に移籍して対戦相手として再会することがある。',
                'A player you sell does not vanish. He joins another club in the league, and you may well face him.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.emoji_people,
        title: Tr.pick('ユース・スカウト画面', 'Youth and scouting screen'),
        overview: Tr.pick(
            '将来性のある若手選手を獲得するための画面。スカウトによる個別発掘と、シーズンごとのユースインテークの両方を扱う。',
            'Where you bring young players in, both by scouting them individually and through the yearly academy intake.'),
        topics: [
          GuideTopic(
            title: Tr.pick('スカウト候補', 'Scouted prospects'),
            description: Tr.pick(
                'スカウトに費用を払って探してもらう若手選手の候補。スタッフの「スカウト」レベルが高いほど、一度に提示される候補の人数が増える。',
                "Young players your scouts find, for a fee. The higher your scout's level, the more names come back at once."),
          ),
          GuideTopic(
            title: Tr.pick('ユースインテーク', 'Youth intake'),
            description: Tr.pick(
                'シーズンの節目に自クラブの下部組織から一括で入団してくる若手選手たち。まとめて確認し、昇格させたい選手を選抜する。',
                'The group that comes up from your own academy at a set point in the season. Look them over and choose who you take on.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.account_balance,
        title: Tr.pick('クラブ経営(ファイナンス)画面', 'Finances screen'),
        overview: Tr.pick(
            'クラブの資金繰りを管理する画面。収入(観客動員・スポンサー)と支出(週俸・ローン返済)を見ながら、融資や投資の判断を行う。',
            'Where you manage the money. Weigh what comes in from the gate and sponsors against wages and loan repayments, and decide whether to borrow or invest.'),
        topics: [
          GuideTopic(
            title: Tr.pick('銀行ローン', 'Bank loans'),
            description: Tr.pick('資金が不足した際に借り入れられる融資。借りた分は利息付きで分割返済していく必要がある。',
                'Money you can borrow when funds run short, repaid in instalments with interest.'),
          ),
          GuideTopic(
            title: Tr.pick('定期預金・資金運用', 'Fixed deposits'),
            description: Tr.pick(
                '余剰資金を一定期間預けて増やす仕組み。すぐには引き出せない代わりに、置いておくだけの資金より効率よく増やせる。',
                'Putting spare money away for a fixed spell. You cannot touch it until it matures, but it grows faster than money sitting idle.'),
          ),
          GuideTopic(
            title: Tr.pick('スポンサー契約', 'Sponsorship'),
            description: Tr.pick(
                '年単位で結ぶ契約で、契約期間中は毎週安定した収入が得られる。契約満了が近づくと更新や新規オファーの検討が必要になる。',
                'A deal measured in years that pays steadily every week. As it runs down you need to think about renewing or taking a new offer.'),
          ),
          GuideTopic(
            title: Tr.pick('財政破綻ペナルティ', 'Running out of money'),
            description: Tr.pick('資金がマイナスの状態が長期間続くと、理事会からの信頼度低下などのペナルティが課される。',
                "Stay in the red long enough and there are consequences, starting with the board's confidence in you."),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.apartment,
        title: Tr.pick('施設・スタッフ画面', 'Facilities and staff screen'),
        overview: Tr.pick(
            'クラブの設備とスタッフを強化する画面。ここへの投資は選手の成長・怪我のしにくさ・収入に長期的な効果をもたらす。',
            'Where you upgrade the club itself. What you spend here pays back over time in player development, fewer injuries and more income.'),
        topics: [
          GuideTopic(
              title: Tr.pick('トレーニング施設', 'Training facilities'),
              description: Tr.pick('レベルが高いほど選手の成長速度にボーナスが付く。',
                  'Higher levels speed up how quickly players improve.')),
          GuideTopic(
              title: Tr.pick('スタジアム', 'Stadium'),
              description: Tr.pick('レベルが高いほど収容人数が増え、観客動員による収入が伸びる。',
                  'Higher levels mean more seats, and more money through the gate.')),
          GuideTopic(
            title: Tr.pick('ユース施設', 'Youth facilities'),
            description: Tr.pick('レベルが高いほどユースインテークで入ってくる選手の質(潜在能力)が上がりやすくなる。',
                'Higher levels raise the quality — the potential — of the players your academy produces.'),
          ),
          GuideTopic(
            title: Tr.pick('商業施設', 'Commercial facilities'),
            description: Tr.pick('レベルに応じて観客収入とスポンサー収入の両方をまとめて底上げする。',
                'Lifts both gate receipts and sponsorship income together, by level.'),
          ),
          GuideTopic(
            title: Tr.pick('スタッフ(スカウト等)', 'Staff'),
            description: Tr.pick('スタッフのレベルはそれぞれの担当領域(スカウトなら候補選手の発掘力など)に影響する。',
                'Each member of staff affects their own area — your scout, for instance, decides what your scouting turns up.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.emoji_events,
        title: Tr.pick('日程・カップ戦・カレンダー画面', 'Fixtures, cups and calendar'),
        overview: Tr.pick('リーグ戦の日程と順位表、国内・大陸カップ戦の進行、そして週ごとの予定を確認する画面群。',
            'The league fixtures and table, how the cups are progressing, and what each week holds.'),
        topics: [
          GuideTopic(
            title: Tr.pick('順位表と昇格・降格', 'The table, promotion and relegation'),
            description: Tr.pick(
                '自クラブの所属ディビジョン以外の順位表も閲覧できる。上位陣は自動昇格または昇格プレーオフ進出、下位陣は降格の対象になる。',
                'You can look at the table for any division, not just your own. The top go up automatically or into the play-offs; the bottom go down.'),
          ),
          GuideTopic(
            title: Tr.pick('昇格プレーオフ', 'Promotion play-offs'),
            description: Tr.pick(
                '自動昇格枠を逃した中位クラブ同士で行われる、上位ディビジョンへの最後の昇格枠を懸けたノックアウト方式のトーナメント。',
                'A knockout between the clubs that just missed automatic promotion, for the last place in the division above.'),
          ),
          GuideTopic(
            title: Tr.pick('国内カップ・大陸カップ', 'Domestic and continental cups'),
            description: Tr.pick(
                '国内カップは同ディビジョン内外を問わないノックアウト方式。大陸カップは上位成績クラブのみが参加し、グループステージの後にノックアウトで優勝を争う。自クラブの試合はライブ観戦でもクイック消化でも進められる。',
                'The domestic cup is a straight knockout, open across divisions. The continental cup takes only the clubs that finished high enough, with a group stage before the knockout rounds. Your own ties can be watched live or simmed.'),
          ),
          GuideTopic(
            title: Tr.pick('勝ち上がり賞金', 'Progression prize money'),
            description: Tr.pick(
                'カップ戦は1勝(1タイ勝ち抜け)ごとに賞金が入り、ラウンドが深いほど高額になる。優勝時はさらに大きな優勝ボーナスが加わるため、カップ戦を勝ち進むこと自体が重要な収入源になる。',
                'Every cup tie you win pays, and the deeper the round the more it is worth. Winning the thing adds a much larger bonus on top, which makes a cup run a serious source of income in itself.'),
          ),
          GuideTopic(
            title: Tr.pick('カレンダー', 'Calendar'),
            description: Tr.pick(
                'リーグ戦・カップ戦の実際の日付と、週の重点トレーニング日を一覧できる。試合が詰まる週の見通しを立てるのに使う。',
                'The actual dates of league and cup matches, plus your main training day each week. Use it to see a congested run coming.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.workspace_premium,
        title:
            Tr.pick('シーズン成績・実績・監督キャリア画面', 'Records, achievements and career'),
        overview: Tr.pick(
            '過去の記録を振り返るための画面群。うまくいった/いかなかったシーズンを見返し、次のシーズンの方針決めに活かす。',
            'Where you look back. Review the seasons that went well and the ones that did not, and decide how to approach the next one.'),
        topics: [
          GuideTopic(
            title: Tr.pick('シーズン成績アーカイブ', 'Season archive'),
            description: Tr.pick('シーズンごとの最終順位・勝敗・昇降格・カップ優勝歴をまとめて振り返れる。',
                'Final positions, records, promotions and relegations, and cups won, season by season.'),
          ),
          GuideTopic(
            title: Tr.pick('実績(アチーブメント)', 'Achievements'),
            description: Tr.pick('タイトル獲得や通算記録など、特定の条件を満たすと解除されるやり込み要素。',
                'Unlocked by meeting particular conditions — winning things, reaching career milestones and so on.'),
          ),
          GuideTopic(
            title: Tr.pick(
                '表彰・ベストイレブン・殿堂', 'Awards, team of the season and hall of fame'),
            description: Tr.pick(
                'シーズン終了時には得点王・MVP・ゴールデングラブ(無失点王)などの個人タイトルとシーズンベストイレブンが選出される。長く活躍した選手は引退・退団後に殿堂入りとして記録に残る。',
                'At the end of each season the top scorer, player of the season and Golden Glove are decided, along with the team of the season. Players who gave you long service are remembered in the hall of fame once they retire or leave.'),
          ),
          GuideTopic(
            title:
                Tr.pick('監督への信頼度・監督としての評価', 'Board confidence and reputation'),
            description: Tr.pick(
                '信頼度は理事会からの評価で、目標順位を下回る成績が続くと下がり0で解任される。評価は世間からの監督評価で、解任・移籍後も引き継がれ、他クラブからの就任オファーの受けやすさに影響する。',
                'Confidence is what your board thinks: results below their target push it down, and at zero you are sacked. Reputation is what the wider game thinks, and unlike confidence it follows you through sackings and moves, shaping the offers you receive.'),
          ),
        ],
      ),
    ];
