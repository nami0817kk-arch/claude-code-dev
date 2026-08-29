"""アプリ収益モデル。

  DAU     = 日次インストール × 継続率の総和（定常状態）
  ARPDAU  = 広告収益/DAU + 課金収益/DAU
  月間収益 = DAU × ARPDAU × 30

継続率は D1 / D7 / D30 の実測3点から冪関数で近似する。
ストア分析画面で取れる3つの数字さえ入れれば、以降の計算が全部つながる。
"""
import math

from .. import store

PARAMS_NAME = "app_params"

DEFAULTS = {
    # 継続率（ストアの分析画面で確認できる）
    "d1": 0.35,               # 翌日継続率
    "d7": 0.15,               # 7日継続率
    "d30": 0.06,              # 30日継続率
    # 広告収益
    "ad_impressions": 6.0,    # 1DAUあたりの広告表示回数
    "ecpm": 600,              # 1000インプレッションあたりの収益（円）
    # 課金収益
    "paying_rate": 0.015,     # 課金ユーザーの割合
    "arppu": 1500,            # 課金ユーザー1人あたりの月間課金額（円）
    # 獲得
    "organic_installs": 5,    # 1日あたりのオーガニックインストール数
    "cpi": 150,               # 広告経由の1インストール単価（円）
    "paid_installs": 0,       # 1日あたりの広告経由インストール数
    # 運営
    "fixed_monthly": 0,       # ストア年会費などを月割りした額
}

# 継続率を積み上げる上限日数。1年見れば十分収束する。
HORIZON_DAYS = 365


def load_params() -> dict:
    params = dict(DEFAULTS)
    params.update(store.load(PARAMS_NAME, {}))
    return params


def save_params(params: dict):
    return store.save(PARAMS_NAME, params)


def retention(day: int, p: dict = None) -> float:
    """公開からの経過日数に対する継続率。

    D1 と D30 の実測2点を通る冪関数 r(d) = d1 * d^(-k) で近似する。
    アプリの継続率は初日に急落して以降なだらかに減るので、
    直線ではなく冪関数のほうが実態に近い。
    """
    p = p or load_params()
    if day <= 0:
        return 1.0
    d1, d30 = p["d1"], p["d30"]
    if d1 <= 0:
        return 0.0
    if d30 <= 0 or d30 >= d1:
        # D30 が取れていない、または不整合な場合は D1 を横ばいで置く
        return d1
    k = math.log(d1 / d30) / math.log(30)
    return min(1.0, d1 * day ** (-k))


def retention_sum(p: dict = None, days: int = HORIZON_DAYS) -> float:
    """継続率の総和。日次インストール1人あたりが生む DAU 寄与。"""
    p = p or load_params()
    return 1.0 + sum(retention(d, p) for d in range(1, days + 1))


def steady_dau(daily_installs: float, p: dict = None) -> float:
    """毎日 daily_installs 人入り続けたときに落ち着く DAU。"""
    return daily_installs * retention_sum(p)


def ad_arpdau(p: dict = None) -> float:
    """1DAUあたりの広告収益（1日分）。"""
    p = p or load_params()
    return p["ad_impressions"] * p["ecpm"] / 1000


def iap_arpdau(p: dict = None) -> float:
    """1DAUあたりの課金収益（1日分）。月額を30で割る。"""
    p = p or load_params()
    return p["paying_rate"] * p["arppu"] / 30


def arpdau(model: str = "both", p: dict = None) -> float:
    p = p or load_params()
    if model == "ad":
        return ad_arpdau(p)
    if model == "iap":
        return iap_arpdau(p)
    return ad_arpdau(p) + iap_arpdau(p)


def monthly_revenue(dau: float, model: str = "both", p: dict = None) -> float:
    return dau * arpdau(model, p) * 30


def required_dau(target: int, model: str = "both", p: dict = None) -> float:
    per_dau = arpdau(model, p) * 30
    return target / per_dau if per_dau > 0 else float("inf")


