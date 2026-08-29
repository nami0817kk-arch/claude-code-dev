"""設備投資の回収期間（ペイバック）の計算。"""
from ._spec import Affiliate, Faq, Field, Output, Tool

ASP = "※ リンク先は提携先のサイトです。導入前に自社の要件をご確認ください。"

TOOL = Tool(
    slug="payback-period",
    title="設備投資の回収期間 計算ツール",
    description="投資額と年間の削減効果から、回収期間・投資利益率・期間内の累計効果を計算します。稟議の判断材料に。",
    category="原価管理",
    lead="設備やシステムの導入を通すには「何年で回収できるか」の一言が要ります。"
         "削減できる人件費・不良費・外注費を入れると、回収期間と期間内の累計効果が出ます。",
    updated="2026-08-29",
    keywords=["回収期間 計算", "投資回収 何年", "ペイバック 計算", "設備投資 判断"],
    inputs=[
        Field("investment", "初期投資額", unit="円", default=3000000, min=0,
              hint="本体・工事・初期設定の合計"),
        Field("labor_saving", "年間の人件費削減", unit="円/年", default=1200000, min=0,
              hint="削減できる工数 × 時給。残業削減分も含めます"),
        Field("defect_saving", "年間の不良・ロス削減", unit="円/年", default=300000, min=0),
        Field("other_saving", "年間のその他削減", unit="円/年", default=100000, min=0,
              hint="外注費・光熱費・保管費など"),
        Field("running_cost", "年間の運用費", unit="円/年", default=240000, min=0,
              hint="保守料・ライセンス料・消耗品など、導入後にかかる費用"),
        Field("years", "評価する期間", unit="年", default=5, min=1,
              hint="設備の耐用年数や、社内の投資判断基準に合わせます"),
    ],
    outputs=[
        Output("payback", "回収期間",
               "investment / (labor_saving + defect_saving + other_saving - running_cost)",
               unit="年", decimals=2, primary=True,
               note="3年以内を基準にする会社が多い項目です"),
        Output("net_saving", "年間の正味削減額",
               "labor_saving + defect_saving + other_saving - running_cost",
               unit="円/年", decimals=0, note="削減効果から運用費を引いた額"),
        Output("payback_months",
               "回収期間（月）",
               "investment / (labor_saving + defect_saving + other_saving - running_cost) * 12",
               unit="ヶ月", decimals=0),
        Output("cumulative",
               "評価期間内の累計効果",
               "(labor_saving + defect_saving + other_saving - running_cost) * years "
               "- investment",
               unit="円", decimals=0,
               note="マイナスなら期間内に回収できません"),
        Output("roi",
               "投資利益率（期間全体）",
               "((labor_saving + defect_saving + other_saving - running_cost) * years "
               "- investment) / investment * 100",
               unit="%", decimals=1),
        Output("break_even_saving", "回収に必要な年間削減額",
               "investment / years + running_cost", unit="円/年", decimals=0,
               note="評価期間内に回収するために最低限必要な削減額"),
    ],
    formula_note="""正味削減額 ＝ 人件費削減 ＋ 不良削減 ＋ その他削減 − 運用費
回収期間   ＝ 初期投資額 ÷ 正味削減額
累計効果   ＝ 正味削減額 × 評価期間 − 初期投資額

運用費を引くのを忘れると回収期間が実際より短く出ます。
保守料やライセンス料は毎年かかるので、必ず差し引いてください。

この計算は貨幣の時間価値を考慮しない単純回収期間法です。
金額が大きい案件や期間が長い案件では、正味現在価値（NPV）での評価も併用されます。""",
    steps=[
        "初期投資額に、本体価格だけでなく工事費・初期設定費用も含めます。",
        "年間の削減効果を項目ごとに入れます。人件費は「削減できる工数 × 時給」で見積もります。",
        "運用費（保守料・ライセンス料）を入れます。ここを忘れると判断を誤ります。",
        "回収期間が社内の投資判断基準に収まっているか確認します。",
        "収まらない場合は、回収に必要な年間削減額を見て、他に計上できる効果がないか検討します。",
    ],
    faq=[
        Faq("人件費の削減額はどう見積もりますか",
            "削減できる作業時間 × 時給（会社負担分を含む）で計算します。"
            "ただし人が減らない限り実際の支出は減らないため、"
            "残業削減として計上するか、空いた時間で他の価値を生む前提を明示するのが実務的です。"),
        Faq("回収期間は何年以内なら通りますか",
            "会社の基準によりますが、3年以内を目安とする例が多いです。"
            "設備の耐用年数より長い回収期間は通りません。"
            "社内の投資規定を先に確認してください。"),
        Faq("削減効果が読めない場合は",
            "回収に必要な年間削減額を見て、その水準が現実的かで逆に判断してください。"
            "「年間120万円削減できるなら通る」と分かれば、検証すべき数字が絞れます。"),
        Faq("この計算方法の限界は",
            "貨幣の時間価値を考慮しない単純回収期間法です。"
            "回収後の効果も評価されないため、回収期間が長くても長期的に大きな効果がある案件が"
            "不利に出ます。大型案件では NPV や IRR も併用してください。"),
    ],
    affiliate=Affiliate(
        heading="削減効果の根拠を実績で示す",
        body="稟議で問われるのは「その削減額の根拠は何か」です。"
             "現状の工数や不良の実績データが無いと、見積もりが感覚論になります。"
             "導入前に実績を数字で押さえておくと、投資判断も導入後の効果検証も通しやすくなります。",
        cta="生産管理システムを比較する",
        url="https://example.com/",
        note=ASP,
    ),
)
