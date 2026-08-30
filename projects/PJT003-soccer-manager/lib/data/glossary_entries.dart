import '../models/attributes.dart';

/// 用語集のカテゴリ。用語集画面でのグルーピング・絞り込みに用いる。
enum GlossaryCategory {
  attribute,
  composite,
  condition,
  contractTransfer,
  tactics,
  liveMatch,
  club,
}

extension GlossaryCategoryInfo on GlossaryCategory {
  String get label => switch (this) {
        GlossaryCategory.attribute => '選手能力値',
        GlossaryCategory.composite => '複合指標',
        GlossaryCategory.condition => 'コンディション・メンタル',
        GlossaryCategory.contractTransfer => '契約・移籍',
        GlossaryCategory.tactics => '戦術',
        GlossaryCategory.liveMatch => 'ライブ観戦',
        GlossaryCategory.club => 'クラブ経営',
      };
}

/// 用語集の1項目。[term]は画面上の見出し、[description]は意味・仕様の説明文。
class GlossaryEntry {
  final String term;
  final GlossaryCategory category;
  final String description;

  const GlossaryEntry({
    required this.term,
    required this.category,
    required this.description,
  });
}

const Map<String, String> _attributeDescriptions = {
  AttributeKeys.corners: 'コーナーキックの精度。コーナー担当に指名された選手の値が高いほどチャンスの質が上がる。',
  AttributeKeys.crossing: 'サイドからのクロスの正確さ。攻撃力の複合値(技術)に反映される。',
  AttributeKeys.dribbling: 'ボールを持って相手を抜く能力。攻撃力の複合値に反映される。',
  AttributeKeys.finishing: 'シュートの決定力。攻撃力の複合値で最も重みが大きい項目。',
  AttributeKeys.firstTouch: 'ボールを受けた際の落ち着き。技術の複合値に反映される。',
  AttributeKeys.freeKick: '直接フリーキックの精度。FK担当に指名された選手の値が高いほどチャンスの質が上がる。',
  AttributeKeys.heading: '空中戦での競り合い・ヘディングシュートの精度。',
  AttributeKeys.longShots: '中距離・遠距離からのシュート精度。攻撃力の複合値に反映される。',
  AttributeKeys.longThrows: 'ロングスローインの飛距離・精度。',
  AttributeKeys.marking: '相手選手を捕まえる能力。守備力の複合値で最も重みが大きい項目。',
  AttributeKeys.passing: 'パスの正確さ。技術の複合値で最も重みが大きい項目。',
  AttributeKeys.penalties: 'PKの成功率。PK担当に指名された選手の値が高いほど成功率が上がる。',
  AttributeKeys.tackling: '相手からボールを奪う能力。守備力の複合値に反映される。',
  AttributeKeys.technique: 'ボールコントロール全般の巧みさ。技術の複合値に反映される。',
  AttributeKeys.aggression: '球際やプレスでの積極性。高いほど守備力にプラスだが、警告・退場のリスクも増える。',
  AttributeKeys.anticipation: '状況を先読みする力。守備力の複合値に反映される。',
  AttributeKeys.bravery: '危険な状況でも臆さずプレーする度胸。',
  AttributeKeys.composure: 'プレッシャー下での冷静さ。高いほど攻撃力にプラスで、警告のリスクを抑える。',
  AttributeKeys.concentration: '試合を通して集中力を維持する能力。',
  AttributeKeys.decisions: '状況判断の的確さ。技術の複合値に反映される。',
  AttributeKeys.determination: '逆境でも諦めない闘志。潜在能力に到達するための成長のしやすさに影響する。',
  AttributeKeys.flair: '独創的なプレーを生み出すひらめき。',
  AttributeKeys.leadership: 'チームを鼓舞する統率力。値が高い選手をキャプテンに指名すると効果的。',
  AttributeKeys.offTheBall: 'ボールを持たない時の動き出し。攻撃力の複合値に反映される。',
  AttributeKeys.positioning: '守備時の立ち位置の的確さ。守備力の複合値に反映される。',
  AttributeKeys.teamwork: '味方と連携してプレーする意識。',
  AttributeKeys.vision: '味方の動きを見通すパスセンス。技術の複合値に反映される。',
  AttributeKeys.workRate: '運動量・献身性。スタミナの複合値に反映される。',
  AttributeKeys.acceleration: '瞬間的な加速力。スタミナの複合値に反映される。',
  AttributeKeys.agility: '身のこなしの俊敏さ。',
  AttributeKeys.balance: '接触時にバランスを崩さない安定感。',
  AttributeKeys.jumpingReach: 'ジャンプの高さ・到達点。空中戦の強さに関わる。',
  AttributeKeys.naturalFitness: '生まれ持った体力の強さ。高いほど怪我をしにくく、トレーニングでの成長効率にも影響する。',
  AttributeKeys.pace: '走る速さ。攻撃力の複合値に反映される。',
  AttributeKeys.stamina: '試合を通して運動量を維持する持久力。スタミナの複合値で最も重みが大きい項目。',
  AttributeKeys.strength: 'フィジカルの強さ。守備力・スタミナ両方の複合値に反映される。',
  AttributeKeys.aerialReach: 'GKが飛び出して高いボールに対応する能力。',
  AttributeKeys.commandOfArea: 'GKがペナルティエリア内を統率する能力。',
  AttributeKeys.handling: 'GKがボールを確実にキャッチ・キープする能力。',
  AttributeKeys.kicking: 'GKのゴールキックやパントキックの精度。',
  AttributeKeys.oneOnOnes: 'GKが1対1の場面でシュートを防ぐ能力。',
  AttributeKeys.reflexes: 'GKの反射的な反応の速さ。',
};

