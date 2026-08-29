"""設備総合効率（OEE）の計算。"""
from ._spec import Affiliate, Faq, Field, Output, Tool

ASP = "※ リンク先は提携先のサイトです。導入前に自社の要件をご確認ください。"

TOOL = Tool(
    slug="oee",
    title="OEE（設備総合効率）計算ツール",
    description="負荷時間・停止時間・生産数・サイクルタイム・不良数から、時間稼働率・性能稼働率・良品率とOEEを計算します。",
    category="生産管理",
    lead="OEE は「時間稼働率 × 性能稼働率 × 良品率」で求めます。"
         "3つのどれが足を引っ張っているかが分かれば、手を入れる場所が決まります。"
         "数値を入れると内訳ごとに表示されます。",
    updated="2026-08-29",
    keywords=["OEE 計算", "設備総合効率", "時間稼働率 性能稼働率", "OEE 求め方"],
    inputs=[
        Field("load_min", "負荷時間", unit="分", default=480, min=1,
              hint="就業時間から計画停止（朝礼・計画保全）を引いた、動かすつもりだった時間"),
        Field("stop_min", "停止時間", unit="分", default=60, min=0,
              hint="故障・段取替え・チョコ停の合計"),
        Field("produced", "生産数", unit="個", default=380, min=0),
        Field("cycle_sec", "理論サイクルタイム", unit="秒/個", default=60, min=0,
              hint="設備の能力上、1個作るのにかかる最短時間"),
        Field("defects", "不良数", unit="個", default=8, min=0,
              hint="手直しした分も不良に含めます"),
    ],
    outputs=[
        Output("oee", "OEE（設備総合効率）",
               "(load_min - stop_min) / load_min * "
               "((cycle_sec * produced / 60) / (load_min - stop_min)) * "
               "((produced - defects) / produced) * 100",
               unit="%", decimals=1, primary=True,
               note="世界的な優良水準は85%とされます"),
        Output("availability", "時間稼働率",
               "(load_min - stop_min) / load_min * 100", unit="%", decimals=1,
               note="止まらずに動けたか"),
        Output("performance", "性能稼働率",
               "(cycle_sec * produced / 60) / (load_min - stop_min) * 100",
               unit="%", decimals=1, note="設計どおりの速さで動けたか"),
        Output("quality", "良品率", "(produced - defects) / produced * 100",
               unit="%", decimals=1, note="作ったものが使えたか"),
        Output("valuable_min", "価値稼働時間", "cycle_sec * (produced - defects) / 60",
               unit="分", decimals=0, note="良品を作るのに実際に使えた時間"),
        Output("loss_min", "ロス時間", "load_min - cycle_sec * (produced - defects) / 60",
               unit="分", decimals=0, note="負荷時間のうち価値を生まなかった時間"),
    ],
    formula_note="""OEE ＝ 時間稼働率 × 性能稼働率 × 良品率

時間稼働率 ＝ (負荷時間 − 停止時間) ÷ 負荷時間
性能稼働率 ＝ (理論サイクルタイム × 生産数) ÷ 稼働時間
良品率     ＝ (生産数 − 不良数) ÷ 生産数

3つの掛け算なので、どれか1つが低いと全体が大きく落ちます。
各90%でも OEE は 73% です。まず一番低い項目から手を入れてください。""",
    steps=[
        "負荷時間を入れます。就業時間から、あらかじめ計画していた停止時間を引いた値です。",
        "停止時間に、故障・段取替え・チョコ停の合計を入れます。記録が無ければまず1週間取ってみてください。",
        "その時間で作った生産数と、不良数（手直し分を含む）を入れます。",
        "理論サイクルタイムは設備の能力値です。カタログ値か、最も速く流れたときの実測を使います。",
        "3つの内訳を見て、最も低い項目から改善に着手します。",
    ],
    faq=[
        Faq("計画停止は負荷時間に含めますか",
            "含めません。朝礼・計画保全・生産計画が無い時間は負荷時間から除きます。"
            "含めてしまうと、計画的に休んだ分まで稼働ロスとして数えることになります。"),
        Faq("性能稼働率が100%を超えます",
            "理論サイクルタイムが実態より長い（遅い）値になっています。"
            "設備の能力を過小に見積もっていないか確認してください。"),
        Faq("OEE の目標値はどのくらいですか",
            "世界的な優良水準として85%が引かれることが多いですが、"
            "設備や品種によって現実的な上限は変わります。"
            "他社比較よりも、自社の前月比で改善しているかを見るほうが実用的です。"),
        Faq("手直しした品は良品に入れますか",
            "入れません。一度で良品にならなかったものは不良として数えます。"
            "手直しの工数はロスなので、良品としてしまうと改善対象が見えなくなります。"),
    ],
    affiliate=Affiliate(
        heading="OEE を毎日自動で出す",
        body="OEE は毎日測って推移で見ないと改善につながりません。"
             "設備の稼働データを自動収集する仕組みを入れると、日報の集計作業なしに"
             "日次のOEEと停止要因の内訳が出ます。手集計では続かないのが実情です。",
        cta="生産管理システムを比較する",
        url="https://example.com/",
        note=ASP,
    ),
)
