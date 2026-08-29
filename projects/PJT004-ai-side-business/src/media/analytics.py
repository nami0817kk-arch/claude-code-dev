"""記事ごとの実績記録と、次の一手の判定。

ストック型の運営は「書く」より「どれを直すか」で結果が変わる。
PVと順位と収益の組み合わせで、記事の状態は4つに分かれ、打ち手も変わる。

  PV高・収益高 → 横展開（関連キーワードを増やす）
  PV高・収益低 → 収益化の問題（導線・案件の見直し）
  PV低・順位低 → リライトで順位を上げる余地がある
  PV低・順位高 → 検索需要そのものが無い（統合か撤退）
"""
import math

from .. import store
from . import articles as art_mod
from . import keywords as kw_mod
from . import model

# 判定のしきい値。運営規模に応じて変える
PV_THRESHOLD = 100          # 月間PVがこれ未満なら「PV低」
GOOD_RANK = 3               # これ以内なら「順位は取れている」
WEAK_RANK = 11              # これ以降なら「1ページ目に入っていない」

DIAGNOSIS = {
    "expand":   ("横展開", "稼げている。関連キーワードを増やして面を取る"),
    "monetize": ("収益化", "読まれているのに稼げていない。導線か案件を見直す"),
    "rewrite":  ("リライト", "順位が付いていない。内容を厚くして上位を狙う"),
    "retire":   ("統合・撤退", "上位なのに読まれない。検索需要が無いキーワード"),
    "wait":     ("様子見", "公開から日が浅い。評価が付くまで待つ"),
}


def record(kw_id: int, pv: int = None, revenue: int = None, rank: int = None,
           published: str = None) -> dict:
    """記事の実績を記録する。"""
    updates = {}
    if pv is not None:
        updates["pv"] = int(pv)
    if revenue is not None:
        updates["revenue"] = int(revenue)
    if rank is not None:
        updates["rank"] = int(rank)
    if published is not None:
        updates["published_at"] = published or store.today()

    saved = art_mod.load()
    for a in saved:
        if a["keyword_id"] == int(kw_id):
            a.update(updates)
            a["measured_at"] = store.now()
            store.save(art_mod.NAME, saved)
            return a
    return None


def months_since(date_str: str) -> float:
    """公開からの経過月数。日付が無ければ 0。"""
    if not date_str:
        return 0.0
    from datetime import datetime
    try:
        published = datetime.strptime(date_str[:10], "%Y-%m-%d")
    except ValueError:
        return 0.0
    return (datetime.now() - published).days / 30.4


def diagnose(article: dict, p: dict = None) -> str:
    """記事の状態を4分類する。"""
    p = p or model.load_params()
    if not article.get("published_at"):
        return "wait"
    if months_since(article["published_at"]) < p["seo_lag_months"]:
        return "wait"

    pv = article.get("pv", 0)
    rank = article.get("rank", 0)
    revenue = article.get("revenue", 0)

    if pv >= PV_THRESHOLD:
        return "expand" if revenue > 0 else "monetize"
    # PV が少ない場合、原因は順位か需要かのどちらか
    if rank and rank <= GOOD_RANK:
        return "retire"
    return "rewrite"


def upside(article: dict, target_rank: int = 3, p: dict = None) -> int:
    """リライトで target_rank まで上げた場合の、月間収益の増加見込み。

    現在の順位と PV から逆算した検索ボリュームを使うので、
    実測に基づいた見積もりになる。
    """
    p = p or model.load_params()
    rank = article.get("rank", 0)
    pv = article.get("pv", 0)

    if not rank or rank <= target_rank:
        return 0

    current_ctr = model.ctr(rank)
    if current_ctr <= 0:
        return 0
    # 実PVと順位別CTRから、そのキーワードの実質的な検索数を逆算する
    volume = pv / current_ctr
    gain_pv = volume * (model.ctr(target_rank) - current_ctr)
    return round(gain_pv * model.revenue_per_pv("both", p))


def rewrite_queue(p: dict = None) -> list:
    """リライトの優先順位。増える見込み額が大きい順。"""
    p = p or model.load_params()
    queue = []
    for a in art_mod.load():
        state = diagnose(a, p)
        if state not in ("rewrite", "monetize"):
            continue
        queue.append({**a, "state": state, "upside": upside(a, p=p)})
    queue.sort(key=lambda a: a["upside"], reverse=True)
    return queue


def totals() -> dict:
    arts = art_mod.load()
    published = [a for a in arts if a.get("published_at")]
    pv = sum(a.get("pv", 0) for a in arts)
    revenue = sum(a.get("revenue", 0) for a in arts)
    cost = sum(a.get("cost_jpy", 0) for a in arts)

    states = {}
    for a in arts:
        states[diagnose(a)] = states.get(diagnose(a), 0) + 1

    return {
        "written": len(arts),
        "published": len(published),
        "pv": pv,
        "revenue": revenue,
        "cost": round(cost, 1),
        "profit": round(revenue - cost, 1),
        "rpv": round(revenue / pv, 2) if pv else 0.0,
        "states": states,
    }