final List<GlossaryEntry> glossaryEntries = [
  for (final key in AttributeKeys.all)
    GlossaryEntry(
      term: AttributeKeys.labelOf(key),
      category: GlossaryCategory.attribute,
      description: _attributeDescriptions[key] ?? '',
    ),
  const GlossaryEntry(
    term: '総合力',
    category: GlossaryCategory.composite,
    description: '選手全体の実力を1つの数値にまとめたもの。攻撃力・守備力・技術・スタミナなど能力値全体の平均から算出される。',
  ),
  const GlossaryEntry(
    term: '潜在能力',
    category: GlossaryCategory.composite,
    description:
        '選手が将来到達しうる総合力の上限。若い選手ほど現在の総合力との差(伸びしろ)が大きくなりやすく、ユース画面では「伸びしろ」でも並び替えできる。',
  ),
  const GlossaryEntry(
    term: '攻撃力',
    category: GlossaryCategory.composite,
    description:
        'フィニッシュ・ロングシュート・ドリブル・オフザボール・冷静さ・スピードの加重平均。試合シミュレーションのチーム攻撃力計算のベースになる。',
  ),
  const GlossaryEntry(
    term: '守備力',
    category: GlossaryCategory.composite,
    description:
        'タックル・マーキング・ポジショニング・予測・強さ・積極性の加重平均。試合シミュレーションのチーム守備力計算のベースになる。',
  ),
  const GlossaryEntry(
    term: '技術',
    category: GlossaryCategory.composite,
    description: 'パス・ファーストタッチ・視野・テクニック・クロス・判断力の加重平均。ボールを扱う巧みさの目安。',
  ),
  const GlossaryEntry(
    term: 'スタミナ(複合値)',
    category: GlossaryCategory.composite,
    description: 'スタミナ・基礎体力・労働量・強さ・加速力の加重平均。運動量が求められるポジションほど重要になる。',
  ),
  const GlossaryEntry(
    term: '疲労',
    category: GlossaryCategory.condition,
    description:
        '試合出場・厳しいプレッシングで蓄積し、休養やトレーニング施設で回復する。高いほど試合でのコンディション(パフォーマンス)が下がる。',
  ),
  const GlossaryEntry(
    term: '士気(モラール)',
    category: GlossaryCategory.condition,
    description: 'チームの勢い・選手の意気込みを表す値。高いほど試合でのコンディションが上がる。連勝や記者会見での受け答えで変動する。',
  ),
  const GlossaryEntry(
    term: 'マッチシャープネス',
    category: GlossaryCategory.condition,
    description:
        '直近の試合勘・実戦感覚。出場を重ねるほど上がり、ベンチ・怪我・出場停止が続くと緩やかに下がる。負傷から復帰した直後は大きく下がるため、復帰後しばらくは本来のコンディションを出しにくい。',
  ),
  const GlossaryEntry(
    term: 'コンディション',
    category: GlossaryCategory.condition,
    description:
        '試合中の実際のパフォーマンス補正。疲労・士気・マッチシャープネスの3要素から算出され、これらが高いほど攻撃力・守備力への影響が良くなる。',
  ),
  const GlossaryEntry(
    term: '不満度',
    category: GlossaryCategory.condition,
    description:
        '選手のクラブへの満足度(0-100)。低いほど移籍を希望しやすくなる。出場機会・週俸・チーム成績・性格によって変動し、性格ごとの閾値を下回ると移籍希望のフラグが立つ。',
  ),
  const GlossaryEntry(
    term: '性格',
    category: GlossaryCategory.condition,
    description:
        '選手の気質(全20種類)。不満度の変動しやすさ・移籍希望の出やすさのほか、チームトークや声かけへの感応度、賃金要求の強さにも影響する。各性格の詳しい説明はガイドの「スカッド・選手詳細画面」を参照。',
  ),
  const GlossaryEntry(
    term: 'デューティ',
    category: GlossaryCategory.condition,
    description:
        '選手の戦術上の役割の重心(守備的/バランス/攻撃的)。攻撃的にするほど攻撃力に、守備的にするほど守備力にボーナスが付く代わりに、もう一方が手薄になる。',
  ),
  const GlossaryEntry(
    term: 'ロール(プレースタイル)',
    category: GlossaryCategory.condition,
    description:
        'どの能力値を活かしたプレーを得意とするかを表す設定(プレーメイカー・ポーチャーなど)。ロールが重視する能力値が高い選手に割り当てるとボーナスが、低い選手に割り当てるとペナルティが付く。',
  ),
  const GlossaryEntry(
    term: 'ポジション適性・慣れ',
    category: GlossaryCategory.condition,
    description:
        '本職(主ポジション)以外で起用した際の習熟度(0-100)。出場を重ねるほど上昇し、本来のポジションとのギャップによる攻撃力・守備力ペナルティを徐々に軽減する。',
  ),
  const GlossaryEntry(
    term: '週俸',
    category: GlossaryCategory.contractTransfer,
    description: '選手に毎週支払う給料(万円)。契約更新の交渉で決まり、性格ごとの賃金感応度によって要求額が変わる。',
  ),
  const GlossaryEntry(
    term: '契約残り年数',
    category: GlossaryCategory.contractTransfer,
    description:
        '現在の契約が満了するまでの年数。シーズン終了時に1年ずつ減り、残り0年のままシーズンを終えると自由契約として退団してしまうため、事前の契約更新が必要になる。',
  ),
  const GlossaryEntry(
    term: '想定移籍金',
    category: GlossaryCategory.contractTransfer,
    description: '年齢・現在の総合力・伸びしろから概算した市場価値(万円)。移籍交渉時のオファー額の目安になる。',
  ),
  const GlossaryEntry(
    term: 'リリース条項',
    category: GlossaryCategory.contractTransfer,
    description: '設定されている場合、他クラブがこの金額(万円)を提示すると交渉なしで自動的に移籍が成立する。',
  ),
  const GlossaryEntry(
    term: '出場手当',
    category: GlossaryCategory.contractTransfer,
    description: '契約更新時に決定される手当(万円)。リーグ公式戦でスタメン出場するたびに支払われる。',
  ),
  const GlossaryEntry(
    term: 'サインボーナス',
    category: GlossaryCategory.contractTransfer,
    description: '契約更新時に一時金として支払う金額。性格ごとの賃金感応度に応じて要求されやすさが変わる。',
  ),
  const GlossaryEntry(
    term: 'キャプテン/副キャプテン',
    category: GlossaryCategory.tactics,
    description:
        'チームの主将・副将。キャプテンが出場している試合では規律が保たれ、カード(警告・退場)をやや受けにくくなる。統率力(リーダーシップ)が高い選手の指名が効果的。',
  ),
  const GlossaryEntry(
    term: '出場停止',
    category: GlossaryCategory.condition,
    description:
        '警告(イエローカード)の累積が一定枚数に達する、または退場(レッドカード)を受けると、その後の一定試合数は出場できなくなる。',
  ),
  const GlossaryEntry(
    term: '移籍リスト登録',
    category: GlossaryCategory.contractTransfer,
    description: '登録すると他クラブからの獲得オファーが届きやすくなる(登録なしより高い確率で発生)。放出したい選手に活用できる。',
  ),
  const GlossaryEntry(
    term: 'ローン(期限付き移籍)',
    category: GlossaryCategory.contractTransfer,
    description:
        '一定期間だけ他クラブへ選手を貸し出す/借り受ける制度。ローン中の選手の週俸は貸出先が負担し、期間満了で自動的に元クラブへ復帰する。買取オプション付きなら期間中に完全移籍へ切り替えられる。',
  ),
  const GlossaryEntry(
    term: '代表召集',
    category: GlossaryCategory.condition,
    description: '一定期間、代表チームの活動のため自クラブの試合に出場できなくなる。召集期間が明ければ通常通りチームに復帰する。',
  ),
  const GlossaryEntry(
    term: '監督への信頼度',
    category: GlossaryCategory.club,
    description: '理事会からの信頼度(0-100)。目標順位を下回る成績が続くと下がり、0になると解任される。',
  ),
  const GlossaryEntry(
    term: '監督としての評価',
    category: GlossaryCategory.club,
    description:
        '世間からの監督としての評価(0-100)。信頼度と異なり解任されてもクラブを移っても引き継がれ、他クラブからの就任オファーの受けやすさに影響する。',
  ),
  const GlossaryEntry(
    term: '理事会の目標順位',
    category: GlossaryCategory.club,
    description: 'シーズン開始時に理事会から示される目標順位(1が最高位)。これを下回る成績が続くと信頼度が低下する。',
  ),
  const GlossaryEntry(
    term: 'プレッシング',
    category: GlossaryCategory.tactics,
    description: '守備時の寄せの強度(0-100)。高いほど相手の攻撃力を抑えられるが、選手の疲労が増えやすくなる。',
  ),
  const GlossaryEntry(
    term: 'ラインの高さ',
    category: GlossaryCategory.tactics,
    description: '守備ラインの高さ(0-100)。高いほど攻撃力にプラスに働くが、裏を突かれるリスクが高まる。',
  ),
  const GlossaryEntry(
    term: '攻撃の幅',
    category: GlossaryCategory.tactics,
    description: 'サイドをどれだけ広く使うか(0-100)。高いほど攻撃力が上がるが、中央の守備が薄くなる。',
  ),
  const GlossaryEntry(
    term: 'テンポ',
    category: GlossaryCategory.tactics,
    description: 'プレーの速さ(0-100)。高いほど攻撃力が上がるが、疲労が溜まりやすくなる。',
  ),
  const GlossaryEntry(
    term: 'メンター',
    category: GlossaryCategory.condition,
    description:
        '若手選手に付ける指導役のベテラン選手(28歳以上)。メンティーの成長率にボーナスが付き、メンター自身も指導のやりがいから士気が少し上がる。',
  ),
  const GlossaryEntry(
    term: '特訓ドリル',
    category: GlossaryCategory.condition,
    description:
        'チーム/個別のトレーニング方針とは別に、狙った能力値を集中的に伸ばす個別設定。1人あたり2つまで指定でき、同時に指定できる人数にはヘッドコーチのレベルに応じた上限がある。',
  ),
  const GlossaryEntry(
    term: '練習強度',
    category: GlossaryCategory.condition,
    description: '軽め/通常/追い込みの3段階。強くするほど成長速度が上がる代わりに、疲労の蓄積と練習中の怪我リスクが増す。',
  ),
  const GlossaryEntry(
    term: 'チームトーク',
    category: GlossaryCategory.condition,
    description:
        '試合前・ハーフタイムに監督が飛ばす檄。鼓舞する/冷静に指示する/叱咤するの3トーンがあり、先発イレブンの士気を変動させる。効果の大きさは選手の性格による結果感応度で変わる。',
  ),
  const GlossaryEntry(
    term: 'マンマーク',
    category: GlossaryCategory.tactics,
    description:
        'スカウティングレポートで判明した相手のキープレイヤーに、自チームの選手(DF・MF)を専任でマークさせる指示。マーカーが出場している間、相手キープレイヤーの攻撃力への貢献を抑えられる。',
  ),
  const GlossaryEntry(
    term: '守備セットプレー担当',
    category: GlossaryCategory.tactics,
    description:
        '相手のコーナーキック・フリーキックを守る担当選手。ヘディング・ジャンプ力が高いほど、相手のセットプレー由来のチャンスの質を下げられる。',
  ),
  const GlossaryEntry(
    term: '逃げ切りモード',
    category: GlossaryCategory.tactics,
    description:
        '有効にすると自チームの攻撃力がやや下がる代わりに守備が安定し、疲労の蓄積も抑えられる。リードした終盤の時間の使い方として使う。',
  ),
  const GlossaryEntry(
    term: '負傷の種類',
    category: GlossaryCategory.condition,
    description:
        '打撲(1-2週)・肉離れ(2-5週)・靭帯損傷(4-10週)の3種類があり、療養期間が異なる。基礎体力(naturalFitness)が高いほど負傷しにくく、同じ種類の負傷を繰り返すと再発しやすくなる。',
  ),
  const GlossaryEntry(
    term: '決定機',
    category: GlossaryCategory.liveMatch,
    description:
        'ライブ観戦中に訪れる得点/失点のチャンス。自クラブの攻撃側ではシュート/パス/ロングシュートを、守備側では積極的にタックル/カバーリングに専念を選ぶ。成功率は関わる選手の能力値の勝負(シューター対GKなど)から算出され、選択前に表示される。',
  ),
  const GlossaryEntry(
    term: 'メンタリティ',
    category: GlossaryCategory.tactics,
    description:
        'チーム全体の姿勢。超守備的〜超攻撃的の5段階から選び、攻撃的なほど攻撃力が上がる代わりに守備のリスクが増える(その逆も同様)。スタメン・戦術画面の戦術タブで設定でき、ライブ観戦・クイック消化の両方に効く。',
  ),
  const GlossaryEntry(
    term: 'スカッド・ステータス',
    category: GlossaryCategory.contractTransfer,
    description:
        '選手に約束する出場機会の立場(キープレイヤー/主力/ローテーション/育成枠)。上の立場ほどベンチに置いたときの不満が大きく、契約交渉で求める週給も高くなる。選手詳細画面で設定する。',
  ),
  const GlossaryEntry(
    term: '週給予算',
    category: GlossaryCategory.club,
    description:
        '理事会が設定する週給総額の上限。シーズン開始時にディビジョンと現在の人件費から決まり、上限を超える新規獲得はブロックされる。クラブ経営画面で使用状況を確認できる。',
  ),
  const GlossaryEntry(
    term: 'チームリーダー',
    category: GlossaryCategory.club,
    description:
        'リーダーシップ・実力・年齢(とキャプテンの肩書)から決まるロッカールームの中心選手(上位3人)。リーダー陣が不機嫌だとチーム全体の士気が下がり、上機嫌だと上がる。リーダーを放出するとチームに動揺が走る。',
  ),
  const GlossaryEntry(
    term: 'カップ目標',
    category: GlossaryCategory.club,
    description:
        '理事会が期待する国内カップの到達ラウンド。リーグ内の戦力が高いクラブほど深いラウンドまで期待され、達成すれば信頼度が上がり、大きく届かないと下がる。',
  ),
  const GlossaryEntry(
    term: '選手検索',
    category: GlossaryCategory.contractTransfer,
    description:
        '全ディビジョンの全選手を名前・ポジション・年齢・総合力で絞り込めるスカウティングツール。補強ターゲットの調査に使い、実際の獲得は移籍市場・フリーエージェント経由で行う。',
  ),
  const GlossaryEntry(
    term: '武者修行(ローン育成)',
    category: GlossaryCategory.contractTransfer,
    description:
        'ローン放出中の選手は貸出先で毎週実戦に出て成長する(24歳未満は特に効果が大きい)。自クラブの施設・スタッフのボーナスは効かないが、実戦感覚を保ちながら能力が伸びるため、出番のない若手の育成手段になる。復帰時には放出中の成長がニュースで報告される。',
  ),
  const GlossaryEntry(
    term: '成長推移',
    category: GlossaryCategory.condition,
    description:
        '選手の総合力を節送りごとに記録した週次の推移。選手詳細画面に折れ線グラフで表示され、伸びている選手・停滞している選手が一目で分かる。自クラブの選手とユース昇格候補が対象で、概ね1シーズン分を保持する。',
  ),
  const GlossaryEntry(
    term: '育成アドバイザー',
    category: GlossaryCategory.condition,
    description:
        'コーチ陣が育成面で手を打つべき選手を挙げてくれるトレーニング画面の提案。疲労が濃い選手、実戦感覚が落ちて成長が鈍っている選手、伸びしろが手つかずの若手(特訓ドリル・育成プラン未設定)、メンターのいない若手を検知する。',
  ),
  const GlossaryEntry(
    term: '戦術スタイル',
    category: GlossaryCategory.tactics,
    description:
        'チームの攻撃の組み立て方の型(柔軟/ポゼッション/ゲーゲンプレス/カウンター/ロングボール/ウイングプレー)。スカッドの関連能力値が高いほど攻守の補正が大きく、向いていないスタイルは逆効果になる。スタイル間には相性(有利・不利の循環)があり、スカウティングレポートで相手の予想スタイルと対策を確認できる。柔軟は補正も弱点もない中立。',
  ),
  const GlossaryEntry(
    term: '紅白戦',
    category: GlossaryCategory.condition,
    description:
        '週次トレーニングの一環として自動で行われるスカッド内の練習試合。スタメン外の選手が実戦感覚(マッチシャープネス)を保ち、実戦経験による成長の機会も得る(そのぶん少し疲労は残る)。負傷・代表招集・ローン放出中の選手は参加できない。',
  ),
  const GlossaryEntry(
    term: 'ユース練習試合',
    category: GlossaryCategory.club,
    description:
        '昇格候補たちが毎週こなす近隣クラブのユースとの練習試合。全員に出場数・得点・評点が記録され、活躍(高評点)した候補は能力がさらに伸びる。戦績はユース画面で確認でき、昇格させるタイミングの判断材料になる。大活躍はクラブニュースにも届く。',
  ),
  const GlossaryEntry(
    term: '監督契約',
    category: GlossaryCategory.club,
    description:
        '理事会と結ぶ監督(あなた)の契約。毎シーズン残り年数が1年ずつ減り、目標達成で3年契約に延長される。契約が切れた時に理事会の信頼が低いと解任、信頼があれば1年の暫定契約で続投となる。残り年数は監督キャリア画面で確認できる。',
  ),
  const GlossaryEntry(
    term: 'ウォッチリスト',
    category: GlossaryCategory.contractTransfer,
    description:
        '気になる選手に星印をつけて追いかけるリスト。選手検索画面の星ボタンで登録・解除でき、「ウォッチ中」フィルタで一覧できる。ウォッチ中の選手が得点するとクラブニュースに届く。',
  ),
  const GlossaryEntry(
    term: '采配方針',
    category: GlossaryCategory.liveMatch,
    description:
        'ライブ観戦中にいつでも切り替えられる試合中の指示。通常/リスクを取る/安全に下がるの3方針があり、以降の決定機の成功率に攻守それぞれへ補正がかかる。',
  ),
  const GlossaryEntry(
    term: 'ライブ交代',
    category: GlossaryCategory.liveMatch,
    description:
        'ライブ観戦中、ハーフタイムを待たずに決定機の合間で交代枠を使って行う選手交代。目前の決定機に関わっている選手は、その決定機が解決するまで交代できない。',
  ),
  const GlossaryEntry(
    term: 'モメンタム(試合の流れ)',
    category: GlossaryCategory.liveMatch,
    description:
        'ライブ観戦画面のスコア下に表示される綱引きバー。ゴールなどで勢いづいた側に傾き、傾いている間はその側の決定機がわずかに決まりやすくなる。',
  ),
  const GlossaryEntry(
    term: 'クイック消化',
    category: GlossaryCategory.liveMatch,
    description:
        'ライブ観戦せず、試合結果だけを即座に確定させる進め方。カップ戦を含め、疲労・負傷・警告累積・出場記録などの試合後効果はライブ観戦と同じように適用される。',
  ),
  const GlossaryEntry(
    term: '値切り交渉',
    category: GlossaryCategory.contractTransfer,
    description:
        '移籍市場の選手を想定移籍金より安い提示額で獲得しようとする交渉。提示額の割合が高いほど成立しやすく、55%以下では必ず決裂する。決裂した選手とはその週は再交渉できない。',
  ),
  const GlossaryEntry(
    term: '移籍市場の入れ替わり',
    category: GlossaryCategory.contractTransfer,
    description:
        '移籍市場の顔ぶれは毎週数人だけが入れ替わる持続的な仕組み。狙っていた選手を翌週以降も追える一方、いつまでも市場に残っているとは限らない。',
  ),
  const GlossaryEntry(
    term: '育成プラン(目標ロール)',
    category: GlossaryCategory.condition,
    description:
        '選手ごとに目標とするロール(プレースタイル)を設定する仕組み。週次トレーニングでそのロールが重視する能力値が優先的に伸びる。ポジションの大分類に合うロールのみ設定できる。',
  ),
  const GlossaryEntry(
    term: '勝ち上がり賞金',
    category: GlossaryCategory.club,
    description: 'カップ戦で1勝(1タイ勝ち抜け)するごとに得られる賞金。ラウンドが深いほど高額で、優勝時はさらに優勝ボーナスが加わる。',
  ),
  const GlossaryEntry(
    term: '天候',
    category: GlossaryCategory.tactics,
    description:
        '試合当日の空模様(晴れ/雨/強風/猛暑/雪)。悪天候ほど攻撃力・チャンス数が下がり、雨は守備側がやや優位、猛暑は疲労が溜まりやすいなど試合展開が変わる。雨男・雪国育ちなど特定の天候で輝く選手特性もある。',
  ),
  const GlossaryEntry(
    term: '記者会見',
    category: GlossaryCategory.condition,
    description:
        '試合後に記者から受ける質問への受け答え。回答の選択によってチームの士気が上下するため、試合結果に合ったコメントを選ぶことが監督業の一部になる。',
  ),
  const GlossaryEntry(
    term: 'スカウティングレポート(試合プレビュー)',
    category: GlossaryCategory.tactics,
    description:
        '次の対戦相手の戦力・キープレイヤー・直近のフォームをまとめた事前情報。ここで判明したキープレイヤーにマンマークを付けるなど、試合前の準備に使う。',
  ),
  const GlossaryEntry(
    term: '個別声かけ(モチベーショントーク)',
    category: GlossaryCategory.condition,
    description:
        '監督が選手個人に声をかけて士気(モラール)を高めるコマンド。効果の大きさは選手の性格による感応度で変わり、一度使うと同じ選手には数週間のクールダウンがある。',
  ),
  const GlossaryEntry(
    term: '話し合い',
    category: GlossaryCategory.condition,
    description:
        '不満を抱えた選手と面談して不満度を和らげるコマンド。士気を対象にする個別声かけとは別物で、こちらにもクールダウンがある。移籍希望のフラグが立った選手を引き留める初手になる。',
  ),
  const GlossaryEntry(
    term: '戦術ミーティング',
    category: GlossaryCategory.condition,
    description:
        'チーム全体で戦術理解を深めるミーティング。判断力・ポジショニング・チームワークといったメンタル系能力値がわずかに成長する。連発はできず、数週間のクールダウンがある。',
  ),
  const GlossaryEntry(
    term: 'ローテーション方針',
    category: GlossaryCategory.condition,
    description:
        '選手個別のトレーニング方針を複数登録しておくと、週替わりで自動的に切り替わる仕組み。攻撃と守備を交互に鍛えるなど、毎週手動で切り替えなくてもバランス良く育成できる。',
  ),
  const GlossaryEntry(
    term: '自動トレーニング',
    category: GlossaryCategory.condition,
    description:
        '有効にすると、節を進めた際に週次トレーニングが自動で実施される。細かく管理したい週だけ無効に戻して手動で行うこともできる。',
  ),
  const GlossaryEntry(
    term: '契約解除の違約金',
    category: GlossaryCategory.contractTransfer,
    description:
        '契約が残っている選手を放出する際に支払う違約金。売却額から差し引かれ、残り契約が長いほど高額になるため、受け取り額がマイナスになることもある。放出のタイミングを見極める材料になる。',
  ),
];
