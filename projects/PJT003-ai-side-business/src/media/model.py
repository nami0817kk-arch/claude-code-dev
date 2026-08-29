"""収益モデルの計算。

アフィリエイト・広告収入は次の掛け算で決まる。ここを曖昧にしたまま
記事を書き始めるのが失敗の典型なので、すべて数式にしておく。

  月間PV   = 検索ボリューム × 順位別CTR
  アフィリ  = PV × 遷移率 × CVR × 単価 × 承認率
  広告     = PV ÷ 1000 × RPM

数値はすべてパラメータ。実測が取れたら data/media_params.json で上書きする。
"""
import math

from .. import store

PARAMS_NAME = "media_params"

# 検索順位別のクリック率。業界調査で一般的に使われる値の中央付近を採用。
# 実際はキーワードの種類や検索結果の形（強調スニペット等）で大きく変わる。
DEFAULT_CTR = {
    1: 0.28, 2: 0.15, 3: 0.11, 4: 0.08, 5: 0.06,
    6: 0.045, 7: 0.035, 8: 0.030, 9: 0.025, 10: 0.022,
}
# 11位以下は 1 ページ目に入らないため、ほぼ流入しない
CTR_BELOW_10 = 0.005

DEFAULTS = {
    # アフィリエイト
    "transition_rate": 0.05,   # 記事を読んだ人がアフィリリンクを踏む割合
    "cvr": 0.02,               # 遷移先での成約率
    "approval_rate": 0.75,     # 発生した成果の承認率
    "unit_price": 3000,        # 1成約あたりの報酬（円）
    # 広告
    "rpm": 300,                # 1000PVあたりの広告収益（円）
    # 運営
    "seo_lag_months": 4,       # 記事が検索評価を得るまでの月数
    "avg_rank": 8,             # 平均的に取れる想定順位
    "fixed_monthly": 1500,     # ドメイン・サーバー等の月額固定費
}


def load_params() -> dict:
    """保存済みパラメータを既定値に重ねて返す。"""
    params = dict(DEFAULTS)
    params.update(store.load(PARAMS_NAME, {}))
    return params


def save_params(params: dict):
    return store.save(PARAMS_NAME, params)


def ctr(rank: int) -> float:
    """検索順位に対応するクリック率。"""
    if rank <= 0:
        return 0.0
    return DEFAULT_CTR.get(int(rank), CTR_BELOW_10)


def pv_from_volume(volume: int, rank: int) -> float:
    """月間検索ボリュームと順位から、想定PVを出す。"""
    return volume * ctr(rank)


def affiliate_revenue(pv: float, p: dict = None) -> float:
    """PVからアフィリエイト収益を計算する。"""
    p = p or load_params()
    conversions = pv * p["transition_rate"] * p["cvr"] * p["approval_rate"]
    return conversions * p["unit_price"]


def ad_revenue(pv: float, p: dict = None) -> float:
    """PVから広告収益を計算する。"""
    p = p or load_params()
    return pv / 1000 * p["rpm"]


def revenue(pv: float, model: str = "both", p: dict = None) -> float:
    """収益モデルを指定して月間収益を出す。"""
    p = p or load_params()
    if model == "affiliate":
        return affiliate_revenue(pv, p)
    if model == "ad":
        return ad_revenue(pv, p)
    return affiliate_revenue(pv, p) + ad_revenue(pv, p)


def revenue_per_pv(model: str = "both", p: dict = None) -> float:
    """1PVあたりの収益。逆算に使う。"""
    return revenue(1000, model, p) / 1000


def required_pv(target: int, model: str = "both", p: dict = None) -> float:
    """目標月収に必要な月間PV。"""
    per_pv = revenue_per_pv(model, p)
    return target / per_pv if per_pv > 0 else float("inf")


def required_articles(target: int, avg_pv_per_article: float,
                      model: str = "both", p: dict = None) -> int:
    """目標月収に必要な記事数。"""
    if avg_pv_per_article <= 0:
        return 0
    return math.ceil(required_pv(target, model, p) / avg_pv_per_article)


def article_pv(volume: int, rank: int = None, p: dict = None) -> float:
    """1記事あたりの想定月間PV。"""
    p = p or load_params()
    return pv_from_volume(volume, rank or p["avg_rank"])


# ---------------------------------------------------------------- 成長シミュレーション

