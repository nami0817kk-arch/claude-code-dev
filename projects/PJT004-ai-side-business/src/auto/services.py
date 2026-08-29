"""提供サービスのカタログ。

「AI が最後まで作れて、そのまま納品できる」ものだけを載せる。
1サービス = 1納品物。ここに定義を足せば、そのまま商品が増える。
"""
from dataclasses import dataclass, field

# 景品表示法・薬機法で問題になりやすい表現。納品前に機械チェックで弾く。
FORBIDDEN = [
    "絶対に儲かる", "絶対に稼げる", "必ず稼げる", "確実に稼げる",
    "誰でも簡単に稼げる", "100%成功", "必ず痩せる", "副作用は一切ありません",
    "業界No.1", "日本一", "最安値保証",
]


@dataclass
class Service:
    key: str
    name: str
    category: str
    description: str
    input_hint: str            # 依頼者からもらう入力
    output_name: str           # 納品物の呼び方
    system: str
    template: str              # {input} と {options} を埋める
    price_min: int
    price_max: int
    manual_hours: float        # 人が手作業でやった場合の想定時間
    auto_minutes: int          # 自動実行にかかる目安時間
    min_chars: int = 300
    max_chars: int = 20000
    required: list = field(default_factory=list)   # 見出しに必ず含まれる語
    qa_points: list = field(default_factory=list)  # AI レビューの採点観点
    max_tokens: int = 16000
    extension: str = "md"
    # アフィリエイトリンクを含む記事は、広告・PR表記が無いとステマ規制に触れる
    disclosure_required: bool = False

    @property
    def price_label(self) -> str:
        return f"{self.price_min:,}〜{self.price_max:,}円"


COMMON_RULES = """
守ること:
- 事実として確認できないことは書かない。数値や実績を捏造しない
- 「絶対に儲かる」「必ず痩せる」のような断定的な効果保証は書かない（景品表示法）
- 依頼内容に情報が足りない場合は、推測で埋めず【要確認】と明記する
- そのまま納品できる完成品として出力する。前置きや「以下が成果物です」等は書かない
"""

