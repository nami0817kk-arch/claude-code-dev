"""横断ダッシュボードと時間配分の表示。"""
from .. import store
from ..auto import jobs as jobs_mod
from . import projects as pjt


def bar(rate: int, width: int = 16) -> str:
    filled = int(width * min(max(rate, 0), 100) / 100)
    return "█" * filled + "░" * (width - filled)


def print_projects(target_income: int = 0):
    all_pjt = pjt.load()
    if not all_pjt:
        print("プロジェクトが登録されていません。")
        print('  例) python main.py pjt add "サッカーゲームアプリ" --type app --status 開発中')
        print('      python main.py pjt add "株式ランキング" --type media --status 公開')
        return

    t = pjt.totals(all_pjt)
    print(f"\n{'='*78}")
    print(f"  プロジェクト一覧  {store.today()}")
    print(f"{'='*78}")
    print(f"  {'#':>3} {'種別':<7}{'名称':<22}{'状態':<7}{'今月':>9}{'累計':>10}"
          f"{'時給':>9}  判定")
    print(f"{'-'*78}")
    for p in all_pjt:
        s = pjt.stats(p)
        state = pjt.diagnose(p, s)
        growth = f" {s['growth']:+d}%" if s["growth"] is not None else ""
        print(f"  {p['id']:>3} {pjt.TYPES.get(p['type'], p['type']):<7}"
              f"{p['name'][:20]:<22}{p['status']:<7}"
              f"{s['latest_revenue']:>8,}円{s['revenue']:>9,}円"
              f"{(str(s['hourly']) + '円' if s['hourly'] else '-'):>9}"
              f"  {pjt.STATE[state][0]}{growth}")
    print(f"{'-'*78}")
    print(f"  {t['count']}件 / 今月 {t['this_month']:,}円", end="")
    if target_income:
        rate = round(t["this_month"] / target_income * 100)
        print(f" / 目標 {target_income:,}円  {bar(rate)} {rate}%")
    else:
        print()
    print(f"  累計 収益 {t['revenue']:,}円 － 原価 {t['cost']:,}円 ＝ "
          f"{t['profit']:,}円 / 投下 {t['hours']}時間", end="")
    if t["hourly"]:
        print(f" → 実績時給 {t['hourly']:,}円")
    else:
        print()
    print(f"{'='*78}")


def print_project(project: dict):
    s = pjt.stats(project)
    state = pjt.diagnose(project, s)
    label, advice = pjt.STATE[state]

    print(f"\n{'='*78}")
    print(f"  [{project['id']}] {project['name']}  "
          f"<{pjt.TYPES.get(project['type'], project['type'])} / {project['status']}>")
    print(f"{'='*78}")
    if project.get("url"):
        print(f"  URL      : {project['url']}")
    print(f"  開始     : {project['started_at']}", end="")
    if project.get("released_at"):
        print(f"   公開: {project['released_at']}（{s['since_release']}ヶ月経過）")
    else:
        print("   未公開")
    if project.get("note"):
        print(f"  メモ     : {project['note']}")

    print(f"\n  判定     : {label} — {advice}")
    if s["months"]:
        print(f"  累計     : 収益 {s['revenue']:,}円 / 原価 {s['cost']:,}円 / "
              f"{s['hours']}時間")
        if s["hourly"]:
            print(f"  実績時給 : {s['hourly']:,}円")
        if s["growth"] is not None:
            print(f"  直近{s['growth_window']}ヶ月の伸び: {s['growth']:+d}%"
                  f"（その前の{s['growth_window']}ヶ月との比較）")

        print(f"\n  {'年月':<9}{'収益':>10}{'原価':>10}{'時間':>8}{'時給':>10}")
        print(f"  {'-'*47}")
        for r in project["records"]:
            hourly = round((r["revenue"] - r["cost"]) / r["hours"]) if r["hours"] else 0
            print(f"  {r['month']:<9}{r['revenue']:>9,}円{r['cost']:>9,}円"
                  f"{r['hours']:>7g}h{(str(hourly) + '円' if hourly else '-'):>10}")
    else:
        print("  実績がまだ記録されていません。")
        print(f"    python main.py pjt record {project['id']} --revenue 3000 --hours 12")
    print(f"{'='*78}")


