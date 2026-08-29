"""プロジェクトの登録と実績管理。

収益モデルの違うものを横に並べて比較できるようにする。

  app     アプリ（アプリ内課金・広告）      → src/apps/model.py
  media   メディア（アフィリエイト・広告）  → src/media/model.py
  service 受託（納品して報酬）              → src/auto/
  other   その他
"""
from datetime import datetime

from .. import store

NAME = "projects"

TYPES = {
    "app": "アプリ",
    "media": "メディア",
    "service": "受託",
    "other": "その他",
}

STATUSES = ["企画", "開発中", "公開", "運用", "停止"]

# 判定に使うしきい値
GRACE_MONTHS = 4        # 公開からこの期間は収益ゼロでも判断を保留する
GIVEUP_MONTHS = 9       # 公開からこれを過ぎて収益ゼロなら撤退を検討する
STALL_MONTHS = 6        # 開発中のままこれを過ぎたら塩漬けとみなす
GROWTH_MONTHS = 3       # 成長率を見る期間

STATE = {
    "expand":  ("伸ばす", "伸びている。ここに時間を寄せる"),
    "keep":    ("維持", "稼いでいるが横ばい。手を入れる余地を探す"),
    "wait":    ("様子見", "公開から日が浅い。判断はまだ早い"),
    "fix":     ("てこ入れ", "公開しているのに収益が立っていない。原因を特定する"),
    "retire":  ("撤退検討", "十分な期間を与えても収益が立たない"),
    "release": ("公開優先", "開発が長い。まず世に出して反応を見る"),
    "build":   ("開発中", "作っている段階"),
    "stopped": ("停止中", "止めている"),
}

# 時間配分の重み。判定ごとの方針であって、最適化の結果ではない。
WEIGHT = {
    "expand": 3.0, "fix": 2.0, "release": 2.0, "keep": 1.5,
    "wait": 1.0, "build": 1.0, "retire": 0.0, "stopped": 0.0,
}


def load() -> list:
    return store.load(NAME, [])


def save(projects: list):
    return store.save(NAME, projects)


def find(pjt_id) -> dict:
    for p in load():
        if p["id"] == int(pjt_id):
            return p
    return None


def add(name: str, kind: str = "other", status: str = "企画", url: str = "",
        note: str = "", started: str = "", released: str = "") -> dict:
    projects = load()
    project = {
        "id": max((p["id"] for p in projects), default=0) + 1,
        "name": name,
        "type": kind,
        "status": status,
        "url": url,
        "note": note,
        "started_at": started or store.today(),
        "released_at": released,
        "records": [],          # [{month, revenue, cost, hours}]
        "created_at": store.now(),
    }
    projects.append(project)
    save(projects)
    return project


def update(pjt_id: int, **fields) -> dict:
    projects = load()
    for p in projects:
        if p["id"] == int(pjt_id):
            p.update(fields)
            save(projects)
            return p
    return None


def remove(pjt_id: int) -> bool:
    projects = load()
    rest = [p for p in projects if p["id"] != int(pjt_id)]
    if len(rest) == len(projects):
        return False
    save(rest)
    return True


def record(pjt_id: int, month: str = "", revenue: int = None, cost: int = None,
           hours: float = None) -> dict:
    """月次の実績を記録する。同じ月なら上書きする。"""
    month = month or store.today()[:7]
    projects = load()
    for p in projects:
        if p["id"] != int(pjt_id):
            continue
        entry = next((r for r in p["records"] if r["month"] == month), None)
        if entry is None:
            entry = {"month": month, "revenue": 0, "cost": 0, "hours": 0.0}
            p["records"].append(entry)
        if revenue is not None:
            entry["revenue"] = int(revenue)
        if cost is not None:
            entry["cost"] = int(cost)
        if hours is not None:
            entry["hours"] = float(hours)
        p["records"].sort(key=lambda r: r["month"])
        save(projects)
        return p
    return None


# ---------------------------------------------------------------- 集計

