import '../models/attributes.dart';
import '../l10n/tr.dart';

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
        GlossaryCategory.attribute => Tr.pick('選手能力値', 'Player attributes'),
        GlossaryCategory.composite => Tr.pick('複合指標', 'Composite ratings'),
        GlossaryCategory.condition =>
          Tr.pick('コンディション・メンタル', 'Condition & mentality'),
        GlossaryCategory.contractTransfer =>
          Tr.pick('契約・移籍', 'Contracts & transfers'),
        GlossaryCategory.tactics => Tr.pick('戦術', 'Tactics'),
        GlossaryCategory.liveMatch => Tr.pick('ライブ観戦', 'Watching live'),
        GlossaryCategory.club => Tr.pick('クラブ経営', 'Club finances'),
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

// const にできないのは、説明文が表示時の言語で決まるため。
Map<String, String> get _attributeDescriptions => {
      AttributeKeys.corners: Tr.pick(
          'コーナーキックの精度。コーナー担当に指名された選手の値が高いほどチャンスの質が上がる。',
          'Accuracy from corners. The higher this is on your nominated taker, the better the chances that come from them.'),
      AttributeKeys.crossing: Tr.pick('サイドからのクロスの正確さ。攻撃力の複合値(技術)に反映される。',
          'Accuracy of crosses from wide. Feeds into the attack and technical ratings.'),
      AttributeKeys.dribbling: Tr.pick('ボールを持って相手を抜く能力。攻撃力の複合値に反映される。',
          'The ability to beat a man with the ball. Feeds into the attack rating.'),
      AttributeKeys.finishing: Tr.pick('シュートの決定力。攻撃力の複合値で最も重みが大きい項目。',
          'How reliably he finishes. The heaviest single item in the attack rating.'),
      AttributeKeys.firstTouch: Tr.pick('ボールを受けた際の落ち着き。技術の複合値に反映される。',
          'How cleanly he takes the ball. Feeds into the technical rating.'),
      AttributeKeys.freeKick: Tr.pick(
          '直接フリーキックの精度。FK担当に指名された選手の値が高いほどチャンスの質が上がる。',
          'Accuracy from direct free kicks. The higher this is on your nominated taker, the better the chances.'),
      AttributeKeys.heading: Tr.pick(
          '空中戦での競り合い・ヘディングシュートの精度。', 'Winning headers, and finishing them.'),
      AttributeKeys.longShots: Tr.pick('中距離・遠距離からのシュート精度。攻撃力の複合値に反映される。',
          'Accuracy shooting from range. Feeds into the attack rating.'),
      AttributeKeys.longThrows: Tr.pick(
          'ロングスローインの飛距離・精度。', 'The distance and accuracy of his long throws.'),
      AttributeKeys.marking: Tr.pick('相手選手を捕まえる能力。守備力の複合値で最も重みが大きい項目。',
          'How well he sticks to an opponent. The heaviest single item in the defence rating.'),
      AttributeKeys.passing: Tr.pick('パスの正確さ。技術の複合値で最も重みが大きい項目。',
          'Accuracy of his passing. The heaviest single item in the technical rating.'),
      AttributeKeys.penalties: Tr.pick('PKの成功率。PK担当に指名された選手の値が高いほど成功率が上がる。',
          'His success rate from the spot. The higher this is on your nominated taker, the better the odds.'),
      AttributeKeys.tackling: Tr.pick('相手からボールを奪う能力。守備力の複合値に反映される。',
          'Winning the ball back. Feeds into the defence rating.'),
      AttributeKeys.technique: Tr.pick('ボールコントロール全般の巧みさ。技術の複合値に反映される。',
          'General skill on the ball. Feeds into the technical rating.'),
      AttributeKeys.aggression: Tr.pick(
          '球際やプレスでの積極性。高いほど守備力にプラスだが、警告・退場のリスクも増える。',
          'How hard he goes into challenges. Helps the defence, but raises the risk of cards.'),
      AttributeKeys.anticipation: Tr.pick('状況を先読みする力。守備力の複合値に反映される。',
          'Reading the play before it happens. Feeds into the defence rating.'),
      AttributeKeys.bravery: Tr.pick(
          '危険な状況でも臆さずプレーする度胸。', 'Playing without flinching where it hurts.'),
      AttributeKeys.composure: Tr.pick('プレッシャー下での冷静さ。高いほど攻撃力にプラスで、警告のリスクを抑える。',
          'Keeping his head under pressure. Helps the attack and reduces the risk of cards.'),
      AttributeKeys.concentration: Tr.pick(
          '試合を通して集中力を維持する能力。', 'Holding his concentration for the full match.'),
      AttributeKeys.decisions: Tr.pick('状況判断の的確さ。技術の複合値に反映される。',
          'Picking the right option. Feeds into the technical rating.'),
      AttributeKeys.determination: Tr.pick(
          '逆境でも諦めない闘志。潜在能力に到達するための成長のしやすさに影響する。',
          'Refusing to give in. Affects how readily he grows towards his potential.'),
      AttributeKeys.flair:
          Tr.pick('独創的なプレーを生み出すひらめき。', 'The spark to do something unexpected.'),
      AttributeKeys.leadership: Tr.pick('チームを鼓舞する統率力。値が高い選手をキャプテンに指名すると効果的。',
          'How he lifts those around him. Worth naming a high-leadership player as captain.'),
      AttributeKeys.offTheBall: Tr.pick('ボールを持たない時の動き出し。攻撃力の複合値に反映される。',
          'His movement without the ball. Feeds into the attack rating.'),
      AttributeKeys.positioning: Tr.pick('守備時の立ち位置の的確さ。守備力の複合値に反映される。',
          'Where he stands when defending. Feeds into the defence rating.'),
      AttributeKeys.teamwork:
          Tr.pick('味方と連携してプレーする意識。', 'How well he plays for the team.'),
      AttributeKeys.vision: Tr.pick('味方の動きを見通すパスセンス。技術の複合値に反映される。',
          'Seeing the pass before others do. Feeds into the technical rating.'),
      AttributeKeys.workRate: Tr.pick('運動量・献身性。スタミナの複合値に反映される。',
          'How much ground he covers, and how willingly. Feeds into the stamina rating.'),
      AttributeKeys.acceleration: Tr.pick('瞬間的な加速力。スタミナの複合値に反映される。',
          'How quickly he gets up to speed. Feeds into the stamina rating.'),
      AttributeKeys.agility: Tr.pick('身のこなしの俊敏さ。', 'How nimbly he moves.'),
      AttributeKeys.balance:
          Tr.pick('接触時にバランスを崩さない安定感。', 'Staying on his feet through contact.'),
      AttributeKeys.jumpingReach: Tr.pick('ジャンプの高さ・到達点。空中戦の強さに関わる。',
          'How high he gets. Central to winning the ball in the air.'),
      AttributeKeys.naturalFitness: Tr.pick(
          '生まれ持った体力の強さ。高いほど怪我をしにくく、トレーニングでの成長効率にも影響する。',
          'His natural constitution. Higher means fewer injuries, and better returns from training.'),
      AttributeKeys.pace: Tr.pick('走る速さ。攻撃力の複合値に反映される。',
          'How fast he runs. Feeds into the attack rating.'),
      AttributeKeys.stamina: Tr.pick('試合を通して運動量を維持する持久力。スタミナの複合値で最も重みが大きい項目。',
          'Keeping his work rate up for 90 minutes. The heaviest single item in the stamina rating.'),
      AttributeKeys.strength: Tr.pick('フィジカルの強さ。守備力・スタミナ両方の複合値に反映される。',
          'Sheer physical strength. Feeds into both the defence and stamina ratings.'),
      AttributeKeys.aerialReach: Tr.pick(
          'GKが飛び出して高いボールに対応する能力。', 'How well the keeper comes for high balls.'),
      AttributeKeys.commandOfArea: Tr.pick(
          'GKがペナルティエリア内を統率する能力。', 'How well the keeper commands his box.'),
      AttributeKeys.handling: Tr.pick(
          'GKがボールを確実にキャッチ・キープする能力。', 'How safely the keeper holds the ball.'),
      AttributeKeys.kicking: Tr.pick('GKのゴールキックやパントキックの精度。',
          "The keeper's accuracy with goal kicks and punts."),
      AttributeKeys.oneOnOnes: Tr.pick(
          'GKが1対1の場面でシュートを防ぐ能力。', 'How the keeper handles a one-on-one.'),
      AttributeKeys.reflexes:
          Tr.pick('GKの反射的な反応の速さ。', "The keeper's reaction speed."),
    };

