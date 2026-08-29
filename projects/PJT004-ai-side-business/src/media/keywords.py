"""キーワード設計。

AI に任せるのは「どんな切り口の記事があり得るか」の発想と分類まで。
検索ボリュームは AI が正確に知らないので推測させず、
ラッコキーワードや キーワードプランナー の CSV を取り込んで上書きする。

優先度は「その記事が月いくら稼ぐか」の期待値で決める。
順位が取れなければ何本書いても意味がないので、難易度から想定順位に落として計算する。
"""
import csv
import math
from pathlib import Path

from .. import llm, store
from . import model

NAME = "keywords"

# 想定難易度 → 現実的に取れる検索順位
RANK_BY_DIFFICULTY = {1: 3, 2: 5, 3: 8, 4: 10, 5: 15}

INTENT_LABEL = {
    "Buy": "購入検討", "Do": "行動したい", "Know": "知りたい", "Go": "特定サイトへ",
}

SYSTEM = """あなたは日本語SEOのキーワード設計者です。個人が運営するメディアの記事設計を行います。

守ること:
- 検索ボリュームを推測して書かない。数値の断定は禁止（volume_hint は「多い/中/少ない」の3段階のみ）
- 大手企業や公式サイトが上位を独占していて個人には勝ち目がない領域は、difficulty を 5 にする
- 医療・健康・金融・法律（YMYL領域）は個人サイトの評価が上がりにくいことを踏まえ、
  該当する場合は difficulty を高く付ける
- 検索意図が曖昧なキーワードは選ばない"""

