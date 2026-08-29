"""人時生産性と必要工数の計算。"""
from ._spec import Affiliate, Faq, Field, Output, Tool

ASP = "※ リンク先は提携先のサイトです。導入前に自社の要件をご確認ください。"

TOOL = Tool(
    slug="labor-productivity",
    title="人時生産性 計算ツール",
    description="生産数と投入工数から人時生産性・1個あたり工数・人件費を出し、目標を達成するのに必要な工数を計算します。",
    category="生産管理",
    lead="人時生産性は「1人が1時間で何個作れたか」です。"
         "人数でも時間でもなく人時（人数×時間）で割るので、"
         "残業や応援を含めた実態が出ます。",
    updated="2026-08-29",
    keywords=["人時生産性 計算", "人時生産性 とは", "労働生産性 計算", "1個あたり工数"],
    inputs=[
        Field("produced", "生産数", unit="個", default=1200, min=0),
        Field("workers", "投入人数", unit="人", default=6, min=0),
        Field("hours", "1人あたりの労働時間", unit="時間", default=8, min=0,
              hint="残業を含めた実労働時間"),
        Field("days", "対象日数", unit="日", default=20, min=1),
        Field("wage", "平均時給（人件費）", unit="円/時", default=1800, min=0,
              hint="社会保険料などの会社負担分を含めた額"),
        Field("target", "目標の生産数", unit="個", default=1500, min=0),
    ],
    outputs=[
        Output("productivity", "人時生産性",
               "produced / (workers * hours * days)",
               unit="個/人時", decimals=2, primary=True,
               note="1人が1時間で作れた数"),
        Output("total_hours", "総投入工数", "workers * hours * days",
               unit="人時", decimals=0),
        Output("hours_per_unit", "1個あたりの工数",
               "workers * hours * days / produced", unit="人時/個", decimals=3),
        Output("cost_per_unit", "1個あたりの人件費",
               "workers * hours * days * wage / produced", unit="円/個", decimals=1),
        Output("required_hours", "目標に必要な総工数",
               "target / (produced / (workers * hours * days))",
               unit="人時", decimals=0),
        Output("required_workers", "目標に必要な人数（同じ時間で）",
               "target / (produced / (workers * hours * days)) / (hours * days)",
               unit="人", decimals=2),
        Output("gap_hours", "追加で必要な工数",
               "target / (produced / (workers * hours * days)) - workers * hours * days",
               unit="人時", decimals=0,
               note="マイナスなら現状の工数で足ります"),
    ],
    formula_note="""人時生産性 ＝ 生産数 ÷ 総投入工数
総投入工数 ＝ 投入人数 × 1人あたり労働時間 × 日数

「人数」ではなく「人時」で割るのが要点です。
5人×8時間と4人×10時間はどちらも40人時なので、同じ土俵で比べられます。
残業で数を作った月と、定時で作った月を並べて評価できるようになります。

目標に必要な工数は、いまの生産性が変わらない前提での値です。
生産性そのものを上げれば、必要工数は下がります。""",
    steps=[
        "対象期間の生産数と、投入した人数・1人あたりの労働時間・日数を入れます。",
        "残業や他部署からの応援もすべて工数に含めます。含めないと生産性が実態より高く出ます。",
        "平均時給には、社会保険料などの会社負担分を含めた額を入れると原価に使えます。",
        "目標生産数を入れると、必要な工数と人数が出ます。",
        "毎月同じ条件で測り、推移で見ます。単月の値だけでは良し悪しが判断できません。",
    ],
    faq=[
        Faq("間接部門の工数は含めますか",
            "目的によります。製造現場の改善に使うなら直接工数だけ、"
            "事業全体の効率を見るなら間接も含めます。"
            "大事なのは毎回同じ範囲で測ることで、途中で定義を変えると推移が比較できなくなります。"),
        Faq("品種が違う製品を混ぜて計算してよいですか",
            "個数で割ると、作りやすい品種が多い月ほど生産性が高く出ます。"
            "品種構成が変わる場合は、個数ではなく標準時間の合計（標準工数）で"
            "割ったほうが実態に近くなります。"),
        Faq("人時生産性の目標値はありますか",
            "業種・製品によって桁が違うので、他社比較にはほとんど意味がありません。"
            "自社の前年同月比・前月比で見るのが実用的です。"),
    ],
    affiliate=Affiliate(
        heading="工数の実績を、集計せずに把握する",
        body="人時生産性を毎月出すには、誰が何時間どの作業に入ったかの記録が要ります。"
             "紙の日報から手集計していると、出す頃には改善のタイミングを逃します。"
             "勤怠・工数管理システムなら、打刻データからそのまま集計できます。",
        cta="工数・勤怠管理システムを比較する",
        url="https://example.com/",
        note=ASP,
    ),
)