def print_allocation(hours_per_week: float):
    rows = pjt.allocate(hours_per_week)
    if not rows:
        print("プロジェクトが登録されていません。")
        return

    print(f"\n{'='*78}")
    print(f"  時間配分の目安  週 {hours_per_week:g} 時間")
    print(f"{'='*78}")
    for r in rows:
        p, s, state = r["project"], r["stats"], r["state"]
        label, advice = pjt.STATE[state]
        if r["hours"] <= 0:
            print(f"\n  {p['name']}  0h  <{label}>")
            print(f"      → {advice}")
            continue

        print(f"\n  {p['name']}  {r['hours']:g}h/週  <{label}>")
        evidence = []
        if s["latest_revenue"]:
            evidence.append(f"今月 {s['latest_revenue']:,}円")
        if s["hourly"]:
            evidence.append(f"実績時給 {s['hourly']:,}円")
        if s["growth"] is not None:
            evidence.append(f"直近{s['growth_window']}ヶ月 {s['growth']:+d}%")
        if s["since_release"] is not None:
            evidence.append(f"公開から{s['since_release']}ヶ月")
        elif p["status"] in ("企画", "開発中"):
            evidence.append(f"着手から{round(pjt.months_since(p['started_at']), 1)}ヶ月")
        if evidence:
            print(f"      {' / '.join(evidence)}")
        print(f"      → {advice}")

    print(f"\n{'-'*78}")
    print("  この配分は判定ごとの方針であって、最適化の結果ではありません。")
    print("  収益の出ていないものに時間を割く判断も、伸びているものに寄せる判断も、")
    print("  最終的には運営者が決めるものです。数字は材料として使ってください。")
    print(f"{'='*78}")


def print_review(target_income: int = 0):
    """判定ごとにまとめて、次の一手を出す。"""
    all_pjt = pjt.load()
    if not all_pjt:
        print("プロジェクトが登録されていません。")
        return

    grouped = {}
    for p in all_pjt:
        grouped.setdefault(pjt.diagnose(p), []).append(p)

    print(f"\n{'='*78}")
    print("  ポートフォリオの見直し")
    print(f"{'='*78}")

    order = ["expand", "fix", "release", "keep", "wait", "retire", "build", "stopped"]
    for state in order:
        items = grouped.get(state)
        if not items:
            continue
        label, advice = pjt.STATE[state]
        print(f"\n■ {label}  — {advice}")
        for p in items:
            s = pjt.stats(p)
            detail = f"今月 {s['latest_revenue']:,}円" if s["months"] else "実績未記録"
            print(f"    [{p['id']}] {p['name']}  {detail}")

    if grouped.get("retire"):
        print(f"\n  ※ 撤退検討に入ったものは、公開から{pjt.GIVEUP_MONTHS}ヶ月以上たって"
              "収益が立っていないものです。")
        print("     残すか畳むかを決めてください。決めないまま抱えるのが一番損をします。")

    t = pjt.totals(all_pjt)
    if target_income and t["this_month"] < target_income:
        gap = target_income - t["this_month"]
        print(f"\n  目標まで あと {gap:,}円/月")
        best = max(all_pjt, key=lambda p: pjt.stats(p)["latest_revenue"], default=None)
        if best and pjt.stats(best)["latest_revenue"] > 0:
            print(f"  いま一番稼いでいるのは「{best['name']}」です。"
                  "新しいものを増やす前に、これを伸ばせないか先に考えてください。")
    print(f"\n{'='*78}")


def sync_service_revenue(project_id: int, month: str = "") -> dict:
    """受託案件（src/auto）の実績を、指定プロジェクトの月次記録に取り込む。"""
    month = month or store.today()[:7]
    revenue = cost = 0
    for job in jobs_mod.load():
        if not job.get("run_at", "").startswith(month):
            continue
        if job.get("revenue_recorded"):
            revenue += job.get("price", 0) or 0
        cost += job.get("cost_jpy", 0) or 0

    pjt.record(project_id, month=month, revenue=revenue, cost=round(cost))
    return {"month": month, "revenue": revenue, "cost": round(cost)}
