"""タスクと売上の記録・進捗管理。

副業が続かない最大の理由は「進んでいるか分からない」こと。
ここでは数字にして見せることに専念する。
"""
from datetime import datetime, timedelta

from . import store

TASKS = "tasks"
REVENUE = "revenue"

STATUS_MARK = {"todo": "[ ]", "doing": "[~]", "done": "[x]"}


# ---------------------------------------------------------------- タスク

def load_tasks() -> list:
    return store.load(TASKS, [])


def save_tasks(tasks: list):
    return store.save(TASKS, tasks)


def next_id(tasks: list) -> int:
    return max((t["id"] for t in tasks), default=0) + 1


def add_task(title: str, phase: str = "その他", due: str = "", idea_id=None,
             hours: float = 0) -> dict:
    tasks = load_tasks()
    task = {
        "id": next_id(tasks),
        "title": title,
        "phase": phase,
        "status": "todo",
        "due": due,
        "hours": hours,
        "idea_id": idea_id,
        "created_at": store.today(),
        "done_at": "",
    }
    tasks.append(task)
    save_tasks(tasks)
    return task


def add_tasks(items: list) -> list:
    """ロードマップ等からまとめて登録する。"""
    tasks = load_tasks()
    added = []
    for item in items:
        task = {
            "id": next_id(tasks),
            "title": item.get("title", ""),
            "phase": item.get("phase", "その他"),
            "status": "todo",
            "due": item.get("due", ""),
            "hours": item.get("hours", 0),
            "idea_id": item.get("idea_id"),
            "created_at": store.today(),
            "done_at": "",
        }
        tasks.append(task)
        added.append(task)
    save_tasks(tasks)
    return added


def set_status(task_id: int, status: str) -> dict:
    tasks = load_tasks()
    for t in tasks:
        if t["id"] == int(task_id):
            t["status"] = status
            t["done_at"] = store.today() if status == "done" else ""
            save_tasks(tasks)
            return t
    return None


def remove_task(task_id: int) -> bool:
    tasks = load_tasks()
    rest = [t for t in tasks if t["id"] != int(task_id)]
    if len(rest) == len(tasks):
        return False
    save_tasks(rest)
    return True


def progress(tasks: list = None) -> dict:
    """全体・フェーズ別の進捗率を計算する。"""
    tasks = load_tasks() if tasks is None else tasks
    total = len(tasks)
    done = sum(1 for t in tasks if t["status"] == "done")

    phases = {}
    for t in tasks:
        p = phases.setdefault(t["phase"], {"total": 0, "done": 0})
        p["total"] += 1
        if t["status"] == "done":
            p["done"] += 1
    for p in phases.values():
        p["rate"] = round(p["done"] / p["total"] * 100) if p["total"] else 0

    return {
        "total": total,
        "done": done,
        "rate": round(done / total * 100) if total else 0,
        "phases": phases,
    }


def overdue(tasks: list = None) -> list:
    """期限切れの未完了タスク。"""
    tasks = load_tasks() if tasks is None else tasks
    today = store.today()
    return [t for t in tasks if t["status"] != "done" and t["due"] and t["due"] < today]


def bar(rate: int, width: int = 20) -> str:
    filled = int(width * rate / 100)
    return "█" * filled + "░" * (width - filled)


def print_tasks(tasks: list = None, show_done: bool = False):
    tasks = load_tasks() if tasks is None else tasks
    if not tasks:
        print("タスクがありません。`python main.py plan <アイデア番号>` で計画を作るか、"
              "`python main.py task add \"やること\"` で追加してください。")
        return

    shown = tasks if show_done else [t for t in tasks if t["status"] != "done"]
    prog = progress(tasks)
    today = store.today()

    print(f"\n{'='*70}")
    print(f"  タスク  {prog['done']}/{prog['total']} 完了  {bar(prog['rate'])} {prog['rate']}%")
    print(f"{'='*70}")

    order = {}
    for t in tasks:
        order.setdefault(t["phase"], [])
    for phase in order:
        items = [t for t in shown if t["phase"] == phase]
        if not items:
            continue
        p = prog["phases"][phase]
        print(f"\n■ {phase}  ({p['done']}/{p['total']})")
        for t in items:
            mark = STATUS_MARK.get(t["status"], "[ ]")
            due = ""
            if t["due"]:
                late = "  ← 期限超過" if t["status"] != "done" and t["due"] < today else ""
                due = f"  〆{t['due']}{late}"
            hours = f"  {t['hours']}h" if t.get("hours") else ""
            print(f"  {mark} {t['id']:>3}. {t['title']}{hours}{due}")

    if not show_done and prog["done"]:
        print(f"\n  （完了 {prog['done']} 件は非表示。--all で表示）")
    print(f"\n{'='*70}")


# ---------------------------------------------------------------- 売上

def load_revenue() -> list:
    return store.load(REVENUE, [])


def add_revenue(amount: int, source: str, date: str = "", memo: str = "",
                hours: float = 0) -> dict:
    records = load_revenue()
    rec = {
        "id": max((r["id"] for r in records), default=0) + 1,
        "date": date or store.today(),
        "amount": int(amount),
        "source": source,
        "hours": hours,
        "memo": memo,
    }
    records.append(rec)
    records.sort(key=lambda r: r["date"])
    store.save(REVENUE, records)
    return rec


def monthly_revenue(records: list = None) -> dict:
    """年月ごとの売上合計。"""
    records = load_revenue() if records is None else records
    months = {}
    for r in records:
        key = r["date"][:7]
        m = months.setdefault(key, {"amount": 0, "count": 0, "hours": 0.0})
        m["amount"] += r["amount"]
        m["count"] += 1
        m["hours"] += float(r.get("hours") or 0)
    return dict(sorted(months.items()))


def hourly_rate(records: list = None):
    """記録された作業時間から実質時給を出す。時間未記録なら None。"""
    records = load_revenue() if records is None else records
    hours = sum(float(r.get("hours") or 0) for r in records)
    if hours <= 0:
        return None
    return round(sum(r["amount"] for r in records) / hours)


def print_revenue(target_income: int = 0):
    records = load_revenue()
    if not records:
        print("売上の記録がありません。`python main.py revenue add 5000 --source \"議事録作成\"` で記録できます。")
        return

    months = monthly_revenue(records)
    print(f"\n{'='*70}")
    print("  売上推移")
    print(f"{'='*70}")
    for month, m in months.items():
        rate = round(m["amount"] / target_income * 100) if target_income else 0
        gauge = f"  {bar(min(rate, 100))} 目標比 {rate}%" if target_income else ""
        print(f"  {month}  {m['amount']:>10,} 円  ({m['count']} 件){gauge}")

    total = sum(r["amount"] for r in records)
    hr = hourly_rate(records)
    print(f"\n  累計 {total:,} 円 / {len(records)} 件")
    if hr:
        print(f"  実質時給 {hr:,} 円")
    print(f"{'='*70}")


def week_range():
    """今週（月曜起点）の開始日・終了日を返す。"""
    today = datetime.now().date()
    start = today - timedelta(days=today.weekday())
    return start.isoformat(), (start + timedelta(days=6)).isoformat()
