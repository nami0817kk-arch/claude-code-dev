"""ツールの定義に使うデータ構造。

1本のツールは「入力 → 計算式 → 出力」で表せるものが大半なので、
そこを宣言で書けるようにする。計算式は JS の式としてそのまま埋め込まれるので、
複雑なものは式の中で好きに書ける。

  Tool(
      slug="safety-stock",
      title="安全在庫・発注点 計算ツール",
      inputs=[Field("daily", "1日あたり平均使用量", unit="個", default=100)],
      outputs=[Output("rop", "発注点", "daily * lead_time", unit="個")],
  )
"""
from dataclasses import dataclass, field


@dataclass
class Field:
    """入力欄1つ。"""
    key: str                       # JS の変数名になる
    label: str
    unit: str = ""
    default: float = 0
    kind: str = "number"           # number / select
    options: list = field(default_factory=list)   # select のとき [(表示, 値), ...]
    step: str = "any"
    min: float = None
    max: float = None
    hint: str = ""

    def __post_init__(self):
        if not self.key.isidentifier():
            raise ValueError(f"key は JS の変数名にできる形にしてください: {self.key}")


@dataclass
class Output:
    """出力1つ。expression は JS の式。先に定義した出力も参照できる。"""
    key: str
    label: str
    expression: str
    unit: str = ""
    decimals: int = 1
    note: str = ""
    primary: bool = False          # 主たる答え。大きく表示する

    def __post_init__(self):
        if not self.key.isidentifier():
            raise ValueError(f"key は JS の変数名にできる形にしてください: {self.key}")


@dataclass
class Faq:
    question: str
    answer: str


@dataclass
class Affiliate:
    """アフィリエイト導線。設定するとページに PR 表記が自動で入る。"""
    heading: str
    body: str
    cta: str
    url: str
    note: str = ""


@dataclass
class Tool:
    slug: str                      # URL になる。半角英小文字とハイフン
    title: str                     # h1 と <title> に使う
    description: str               # meta description。80〜120文字
    category: str                  # 一覧ページのグループ分けと内部リンクに使う
    lead: str = ""                  # 冒頭の説明。検索意図に最初に答える
    inputs: list = field(default_factory=list)
    outputs: list = field(default_factory=list)
    formula_note: str = ""         # 計算式の説明（そのまま表示する）
    steps: list = field(default_factory=list)   # 使い方の手順
    faq: list = field(default_factory=list)
    affiliate: Affiliate = None
    keywords: list = field(default_factory=list)
    updated: str = ""              # YYYY-MM-DD

    def __post_init__(self):
        import re
        if not re.fullmatch(r"[a-z0-9-]+", self.slug):
            raise ValueError(f"slug は半角英小文字・数字・ハイフンのみ: {self.slug}")
        if not self.inputs:
            raise ValueError(f"{self.slug}: 入力欄が1つもありません")
        if not self.outputs:
            raise ValueError(f"{self.slug}: 出力が1つもありません")

        keys = [f.key for f in self.inputs] + [o.key for o in self.outputs]
        duplicated = {k for k in keys if keys.count(k) > 1}
        if duplicated:
            raise ValueError(f"{self.slug}: key が重複しています: {duplicated}")

        if not any(o.primary for o in self.outputs):
            self.outputs[0].primary = True

    @property
    def has_affiliate(self) -> bool:
        return self.affiliate is not None

    @property
    def url_path(self) -> str:
        return f"/{self.slug}/"