// final ではなくゲッターにしている。final にすると最初のアクセス時に
// リストが組み立てられ、そのときの言語で文言が固定されてしまい、設定で
// 日本語/英語を切り替えても用語集だけ変わらなくなる。
List<GlossaryEntry> get glossaryEntries => [
      for (final key in AttributeKeys.all)
        GlossaryEntry(
          term: AttributeKeys.labelOf(key),
          category: GlossaryCategory.attribute,
          description: _attributeDescriptions[key] ?? '',
        ),
      GlossaryEntry(
        term: Tr.pick('総合力', 'Overall'),
        category: GlossaryCategory.composite,
        description: Tr.pick(
            '選手全体の実力を1つの数値にまとめたもの。攻撃力・守備力・技術・スタミナなど能力値全体の平均から算出される。',
            'One number for how good he is overall, averaged across attack, defence, technical and stamina.'),
      ),
      GlossaryEntry(
        term: Tr.pick('潜在能力', 'Potential'),
        category: GlossaryCategory.composite,
        description: Tr.pick(
            '選手が将来到達しうる総合力の上限。若い選手ほど現在の総合力との差(伸びしろ)が大きくなりやすく、ユース画面では「伸びしろ」でも並び替えできる。',
            'The ceiling on his overall. Younger players tend to have more room between the two, and the youth screen lets you sort by that gap.'),
      ),
      GlossaryEntry(
        term: Tr.pick('攻撃力', 'Attack'),
        category: GlossaryCategory.composite,
        description: Tr.pick(
            'フィニッシュ・ロングシュート・ドリブル・オフザボール・冷静さ・スピードの加重平均。試合シミュレーションのチーム攻撃力計算のベースになる。',
            "A weighted average of finishing, long shots, dribbling, movement off the ball, composure and pace. The basis of your side's attacking strength in the match simulation."),
      ),
      GlossaryEntry(
        term: Tr.pick('守備力', 'Defence'),
        category: GlossaryCategory.composite,
        description: Tr.pick(
            'タックル・マーキング・ポジショニング・予測・強さ・積極性の加重平均。試合シミュレーションのチーム守備力計算のベースになる。',
            "A weighted average of tackling, marking, positioning, anticipation, strength and aggression. The basis of your side's defensive strength in the match simulation."),
      ),
      GlossaryEntry(
        term: Tr.pick('技術', 'Technical'),
        category: GlossaryCategory.composite,
        description: Tr.pick('パス・ファーストタッチ・視野・テクニック・クロス・判断力の加重平均。ボールを扱う巧みさの目安。',
            'A weighted average of passing, first touch, vision, technique, crossing and decisions. A measure of how well he handles the ball.'),
      ),
      GlossaryEntry(
        term: Tr.pick('スタミナ(複合値)', 'Stamina (composite)'),
        category: GlossaryCategory.composite,
        description: Tr.pick('スタミナ・基礎体力・労働量・強さ・加速力の加重平均。運動量が求められるポジションほど重要になる。',
            'A weighted average of stamina, natural fitness, work rate, strength and acceleration. It matters more the more ground a position demands.'),
      ),
      GlossaryEntry(
        term: Tr.pick('疲労', 'Fatigue'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '試合出場・厳しいプレッシングで蓄積し、休養やトレーニング施設で回復する。高いほど試合でのコンディション(パフォーマンス)が下がる。',
            'Builds up through matches and hard pressing, and comes down with rest and good facilities. The higher it is, the worse his condition on the day.'),
      ),
      GlossaryEntry(
        term: Tr.pick('士気(モラール)', 'Morale'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            'チームの勢い・選手の意気込みを表す値。高いほど試合でのコンディションが上がる。連勝や記者会見での受け答えで変動する。',
            'How the side and the player feel about things. Higher means a better condition on the day. Winning runs and your press answers move it.'),
      ),
      GlossaryEntry(
        term: Tr.pick('マッチシャープネス', 'Match sharpness'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '直近の試合勘・実戦感覚。出場を重ねるほど上がり、ベンチ・怪我・出場停止が続くと緩やかに下がる。負傷から復帰した直後は大きく下がるため、復帰後しばらくは本来のコンディションを出しにくい。',
            'How match-ready he is. It rises with minutes and drifts down through spells on the bench, injured or suspended. It drops sharply on return from injury, so he will not be himself for a while.'),
      ),
      GlossaryEntry(
        term: Tr.pick('コンディション', 'Condition'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '試合中の実際のパフォーマンス補正。疲労・士気・マッチシャープネスの3要素から算出され、これらが高いほど攻撃力・守備力への影響が良くなる。',
            'The modifier applied to his performance on the day. Worked out from fatigue, morale and match sharpness; the better those are, the more he contributes.'),
      ),
      GlossaryEntry(
        term: Tr.pick('不満度', 'Happiness'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '選手のクラブへの満足度(0-100)。低いほど移籍を希望しやすくなる。出場機会・週俸・チーム成績・性格によって変動し、性格ごとの閾値を下回ると移籍希望のフラグが立つ。',
            'How content he is at the club (0-100). The lower it is, the more likely he asks to leave. Minutes, wages, results and his personality all move it, and each personality has its own threshold for requesting a move.'),
      ),
      GlossaryEntry(
        term: Tr.pick('性格', 'Personality'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '選手の気質(全20種類)。不満度の変動しやすさ・移籍希望の出やすさのほか、チームトークや声かけへの感応度、賃金要求の強さにも影響する。各性格の詳しい説明はガイドの「スカッド・選手詳細画面」を参照。',
            "His temperament, one of twenty. It governs how easily he becomes unsettled, how readily he asks for a move, how he responds to team talks and quiet words, and how hard he pushes on wages. The guide's squad section describes each one."),
      ),
      GlossaryEntry(
        term: Tr.pick('デューティ', 'Duty'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '選手の戦術上の役割の重心(守備的/バランス/攻撃的)。攻撃的にするほど攻撃力に、守備的にするほど守備力にボーナスが付く代わりに、もう一方が手薄になる。',
            'Where his role sits between defend, support and attack. Pushing towards attack adds attacking output at the cost of defensive cover, and the other way round.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ロール(プレースタイル)', 'Role'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            'どの能力値を活かしたプレーを得意とするかを表す設定(プレーメイカー・ポーチャーなど)。ロールが重視する能力値が高い選手に割り当てるとボーナスが、低い選手に割り当てるとペナルティが付く。',
            'What kind of player he is asked to be (playmaker, poacher and so on). Give a role to someone strong in the attributes it values and he gains; give it to someone weak in them and he suffers.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ポジション適性・慣れ', 'Position familiarity'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '本職(主ポジション)以外で起用した際の習熟度(0-100)。出場を重ねるほど上昇し、本来のポジションとのギャップによる攻撃力・守備力ペナルティを徐々に軽減する。',
            'How settled he is in a position that is not his own (0-100). It climbs with minutes there, and gradually eats away at the penalty for playing out of position.'),
      ),
      GlossaryEntry(
        term: Tr.pick('週俸', 'Wage'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '選手に毎週支払う給料(万円)。契約更新の交渉で決まり、性格ごとの賃金感応度によって要求額が変わる。',
            'What he is paid each week. Set in contract talks, and how hard he pushes depends on his personality.'),
      ),
      GlossaryEntry(
        term: Tr.pick('契約残り年数', 'Years remaining'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '現在の契約が満了するまでの年数。シーズン終了時に1年ずつ減り、残り0年のままシーズンを終えると自由契約として退団してしまうため、事前の契約更新が必要になる。',
            'How long his deal has left. It drops by a year each season, and if it reaches zero he leaves on a free, so renew before then.'),
      ),
      GlossaryEntry(
        term: Tr.pick('想定移籍金', 'Estimated fee'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick('年齢・現在の総合力・伸びしろから概算した市場価値(万円)。移籍交渉時のオファー額の目安になる。',
            'A rough valuation from his age, current overall and room to grow. It is the yardstick for what a bid should look like.'),
      ),
      GlossaryEntry(
        term: Tr.pick('リリース条項', 'Release clause'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick('設定されている場合、他クラブがこの金額(万円)を提示すると交渉なしで自動的に移籍が成立する。',
            'Where one is set, any club offering that amount takes him with no negotiation at all.'),
      ),
      GlossaryEntry(
        term: Tr.pick('出場手当', 'Appearance fee'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick('契約更新時に決定される手当(万円)。リーグ公式戦でスタメン出場するたびに支払われる。',
            'Agreed when you renew, and paid every time he starts a league match.'),
      ),
      GlossaryEntry(
        term: Tr.pick('サインボーナス', 'Signing bonus'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick('契約更新時に一時金として支払う金額。性格ごとの賃金感応度に応じて要求されやすさが変わる。',
            'A lump sum paid on renewal. How often it is demanded depends on his personality.'),
      ),
      GlossaryEntry(
        term: Tr.pick('キャプテン/副キャプテン', 'Captain and vice captain'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            'チームの主将・副将。キャプテンが出場している試合では規律が保たれ、カード(警告・退場)をやや受けにくくなる。統率力(リーダーシップ)が高い選手の指名が効果的。',
            'Your on-field leaders. With the captain playing the side keeps its discipline and picks up slightly fewer cards. Name someone with high leadership.'),
      ),
      GlossaryEntry(
        term: Tr.pick('出場停止', 'Suspension'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '警告(イエローカード)の累積が一定枚数に達する、または退場(レッドカード)を受けると、その後の一定試合数は出場できなくなる。',
            'Collect enough yellows, or a red, and he sits out a set number of matches.'),
      ),
      GlossaryEntry(
        term: Tr.pick('移籍リスト登録', 'Transfer listing'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '登録すると他クラブからの獲得オファーが届きやすくなる(登録なしより高い確率で発生)。放出したい選手に活用できる。',
            'Listing a player makes offers from other clubs arrive more often. Useful for anyone you want off the books.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ローン(期限付き移籍)', 'Loan'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '一定期間だけ他クラブへ選手を貸し出す/借り受ける制度。ローン中の選手の週俸は貸出先が負担し、期間満了で自動的に元クラブへ復帰する。買取オプション付きなら期間中に完全移籍へ切り替えられる。',
            'Sending a player elsewhere, or taking one in, for a fixed spell. The receiving club pays his wages, and he returns automatically when it ends. With an option to buy, it can be made permanent at any point.'),
      ),
      GlossaryEntry(
        term: Tr.pick('代表召集', 'International duty'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '一定期間、代表チームの活動のため自クラブの試合に出場できなくなる。召集期間が明ければ通常通りチームに復帰する。',
            'He is away with his country for a spell and unavailable to you. He rejoins normally once it is over.'),
      ),
      GlossaryEntry(
        term: Tr.pick('監督への信頼度', 'Board confidence'),
        category: GlossaryCategory.club,
        description: Tr.pick('理事会からの信頼度(0-100)。目標順位を下回る成績が続くと下がり、0になると解任される。',
            'How much the board trusts you (0-100). Sustained results below their target push it down, and at zero you are sacked.'),
      ),
      GlossaryEntry(
        term: Tr.pick('監督としての評価', 'Reputation'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '世間からの監督としての評価(0-100)。信頼度と異なり解任されてもクラブを移っても引き継がれ、他クラブからの就任オファーの受けやすさに影響する。',
            'How the wider game rates you (0-100). Unlike board confidence it follows you through sackings and moves, and shapes the offers you receive.'),
      ),
      GlossaryEntry(
        term: Tr.pick('理事会の目標順位', 'Board target'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            'シーズン開始時に理事会から示される目標順位(1が最高位)。これを下回る成績が続くと信頼度が低下する。',
            'The finishing position the board asks for at the start of the season. Staying below it costs you their confidence.'),
      ),
      GlossaryEntry(
        term: Tr.pick('プレッシング', 'Pressing'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            '守備時の寄せの強度(0-100)。高いほど相手の攻撃力を抑えられるが、選手の疲労が増えやすくなる。',
            'How hard you close down (0-100). Higher blunts their attack, but tires your side faster.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ラインの高さ', 'Defensive line'),
        category: GlossaryCategory.tactics,
        description: Tr.pick('守備ラインの高さ(0-100)。高いほど攻撃力にプラスに働くが、裏を突かれるリスクが高まる。',
            'How high the back line sits (0-100). Higher helps the attack, but leaves more space behind.'),
      ),
      GlossaryEntry(
        term: Tr.pick('攻撃の幅', 'Attacking width'),
        category: GlossaryCategory.tactics,
        description: Tr.pick('サイドをどれだけ広く使うか(0-100)。高いほど攻撃力が上がるが、中央の守備が薄くなる。',
            'How much of the pitch you use across (0-100). Wider adds attacking threat, but thins the middle.'),
      ),
      GlossaryEntry(
        term: Tr.pick('テンポ', 'Tempo'),
        category: GlossaryCategory.tactics,
        description: Tr.pick('プレーの速さ(0-100)。高いほど攻撃力が上がるが、疲労が溜まりやすくなる。',
            'How quickly you play (0-100). Quicker adds attacking threat, but tires the side.'),
      ),
      GlossaryEntry(
        term: Tr.pick('メンター', 'Mentor'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '若手選手に付ける指導役のベテラン選手(28歳以上)。メンティーの成長率にボーナスが付き、メンター自身も指導のやりがいから士気が少し上がる。',
            "An older player (28 or over) paired with a young one. The younger man grows faster, and the mentor's own morale lifts a little from the responsibility."),
      ),
      GlossaryEntry(
        term: Tr.pick('特訓ドリル', 'Focus drill'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            'チーム/個別のトレーニング方針とは別に、狙った能力値を集中的に伸ばす個別設定。1人あたり2つまで指定でき、同時に指定できる人数にはヘッドコーチのレベルに応じた上限がある。',
            "Separate from the squad and individual focus, this drives one specific attribute hard. Up to two per player, with a cap on how many players at once that rises with your head coach's level."),
      ),
      GlossaryEntry(
        term: Tr.pick('全体練習', 'General training'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            'トレーニング方針の既定値。ポジションに応じて攻守をバランス良く伸ばす。攻撃強化などの特化練習より1項目あたりの伸びは緩やかだが、どのポジションの選手も自分の主戦場の能力を伸ばせる。休養と違い、方針を変えなくても選手は育つ。',
            'The default focus. It develops attack and defence evenly by position. Any one attribute moves more slowly than under a specialised session, but every player improves at what his position asks of him. Unlike rest, it grows the squad without you touching anything.'),
      ),
      GlossaryEntry(
        term: Tr.pick('練習強度', 'Training intensity'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '軽め/通常/追い込みの3段階。強くするほど成長速度が上がる代わりに、疲労の蓄積と練習中の怪我リスクが増す。',
            'Light, normal or intense. Harder means faster growth, at the cost of more fatigue and more injuries on the training ground.'),
      ),
      GlossaryEntry(
        term: Tr.pick('チームトーク', 'Team talk'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '試合前・ハーフタイムに監督が飛ばす檄。鼓舞する/冷静に指示する/叱咤するの3トーンがあり、先発イレブンの士気を変動させる。効果の大きさは選手の性格による結果感応度で変わる。',
            "What you say before the match and at half time. Three tones — inspire, talk them through it, tear into them — each moving the starting XI's morale. How far it moves depends on each player's personality."),
      ),
      GlossaryEntry(
        term: Tr.pick('マンマーク', 'Man-marking'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            'スカウティングレポートで判明した相手のキープレイヤーに、自チームの選手(DF・MF)を専任でマークさせる指示。マーカーが出場している間、相手キープレイヤーの攻撃力への貢献を抑えられる。',
            "Assigning one of your defenders or midfielders to the opponent's key player, as identified in the scout report. While your marker is on the pitch, their man contributes less going forward."),
      ),
      GlossaryEntry(
        term: Tr.pick('守備セットプレー担当', 'Defensive set piece duty'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            '相手のコーナーキック・フリーキックを守る担当選手。ヘディング・ジャンプ力が高いほど、相手のセットプレー由来のチャンスの質を下げられる。',
            'Who takes charge of defending their corners and free kicks. The better his heading and jumping reach, the less dangerous their set pieces become.'),
      ),
      GlossaryEntry(
        term: Tr.pick('逃げ切りモード', 'Seeing out the game'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            '有効にすると自チームの攻撃力がやや下がる代わりに守備が安定し、疲労の蓄積も抑えられる。リードした終盤の時間の使い方として使う。',
            'Trades a little attacking threat for a steadier defence and less fatigue. What you turn on to protect a lead late.'),
      ),
      GlossaryEntry(
        term: Tr.pick('負傷の種類', 'Types of injury'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '打撲(1-2週)・肉離れ(2-5週)・靭帯損傷(4-10週)の3種類があり、療養期間が異なる。基礎体力(naturalFitness)が高いほど負傷しにくく、同じ種類の負傷を繰り返すと再発しやすくなる。',
            'Three kinds, each with its own lay-off: a bruise (1-2 weeks), a torn muscle (2-5) and ligament damage (4-10). Better natural fitness means fewer injuries, and repeating the same one makes it more likely again.'),
      ),
      GlossaryEntry(
        term: Tr.pick('決定機', 'Big chance'),
        category: GlossaryCategory.liveMatch,
        description: Tr.pick(
            'ライブ観戦中に訪れる得点/失点のチャンス。自クラブの攻撃側ではシュート/パス/ロングシュートを、守備側では積極的にタックル/カバーリングに専念を選ぶ。成功率は関わる選手の能力値の勝負(シューター対GKなど)から算出され、選択前に表示される。',
            'The moments in a live match where a goal is on. Attacking, you choose to shoot, pass or try one from distance; defending, you choose to go in hard or hold your shape. The odds come from the attributes of the players involved — shooter against keeper, for instance — and are shown before you decide.'),
      ),
      GlossaryEntry(
        term: Tr.pick('メンタリティ', 'Mentality'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            'チーム全体の姿勢。超守備的〜超攻撃的の5段階から選び、攻撃的なほど攻撃力が上がる代わりに守備のリスクが増える(その逆も同様)。スタメン・戦術画面の戦術タブで設定でき、ライブ観戦・クイック消化の両方に効く。',
            'How the side approaches the match, across five steps from very defensive to very attacking. The more positive it is, the more attacking threat and the more defensive risk, and the reverse. Set it on the tactics tab; it applies whether you watch live or sim the match.'),
      ),
      GlossaryEntry(
        term: Tr.pick('スカッド・ステータス', 'Squad status'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '選手に約束する出場機会の立場(キープレイヤー/主力/ローテーション/育成枠)。上の立場ほどベンチに置いたときの不満が大きく、契約交渉で求める週給も高くなる。選手詳細画面で設定する。',
            'What you promise a player about his minutes: key player, first team, rotation or prospect. The higher the billing, the more he resents the bench and the more he asks for in wages. Set from his own page.'),
      ),
      GlossaryEntry(
        term: Tr.pick('週給予算', 'Wage budget'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '理事会が設定する週給総額の上限。シーズン開始時にディビジョンと現在の人件費から決まり、上限を超える新規獲得はブロックされる。クラブ経営画面で使用状況を確認できる。',
            'The ceiling the board puts on your total weekly wages. It is set at the start of the season from your division and current bill, and any signing that would break it is blocked. The finances screen shows where you stand.'),
      ),
      GlossaryEntry(
        term: Tr.pick('チームリーダー', 'Team leaders'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            'リーダーシップ・実力・年齢(とキャプテンの肩書)から決まるロッカールームの中心選手(上位3人)。リーダー陣が不機嫌だとチーム全体の士気が下がり、上機嫌だと上がる。リーダーを放出するとチームに動揺が走る。',
            "The three players the dressing room looks to, decided by leadership, ability, age and the captaincy. When they are unhappy the whole squad's morale sags; when they are content it lifts. Selling one unsettles everybody."),
      ),
      GlossaryEntry(
        term: Tr.pick('カップ目標', 'Cup target'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '理事会が期待する国内カップの到達ラウンド。リーグ内の戦力が高いクラブほど深いラウンドまで期待され、達成すれば信頼度が上がり、大きく届かないと下がる。',
            'How far the board expects you to go in the domestic cup. Stronger clubs are expected deeper; meeting it raises their confidence, falling well short lowers it.'),
      ),
      GlossaryEntry(
        term: Tr.pick('選手検索', 'Player search'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '全ディビジョンの全選手を名前・ポジション・年齢・総合力で絞り込めるスカウティングツール。補強ターゲットの調査に使い、実際の獲得は移籍市場・フリーエージェント経由で行う。',
            'A scouting tool that filters every player in every division by name, position, age and overall. Use it to find targets; you still sign them through the transfer market or as free agents.'),
      ),
      GlossaryEntry(
        term: Tr.pick('武者修行(ローン育成)', 'Development loans'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            'ローン放出中の選手は貸出先で毎週実戦に出て成長する(24歳未満は特に効果が大きい)。自クラブの施設・スタッフのボーナスは効かないが、実戦感覚を保ちながら能力が伸びるため、出番のない若手の育成手段になる。復帰時には放出中の成長がニュースで報告される。',
            'A player out on loan plays every week and improves for it, especially under 24. He does not get your facilities or staff, but he stays sharp and grows, which makes it the answer for a young player with no route into your side. His progress is reported when he comes back.'),
      ),
      GlossaryEntry(
        term: Tr.pick('成長推移', 'Progress over time'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '選手の総合力を節送りごとに記録した週次の推移。選手詳細画面に折れ線グラフで表示され、伸びている選手・停滞している選手が一目で分かる。自クラブの選手とユース昇格候補が対象で、概ね1シーズン分を保持する。',
            "A weekly record of a player's overall, matchday by matchday. His page draws it as a line, so you can see at a glance who is climbing and who has stalled. Kept for your own players and academy prospects, roughly a season's worth."),
      ),
      GlossaryEntry(
        term: Tr.pick('育成アドバイザー', 'Development adviser'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            'コーチ陣が育成面で手を打つべき選手を挙げてくれるトレーニング画面の提案。疲労が濃い選手、実戦感覚が落ちて成長が鈍っている選手、伸びしろが手つかずの若手(特訓ドリル・育成プラン未設定)、メンターのいない若手を検知する。',
            'Your coaches flagging players who need attention, shown on the training screen. It picks up heavy fatigue, growth stalling from lost sharpness, young players with untouched potential and no drill or plan set, and young players without a mentor.'),
      ),
      GlossaryEntry(
        term: Tr.pick('戦術スタイル', 'Style of play'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            'チームの攻撃の組み立て方の型(柔軟/ポゼッション/ゲーゲンプレス/カウンター/ロングボール/ウイングプレー)。スカッドの関連能力値が高いほど攻守の補正が大きく、向いていないスタイルは逆効果になる。スタイル間には相性(有利・不利の循環)があり、スカウティングレポートで相手の予想スタイルと対策を確認できる。柔軟は補正も弱点もない中立。',
            "How your side builds its attacks: flexible, possession, gegenpress, counter attack, direct or wing play. The better your squad's relevant attributes, the bigger the bonus; a style that does not suit them works against you. The styles also counter each other in a cycle, and the scout report tells you what the opponent is likely to play and what beats it. Flexible is neutral, with neither bonus nor weakness."),
      ),
      GlossaryEntry(
        term: Tr.pick('紅白戦', 'Practice match'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '週次トレーニングの一環として自動で行われるスカッド内の練習試合。スタメン外の選手が実戦感覚(マッチシャープネス)を保ち、実戦経験による成長の機会も得る(そのぶん少し疲労は残る)。負傷・代表招集・ローン放出中の選手は参加できない。',
            'An in-house match played automatically as part of the weekly session. Players outside the XI keep their match sharpness and get some growth from the minutes, at the cost of a little fatigue. Anyone injured, away with their country or out on loan sits it out.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ユース練習試合', 'Youth matches'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '昇格候補たちが毎週こなす近隣クラブのユースとの練習試合。全員に出場数・得点・評点が記録され、活躍(高評点)した候補は能力がさらに伸びる。戦績はユース画面で確認でき、昇格させるタイミングの判断材料になる。大活躍はクラブニュースにも届く。',
            "Your prospects play a nearby club's academy each week. Appearances, goals and ratings are recorded for all of them, and those who play well improve faster. The youth screen shows the record, which helps you judge when to promote someone. A standout performance makes the club news."),
      ),
      GlossaryEntry(
        term: Tr.pick('監督契約', 'Your contract'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '理事会と結ぶ監督(あなた)の契約。毎シーズン残り年数が1年ずつ減り、目標達成で3年契約に延長される。契約が切れた時に理事会の信頼が低いと解任、信頼があれば1年の暫定契約で続投となる。残り年数は監督キャリア画面で確認できる。',
            'The deal you hold with the board. It loses a year each season, and meeting their target extends it to three. If it runs out while their confidence is low you are sacked; if they still back you, they offer a one-year extension. Your career page shows what is left.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ウォッチリスト', 'Watchlist'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '気になる選手に星印をつけて追いかけるリスト。選手検索画面の星ボタンで登録・解除でき、「ウォッチ中」フィルタで一覧できる。ウォッチ中の選手が得点するとクラブニュースに届く。',
            'Star a player to keep an eye on him. Add and remove from the search screen, and use the watchlist filter to see them all. When one of them scores, it reaches your club news.'),
      ),
      GlossaryEntry(
        term: Tr.pick('采配方針', 'In-match approach'),
        category: GlossaryCategory.liveMatch,
        description: Tr.pick(
            'ライブ観戦中にいつでも切り替えられる試合中の指示。通常/リスクを取る/安全に下がるの3方針があり、以降の決定機の成功率に攻守それぞれへ補正がかかる。',
            'An instruction you can switch at any point while watching live: normal, take risks, or sit back. It shifts the odds on the big chances that follow, both ways.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ライブ交代', 'Live substitution'),
        category: GlossaryCategory.liveMatch,
        description: Tr.pick(
            'ライブ観戦中、ハーフタイムを待たずに決定機の合間で交代枠を使って行う選手交代。目前の決定機に関わっている選手は、その決定機が解決するまで交代できない。',
            'Changing a player mid-half rather than waiting for the break, using one of your subs between chances. Anyone caught up in the chance in front of you cannot come off until it resolves.'),
      ),
      GlossaryEntry(
        term: Tr.pick('モメンタム(試合の流れ)', 'Momentum'),
        category: GlossaryCategory.liveMatch,
        description: Tr.pick(
            'ライブ観戦画面のスコア下に表示される綱引きバー。ゴールなどで勢いづいた側に傾き、傾いている間はその側の決定機がわずかに決まりやすくなる。',
            'The tug-of-war bar under the scoreline while you watch live. It swings towards whoever has just had a moment, and while it leans their way their chances go in a little more often.'),
      ),
      GlossaryEntry(
        term: Tr.pick('クイック消化', 'Simming a match'),
        category: GlossaryCategory.liveMatch,
        description: Tr.pick(
            'ライブ観戦せず、試合結果だけを即座に確定させる進め方。カップ戦を含め、疲労・負傷・警告累積・出場記録などの試合後効果はライブ観戦と同じように適用される。',
            'Settling the result without watching. Everything that follows a match — fatigue, injuries, cards, appearances — applies exactly as it would live, cup ties included.'),
      ),
      GlossaryEntry(
        term: Tr.pick('値切り交渉', 'Haggling'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '移籍市場の選手を想定移籍金より安い提示額で獲得しようとする交渉。提示額の割合が高いほど成立しやすく、55%以下では必ず決裂する。決裂した選手とはその週は再交渉できない。',
            "Bidding below a player's valuation. The closer to the asking price, the likelier it is accepted; at 55% or under it always fails. Once talks break down you cannot go back to him that week."),
      ),
      GlossaryEntry(
        term: Tr.pick('移籍市場の入れ替わり', 'How the market turns over'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '移籍市場の顔ぶれは毎週数人だけが入れ替わる持続的な仕組み。狙っていた選手を翌週以降も追える一方、いつまでも市場に残っているとは限らない。',
            'Only a handful of names change each week. A target you have your eye on will usually still be there next week, though not forever.'),
      ),
      GlossaryEntry(
        term: Tr.pick('育成プラン(目標ロール)', 'Development plan'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '選手ごとに目標とするロール(プレースタイル)を設定する仕組み。週次トレーニングでそのロールが重視する能力値が優先的に伸びる。ポジションの大分類に合うロールのみ設定できる。',
            'Setting a target role for a player. Weekly training then favours the attributes that role values. You can only choose roles that suit his position group.'),
      ),
      GlossaryEntry(
        term: Tr.pick('勝ち上がり賞金', 'Progression prize money'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            'カップ戦で1勝(1タイ勝ち抜け)するごとに得られる賞金。ラウンドが深いほど高額で、優勝時はさらに優勝ボーナスが加わる。',
            'Paid every time you win a cup tie. The deeper the round, the more it is worth, and winning the thing adds a further bonus on top.'),
      ),
      GlossaryEntry(
        term: Tr.pick('天候', 'Weather'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            '試合当日の空模様(晴れ/雨/強風/猛暑/雪)。悪天候ほど攻撃力・チャンス数が下がり、雨は守備側がやや優位、猛暑は疲労が溜まりやすいなど試合展開が変わる。雨男・雪国育ちなど特定の天候で輝く選手特性もある。',
            'What the day brings: clear, rain, wind, a heatwave or snow. The worse it is, the less attacking threat and the fewer chances. Rain slightly favours defending, heat tires players faster, and some traits make a player shine in particular conditions.'),
      ),
      GlossaryEntry(
        term: Tr.pick('記者会見', 'Press conference'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '試合後に記者から受ける質問への受け答え。回答の選択によってチームの士気が上下するため、試合結果に合ったコメントを選ぶことが監督業の一部になる。',
            "Answering the press after a match. What you say moves the squad's morale, so picking a line that fits the result is part of the job."),
      ),
      GlossaryEntry(
        term: Tr.pick('スカウティングレポート(試合プレビュー)', 'Scout report'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            '次の対戦相手の戦力・キープレイヤー・直近のフォームをまとめた事前情報。ここで判明したキープレイヤーにマンマークを付けるなど、試合前の準備に使う。',
            'What you know about the next opponent: their strength, their key player and their recent form. Use it to prepare, for instance by putting a man-marker on the player it names.'),
      ),
      GlossaryEntry(
        term: Tr.pick('個別声かけ(モチベーショントーク)', 'A quiet word'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '監督が選手個人に声をかけて士気(モラール)を高めるコマンド。効果の大きさは選手の性格による感応度で変わり、一度使うと同じ選手には数週間のクールダウンがある。',
            'Taking a player aside to lift his morale. How much it moves depends on his personality, and you cannot go back to the same player for a few weeks.'),
      ),
      GlossaryEntry(
        term: Tr.pick('話し合い', 'A talk'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '不満を抱えた選手と面談して不満度を和らげるコマンド。士気を対象にする個別声かけとは別物で、こちらにもクールダウンがある。移籍希望のフラグが立った選手を引き留める初手になる。',
            'Sitting down with an unhappy player to ease his discontent. Separate from the quiet word, which targets morale, and it has its own cooldown. This is your first move when someone asks to leave.'),
      ),
      GlossaryEntry(
        term: Tr.pick('戦術ミーティング', 'Tactical meeting'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            'チーム全体で戦術理解を深めるミーティング。判断力・ポジショニング・チームワークといったメンタル系能力値がわずかに成長する。連発はできず、数週間のクールダウンがある。',
            'Working through the tactics with the whole squad. Decisions, positioning and teamwork all improve a little. You cannot hold them back to back; there is a cooldown of a few weeks.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ローテーション方針', 'Rotating focuses'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '選手個別のトレーニング方針を複数登録しておくと、週替わりで自動的に切り替わる仕組み。攻撃と守備を交互に鍛えるなど、毎週手動で切り替えなくてもバランス良く育成できる。',
            'Queue up several training focuses for a player and he cycles through them week by week. Alternating attack and defence, say, without you changing it by hand every week.'),
      ),
      GlossaryEntry(
        term: Tr.pick('自動トレーニング', 'Automatic training'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '有効にすると、節を進めた際に週次トレーニングが自動で実施される。細かく管理したい週だけ無効に戻して手動で行うこともできる。',
            'With this on, the weekly session runs itself as you play through the matchdays. Turn it off for any week you want to handle yourself.'),
      ),
      GlossaryEntry(
        term: Tr.pick('契約解除の違約金', 'Release compensation'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '契約が残っている選手を放出する際に支払う違約金。売却額から差し引かれ、残り契約が長いほど高額になるため、受け取り額がマイナスになることもある。放出のタイミングを見極める材料になる。',
            'What you owe for tearing up a contract that still has time to run. It comes off the fee, and the longer the deal has left the more it costs — enough that you can end up paying to let someone go. Worth weighing when you choose the moment.'),
      ),
    ];
