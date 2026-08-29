"""原価と利益の集計。

AI で自動化する副業は「1件いくらの原価で作れて、いくらで売れるか」がすべてなので、
トークン単価から実測の原価を出し、粗利率と実質時給まで落とす。
"""
from .. import llm
from . import jobs as jobs_mod
from . import services


def summary(jobs: list = None) -> dict:
    jobs = jobs_mod.load() if jobs is None else jobs
    ran = [j for j in jobs if j.get("cost_jpy")]

    # 売上は計上済み（納品まで到達した）ものだけを数える
    sales = sum(j.get("price", 0) or 0 for j in ran if j.get("revenue_recorded"))
    cost = sum(j.get("cost_jpy", 0) or 0 for j in ran)
    minutes = sum(
        (services.get(j["service"]).auto_minutes if services.get(j["service"]) else 3)
        for j in ran
    )
    manual_hours = sum(
        (services.get(j["service"]).manual_hours if services.get(j["service"]) else 1)
        for j in ran
    )

    by_service = {}
    for j in ran:
        s = by_service.setdefault(j["service"], {"count": 0, "sales": 0, "cost": 0.0})
        s["count"] += 1
        s["sales"] += (j.get("price", 0) or 0) if j.get("revenue_recorded") else 0
        s["cost"] += j.get("cost_jpy", 0) or 0
    for s in by_service.values():
        s["profit"] = s["sales"] - s["cost"]
        s["margin"] = round(s["profit"] / s["sales"] * 100, 1) if s["sales"] else 0.0
        s["avg_cost"] = round(s["cost"] / s["count"], 1) if s["count"] else 0.0

    return {
        "count": len(ran),
        "sales": sales,
        "cost": round(cost, 1),
        "profit": round(sales - cost, 1),
        "margin": round((sales - cost) / sales * 100, 1) if sales else 0.0,
        "avg_cost": round(cost / len(ran), 1) if ran else 0.0,
        "avg_price": round(sales / len(ran)) if ran else 0,
        "auto_hours": round(minutes / 60, 2),
        "manual_hours": manual_hours,
        "saved_hours": round(manual_hours - minutes / 60, 1),
        # 実際にかかった自動実行時間で割った時給
        "hourly": round((sales - cost) / (minutes / 60)) if minutes else 0,
        "by_service": by_service,
    }


def estimate(service_key: str, input_chars: int = 3000) -> dict:
    """実行前に、1件あたりの原価をおおまかに見積もる。

    トークン数は日本語で「1文字 ≒ 1トークン」を目安に概算する。
    生成 + 検品 + 修正1回で、出力はおおよそ入力の1.5倍を想定。
    """
    service = services.get(service_key)
    if not service:
        return {}

    system_tokens = len(service.system) + len(service.template)
    out_tokens = min(service.max_tokens, max(service.min_chars * 2, 2000))

    usage = llm.Usage(llm.DEFAULT_MODEL)
    # 生成
    usage.input_tokens += system_tokens + input_chars
    usage.output_tokens += out_tokens
    # 検品（出力を読み直す）
    usage.input_tokens += out_tokens + 500
    usage.output_tokens += 600
    # 修正1回ぶんの余裕
    usage.input_tokens += out_tokens + 1000
    usage.output_tokens += out_tokens
    usage.calls = 3

    cost = usage.cost_jpy()
    return {
        "service": service.name,
        "model": usage.model,
        "cost_jpy": round(cost, 1),
        "price_min": service.price_min,
        "price_max": service.price_max,
        "margin_min": round((service.price_min - cost) / service.price_min * 100, 1),
        "margin_max": round((service.price_max - cost) / service.price_max * 100, 1),
        "breakeven": int(cost) + 1,
        "tokens": usage.total_tokens,
    }


def print_estimates(target_income: int = 0):
    print(f"\n{'='*74}")
    print(f"  1件あたりの原価見積もり（モデル: {llm.DEFAULT_MODEL} / "
          f"1USD={llm.USD_JPY:.0f}円）")
    print(f"{'='*74}")
    header = f"  {'サービス':<14}{'想定原価':>10}{'想定単価':>20}{'粗利率':>10}"
    if target_income:
        header += f"{'目標必要件数':>12}"
    print(header)
    print(f"{'-'*74}")
    for key in services.keys():
        e = estimate(key)
        line = (f"  {e['service']:<14}{e['cost_jpy']:>9.0f}円"
                f"{e['price_min']:>11,}〜{e['price_max']:,}円{e['margin_min']:>9.1f}%")
        if target_income:
            per = e["price_min"] - e["cost_jpy"]
            need = int(-(-target_income // per)) if per > 0 else 0
            line += f"{need:>10} 件/月"
        print(line)
    print(f"{'-'*74}")
    print("  粗利率は最低単価で受けた場合の値。API利用料以外の経費は含みません")
    if target_income:
        print(f"  目標必要件数は月 {target_income:,}円を最低単価で達成するのに要する件数")
    print("  ※ 概算です。実績は `python main.py cost` で実測値を確認してください")
    print(f"{'='*74}")


def print_summary():
    s = summary()
    if not s["count"]:
        print("実行済みの案件がありません。まず `python main.py auto` を実行してください。")
        print("実行前の概算は `python main.py cost --estimate` で確認できます。")
        return

    print(f"\n{'='*74}")
    print(f"  原価・利益レポート（実測 {s['count']} 件）")
    print(f"{'='*74}")
    print(f"  売上   {s['sales']:>12,} 円")
    print(f"  原価   {s['cost']:>12,.0f} 円（API利用料）")
    print(f"  ─────────────────────")
    print(f"  粗利   {s['profit']:>12,.0f} 円   粗利率 {s['margin']}%")
    print(f"\n  1件あたり: 売価 {s['avg_price']:,}円 / 原価 {s['avg_cost']:.0f}円")
    print(f"  実行時間 : 合計 {s['auto_hours']}時間  → 実質時給 {s['hourly']:,} 円")
    print(f"  手作業なら {s['manual_hours']:g}時間かかる内容（{s['saved_hours']}時間の削減）")

    print(f"\n{'-'*74}")
    print(f"  {'サービス':<14}{'件数':>6}{'売上':>12}{'原価':>10}{'粗利率':>10}")
    print(f"{'-'*74}")
    for key, v in sorted(s["by_service"].items(), key=lambda x: -x[1]["sales"]):
        service = services.get(key)
        print(f"  {(service.name if service else key):<14}{v['count']:>6}"
              f"{v['sales']:>11,}円{v['cost']:>9.0f}円{v['margin']:>9.1f}%")
    print(f"{'='*74}")
