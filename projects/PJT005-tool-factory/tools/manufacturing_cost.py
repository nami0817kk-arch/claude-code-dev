"""製造原価と損益分岐点の計算。"""
from ._spec import Affiliate, Faq, Field, Output, Tool

ASP = "※ リンク先は提携先のサイトです。導入前に自社の要件をご確認ください。"

TOOL = Tool(
    slug="manufacturing-cost",
    title="製造原価・損益分岐点 計算ツール",
    description="材料費・労務費・製造経費から単位あたり原価を出し、売価に対する限界利益と損益分岐点数量を計算します。",
    category="原価管理",
    lead="原価を「材料費＋労務費＋経費」で足すだけでは、あと何個売れば黒字かは分かりません。"
         "変動費と固定費に分けて見ると、損益分岐点の数量が出ます。",
    updated="2026-08-29",
    keywords=["製造原価 計算", "損益分岐点 計算", "限界利益 計算", "原価計算 やり方"],
    inputs=[
        Field("material", "材料費（1個あたり）", unit="円/個", default=320, min=0,
              hint="部品・原材料など、作る個数に比例する費用"),
        Field("variable_labor", "変動労務費（1個あたり）", unit="円/個", default=180, min=0,
              hint="出来高・残業など、生産量に応じて増える人件費"),
        Field("other_variable", "その他変動費（1個あたり）", unit="円/個", default=60, min=0,
              hint="電力・消耗品・外注加工など"),
        Field("fixed_cost", "月間の固定費", unit="円/月", default=1800000, min=0,
              hint="正社員の給与・減価償却・家賃など、作らなくてもかかる費用"),
        Field("qty", "月間の生産数", unit="個/月", default=4000, min=1),
        Field("price", "売価", unit="円/個", default=980, min=0),
    ],
    outputs=[
        Output("unit_cost", "製造原価（1個あたり）",
               "material + variable_labor + other_variable + fixed_cost / qty",
               unit="円/個", decimals=1, primary=True,
               note="変動費 ＋ 固定費を生産数で割った額"),
        Output("variable_unit", "変動費（1個あたり）",
               "material + variable_labor + other_variable", unit="円/個", decimals=1),
        Output("fixed_unit", "固定費の配賦（1個あたり）", "fixed_cost / qty",
               unit="円/個", decimals=1, note="作る数が増えるほど下がります"),
        Output("contribution", "限界利益（1個あたり）",
               "price - (material + variable_labor + other_variable)",
               unit="円/個", decimals=1, note="1個売るごとに固定費の回収に回る額"),
        Output("bep_qty",
               "損益分岐点の数量",
               "fixed_cost / (price - (material + variable_labor + other_variable))",
               unit="個/月", decimals=0, note="この数を超えた分から利益が出ます"),
        Output("profit", "月間の営業利益",
               "qty * (price - (material + variable_labor + other_variable)) - fixed_cost",
               unit="円/月", decimals=0),
        Output("margin_rate", "限界利益率",
               "(price - (material + variable_labor + other_variable)) / price * 100",
               unit="%", decimals=1),
    ],
    formula_note="""変動費 ＝ 材料費 ＋ 変動労務費 ＋ その他変動費
製造原価 ＝ 変動費 ＋ 固定費 ÷ 生産数
限界利益 ＝ 売価 − 変動費
損益分岐点の数量 ＝ 固定費 ÷ 限界利益
営業利益 ＝ 生産数 × 限界利益 − 固定費

固定費は作っても作らなくてもかかるので、生産数で割った額（配賦）は
数量が増えるほど下がります。「たくさん作ると安くなる」のはこの部分だけで、
変動費は減りません。値下げ交渉の可否は限界利益で判断してください。""",
    steps=[
        "1個あたりの材料費・変動労務費・その他変動費を入れます。生産量に比例する費用だけを入れます。",
        "月間の固定費を入れます。正社員給与・減価償却・家賃など、作らなくてもかかる費用です。",
        "月間の生産数と売価を入れます。",
        "損益分岐点の数量を見て、現在の生産数がそれを超えているか確認します。",
        "限界利益率が低い品目は、数量を増やしても利益が伸びにくいので、単価か変動費の見直しが先です。",
    ],
    faq=[
        Faq("変動費と固定費の分け方が分かりません",
            "「生産数がゼロでもかかるか」で分けます。かかるなら固定費です。"
            "正社員の基本給は固定費、出来高給や残業代は変動費に近い扱いになります。"
            "厳密に分けきれない費用は、実績のグラフから傾きで推定する方法（スキャッターチャート法）もあります。"),
        Faq("値下げ要求に応じてよいか判断したい",
            "限界利益が残るかで判断します。売価が変動費を上回っている限り、"
            "その差額は固定費の回収に貢献します。ただし全品目で同じことをすると"
            "固定費を回収しきれなくなるので、限界利益率の高い品目とのバランスで見てください。"),
        Faq("固定費の配賦はこの方法でよいですか",
            "生産数で均等に割る単純な方法です。品目ごとに設備の使用時間が大きく違う場合は、"
            "機械時間や直接作業時間を基準にした配賦のほうが実態に合います。"),
    ],
    affiliate=Affiliate(
        heading="品目ごとの原価を実績から出す",
        body="この計算は1品目の概算です。品目が増えると、実績の材料出庫や作業時間を"
             "品目に紐づける作業が必要になります。原価管理機能を持つ会計・生産管理システムなら、"
             "日々の実績から品目別の原価と粗利が自動で出ます。",
        cta="原価管理システムを比較する",
        url="https://example.com/",
        note=ASP,
    ),
)