SCHEMA = {
    "type": "object",
    "properties": {
        "keywords": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "keyword": {"type": "string"},
                    "intent": {"type": "string", "enum": ["Buy", "Do", "Know", "Go"]},
                    "volume_hint": {"type": "string", "enum": ["多い", "中", "少ない"]},
                    "difficulty": {"type": "integer", "minimum": 1, "maximum": 5},
                    "profitability": {"type": "integer", "minimum": 1, "maximum": 5},
                    "article_type": {"type": "string",
                                     "enum": ["レビュー", "比較", "解説", "手順", "まとめ"]},
                    "title": {"type": "string"},
                    "reason": {"type": "string"},
                    "role": {"type": "string", "enum": ["収益記事", "集客記事"]},
                },
                "required": ["keyword", "intent", "volume_hint", "difficulty",
                             "profitability", "article_type", "title", "reason", "role"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["keywords"],
    "additionalProperties": False,
}

PROMPT = """次のテーマでメディアを立ち上げます。狙うべきキーワードを {n} 個設計してください。

## テーマ
{theme}

## 運営者の状況
{profile}

## 設計の方針
- 収益記事（購入・申込につながる Buy / Do 意図）と、
  集客記事（Know 意図で人を集め、収益記事へ内部リンクで送る）の両方を含める
- 収益記事は全体の3割程度。残りは集客記事にする
- 個人が半年〜1年で上位を取れる見込みのあるものを優先する
- キーワードは実際に検索されそうな自然な日本語にする（2〜4語の複合語が中心）

## 各項目の意味
- volume_hint: 検索需要の体感（多い/中/少ない）。数値は書かない
- difficulty: 上位表示の難しさ 1〜5（5 = 個人には勝ち目が薄い）
- profitability: 収益への近さ 1〜5（5 = 読んだ人がそのまま申し込む）
- role: 収益記事 / 集客記事
- title: そのキーワードで書く記事のタイトル案（32文字以内）
- reason: そのキーワードを狙う理由（1文）"""

# volume_hint を数値に変換する際の目安。実データを入れるまでの仮置き。
VOLUME_GUESS = {"多い": 2000, "中": 500, "少ない": 100}


def expected(kw: dict, p: dict = None) -> dict:
    """そのキーワードが月いくら稼ぐかの期待値を出す。

    難易度から取れる順位を決め、順位別CTRでPVにし、収益モデルに通す。
    収益性は「アフィリエイトにどれだけ近いか」の係数として使う。
    """
    p = p or model.load_params()
    volume = kw.get("volume") or VOLUME_GUESS.get(kw.get("volume_hint", "中"), 500)
    rank = RANK_BY_DIFFICULTY.get(kw.get("difficulty", 3), 8)
    pv = model.pv_from_volume(volume, rank)

    aff = model.affiliate_revenue(pv, p) * (kw.get("profitability", 3) / 5)
    ad = model.ad_revenue(pv, p)

    return {
        "volume": volume,
        "estimated": kw.get("volume") is None,   # 実データか推測か
        "rank": rank,
        "pv": round(pv, 1),
        "revenue": round(aff + ad),
    }


def score_all(keywords: list, p: dict = None) -> list:
    """全キーワードに期待値を付けて、稼げる順に並べる。"""
    p = p or model.load_params()
    for kw in keywords:
        kw["expected"] = expected(kw, p)
    keywords.sort(key=lambda k: k["expected"]["revenue"], reverse=True)
    for i, kw in enumerate(keywords, 1):
        kw["id"] = i
    return keywords


def generate(theme: str, prof: dict, n: int = 20) -> list:
    from .. import profile as profile_mod

    result = llm.ask_json(
        PROMPT.format(n=n, theme=theme, profile=profile_mod.summary_text(prof)),
        system=SYSTEM,
        schema=SCHEMA,
        max_tokens=8000,
    )
    keywords = score_all(result.get("keywords", []))
    store.save(NAME, {"theme": theme, "generated_at": store.now(),
                      "keywords": keywords})
    return keywords


def load() -> list:
    return store.load(NAME, {}).get("keywords", [])


def theme() -> str:
    return store.load(NAME, {}).get("theme", "")


def find(kw_id) -> dict:
    for kw in load():
        if kw["id"] == int(kw_id):
            return kw
    return None


def import_volumes(csv_path: str) -> dict:
    """検索ボリュームの実データを CSV から取り込む。

    ラッコキーワードやキーワードプランナーの出力を想定。
    1列目にキーワード、2列目に月間検索数があれば読める。
    """
    path = Path(csv_path)
    if not path.exists():
        raise FileNotFoundError(csv_path)

    volumes = {}
    with path.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.reader(f):
            if len(row) < 2:
                continue
            key = row[0].strip()
            raw = row[1].replace(",", "").strip()
            # ヘッダー行や範囲表記（1000〜1万）は数字だけ拾う
            digits = "".join(ch for ch in raw if ch.isdigit())
            if key and digits:
                volumes[key] = int(digits)

    keywords = load()
    matched = 0
    for kw in keywords:
        if kw["keyword"] in volumes:
            kw["volume"] = volumes[kw["keyword"]]
            matched += 1

    keywords = score_all(keywords)
    data = store.load(NAME, {})
    data["keywords"] = keywords
    store.save(NAME, data)

    return {"read": len(volumes), "matched": matched, "total": len(keywords)}


def totals(keywords: list = None) -> dict:
    keywords = load() if keywords is None else keywords
    pv = sum(k["expected"]["pv"] for k in keywords)
    rev = sum(k["expected"]["revenue"] for k in keywords)
    return {
        "count": len(keywords),
        "pv": round(pv),
        "revenue": rev,
        "money": sum(1 for k in keywords if k.get("role") == "収益記事"),
        "estimated": sum(1 for k in keywords if k["expected"]["estimated"]),
    }


def print_keywords(keywords: list = None, top: int = 0, detail: bool = False):
    keywords = load() if keywords is None else keywords
    if not keywords:
        print("キーワードがまだありません。"
              '`python main.py media keywords --theme "テーマ"` を実行してください。')
        return

    shown = keywords[:top] if top else keywords
    t = totals(keywords)

    print(f"\n{'='*78}")
    print(f"  キーワード設計  {theme() or ''}")
    print(f"{'='*78}")
    print(f"  {'#':>3} {'役割':<5}{'キーワード':<24}{'意図':<6}{'難度':>4}{'収益性':>5}"
          f"{'検索数':>9}{'想定':>5}{'月収益':>9}")
    print(f"{'-'*78}")
    for kw in shown:
        e = kw["expected"]
        vol = f"{e['volume']:,}" + ("?" if e["estimated"] else "")
        role = "収益" if kw.get("role") == "収益記事" else "集客"
        print(f"  {kw['id']:>3} {role:<5}{kw['keyword'][:22]:<24}"
              f"{INTENT_LABEL.get(kw.get('intent',''), kw.get('intent','')):<6}"
              f"{kw.get('difficulty',0):>4}{kw.get('profitability',0):>5}"
              f"{vol:>9}{e['rank']:>4}位{e['revenue']:>8,}円")
        if detail:
            print(f"      {kw.get('title','')}")
            print(f"      {kw.get('reason','')}")
    print(f"{'-'*78}")
    print(f"  {t['count']}記事（うち収益記事 {t['money']}本）を全部書いて全部想定順位なら "
          f"月間 {t['pv']:,}PV / {t['revenue']:,}円")
    if t["estimated"]:
        print(f"  ※ {t['estimated']}件は検索数が推測値（末尾 ?）。"
              "実データを入れると精度が上がります:")
        print("     python main.py media keywords --import volumes.csv")
    print(f"{'='*78}")
    print("  記事を書く: python main.py media write <番号>")
    print(f"{'='*78}")