def months_since(date_str: str) -> float:
    if not date_str:
        return 0.0
    try:
        start = datetime.strptime(date_str[:10], "%Y-%m-%d")
    except ValueError:
        return 0.0
    return (datetime.now() - start).days / 30.4


def stats(project: dict) -> dict:
    """1プロジェクトの累計と直近の状況。"""
    records = project.get("records", [])
    revenue = sum(r["revenue"] for r in records)
    cost = sum(r["cost"] for r in records)
    hours = sum(r["hours"] for r in records)

    # 直近と、その前の同じ長さの期間を比べる。
    # 記録が少ないうちは窓を縮めて、2ヶ月分あれば比較できるようにする。
    window = min(GROWTH_MONTHS, len(records) // 2)
    growth = None
    if window >= 1:
        recent_rev = sum(r["revenue"] for r in records[-window:])
        prev_rev = sum(r["revenue"] for r in records[-window * 2:-window])
        if prev_rev > 0:
            growth = round((recent_rev - prev_rev) / prev_rev * 100)
        elif recent_rev > 0:
            growth = 100      # ゼロからの立ち上がり

    return {
        "months": len(records),
        "growth_window": window if window >= 1 else 0,
        "revenue": revenue,
        "cost": cost,
        "profit": revenue - cost,
        "hours": round(hours, 1),
        "hourly": round((revenue - cost) / hours) if hours else 0,
        "latest_month": records[-1]["month"] if records else "",
        "latest_revenue": records[-1]["revenue"] if records else 0,
        "growth": growth,
        "age_months": round(months_since(project.get("released_at")
                                        or project.get("started_at")), 1),
        "since_release": round(months_since(project["released_at"]), 1)
        if project.get("released_at") else None,
    }


def diagnose(project: dict, s: dict = None) -> str:
    """プロジェクトの状態を分類する。"""
    s = s or stats(project)
    status = project.get("status", "企画")

    if status == "停止":
        return "stopped"
    if status in ("企画", "開発中"):
        return "release" if months_since(project.get("started_at")) >= STALL_MONTHS \
            else "build"

    age = s["since_release"] if s["since_release"] is not None else s["age_months"]

    if s["latest_revenue"] > 0:
        if s["growth"] is not None and s["growth"] >= 20:
            return "expand"
        return "keep"

    # 公開しているのに収益が立っていない
    if age < GRACE_MONTHS:
        return "wait"
    if age >= GIVEUP_MONTHS:
        return "retire"
    return "fix"


def allocate(hours_per_week: float, projects: list = None) -> list:
    """週の稼働時間をプロジェクトに割り振る目安を出す。

    重みは判定ごとの方針。最適化ではないので、根拠を必ず併記する。
    """
    projects = load() if projects is None else projects
    rows = []
    for p in projects:
        s = stats(p)
        state = diagnose(p, s)
        rows.append({"project": p, "stats": s, "state": state,
                     "weight": WEIGHT[state]})

    total = sum(r["weight"] for r in rows)
    for r in rows:
        share = r["weight"] / total if total else 0
        # 0.5時間刻みに丸める
        r["hours"] = round(hours_per_week * share * 2) / 2
    return sorted(rows, key=lambda r: -r["hours"])


def totals(projects: list = None) -> dict:
    projects = load() if projects is None else projects
    month = store.today()[:7]

    revenue = cost = hours = 0
    this_month = 0
    for p in projects:
        s = stats(p)
        revenue += s["revenue"]
        cost += s["cost"]
        hours += s["hours"]
        for r in p.get("records", []):
            if r["month"] == month:
                this_month += r["revenue"]

    states = {}
    for p in projects:
        state = diagnose(p)
        states[state] = states.get(state, 0) + 1

    return {
        "count": len(projects),
        "revenue": revenue,
        "cost": cost,
        "profit": revenue - cost,
        "hours": round(hours, 1),
        "hourly": round((revenue - cost) / hours) if hours else 0,
        "this_month": this_month,
        "states": states,
    }
