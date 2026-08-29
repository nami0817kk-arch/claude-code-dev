"""ダッシュボード表示と Markdown レポート出力。"""
from pathlib import Path

from . import ideas, research, roadmap, store, tracker

REPORT_DIR = Path(__file__).resolve().parent.parent / "data" / "reports"


def _next_actions(tasks: list, limit: int = 3) -> list:
    """次に着手すべきタスク。期限が近い順、次に登録順。"""
    todo = [t for t in tasks if t["status"] != "done"]
    todo.sort(key=lambda t: (t["due"] or "9999-99-99", t["id"]))
    return todo[:limit]


def status(prof: dict) -> dict:
    """進捗・売上をまとめた状態を返す。"""
    tasks = tracker.load_tasks()
    records = tracker.load_revenue()
    months = tracker.monthly_revenue(records)
    this_month = store.today()[:7]
    current = months.get(this_month, {"amount": 0, "count": 0})

    target = prof.get("target_income", 0)
    return {
        "progress": tracker.progress(tasks),
        "overdue": tracker.overdue(tasks),
        "next_actions": _next_actions(tasks),
        "doing": [t for t in tasks if t["status"] == "doing"],
        "month": this_month,
        "month_amount": current["amount"],
        "month_count": current["count"],
        "target": target,
        "achievement": round(current["amount"] / target * 100) if target else 0,
        "total_amount": sum(r["amount"] for r in records),
        "hourly_rate": tracker.hourly_rate(records),
        "months": months,
    }


def print_status(prof: dict):
    s = status(prof)
    p = s["progress"]

    print(f"\n{'='*70}")
    print(f"  AI 副業ダッシュボード  {store.today()}")
    print(f"{'='*70}")

    print(f"\n【今月の売上】{s['month']}")
    print(f"  {s['month_amount']:,} 円 / 目標 {s['target']:,} 円   "
          f"{tracker.bar(min(s['achievement'], 100))} {s['achievement']}%")
    if s["month_count"]:
        print(f"  {s['month_count']} 件成約")
    if s["hourly_rate"]:
        print(f"  実質時給 {s['hourly_rate']:,} 円（累計 {s['total_amount']:,} 円）")
    elif s["total_amount"]:
        print(f"  累計 {s['total_amount']:,} 円")

    print("\n【タスク進捗】")
    if p["total"]:
        print(f"  {p['done']}/{p['total']} 完了   {tracker.bar(p['rate'])} {p['rate']}%")
        for name, ph in p["phases"].items():
            print(f"    {name:<24} {ph['done']}/{ph['total']}  {ph['rate']}%")
    else:
        print("  タスク未登録。`python main.py plan <アイデア番号>` で計画を作りましょう。")

    if s["doing"]:
        print("\n【着手中】")
        for t in s["doing"]:
            print(f"  [~] {t['id']}. {t['title']}")

    if s["next_actions"]:
        print("\n【次にやること】")
        for t in s["next_actions"]:
            due = f"  〆{t['due']}" if t["due"] else ""
            print(f"  {t['id']}. {t['title']}{due}")

    if s["overdue"]:
        print(f"\n【期限超過 {len(s['overdue'])} 件】")
        for t in s["overdue"]:
            print(f"  ! {t['id']}. {t['title']}  〆{t['due']}")
        print("  → 終わらせるか、期限を引き直すか、切り捨てるかを今決める")

    print(f"\n{'='*70}")


def export_markdown(prof: dict, idea_id=None) -> Path:
    """現状をまとめた Markdown レポートを data/reports/ に出力する。"""
    from . import profile as profile_mod

    s = status(prof)
    lines = [
        f"# AI 副業 進捗レポート  {store.today()}",
        "",
        "## プロフィール",
        "",
        profile_mod.summary_text(prof),
        "",
        "## 今月の状況",
        "",
        f"- 売上: {s['month_amount']:,} 円 / 目標 {s['target']:,} 円（達成率 {s['achievement']}%）",
        f"- 成約: {s['month_count']} 件",
        f"- タスク進捗: {s['progress']['done']}/{s['progress']['total']}（{s['progress']['rate']}%）",
    ]
    if s["hourly_rate"]:
        lines.append(f"- 実質時給: {s['hourly_rate']:,} 円")

    if s["months"]:
        lines += ["", "### 売上推移", "", "| 年月 | 売上 | 件数 |", "|---|---:|---:|"]
        for month, m in s["months"].items():
            lines.append(f"| {month} | {m['amount']:,} 円 | {m['count']} |")

    idea_list = ideas.load()
    if idea_list:
        lines += ["", "## アイデア一覧", "", "| # | アイデア | スコア | 月収目安 | 週工数 |", "|---:|---|---:|---:|---:|"]
        for it in idea_list:
            lines.append(
                f"| {it['id']} | {it['name']} | {it['score']['total']} | "
                f"{it.get('monthly_potential', 0):,} 円 | {it.get('hours_per_week', '-')}h |"
            )

    if idea_id:
        r = research.load(idea_id)
        if r:
            lines += ["", f"## 市場調査: {r.get('idea_name','')}", "",
                      f"- 判定: **{r.get('verdict','')}** — {r.get('verdict_reason','')}",
                      f"- 需要: {r.get('demand','')}",
                      f"- 価格方針: {r.get('price_advice','')}",
                      f"- 撤退基準: {r.get('kill_criteria','')}"]
        plan = roadmap.load(idea_id)
        if plan:
            lines += ["", f"## ロードマップ: {plan.get('idea_name','')}", "",
                      f"90日後のゴール: {plan.get('goal','')}", ""]
            for phase in plan.get("phases", []):
                lines += [f"### {phase.get('name','')}（{phase.get('period','')}）", "",
                          f"- 目標: {phase.get('goal','')}",
                          f"- KPI: {phase.get('kpi','')}", ""]
                for t in phase.get("tasks", []):
                    lines.append(f"  - [ ] {t.get('title','')}（{t.get('hours',0):g}h）")
                lines.append("")

    tasks = tracker.load_tasks()
    if tasks:
        lines += ["", "## タスク", ""]
        current_phase = None
        for t in sorted(tasks, key=lambda x: (x["phase"], x["id"])):
            if t["phase"] != current_phase:
                current_phase = t["phase"]
                lines += ["", f"### {current_phase}", ""]
            mark = "x" if t["status"] == "done" else " "
            due = f"  〆{t['due']}" if t["due"] else ""
            lines.append(f"- [{mark}] {t['title']}{due}")

    if s["overdue"]:
        lines += ["", "## 期限超過", ""]
        for t in s["overdue"]:
            lines.append(f"- {t['title']}（〆{t['due']}）")

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    path = REPORT_DIR / f"report-{store.today()}.md"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path