SERVICES = [
    Service(
        key="minutes",
        name="議事録作成",
        category="代行",
        description="会議の文字起こしやメモから、配布できる議事録に整える",
        input_hint="会議の文字起こし、または箇条書きのメモ",
        output_name="議事録",
        price_min=3000, price_max=8000, manual_hours=1.5, auto_minutes=2,
        min_chars=400,
        required=["決定事項", "ToDo"],
        system="あなたは企業の議事録作成の専門家です。" + COMMON_RULES + """
- 発言の要約は簡潔にし、雑談や重複は落とす
- 決定事項と、誰がいつまでに何をするかを最優先で拾う
- 曖昧なまま終わった論点は「継続検討」として残す""",
        template="""次の会議記録から議事録を作成してください。

## 会議記録
{input}

{options}

## 出力形式（Markdown）
# 議事録
- 日時 / 参加者 / 議題（記録から分かる範囲で。不明なら【要確認】）

## 決定事項
（箇条書き。決まったことだけ）

## ToDo
| 担当 | 内容 | 期限 |

## 議論の要点
（論点ごとに見出しを付けて要約）

## 継続検討
（結論が出なかったもの）""",
        qa_points=["決定事項とToDoが漏れなく拾えているか",
                   "担当と期限が特定できているか",
                   "発言の意図を変えていないか"],
    ),
    Service(
        key="blog",
        name="ブログ記事執筆",
        category="コンテンツ",
        description="キーワードから、検索意図に沿った記事を構成込みで書く",
        input_hint="テーマ・想定キーワード・読者像",
        output_name="記事",
        price_min=5000, price_max=15000, manual_hours=3, auto_minutes=3,
        min_chars=2000,
        required=["まとめ"],
        system="あなたは日本語SEOに詳しいWebライターです。" + COMMON_RULES + """
- 検索意図（何を知りたくて検索したか）に最初の200文字で答える
- 一次情報を持たない話題では、断定せず「一般に」「〜とされる」と書く
- キーワードの不自然な詰め込みはしない""",
        template="""次の条件でブログ記事を執筆してください。

## 依頼内容
{input}

{options}

## 出力形式（Markdown）
# タイトル（32文字以内・キーワードを前方に）

リード文（読者の悩みに触れ、記事で何が分かるかを150〜200文字で）

## 見出し（h2を4〜6本、必要に応じてh3）
各見出しの下に400〜600文字。具体例を1つ以上入れる。

## まとめ
要点を3つに絞って再掲し、読者の次の行動を1つ示す。""",
        qa_points=["検索意図に冒頭で答えているか",
                   "見出しだけ読んで内容が分かるか",
                   "根拠のない断定がないか"],
    ),
    Service(
        key="product",
        name="商品説明文作成",
        category="コンテンツ",
        description="EC・ネットショップ向けの商品説明文を作る",
        input_hint="商品名・スペック・価格・ターゲット",
        output_name="商品説明文",
        price_min=2000, price_max=5000, manual_hours=1, auto_minutes=2,
        min_chars=600,
        required=["こんな方"],
        system="あなたはECの売れる商品説明文を書くコピーライターです。" + COMMON_RULES + """
- スペックの羅列ではなく、それによって生活がどう変わるかを書く
- 与えられていないスペックを creative に足さない""",
        template="""次の商品の説明文を作成してください。

## 商品情報
{input}

{options}

## 出力形式（Markdown）
# キャッチコピー（30文字以内）

## 商品の特長
（3つ。それぞれ「特長 → だから何が嬉しいか」の順で）

## こんな方におすすめ
（3〜4個の箇条書き）

## 商品仕様
| 項目 | 内容 |

## ご購入前にご確認ください
（注意点。無ければ一般的な注意を1つ）""",
        qa_points=["ベネフィットが具体的か", "与えられていない情報を捏造していないか",
                   "誇大表現がないか"],
    ),
    Service(
        key="sns",
        name="SNS投稿作成",
        category="コンテンツ",
        description="1テーマから X / Instagram 向けの投稿を10本量産する",
        input_hint="発信テーマ・アカウントの立場・訴求したいこと",
        output_name="投稿10本",
        price_min=3000, price_max=10000, manual_hours=2, auto_minutes=2,
        min_chars=800,
        required=["投稿"],
        system="あなたはSNS運用の専門家です。" + COMMON_RULES + """
- 1投稿目の1行目で手を止めさせる。ありがちな問いかけで始めない
- 10本が同じ型の言い換えにならないよう、切り口を変える
- ハッシュタグは3〜5個まで""",
        template="""次のテーマでSNS投稿を10本作成してください。

## 依頼内容
{input}

{options}

## 出力形式（Markdown）
各投稿を次の形式で。切り口（体験談 / ノウハウ / 失敗談 / 数字 / 問いかけ / 反論 など）を変えること。

### 投稿1
**切り口**: ○○
```
（本文。140字前後）
```
ハッシュタグ: #○○ #○○

（以下、投稿10まで）""",
        qa_points=["10本の切り口が実際に違うか", "1行目で読ませる力があるか",
                   "文字数がプラットフォームに収まっているか"],
    ),
    Service(
        key="lp",
        name="LPコピー作成",
        category="コンテンツ",
        description="ランディングページの構成とコピーを一式作る",
        input_hint="商品・サービス内容、ターゲット、価格、実績",
        output_name="LP構成とコピー",
        price_min=20000, price_max=50000, manual_hours=8, auto_minutes=4,
        min_chars=2500,
        required=["ファーストビュー", "よくある質問"],
        system="あなたはダイレクトレスポンスマーケティングのコピーライターです。" + COMMON_RULES + """
- 読者の反論を先回りして潰す構成にする
- 実績・数字は依頼者から与えられたものだけを使い、無ければ【要確認】と書く""",
        template="""次のサービスのランディングページ構成とコピーを作成してください。

## サービス情報
{input}

{options}

## 出力形式（Markdown）
## ファーストビュー
- キャッチコピー（誰の何を、どう変えるか）
- サブコピー
- CTAボタン文言

## 共感パート
（読者が抱えている状況を言語化）

## 解決策の提示

## 選ばれる理由
（3つ）

## ご利用の流れ
（4ステップ）

## 料金

## よくある質問
（購入前の不安を潰す5問）

## 最後のひと押し + CTA""",
        qa_points=["ファーストビューで対象読者が自分事と分かるか",
                   "反論への回答が入っているか",
                   "捏造した実績がないか"],
    ),
    Service(
        key="mail",
        name="ステップメール作成",
        category="コンテンツ",
        description="見込み客を育てる5通のステップメールを作る",
        input_hint="商材・ターゲット・ゴール（何をしてほしいか）",
        output_name="ステップメール5通",
        price_min=15000, price_max=30000, manual_hours=6, auto_minutes=3,
        min_chars=2000,
        required=["1通目", "5通目"],
        system="あなたはメールマーケティングの専門家です。" + COMMON_RULES + """
- 売り込みは4通目以降。1〜3通目は読む理由を作ることに使う
- 件名は開封したくなる具体性を持たせる（煽り表現は使わない）""",
        template="""次の商材のステップメールを5通作成してください。

## 依頼内容
{input}

{options}

## 出力形式（Markdown）
各通ごとに次を書く。

### 1通目（配信タイミング: 登録直後）
**件名**:
**目的**:
**本文**:
（400〜600文字）

（5通目まで。配信タイミングも設計すること）""",
        qa_points=["1通目から売り込んでいないか", "件名に具体性があるか",
                   "5通で行動につながる流れになっているか"],
    ),
    Service(
        key="summary",
        name="資料要約",
        category="代行",
        description="長文の資料・レポートを、意思決定に使える要約にする",
        input_hint="要約したい文章（長文可）",
        output_name="要約レポート",
        price_min=2000, price_max=5000, manual_hours=1, auto_minutes=2,
        min_chars=300,
        required=["結論"],
        system="あなたは経営会議向けの資料要約を専門とするアナリストです。" + COMMON_RULES + """
- 原文に無い解釈を足さない。推測は「推測」と明示する
- 数字は原文のまま正確に引く""",
        template="""次の資料を要約してください。

## 原文
{input}

{options}

## 出力形式（Markdown）
## 結論
（3行以内。この資料が言っていることは何か）

## 要点
（5点以内の箇条書き。数字は原文のまま）

## 押さえるべき数字
| 項目 | 数値 | 出典箇所 |

## 判断に必要だが書かれていないこと
（あれば。無ければ「特になし」）""",
        qa_points=["原文にない主張を足していないか", "数字が正確か",
                   "結論だけ読んで判断できるか"],
    ),
    Service(
        key="faq",
        name="FAQ作成",
        category="代行",
        description="商品・サービス情報から、問い合わせを減らすFAQを作る",
        input_hint="サービス概要・料金・利用条件など",
        output_name="FAQ",
        price_min=5000, price_max=15000, manual_hours=2.5, auto_minutes=2,
        min_chars=1200,
        required=["Q1"],
        system="あなたはカスタマーサポートの設計者です。" + COMMON_RULES + """
- 実際に問い合わせが来る順に並べる（料金・解約・トラブルは上位）
- 与えられていない条件は断定せず【要確認】と書く""",
        template="""次のサービスのFAQを15問作成してください。

## サービス情報
{input}

{options}

## 出力形式（Markdown）
## よくあるご質問

### Q1. （質問）
A. （回答。100〜200文字。回答できない条件は【要確認】と明記）

（Q15まで。カテゴリ見出しで区切ってよい）""",
        qa_points=["問い合わせが多そうな順になっているか",
                   "回答が具体的で、たらい回しになっていないか",
                   "与えられていない条件を断定していないか"],
    ),
    Service(
        key="script",
        name="動画台本作成",
        category="コンテンツ",
        description="YouTube・ショート動画の台本を構成込みで作る",
        input_hint="テーマ・動画の長さ・チャンネルの立場",
        output_name="台本",
        price_min=5000, price_max=15000, manual_hours=3, auto_minutes=3,
        min_chars=1500,
        required=["冒頭"],
        system="あなたはYouTube動画の構成作家です。" + COMMON_RULES + """
- 冒頭15秒で離脱を防ぐ。結論を先に出す
- 話し言葉で書く。読み上げてそのまま成立する文にする""",
        template="""次のテーマで動画台本を作成してください。

## 依頼内容
{input}

{options}

## 出力形式（Markdown）
## 動画タイトル案（3案）

## 冒頭15秒（フック）
（読み上げ用の話し言葉）

## 本編
### パート1〜（各パートに見出し・尺の目安・読み上げ原稿）

## エンディング
（次の行動を1つだけ促す）

## 概要欄テキスト""",
        qa_points=["冒頭15秒で続きを見たくなるか", "読み上げて自然な話し言葉か",
                   "尺の配分が現実的か"],
    ),
]