def simulate(months: int, articles_per_month: int, avg_volume: int,
             target: int = 0, model: str = "both", article_cost: float = 0,
             p: dict = None) -> dict:
    """月ごとの収益・原価・累積損益を計算する。

    ストック型の肝は「書いてもすぐには収益にならない」こと。
    記事は公開から seo_lag_months かけて徐々に順位がつく前提で、
    公開 m ヶ月後の記事は本来PVの min(1, m / lag) 倍を稼ぐとする。
    """
    p = p or load_params()
    lag = max(1, p["seo_lag_months"])
    mature_pv = article_pv(avg_volume, p["avg_rank"], p)

    rows = []
    cumulative_profit = 0.0
    breakeven_month = None
    target_month = None

    for month in range(1, months + 1):
        published = articles_per_month * month

        # 各月に公開した記事の、今月時点での寄与を足し上げる
        pv = 0.0
        for pub_month in range(1, month + 1):
            age = month - pub_month
            pv += articles_per_month * mature_pv * min(1.0, age / lag)

        gross = revenue(pv, model, p)
        cost = article_cost * articles_per_month + p["fixed_monthly"]
        profit = gross - cost
        cumulative_profit += profit

        if breakeven_month is None and cumulative_profit > 0:
            breakeven_month = month
        if target and target_month is None and gross >= target:
            target_month = month

        rows.append({
            "month": month,
            "articles": published,
            "pv": round(pv),
            "revenue": round(gross),
            "cost": round(cost),
            "profit": round(profit),
            "cumulative": round(cumulative_profit),
        })

    return {
        "rows": rows,
        "breakeven_month": breakeven_month,
        "target_month": target_month,
        "final_revenue": rows[-1]["revenue"] if rows else 0,
        "final_pv": rows[-1]["pv"] if rows else 0,
        "total_articles": rows[-1]["articles"] if rows else 0,
        "max_drawdown": round(min([r["cumulative"] for r in rows], default=0)),
        "params": p,
        "model": model,
    }


# ---------------------------------------------------------------- 逆算

def plan(target: int, avg_volume: int = 1000, model: str = "both",
         articles_per_month: int = 8, p: dict = None) -> dict:
    """目標月収から、必要なPV・記事数・期間を逆算する。"""
    p = p or load_params()
    per_pv = revenue_per_pv(model, p)
    need_pv = required_pv(target, model, p)
    pv_per_article = article_pv(avg_volume, p["avg_rank"], p)
    need_articles = math.ceil(need_pv / pv_per_article) if pv_per_article else 0
    months_to_write = math.ceil(need_articles / articles_per_month) if articles_per_month else 0

    # 順位が変わると必要記事数がどう変わるか
    by_rank = []
    for rank in (3, 5, 8, 10):
        pv_a = pv_from_volume(avg_volume, rank)
        by_rank.append({
            "rank": rank,
            "ctr": ctr(rank),
            "pv_per_article": round(pv_a),
            "articles": math.ceil(need_pv / pv_a) if pv_a else 0,
        })

    # 単価が変わると必要PVがどう変わるか（アフィリを含むモデルのみ意味を持つ）
    by_price = []
    if model in ("affiliate", "both"):
        for price in (1000, 3000, 10000, 30000):
            q = dict(p, unit_price=price)
            pv = required_pv(target, model, q)
            by_price.append({
                "price": price,
                "pv": round(pv),
                "articles": math.ceil(pv / pv_per_article) if pv_per_article else 0,
            })

    return {
        "target": target,
        "model": model,
        "revenue_per_pv": per_pv,
        "required_pv": round(need_pv),
        "pv_per_article": round(pv_per_article, 1),
        "required_articles": need_articles,
        "articles_per_month": articles_per_month,
        "months_to_write": months_to_write,
        # 書き終えてから評価がつくまでのラグを足したものが、現実の到達時期
        "months_to_target": months_to_write + p["seo_lag_months"],
        "avg_volume": avg_volume,
        "by_rank": by_rank,
        "by_price": by_price,
        "params": p,
    }


MODEL_LABEL = {"affiliate": "アフィリエイト", "ad": "広告", "both": "アフィリ+広告"}


def print_plan(pl: dict):
    p = pl["params"]
    print(f"\n{'='*74}")
    print(f"  目標からの逆算  月 {pl['target']:,}円  "
          f"（{MODEL_LABEL.get(pl['model'], pl['model'])}）")
    print(f"{'='*74}")
    print(f"  1PVあたりの収益        {pl['revenue_per_pv']:>10.2f} 円")
    print(f"  必要な月間PV          {pl['required_pv']:>10,} PV")
    print(f"  1記事あたりの想定PV     {pl['pv_per_article']:>10,.1f} PV"
          f"   （検索数 {pl['avg_volume']:,} / {p['avg_rank']}位想定）")
    print(f"  必要な記事数          {pl['required_articles']:>10,} 本")
    print(f"\n  月 {pl['articles_per_month']} 本のペースなら、書き終わるまで "
          f"{pl['months_to_write']} ヶ月")
    print(f"  検索評価のラグ {p['seo_lag_months']} ヶ月を足すと、"
          f"目標到達は最短 {pl['months_to_target']} ヶ月後")

    print(f"\n{'-'*74}")
    print("  【順位が変わると必要記事数はこう変わる】")
    print(f"  {'順位':>6}{'CTR':>9}{'記事あたりPV':>14}{'必要記事数':>12}")
    for r in pl["by_rank"]:
        print(f"  {r['rank']:>5}位{r['ctr']*100:>8.1f}%{r['pv_per_article']:>13,}PV"
              f"{r['articles']:>11,}本")
    print("  → 順位を上げるほうが、記事を増やすより効く場合が多い")

    if pl["by_price"]:
        print(f"\n{'-'*74}")
        print("  【案件単価が変わると必要量はこう変わる】")
        print(f"  {'単価':>10}{'必要PV':>13}{'必要記事数':>12}")
        for r in pl["by_price"]:
            print(f"  {r['price']:>9,}円{r['pv']:>12,}PV{r['articles']:>11,}本")
        print("  → 単価の高いジャンルを選ぶだけで必要量が桁で変わる。ジャンル選定が最重要")

    print(f"\n{'='*74}")
    print("  シミュレーション: python main.py media simulate --months 24")
    print(f"{'='*74}")


