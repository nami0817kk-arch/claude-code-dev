"""メディア記事の生成。

受託の納品物と違い、記事は自分の資産になる。ゆえに求められるものが違う。

- 検索意図に答えること（順位が付かなければ 1 円にもならない）
- 収益記事から集客記事へ、集客記事から収益記事へ内部リンクを張ること
- アフィリエイトリンクを含む記事には広告表記を入れること（ステマ規制）

生成・検品・修正のループは src/auto/pipeline.py をそのまま使う。
"""
from pathlib import Path

from .. import store
from ..auto import pipeline, qa
from ..auto.services import COMMON_RULES, Service
from . import keywords as kw_mod

ARTICLE_DIR = Path(__file__).resolve().parent.parent.parent / "articles"
NAME = "articles"

MEDIA_RULES = COMMON_RULES + """
- 検索した人が最初の200文字で「答えに辿り着いた」と感じる書き出しにする
- 実体験していないことを体験談として書かない。使ったことのない商品は
  「公表されている仕様では」と書く
- 医療・健康・金融・法律に関わる内容では断定を避け、専門家への相談を促す
- 出典が必要な数値には【要出典】と付け、運営者が後から確認できるようにする
"""

# 記事タイプごとの構成
TEMPLATES = {
    "レビュー": """# タイトル（32文字以内・キーワードを前方に）

（収益記事の場合は冒頭に「※本記事はプロモーションを含みます」を置く）

リード文（読者の検討状況に触れ、この記事で何が分かるかを150〜200文字で）

## 結論
（どういう人に向くか・向かないかを先に書く）

## 基本情報
| 項目 | 内容 |

## 良い点
（3つ。それぞれ根拠とセットで）

## 気になる点
（2つ以上。必ず書く。欠点を書かない記事は信用されない）

## 他の選択肢との違い

## こんな人におすすめ / おすすめしない

## よくある質問
（3問）

## まとめ""",

    "比較": """# タイトル（32文字以内）

（収益記事の場合は冒頭に「※本記事はプロモーションを含みます」を置く）

リード文（何を基準に比較したかを明示）

## 結論：目的別のおすすめ
（「◯◯重視なら A」の形で3パターン）

## 比較表
| 項目 | A | B | C |

## それぞれの詳細
### A
（向く人・向かない人）
（B、C も同様に）

## 選び方の基準
（3つ）

## よくある質問
（3問）

## まとめ""",

    "解説": """# タイトル（32文字以内）

リード文（検索意図に150〜200文字で答える）

## 結論
（先に答えを出す）

## 詳しい解説
（h2を3〜5本。各400〜600文字。具体例を必ず1つ入れる）

## 注意点

## よくある質問
（3問）

## まとめ""",

    "手順": """# タイトル（32文字以内）

リード文（何ができるようになるか・所要時間・必要なもの）

## 必要なもの

## 手順
### STEP1 〜
（各ステップに、やること・つまずきやすい点を書く）

## うまくいかないときは
（想定される失敗と対処を3つ）

## よくある質問
（3問）

## まとめ""",

    "まとめ": """# タイトル（32文字以内）

リード文（何をどんな基準で集めたか）

## 選定基準

## 一覧
### 1. 〜
（各項目に、特徴・向く人・注意点）

## 比較表
| 項目 | 特徴 | 向く人 |

## まとめ""",
}


def build_service(kw: dict, related: list = None) -> Service:
    """キーワード1件から、そのまま pipeline に渡せるサービス定義を作る。"""
    article_type = kw.get("article_type", "解説")
    is_money = kw.get("role") == "収益記事"
    template_body = TEMPLATES.get(article_type, TEMPLATES["解説"])

    required = ["まとめ"]
    min_chars = 3000 if article_type in ("比較", "まとめ") else 2500

    link_note = ""
    if related:
        lines = "\n".join(f"- {r['keyword']}（{r.get('title','')}）" for r in related[:5])
        link_note = f"""
## 内部リンク
本文中の自然な位置で、次の記事へのリンクを2〜3本入れてください。
リンクは `[アンカーテキスト](記事URL)` の形式で書き、URL は後から差し替える前提の
仮の値で構いません。リンクだけを並べた「関連記事」節にはせず、文脈の中に置くこと。

{lines}
"""

    # pipeline は template.format(input=..., options=...) を呼ぶので、
    # 本文側の波かっこはエスケープしておく（Markdown のプレースホルダ等）
    def escape(text: str) -> str:
        return text.replace("{", "{{").replace("}", "}}")

    body = escape(template_body)
    note = escape(link_note)

    return Service(
        key=f"article_{kw.get('id', 0)}",
        name=f"{article_type}記事",
        category="メディア",
        description=f"{kw['keyword']} の{article_type}記事",
        input_hint="キーワードと記事の狙い",
        output_name="記事",
        price_min=0, price_max=0, manual_hours=3, auto_minutes=3,
        min_chars=min_chars,
        required=required,
        disclosure_required=is_money,
        system=f"あなたは日本語SEOに強いWebライターです。{MEDIA_RULES}",
        template="""次のキーワードで記事を書いてください。

## 狙うキーワード
{input}

{options}
""" + note + f"""
## 記事の役割
{'収益記事（読者を申込・購入につなげる。アフィリエイトリンクを想定）'
 if is_money else '集客記事（検索から人を集め、収益記事へ内部リンクで送る）'}

## 出力形式（Markdown）
{body}
""",
        qa_points=[
            "検索意図に冒頭200文字で答えているか",
            "見出しだけ読んで内容が分かるか",
            "体験していないことを体験談として書いていないか",
            ("広告表記があり、欠点にも触れて中立性が保たれているか"
             if is_money else "収益記事への導線が自然に入っているか"),
        ],
        max_tokens=16000,
    )