BY_KEY = {s.key: s for s in SERVICES}


def get(key: str) -> Service:
    return BY_KEY.get(key)


def keys() -> list:
    return list(BY_KEY)


def print_services():
    print(f"\n{'='*74}")
    print("  提供サービス一覧（すべて AI が生成 → 品質チェック → 納品まで自動）")
    print(f"{'='*74}")
    current = None
    for s in sorted(SERVICES, key=lambda x: (x.category, x.key)):
        if s.category != current:
            current = s.category
            print(f"\n■ {current}")
        saved = s.manual_hours - s.auto_minutes / 60
        print(f"  {s.key:<9} {s.name:<12} {s.price_label:>18}  "
              f"手作業{s.manual_hours:g}h → 自動{s.auto_minutes}分（{saved:.1f}h削減）")
        print(f"  {'':<9} {s.description}")
    print(f"\n{'='*74}")
    print("  詳細: python main.py service show <key>")
    print("  依頼登録: python main.py job add <key> --input <ファイル> --price 5000")
    print(f"{'='*74}")


def print_service(s: Service):
    print(f"\n{'='*74}")
    print(f"  {s.name}  [{s.key}]  <{s.category}>")
    print(f"{'='*74}")
    print(f"  {s.description}\n")
    print(f"  想定単価   : {s.price_label}")
    print(f"  必要な入力 : {s.input_hint}")
    print(f"  納品物     : {s.output_name}（{s.extension}）")
    print(f"  所要時間   : 手作業 {s.manual_hours:g}時間 → 自動実行 約{s.auto_minutes}分")
    print(f"  品質基準   : {s.min_chars:,}文字以上 / 必須項目 {'、'.join(s.required) or 'なし'}")
    print("\n  【品質チェックの観点】")
    for p in s.qa_points:
        print(f"    ・{p}")
    print(f"\n{'='*74}")