def print_params(p: dict = None):
    p = p or load_params()
    print(f"\n{'='*74}")
    print("  収益モデルのパラメータ")
    print(f"{'='*74}")
    print("  【アフィリエイト】")
    print(f"    遷移率     {p['transition_rate']*100:>6.1f}%   記事の読者がリンクを踏む割合")
    print(f"    CVR        {p['cvr']*100:>6.1f}%   遷移先での成約率")
    print(f"    承認率     {p['approval_rate']*100:>6.1f}%   発生した成果が承認される割合")
    print(f"    単価     {p['unit_price']:>8,}円   1成約あたりの報酬")
    print("  【広告】")
    print(f"    RPM      {p['rpm']:>8,}円   1000PVあたりの広告収益")
    print("  【運営】")
    print(f"    想定順位   {p['avg_rank']:>6}位   平均的に取れる検索順位（CTR {ctr(p['avg_rank'])*100:.1f}%）")
    print(f"    SEOラグ    {p['seo_lag_months']:>6}ヶ月  記事が評価されるまでの期間")
    print(f"    固定費   {p['fixed_monthly']:>8,}円   ドメイン・サーバー等の月額")
    print(f"\n  1PVあたりの収益: {revenue_per_pv('both', p):.2f}円"
          f"（アフィリ {revenue_per_pv('affiliate', p):.2f}円 / 広告 {revenue_per_pv('ad', p):.2f}円）")
    print(f"{'='*74}")
    print("  変更: python main.py media params --set cvr=0.03 unit_price=5000")
    print("  ※ 既定値は一般的な目安。実測が取れたら必ず自分の数字に置き換えること")
    print(f"{'='*74}")


def print_simulation(sim: dict, target: int = 0):
    p = sim["params"]
    rows = sim["rows"]

    print(f"\n{'='*74}")
    print(f"  収益シミュレーション  {MODEL_LABEL.get(sim['model'], sim['model'])}")
    print(f"{'='*74}")
    print(f"  {'月':>3}{'記事数':>7}{'月間PV':>10}{'収益':>11}{'原価':>9}{'損益':>11}{'累積':>12}")
    print(f"{'-'*74}")
    for r in rows:
        mark = ""
        if r["month"] == sim["breakeven_month"]:
            mark = "  ← 累積黒字化"
        elif r["month"] == sim["target_month"]:
            mark = "  ← 目標達成"
        print(f"  {r['month']:>3}{r['articles']:>7}{r['pv']:>10,}"
              f"{r['revenue']:>10,}円{r['cost']:>8,}円{r['profit']:>10,}円"
              f"{r['cumulative']:>11,}円{mark}")
    print(f"{'-'*74}")

    print(f"\n  {len(rows)}ヶ月後: {sim['total_articles']}記事 / "
          f"月間 {sim['final_pv']:,}PV / 月収 {sim['final_revenue']:,}円")
    print(f"  最大赤字額（一番苦しい時点の累積）: {sim['max_drawdown']:,}円")

    if sim["breakeven_month"]:
        print(f"  累積黒字化: {sim['breakeven_month']}ヶ月目")
    else:
        print("  累積黒字化: この期間内には到達しない")

    if target:
        if sim["target_month"]:
            print(f"  目標月収 {target:,}円の達成: {sim['target_month']}ヶ月目")
        else:
            print(f"  目標月収 {target:,}円: この条件・期間では到達しない")
            print("    → 記事数を増やす / 単価の高いジャンルに変える / 想定順位を上げる、"
                  "のいずれかが必要")
    print(f"\n  最初の{p['seo_lag_months']}ヶ月は収益がほぼ立たない前提で計算しています。"
          "これはストック型の構造上避けられません")
    print(f"{'='*74}")