def write(kw: dict, options: str = "", related: list = None,
          use_ai_qa: bool = True, verbose: bool = True) -> dict:
    """記事を1本生成し、ファイルに保存する。"""
    service = build_service(kw, related)
    input_text = (
        f"キーワード: {kw['keyword']}\n"
        f"記事タイトル案: {kw.get('title', '')}\n"
        f"検索意図: {kw_mod.INTENT_LABEL.get(kw.get('intent',''), kw.get('intent',''))}\n"
        f"狙う理由: {kw.get('reason', '')}"
    )

    if verbose:
        role = "収益記事" if kw.get("role") == "収益記事" else "集客記事"
        print(f"\n[{kw['id']}] {kw['keyword']}  <{service.name} / {role}>")

    result = pipeline.run(service, input_text, options,
                          use_ai_qa=use_ai_qa, verbose=verbose)

    ARTICLE_DIR.mkdir(parents=True, exist_ok=True)
    from ..auto.deliver import safe_name
    path = ARTICLE_DIR / f"{kw['id']:03d}_{safe_name(kw['keyword'])}.md"
    path.write_text(result["output"], encoding="utf-8")

    record = {
        "keyword_id": kw["id"],
        "keyword": kw["keyword"],
        "title": kw.get("title", ""),
        "role": kw.get("role", ""),
        "path": str(path),
        "chars": result["chars"],
        "cost_jpy": result["cost_jpy"],
        "qa_score": result["qa"].get("score", 0),
        "revisions": result["revisions"],
        "needs_human": result["needs_human"],
        "written_at": store.now(),
        "published_at": "",
        "pv": 0,
        "revenue": 0,
        "rank": 0,
    }

    saved = [a for a in load() if a["keyword_id"] != kw["id"]]
    saved.append(record)
    saved.sort(key=lambda a: a["keyword_id"])
    store.save(NAME, saved)

    if verbose:
        print(f"  完了: {result['chars']:,}文字 / 原価 {result['cost_jpy']:.1f}円 / "
              f"品質 {result['qa'].get('score', 0)}点")
        if result["needs_human"]:
            print("  ⚠ 公開前に確認が必要です")
            qa.print_qa(result["qa"])
        print(f"  保存: {path}")

    return record


def load() -> list:
    return store.load(NAME, [])


def find(kw_id) -> dict:
    for a in load():
        if a["keyword_id"] == int(kw_id):
            return a
    return None


def write_batch(kw_ids: list = None, limit: int = 0, options: str = "",
                use_ai_qa: bool = True, verbose: bool = True) -> list:
    """未執筆のキーワードをまとめて記事にする。"""
    all_kw = kw_mod.load()
    written = {a["keyword_id"] for a in load()}

    if kw_ids:
        targets = [k for k in all_kw if k["id"] in kw_ids]
    else:
        targets = [k for k in all_kw if k["id"] not in written]
    if limit:
        targets = targets[:limit]

    if not targets:
        if verbose:
            print("執筆対象のキーワードがありません。")
        return []

    # 収益記事は内部リンクの送り先になるので、リンク候補として渡す
    money = [k for k in all_kw if k.get("role") == "収益記事"]

    if verbose:
        print(f"\n{'#'*74}")
        print(f"  記事生成  {len(targets)} 本")
        print(f"{'#'*74}")

    results = []
    for kw in targets:
        related = money if kw.get("role") != "収益記事" else [
            k for k in all_kw if k.get("role") != "収益記事"]
        results.append(write(kw, options=options, related=related,
                             use_ai_qa=use_ai_qa, verbose=verbose))

    if verbose:
        cost = sum(r["cost_jpy"] for r in results)
        review = sum(1 for r in results if r["needs_human"])
        print(f"\n{'#'*74}")
        print(f"  {len(results)}本 生成 / 要確認 {review}本 / 原価 合計 {cost:,.0f}円")
        print("  記事は articles/ に保存されました。公開後に "
              "`python main.py media publish <番号>` で公開日を記録します")
        print(f"{'#'*74}")
    return results
