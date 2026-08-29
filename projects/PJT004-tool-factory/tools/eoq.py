"""経済的発注量（EOQ）の計算。"""
from ._spec import Affiliate, Faq, Field, Output, Tool

TOOL = Tool(
    slug="eoq",
    title="EOQ（経済的発注量）計算ツール",
    description="年間需要量・発注1回あたりの費用・在庫維持費から、総費用が最小になる発注量を計算します。",
    category="在庫管理",
    lead="1回にまとめて多く買うと発注の手間は減りますが在庫費用が増え、"
         "小分けに買うとその逆になります。両者の合計が最小になる発注量が EOQ です。",
    updated="2026-08-29",
    keywords=["EOQ 計算", "経済的発注量", "発注量 最適", "経済的発注量 求め方"],
    inputs=[
        Field("annual_demand", "年間の使用量", unit="個/年", default=12000, min=0),
        Field("order_cost", "発注1回あたりの費用", unit="円/回", default=5000, min=0,
              hint="発注処理・検収・入庫の手間を金額換算したもの"),
        Field("unit_cost", "単価", unit="円/個", default=500, min=0),
        Field("holding_rate", "年間在庫維持費率", unit="%", default=20, min=0,
              hint="保管料・金利・陳腐化の合計。一般に15〜25%が目安"),
    ],
    outputs=[
        Output("eoq",
               "経済的発注量（EOQ）",
               "Math.sqrt((2 * annual_demand * order_cost) / (unit_cost * holding_rate / 100))",
               unit="個", decimals=0, primary=True,
               note="1回あたりこの量で発注すると総費用が最小になります"),
        Output("orders_per_year", "年間の発注回数", "annual_demand / eoq",
               unit="回/年", decimals=1),
        Output("interval_days", "発注間隔", "365 / (annual_demand / eoq)",
               unit="日", decimals=0),
        Output("total_cost",
               "年間の総費用（発注＋在庫維持）",
               "(annual_demand / eoq) * order_cost + (eoq / 2) * unit_cost * holding_rate / 100",
               unit="円/年", decimals=0),
    ],
    formula_note="""EOQ ＝ √( 2 × 年間需要量 × 発注1回あたり費用 ÷ 年間在庫維持費 )
年間在庫維持費 ＝ 単価 × 在庫維持費率

年間需要量が4倍になっても EOQ は2倍にしかなりません（√で効くため）。
まとめ買いの効果は、量を増やすほど鈍っていきます。""",
    steps=[
        "年間の使用量を入れます。過去実績か需要予測のどちらでも構いません。",
        "発注1回あたりの費用を入れます。発注処理・検収・入庫にかかる人件費を時間換算するのが実務的です。",
        "単価と、年間の在庫維持費率を入れます。維持費率が分からなければ20%から始めてください。",
        "出た EOQ を、実際の発注ロット（箱単位・パレット単位）に丸めて使います。",
    ],
    faq=[
        Faq("在庫維持費率はどう決めますか",
            "保管スペースの費用、在庫に寝ている資金の金利、陳腐化・劣化のリスクを"
            "合計して単価に対する割合で表します。一般に15〜25%が目安ですが、"
            "自社の倉庫費用と資金コストから積み上げるのが正確です。"),
        Faq("EOQ どおりに発注できません",
            "実務では箱・パレット単位の制約や、最低発注数量があります。"
            "EOQ は目安として出し、実際は近い実発注単位に丸めてください。"
            "総費用の曲線は EOQ 付近で平坦なので、多少ずれても影響は小さいです。"),
        Faq("需要が季節変動する場合は",
            "この式は需要が年間で一定という前提です。季節性が強い品目では、"
            "期間を分けて計算するか、需要予測に基づく別の方式を検討してください。"),
    ],
    affiliate=Affiliate(
        heading="発注量の見直しを、勘から数字に",
        body="EOQ は品目ごとに違います。取扱品目が数十を超えると手計算では回りません。"
             "在庫管理システムには発注点・発注量の自動計算を持つものがあり、"
             "実績データからそのまま算出できます。",
        cta="在庫管理システムを比較する",
        url="https://example.com/",
        note="※ リンク先は提携先のサイトです。導入前に自社の要件をご確認ください。",
    ),
)