def calibrate(p: dict = None) -> dict:
    """実測値と、モデルが想定していた値のズレを出す。

    ここが合っていないと、シミュレーションも逆算も意味を持たない。
    """
    p = p or model.load_params()
    t = totals()
    assumed = model.revenue_per_pv("both", p)

    ranked = [a for a in art_mod.load() if a.get("rank")]
    avg_rank = round(sum(a["rank"] for a in ranked) / len(ranked), 1) if ranked else None

    return {
        "measured_rpv": t["rpv"],
        "assumed_rpv": round(assumed, 2),
        "ratio": round(t["rpv"] / assumed, 2) if assumed and t["pv"] else None,
        "pv": t["pv"],
        "avg_rank": avg_rank,
        "assumed_rank": p["avg_rank"],
        "samples": t["published"],
    }


def print_articles():
    arts = art_mod.load()
    if not arts:
        print("記事がまだありません。`python main.py media write --limit 5` で生成できます。")
        return

    t = totals()
    print(f"\n{'='*78}")
    print("  記事の実績")
    print(f"{'='*78}")
    print(f"  {'#':>3} {'キーワード':<24}{'役割':<5}{'公開':>11}{'順位':>5}"
          f"{'PV':>8}{'収益':>9}  状態")
    print(f"{'-'*78}")
    for a in arts:
        state = diagnose(a)
        label = DIAGNOSIS[state][0]
        print(f"  {a['keyword_id']:>3} {a['keyword'][:22]:<24}"
              f"{'収益' if a.get('role') == '収益記事' else '集客':<5}"
              f"{(a.get('published_at') or '未公開')[:10]:>11}"
              f"{(a.get('rank') or '-'):>5}{a.get('pv', 0):>8,}"
              f"{a.get('revenue', 0):>8,}円  {label}")
    print(f"{'-'*78}")
    print(f"  {t['written']}記事（公開 {t['published']}本） / "
          f"月間 {t['pv']:,}PV / 収益 {t['revenue']:,}円")
    print(f"  制作原価 累計 {t['cost']:,.0f}円 → 累積損益 {t['profit']:,.0f}円")
    if t["pv"]:
        print(f"  実測 1PVあたり収益 {t['rpv']}円")
    print(f"{'='*78}")


def print_rewrite_queue():
    queue = rewrite_queue()
    if not queue:
        print("いま手を入れるべき記事はありません。")
        print("  実績を記録すると判定できます: "
              "python main.py media stats 1 --pv 320 --rank 8 --revenue 1200")
        return

    print(f"\n{'='*78}")
    print("  改善の優先順位（直したときに増える見込み額の順）")
    print(f"{'='*78}")
    for a in queue:
        label, advice = DIAGNOSIS[a["state"]]
        print(f"\n  [{a['keyword_id']}] {a['keyword']}  <{label}>")
        print(f"      現状: {a.get('rank') or '-'}位 / {a.get('pv', 0):,}PV / "
              f"{a.get('revenue', 0):,}円")
        if a["upside"]:
            print(f"      3位まで上げられれば 月 +{a['upside']:,}円")
        print(f"      → {advice}")
    print(f"\n{'='*78}")
    print("  リライト後は再度 stats を記録して、効果を確認してください")
    print(f"{'='*78}")


def print_calibration():
    c = calibrate()
    print(f"\n{'='*74}")
    print("  実測とモデルのズレ")
    print(f"{'='*74}")
    if not c["pv"]:
        print("  まだ実測データがありません。")
        print("  記事を公開したら記録してください:")
        print("    python main.py media stats 1 --pv 320 --rank 8 --revenue 1200")
        print(f"{'='*74}")
        return

    print(f"  1PVあたり収益   想定 {c['assumed_rpv']}円  →  実測 {c['measured_rpv']}円", end="")
    if c["ratio"]:
        print(f"  （想定の {c['ratio']:.0%}）")
    else:
        print()
    if c["avg_rank"]:
        print(f"  平均順位        想定 {c['assumed_rank']}位  →  実測 {c['avg_rank']}位")
    print(f"  サンプル数      公開記事 {c['samples']} 本 / 累計 {c['pv']:,}PV")

    if c["ratio"] and c["samples"] >= 3:
        if c["ratio"] < 0.7:
            print("\n  実測が想定を大きく下回っています。パラメータを実測に合わせてください。")
            print("    例) python main.py media params --set cvr=0.01")
            print("  そのうえで逆算し直すと、必要な記事数の現実的な見積もりが出ます。")
        elif c["ratio"] > 1.3:
            print("\n  実測が想定を上回っています。同じジャンルへの投下を増やす判断ができます。")
        else:
            print("\n  想定と実測はおおむね一致しています。シミュレーションを信頼して構いません。")
    elif c["samples"] < 3:
        print("\n  サンプルが少ないため、まだ判断材料になりません（公開3本以上が目安）。")
    print(f"{'='*74}")
