"""ジャンル（テーマ）の選定。

逆算すると分かるが、アフィリエイトで効くのは記事数より単価と順位。
単価 1,000円のジャンルで月5万円は 1,500記事、30,000円なら 74記事。
つまり最初のジャンル選びで、必要な労力が桁で変わる。

ここでは AI に候補を出させ、必要記事数と到達月数はこちらで計算する。
案件単価は AI の記憶ではなく ASP で必ず確認すること（出力にも明記される）。
"""
import math

from .. import llm, store
from . import model

NAME = "genres"

# 競合の強さ → 個人が現実的に取れる順位
RANK_BY_COMPETITION = {1: 3, 2: 5, 3: 8, 4: 10, 5: 15}

PRICE_BAND = {"低": 1000, "中": 5000, "高": 15000, "特に高い": 30000}

SYSTEM = """あなたはアフィリエイトメディアの立ち上げに詳しいコンサルタントです。

守ること:
- 案件の報酬額を断定しない。price_band は「低/中/高/特に高い」の4段階でのみ答える
- 存在しない ASP 名や案件名を作らない。確実でないものは書かない
- 医療・健康・金融・法律・美容（YMYL領域）は、個人サイトが検索評価を得にくいことを
  必ず考慮し、ymyl を true にしたうえで competition を高く付ける
- 「稼ぎやすい」と煽らない。個人が今から参入して勝ち目が薄い領域は正直に薄いと言う
- 相談者が実際に経験・知識を持っている領域を優先する。E-E-A-Tの観点で、
  体験のない領域は上位表示が難しい"""