def required_installs(target: int, model: str = "both", p: dict = None) -> dict:
    """目標月収に必要な DAU と、そのための日次インストール数。"""
    p = p or load_params()
    dau = required_dau(target, model, p)
    contribution = retention_sum(p)
    daily = dau / contribution if contribution else float("inf")
    return {
        "dau": round(dau),
        "daily_installs": math.ceil(daily),
        "retention_sum": round(contribution, 1),
        # 定常状態に達するまでに必要な累計インストール（おおよそ90日ぶん）
        "installs_90d": math.ceil(daily * 90),
        "organic_gap": math.ceil(daily) - p["organic_installs"],
        "ua_cost_monthly": round(max(0, math.ceil(daily) - p["organic_installs"])
                                 * 30 * p["cpi"]),
    }


def ltv(p: dict = None, model: str = "both") -> float:
    """1インストールが生涯に生む収益。CPI と比べて広告出稿の可否を判断する。"""
    p = p or load_params()
    return retention_sum(p) * arpdau(model, p)


def simulate(months: int, daily_installs: float, model: str = "both",
             target: int = 0, growth: float = 0.0, p: dict = None) -> dict:
    """月ごとの DAU・収益・累積損益。

    growth は日次インストールの月次成長率（0.1 なら毎月10%増）。
    """
    p = p or load_params()
    rows = []
    cumulative = 0.0
    breakeven_month = None
    target_month = None

    # 日ごとのインストール数を積み上げ、各日の生存分を足して DAU を出す
    installs = []
    for month in range(1, months + 1):
        rate = daily_installs * ((1 + growth) ** (month - 1))
        installs.extend([rate] * 30)

        day_index = month * 30
        dau = sum(
            installs[i] * retention(day_index - i - 1, p)
            for i in range(day_index)
        )
        gross = monthly_revenue(dau, model, p)
        paid = p["paid_installs"] * 30 * p["cpi"] if p["paid_installs"] else 0
        cost = paid + p["fixed_monthly"]
        profit = gross - cost
        cumulative += profit

        if breakeven_month is None and cumulative > 0:
            breakeven_month = month
        if target and target_month is None and gross >= target:
            target_month = month

        rows.append({
            "month": month,
            "dau": round(dau),
            "installs_total": round(sum(installs)),
            "revenue": round(gross),
            "cost": round(cost),
            "profit": round(profit),
            "cumulative": round(cumulative),
        })

    return {
        "rows": rows,
        "breakeven_month": breakeven_month,
        "target_month": target_month,
        "final_dau": rows[-1]["dau"] if rows else 0,
        "final_revenue": rows[-1]["revenue"] if rows else 0,
        "params": p,
        "model": model,
    }


MODEL_LABEL = {"ad": "広告のみ", "iap": "課金のみ", "both": "広告+課金"}


def print_params(p: dict = None):
    p = p or load_params()
    print(f"\n{'='*74}")
    print("  アプリ収益モデルのパラメータ")
    print(f"{'='*74}")
    print("  【継続率】ストアの分析画面で確認できる")
    print(f"    D1  {p['d1']*100:>6.1f}%   翌日に戻ってくる割合")
    print(f"    D7  {p['d7']*100:>6.1f}%   7日後")
    print(f"    D30 {p['d30']*100:>6.1f}%   30日後")
    print(f"    → 1インストールあたりの DAU 寄与 {retention_sum(p):.1f} 日分")
    print("  【広告】")
    print(f"    表示回数 {p['ad_impressions']:>6.1f}回   1DAUあたり")
    print(f"    eCPM   {p['ecpm']:>8,}円   1000インプレッションあたり")
    print("  【課金】")
    print(f"    課金率   {p['paying_rate']*100:>6.2f}%")
    print(f"    ARPPU  {p['arppu']:>8,}円   課金ユーザー1人の月間課金額")
    print("  【獲得】")
    print(f"    オーガニック {p['organic_installs']:>4}件/日")
    print(f"    CPI      {p['cpi']:>8,}円   広告で1インストール獲得する単価")

    print(f"\n  ARPDAU  {arpdau('both', p):.2f}円/日"
          f"（広告 {ad_arpdau(p):.2f} + 課金 {iap_arpdau(p):.2f}）")
    print(f"  LTV     {ltv(p):.1f}円/インストール", end="")
    if p["cpi"]:
        ratio = ltv(p) / p["cpi"]
        verdict = "広告出稿は成立する" if ratio >= 1 else "広告を打つと赤字になる"
        print(f"   CPI {p['cpi']:,}円 との比 {ratio:.2f}倍 → {verdict}")
    else:
        print()
    print(f"{'='*74}")
    print("  変更: python main.py app params --set d1=0.42 ecpm=800")
    print("  ※ 既定値は目安。ストアの実測が出たら必ず置き換えること")
    print(f"{'='*74}")


