"""新しいツールのひな型を作る。

  python new_tool.py cpk "工程能力指数 Cpk 計算ツール" --category 品質管理

tools/<name>.py が生成されるので、入力・出力・式・FAQ を埋めれば1本増える。
収益導線を空のままにするとビルド時に警告が出る。広告だけでは分岐点に届かないため。
"""
import argparse
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent

TEMPLATE = '''"""{title}"""
from ._spec import Affiliate, Faq, Field, Output, Tool

TOOL = Tool(
    slug="{slug}",
    title="{title}",
    description="",              # 80〜120文字。検索結果に出る一文
    category="{category}",
    lead="",                     # 冒頭で検索意図に答える2〜3文
    updated="{today}",
    keywords=[],                 # media keywords で設計したものを入れる
    inputs=[
        Field("value_a", "入力A", unit="", default=100, min=0,
              hint=""),
        # Field("mode", "選択肢", kind="select", default=1, options=[("表示", 1)]),
    ],
    outputs=[
        Output("result", "結果", "value_a * 2", unit="", decimals=1, primary=True,
               note=""),
    ],
    formula_note="""結果 ＝ 入力A × 2

式の意味や、実務で気をつける点をここに書く。""",
    steps=[
        "",
    ],
    faq=[
        Faq("", ""),
    ],
    # 収益導線。ここを設定するとPR表記が自動で入る。
    # 未設定のままだと広告収益しか乗らず、分岐点に届かない。
    affiliate=Affiliate(
        heading="",
        body="",
        cta="",
        url="https://example.com/",
        note="※ リンク先は提携先のサイトです。導入前に自社の要件をご確認ください。",
    ),
)
'''


def main():
    parser = argparse.ArgumentParser(description="ツールのひな型を作る")
    parser.add_argument("slug", help="URL になる名前（半角英小文字とハイフン）")
    parser.add_argument("title", help="ツール名")
    parser.add_argument("--category", default="その他", help="カテゴリ（既定: その他）")
    args = parser.parse_args()

    if not re.fullmatch(r"[a-z0-9-]+", args.slug):
        raise SystemExit("slug は半角英小文字・数字・ハイフンのみです")

    path = ROOT / "tools" / f"{args.slug.replace('-', '_')}.py"
    if path.exists():
        raise SystemExit(f"すでに存在します: {path}")

    path.write_text(TEMPLATE.format(
        slug=args.slug, title=args.title, category=args.category,
        today=datetime.now().strftime("%Y-%m-%d")), encoding="utf-8")

    print(f"作成しました: {path}")
    print("\n  次の順で埋めてください:")
    print("    1. description と lead（検索意図に答える）")
    print("    2. inputs と outputs（式は JS の式として書く）")
    print("    3. affiliate（誰に何を勧めるか。ここが収益点）")
    print("    4. faq と steps")
    print(f"\n  確認: python build.py --serve")


if __name__ == "__main__":
    main()