SCHEMA = {
    "type": "object",
    "properties": {
        "genres": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "genre": {"type": "string"},
                    "summary": {"type": "string"},
                    "fit_reason": {"type": "string"},
                    "monetization": {"type": "string",
                                     "enum": ["アフィリ主体", "広告主体", "両方"]},
                    "price_band": {"type": "string",
                                   "enum": ["低", "中", "高", "特に高い"]},
                    "asp_hint": {"type": "string"},
                    "competition": {"type": "integer", "minimum": 1, "maximum": 5},
                    "ymyl": {"type": "boolean"},
                    "experience_needed": {"type": "string"},
                    "keyword_examples": {"type": "array", "items": {"type": "string"}},
                    "risk": {"type": "string"},
                },
                "required": ["genre", "summary", "fit_reason", "monetization",
                             "price_band", "asp_hint", "competition", "ymyl",
                             "experience_needed", "keyword_examples", "risk"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["genres"],
    "additionalProperties": False,
}

PROMPT = """アフィリエイト・広告収入のメディアを立ち上げます。
候補になるジャンルを {n} 個提案してください。

## 運営者のプロフィール
{profile}
{theme}

## 各項目の意味
- genre: ジャンル名（15文字以内）
- summary: どんな読者に何を紹介するメディアか（60文字程度）
- fit_reason: この人がやる場合の適性（経歴・スキルとの接点。無ければ正直に「接点は薄い」と書く）
- monetization: 収益の主軸
- price_band: 案件報酬の水準（低/中/高/特に高い の4段階のみ。金額は書かない）
- asp_hint: どういう種類の案件があるか（一般的な説明にとどめ、具体的な案件名は書かない）
- competition: 個人が上位を取る難しさ 1〜5（5 = 大手が独占していて勝ち目が薄い）
- ymyl: 医療・健康・金融・法律・美容に該当するか
- experience_needed: 書くために必要な経験・情報（何を持っていれば書けるか）
- keyword_examples: 想定されるキーワード例（3つ）
- risk: このジャンル固有のリスク（1文）"""


def evaluate(genre: dict, target: int, articles_per_month: int = 8,
             avg_volume: int = 500, p: dict = None) -> dict:
    """ジャンルごとに、目標到達に必要な記事数と月数を計算する。"""
    p = p or model.load_params()
    price = PRICE_BAND.get(genre.get("price_band", "中"), 5000)
    rank = RANK_BY_COMPETITION.get(genre.get("competition", 3), 8)

    # このジャンルの条件でパラメータを差し替えて逆算する
    q = dict(p, unit_price=price, avg_rank=rank)
    revenue_model = {"アフィリ主体": "affiliate", "広告主体": "ad"}.get(
        genre.get("monetization", "両方"), "both")

    need_pv = model.required_pv(target, revenue_model, q)
    pv_per_article = model.pv_from_volume(avg_volume, rank)
    articles = math.ceil(need_pv / pv_per_article) if pv_per_article else 0
    months = (math.ceil(articles / articles_per_month) + p["seo_lag_months"]
              if articles_per_month else 0)

    return {
        "assumed_price": price,
        "assumed_rank": rank,
        "revenue_model": revenue_model,
        "required_pv": round(need_pv),
        "required_articles": articles,
        "months_to_target": months,
    }


def rank_genres(genres: list, target: int, articles_per_month: int = 8,
                avg_volume: int = 500, p: dict = None) -> list:
    """到達までの月数が短い順に並べる。"""
    for g in genres:
        g["estimate"] = evaluate(g, target, articles_per_month, avg_volume, p)
    genres.sort(key=lambda g: (g["estimate"]["months_to_target"], g["competition"]))
    for i, g in enumerate(genres, 1):
        g["id"] = i
    return genres


def generate(prof: dict, target: int, theme: str = "", n: int = 6,
             articles_per_month: int = 8) -> list:
    from .. import profile as profile_mod

    result = llm.ask_json(
        PROMPT.format(
            n=n,
            profile=profile_mod.summary_text(prof),
            theme=f"\n## 検討したい方向性\n{theme}" if theme else "",
        ),
        system=SYSTEM,
        schema=SCHEMA,
        max_tokens=8000,
    )
    genres = rank_genres(result.get("genres", []), target, articles_per_month)
    store.save(NAME, {"generated_at": store.now(), "target": target,
                      "genres": genres})
    return genres


def load() -> list:
    return store.load(NAME, {}).get("genres", [])


def find(genre_id) -> dict:
    for g in load():
        if g["id"] == int(genre_id):
            return g
    return None


def print_genres(genres: list = None, detail: bool = False):
    genres = load() if genres is None else genres
    if not genres:
        print("ジャンル候補がまだありません。"
              "`python main.py media genre` を実行してください。")
        return

    print(f"\n{'='*78}")
    print("  ジャンル候補  目標到達が早い順")
    print(f"{'='*78}")
    for g in genres:
        e = g["estimate"]
        flags = []
        if g.get("ymyl"):
            flags.append("YMYL")
        if g.get("competition", 3) >= 4:
            flags.append("競合強")
        flag = f"  [{' / '.join(flags)}]" if flags else ""

        print(f"\n  [{g['id']}] {g['genre']}  単価{g.get('price_band','')}  "
              f"競合{g.get('competition','')}/5{flag}")
        print(f"      {g.get('summary','')}")
        print(f"      収益: {g.get('monetization','')}  "
              f"想定 {e['assumed_rank']}位 → 必要 {e['required_articles']:,}記事 / "
              f"{e['required_pv']:,}PV")
        print(f"      目標到達まで 約{e['months_to_target']}ヶ月")
        print(f"      適性: {g.get('fit_reason','')}")
        if detail:
            print(f"      案件の種類: {g.get('asp_hint','')}")
            print(f"      必要な経験: {g.get('experience_needed','')}")
            print(f"      キーワード例: {'、'.join(g.get('keyword_examples', []))}")
            print(f"      リスク: {g.get('risk','')}")
    print(f"\n{'='*78}")
    print("  ※ 単価はAIの推定ではなく段階評価です。実際の報酬額は必ず ASP で確認してください")
    print("  ※ YMYL（医療・健康・金融・法律・美容）は個人サイトの評価が上がりにくい領域です")
    print(f"{'='*78}")
    print('  決めたら: python main.py media keywords --theme "<ジャンル名>"')
    print(f"{'='*78}")