def print_plan(target: int, model: str = "both", p: dict = None):
    p = p or load_params()
    r = required_installs(target, model, p)

    print(f"\n{'='*74}")
    print(f"  目標からの逆算  月 {target:,}円  （{MODEL_LABEL.get(model, model)}）")
    print(f"{'='*74}")
    print(f"  ARPDAU              {arpdau(model, p):>10.2f} 円/日")
    print(f"  必要なDAU           {r['dau']:>10,} 人")
    print(f"  必要な日次インストール  {r['daily_installs']:>10,} 件/日")
    print(f"  （1インストールが平均 {r['retention_sum']} 日分の DAU を生むため）")
    print(f"  定常状態までの累計インストール 約 {r['installs_90d']:,} 件")

    print(f"\n{'-'*74}")
    print(f"  現在のオーガニック獲得は {p['organic_installs']} 件/日の想定")
    if r["organic_gap"] > 0:
        print(f"  → {r['organic_gap']:,} 件/日 足りない")
        print(f"  → 広告で埋めるなら 月 {r['ua_cost_monthly']:,}円 の出稿費が必要")
        if ltv(p, model) < p["cpi"]:
            print(f"  ⚠ LTV {ltv(p, model):.0f}円 < CPI {p['cpi']:,}円 なので、"
                  "広告を打つほど赤字が増える")
            print("     先に継続率か ARPDAU を上げること")
    else:
        print("  → オーガニックだけで足りる計算")

    print(f"\n{'-'*74}")
    print("  【継続率が変わると必要インストール数はこう変わる】")
    print(f"  {'D1':>6}{'D30':>7}{'DAU寄与':>10}{'必要インストール':>16}")
    for d1, d30 in ((0.20, 0.02), (0.35, 0.06), (0.50, 0.12), (0.60, 0.20)):
        q = dict(p, d1=d1, d30=d30)
        rr = required_installs(target, model, q)
        mark = "  ← 現在" if abs(d1 - p["d1"]) < 0.01 else ""
        print(f"  {d1*100:>5.0f}%{d30*100:>6.0f}%{retention_sum(q):>9.1f}日"
              f"{rr['daily_installs']:>13,}件/日{mark}")
    print("  → 継続率を上げるほうが、インストールを増やすより効く")
    print(f"{'='*74}")


def print_simulation(sim: dict, target: int = 0):
    print(f"\n{'='*74}")
    print(f"  アプリ収益シミュレーション  {MODEL_LABEL.get(sim['model'], sim['model'])}")
    print(f"{'='*74}")
    print(f"  {'月':>3}{'累計DL':>10}{'DAU':>9}{'収益':>11}{'原価':>10}{'累積':>12}")
    print(f"{'-'*74}")
    for r in sim["rows"]:
        mark = ""
        if r["month"] == sim["breakeven_month"]:
            mark = "  ← 累積黒字化"
        elif r["month"] == sim["target_month"]:
            mark = "  ← 目標達成"
        print(f"  {r['month']:>3}{r['installs_total']:>10,}{r['dau']:>9,}"
              f"{r['revenue']:>10,}円{r['cost']:>9,}円{r['cumulative']:>11,}円{mark}")
    print(f"{'-'*74}")
    print(f"\n  {len(sim['rows'])}ヶ月後: DAU {sim['final_dau']:,} 人 / "
          f"月収 {sim['final_revenue']:,}円")
    if target and not sim["target_month"]:
        print(f"  目標月収 {target:,}円: この条件では到達しない")
        print("    → 継続率を上げる / ARPDAU を上げる / インストールを増やす")
    print(f"{'='*74}")
