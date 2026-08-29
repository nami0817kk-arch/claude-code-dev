"""ローカルで開くダッシュボード画面を生成する。

data/ 配下の記録を1枚の HTML にまとめる。外部ライブラリも通信も使わないので、
ファイルをダブルクリックすればオフラインで開き、収益データが外に出ることもない。

  python main.py screen --open
"""
import html
import json
from datetime import datetime
from pathlib import Path

from . import profile as profile_mod
from . import expenses as expense_mod
from . import store, tracker
from .auto import jobs as jobs_mod
from .media import analytics as media_analytics
from .media import articles as media_articles
from .portfolio import projects as pjt

OUTPUT = Path(__file__).resolve().parent.parent / "dashboard.html"

# データビズの検証済みパレット（validate_palette.js で light/dark とも全項目 PASS）
SERIES_LIGHT = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300"]
SERIES_DARK = ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#008300"]

# 判定バッジの色。状態色は系列色と混ざらないよう固定で、必ず文字ラベルと併記する。
STATE_TONE = {
    "expand": "good", "keep": "neutral", "wait": "muted", "fix": "warning",
    "retire": "critical", "release": "serious", "build": "muted", "stopped": "muted",
}


# ---------------------------------------------------------------- データ収集

def month_range(months: list) -> list:
    """記録のある最初の月から最新月までを、抜けなく並べる。"""
    if not months:
        return []
    start, end = min(months), max(months)
    out, (y, m) = [], (int(start[:4]), int(start[5:7]))
    end_y, end_m = int(end[:4]), int(end[5:7])
    while (y, m) <= (end_y, end_m):
        out.append(f"{y:04d}-{m:02d}")
        m += 1
        if m > 12:
            y, m = y + 1, 1
    return out


def collect() -> dict:
    """画面に出す材料を全部集める。記録が無い部分は空のまま返す。"""
    prof = profile_mod.load()
    projects = pjt.load()
    this_month = store.today()[:7]

    # プロジェクトが未登録なら、受託の売上記録だけでも1系列として見せる
    if not projects and tracker.load_revenue():
        months = {}
        for r in tracker.load_revenue():
            key = r["date"][:7]
            months[key] = months.get(key, 0) + r["amount"]
        projects = [{
            "id": 0, "name": "受託（売上記録）", "type": "service", "status": "運用",
            "started_at": "", "released_at": "", "url": "", "note": "",
            "records": [{"month": k, "revenue": v, "cost": 0, "hours": 0.0}
                        for k, v in sorted(months.items())],
        }]

    rows = []
    for p in projects:
        s = pjt.stats(p)
        rows.append({
            "project": p,
            "stats": s,
            "state": pjt.diagnose(p, s),
            "by_month": {r["month"]: r for r in p.get("records", [])},
        })

    totals = pjt.totals(projects) if projects else {
        "count": 0, "revenue": 0, "cost": 0, "profit": 0, "hours": 0,
        "hourly": 0, "this_month": 0, "states": {},
    }

    month_hours = sum(r["by_month"].get(this_month, {}).get("hours", 0) for r in rows)
    month_cost = sum(r["by_month"].get(this_month, {}).get("cost", 0) for r in rows)

    # 共通経費（利用料など）とプロジェクト原価を合わせたものが実際の投資額
    exp_records = expense_mod.load()
    exp_by_month = expense_mod.by_month(exp_records)
    all_months = month_range(
        [r["month"] for p in projects for r in p.get("records", [])]
        + list(exp_by_month))

    project_cost = totals["cost"]
    investment = expense_mod.total(exp_records) + project_cost
    revenue_total = totals["revenue"]
    run_rate = expense_mod.monthly_run_rate(exp_records) + month_cost

    # 前月比（今月がまだ途中でも、伸びの向きは見たい）
    previous = 0
    if len(all_months) >= 2:
        prev_key = all_months[-2] if all_months[-1] == this_month else all_months[-1]
        previous = sum(r["by_month"].get(prev_key, {}).get("revenue", 0) for r in rows)

    # 月ごとの収支
    flow = []
    cumulative = 0
    for month in all_months:
        income = sum(r["by_month"].get(month, {}).get("revenue", 0) for r in rows)
        spend = (exp_by_month.get(month, 0)
                 + sum(r["by_month"].get(month, {}).get("cost", 0) for r in rows))
        cumulative += income - spend
        flow.append({"month": month, "income": income, "spend": spend,
                     "cumulative": cumulative})

    return {
        "expenses": {
            "records": exp_records,
            "by_item": expense_mod.by_item(exp_records),
            "total": expense_mod.total(exp_records),
            "this_month": expense_mod.this_month(exp_records),
            "months": expense_mod.months_elapsed(exp_records),
        },
        "flow": flow,
        "investment": investment,
        "revenue_total": revenue_total,
        "net": revenue_total - investment,
        "run_rate": run_rate,
        "phase": "investment" if revenue_total == 0 else "growth",
        "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "profile": prof,
        "rows": rows,
        "months": all_months,
        "totals": totals,
        "this_month": this_month,
        "previous_month_revenue": previous,
        "month_hours": round(month_hours, 1),
        "month_cost": round(month_cost),
        "allocation": pjt.allocate(prof["hours_per_week"], projects) if projects else [],
        "tasks": task_summary(),
        "jobs": job_summary(),
        "articles": article_summary(),
    }


def task_summary() -> dict:
    tasks = tracker.load_tasks()
    prog = tracker.progress(tasks)
    return {
        "total": prog["total"], "done": prog["done"], "rate": prog["rate"],
        "overdue": [{"id": t["id"], "title": t["title"], "due": t["due"]}
                    for t in tracker.overdue(tasks)],
        "next": [{"id": t["id"], "title": t["title"], "due": t["due"]}
                 for t in sorted((t for t in tasks if t["status"] != "done"),
                                 key=lambda t: (t["due"] or "9999", t["id"]))[:5]],
    }


def job_summary() -> dict:
    jobs = jobs_mod.load()
    states = {}
    for j in jobs:
        states[j["status"]] = states.get(j["status"], 0) + 1
    return {
        "total": len(jobs),
        "pending": states.get("pending", 0),
        "review": states.get("review", 0),
        "failed": states.get("failed", 0),
        "cost": round(sum(j.get("cost_jpy", 0) or 0 for j in jobs)),
    }


def article_summary() -> dict:
    arts = media_articles.load()
    if not arts:
        return {"total": 0, "published": 0, "pv": 0, "revenue": 0, "queue": []}
    t = media_analytics.totals()
    queue = media_analytics.rewrite_queue()[:5]
    return {
        "total": t["written"], "published": t["published"],
        "pv": t["pv"], "revenue": t["revenue"], "cost": t["cost"],
        "queue": [{"id": a["keyword_id"], "keyword": a["keyword"],
                   "state": media_analytics.DIAGNOSIS[a["state"]][0],
                   "upside": a["upside"]} for a in queue],
    }


# ---------------------------------------------------------------- SVG 部品

def esc(text) -> str:
    return html.escape(str(text), quote=True)


def yen(value) -> str:
    return f"{round(value):,}"


def nice_ceiling(value: float) -> int:
    """軸の上限を、切りのいい数に丸める。

    刻みを細かく持つのは、目盛りの上限が実データより極端に高くなって
    棒が潰れるのを防ぐため。
    """
    if value <= 0:
        return 1000
    step = 10 ** (len(str(int(value))) - 1)
    for mult in (1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10):
        top = step * mult
        if top >= value:
            return int(top)
    return int(step * 10)


def rounded_top(x: float, y: float, w: float, h: float, r: float = 4) -> str:
    """上端だけ角丸、下端は角のままのパス。棒はベースラインに接地させる。"""
    r = min(r, w / 2, h)
    return (f"M{x:.1f},{y + h:.1f} V{y + r:.1f} Q{x:.1f},{y:.1f} {x + r:.1f},{y:.1f} "
            f"H{x + w - r:.1f} Q{x + w:.1f},{y:.1f} {x + w:.1f},{y + r:.1f} "
            f"V{y + h:.1f} Z")


def rounded_bottom(x: float, y: float, w: float, h: float, r: float = 4) -> str:
    """下端だけ角丸。ゼロ線から下に伸びる棒（支出）用。"""
    r = min(r, w / 2, h)
    return (f"M{x:.1f},{y:.1f} H{x + w:.1f} V{y + h - r:.1f} "
            f"Q{x + w:.1f},{y + h:.1f} {x + w - r:.1f},{y + h:.1f} "
            f"H{x + r:.1f} Q{x:.1f},{y + h:.1f} {x:.1f},{y + h - r:.1f} Z")


def nice_step(span: float, divisions: int = 4) -> int:
    """目盛りの刻み幅を、切りのいい数にする。"""
    if span <= 0:
        return 1000
    raw = span / divisions
    step = 10 ** (len(str(int(raw))) - 1) if raw >= 1 else 1
    for mult in (1, 2, 2.5, 5, 10):
        if step * mult >= raw:
            return int(step * mult)
    return int(step * 10)


def flow_chart(data: dict) -> str:
    """月次の収支。収益を上、支出を下に出し、累積損益を線で重ねる。

    収益がまだ無い時期は棒が下にしか出ないが、それが実態なので隠さない。
    累積線が下がり続けているのか、底を打ったのかが一目で分かることを優先する。
    """
    flow = data["flow"]
    if not flow:
        return ('<p class="empty">まだ記録がありません。'
                '<code>expense add</code> で経費を、<code>pjt record</code> で'
                '収益を登録すると、ここに収支の推移が出ます。</p>')

    W, H = 760, 320
    pad = {"t": 22, "r": 20, "b": 46, "l": 72}
    plot_w = W - pad["l"] - pad["r"]
    plot_h = H - pad["t"] - pad["b"]

    series = data["rows"][:len(SERIES_LIGHT)]
    other = data["rows"][len(SERIES_LIGHT):]

    max_income = max([f["income"] for f in flow] + [0])
    max_spend = max([f["spend"] for f in flow] + [0])
    cums = [f["cumulative"] for f in flow]
    top = max(max_income, max(cums), 0)
    bottom = min(-max_spend, min(cums), 0)
    if top == bottom:
        top, bottom = 1000, 0

    step = nice_step(top - bottom)
    top = (int(top / step) + (1 if top % step else 0)) * step or step
    bottom = -((int(-bottom / step) + (1 if (-bottom) % step else 0)) * step) \
        if bottom < 0 else 0

    span = top - bottom
    band = plot_w / len(flow)
    bar_w = min(24, band * 0.5)

    def y_of(value):
        return pad["t"] + plot_h - ((value - bottom) / span * plot_h)

    parts = [f'<svg viewBox="0 0 {W} {H}" role="img" '
             f'aria-label="月次の収益・支出と累積損益の推移">']

    value = bottom
    while value <= top + 1:
        y = y_of(value)
        cls = "zero" if value == 0 else "grid"
        parts.append(f'<line class="{cls}" x1="{pad["l"]}" y1="{y:.1f}" '
                     f'x2="{W - pad["r"]}" y2="{y:.1f}"/>')
        parts.append(f'<text class="tick" x="{pad["l"] - 10}" y="{y + 4:.1f}" '
                     f'text-anchor="end">{yen(value)}</text>')
        value += step

    zero_y = y_of(0)
    line_points = []

    for fi, f in enumerate(flow):
        cx = pad["l"] + band * (fi + 0.5)
        x = cx - bar_w / 2

        # 収益（上向き・プロジェクト別の積み上げ）
        cursor = zero_y
        stack = []
        for si, row in enumerate(series):
            v = row["by_month"].get(f["month"], {}).get("revenue", 0)
            if v > 0:
                stack.append((si, row["project"]["name"], v))
        if other:
            rest = sum(r["by_month"].get(f["month"], {}).get("revenue", 0)
                       for r in other)
            if rest > 0:
                stack.append((len(SERIES_LIGHT) - 1, "その他", rest))

        for idx, (si, name, v) in enumerate(stack):
            h = v / span * plot_h
            gap = 2 if idx < len(stack) - 1 else 0
            h_draw = max(1.0, h - gap)
            y = cursor - h
            tip = f"{f['month']}｜収益 {name}｜{yen(v)}円"
            shape = (rounded_top(x, y, bar_w, h_draw) if idx == len(stack) - 1
                     else f"M{x:.1f},{y:.1f} h{bar_w:.1f} v{h_draw:.1f} h-{bar_w:.1f} Z")
            parts.append(f'<path class="seg s{si + 1}" d="{shape}" tabindex="0" '
                         f'data-tip="{esc(tip)}"><title>{esc(tip)}</title></path>')
            cursor = y

        # 支出（下向き・単色）
        if f["spend"] > 0:
            h = f["spend"] / span * plot_h
            tip = f"{f['month']}｜支出｜{yen(f['spend'])}円"
            parts.append(f'<path class="seg spend" '
                         f'd="{rounded_bottom(x, zero_y, bar_w, max(1.0, h))}" '
                         f'tabindex="0" data-tip="{esc(tip)}">'
                         f'<title>{esc(tip)}</title></path>')

        line_points.append((cx, y_of(f["cumulative"])))

    # 累積損益（サマリーの線なので、系列色ではなく中立色にする）
    if len(line_points) >= 2:
        d = " ".join(f"{'M' if i == 0 else 'L'}{x:.1f},{y:.1f}"
                     for i, (x, y) in enumerate(line_points))
        parts.append(f'<path class="cum-line" d="{d}"/>')
    ex, ey = line_points[-1]
    parts.append(f'<circle class="cum-dot" cx="{ex:.1f}" cy="{ey:.1f}" r="4.5"/>')
    last = flow[-1]["cumulative"]
    anchor = "end" if len(flow) > 1 else "middle"
    parts.append(f'<text class="cum-label" x="{ex - 8:.1f}" '
                 f'y="{ey + (16 if last < 0 else -12):.1f}" text-anchor="{anchor}">'
                 f'累積 {yen(last)}円</text>')

    for fi, f in enumerate(flow):
        cx = pad["l"] + band * (fi + 0.5)
        label = (f["month"][5:7] + "月"
                 if fi and f["month"][:4] == flow[fi - 1]["month"][:4]
                 else f["month"])
        parts.append(f'<text class="tick" x="{cx:.1f}" y="{H - 22}" '
                     f'text-anchor="middle">{esc(label)}</text>')

    parts.append("</svg>")

    keys = []
    if max_income > 0:
        for si, row in enumerate(series):
            if row["stats"]["revenue"]:
                keys.append(f'<span class="key"><i class="dot s{si + 1}"></i>'
                            f'{esc(row["project"]["name"])}</span>')
    keys.append('<span class="key"><i class="dot spend-dot"></i>支出</span>')
    keys.append('<span class="key"><i class="line-key"></i>累積損益</span>')

    return (f'<div class="chart">{"".join(parts)}</div>'
            f'<div class="legend">{"".join(keys)}</div>')


def sparkline(values: list, slot: int) -> str:
    """月次推移の小さな折れ線。末端に丸マーカーを置く。"""
    if len(values) < 2:
        return '<span class="spark-empty">—</span>'
    W, H, pad = 96, 26, 4
    top = max(values) or 1
    step = (W - pad * 2) / (len(values) - 1)
    points = [(pad + i * step, H - pad - (v / top) * (H - pad * 2))
              for i, v in enumerate(values)]
    path = " ".join(f"{'M' if i == 0 else 'L'}{x:.1f},{y:.1f}"
                    for i, (x, y) in enumerate(points))
    ex, ey = points[-1]
    return (f'<svg class="spark" viewBox="0 0 {W} {H}" aria-hidden="true">'
            f'<path class="spark-line s{slot}" d="{path}"/>'
            f'<circle class="spark-dot s{slot}" cx="{ex:.1f}" cy="{ey:.1f}" r="4"/>'
            f'</svg>')


def meter(rate: int, tone: str = "") -> str:
    """1つの比率を、同じ色相のトラックの上に見せる。"""
    rate = max(0, min(100, int(rate)))
    return (f'<div class="meter{" " + tone if tone else ""}">'
            f'<div class="meter-fill" style="width:{rate}%"></div></div>')


# ---------------------------------------------------------------- HTML 生成

STYLE = """
:root{
  color-scheme: light;
  --page:#f9f9f7; --surface:#fcfcfb; --border:rgba(11,11,11,.10);
  --ink:#0b0b0b; --ink-2:#52514e; --muted:#898781;
  --grid:#e1e0d9; --axis:#c3c2b7;
  --good:#0ca30c; --warning:#fab219; --serious:#ec835a; --critical:#d03b3b;
  --up:#006300;
  --s1:#2a78d6; --s2:#eb6834; --s3:#1baf7a; --s4:#eda100; --s5:#e87ba4; --s6:#008300;
  --track:#e8e7e1;
}
@media (prefers-color-scheme: dark){
  :root:not([data-theme="light"]){
    color-scheme: dark;
    --page:#0d0d0d; --surface:#1a1a19; --border:rgba(255,255,255,.10);
    --ink:#fff; --ink-2:#c3c2b7; --muted:#898781;
    --grid:#2c2c2a; --axis:#383835; --up:#0ca30c;
    --s1:#3987e5; --s2:#d95926; --s3:#199e70; --s4:#c98500; --s5:#d55181; --s6:#008300;
    --track:#2c2c2a;
  }
}
:root[data-theme="dark"]{
  color-scheme: dark;
  --page:#0d0d0d; --surface:#1a1a19; --border:rgba(255,255,255,.10);
  --ink:#fff; --ink-2:#c3c2b7; --muted:#898781;
  --grid:#2c2c2a; --axis:#383835; --up:#0ca30c;
  --s1:#3987e5; --s2:#d95926; --s3:#199e70; --s4:#c98500; --s5:#d55181; --s6:#008300;
  --track:#2c2c2a;
}
*{box-sizing:border-box}
body{
  margin:0; background:var(--page); color:var(--ink);
  font:14px/1.6 system-ui,-apple-system,"Segoe UI","Hiragino Sans","Yu Gothic UI",sans-serif;
}
.wrap{max-width:1080px; margin:0 auto; padding:28px 20px 64px}
header{display:flex; align-items:baseline; gap:12px; flex-wrap:wrap; margin-bottom:24px}
h1{font-size:19px; margin:0; letter-spacing:.01em}
.stamp{color:var(--muted); font-size:12px}
.toggle{
  margin-left:auto; background:var(--surface); color:var(--ink-2);
  border:1px solid var(--border); border-radius:999px; padding:5px 13px;
  font:inherit; font-size:12px; cursor:pointer;
}
.toggle:hover{color:var(--ink)}
section{
  background:var(--surface); border:1px solid var(--border); border-radius:12px;
  padding:20px 22px; margin-bottom:16px;
}
h2{font-size:13px; margin:0 0 16px; color:var(--ink-2); font-weight:600;
   letter-spacing:.04em}
.hero{display:flex; gap:36px; align-items:flex-end; flex-wrap:wrap}
.hero-num{font-size:52px; line-height:1.05; font-weight:600; letter-spacing:-.02em}
.hero-num small{font-size:20px; font-weight:500; color:var(--ink-2); margin-left:4px}
.hero-sub{color:var(--ink-2); font-size:13px; margin-top:6px}
.hero-goal{flex:1; min-width:260px}
.goal-row{display:flex; justify-content:space-between; font-size:12px;
          color:var(--ink-2); margin-bottom:7px}
.delta{font-size:13px; font-weight:600}
.delta.up{color:var(--up)} .delta.down{color:var(--critical)}
.meter{height:9px; background:var(--track); border-radius:999px; overflow:hidden}
.meter-fill{height:100%; background:var(--s1); border-radius:999px}
.meter.good .meter-fill{background:var(--good)}
.meter.warning .meter-fill{background:var(--warning)}
.kpis{display:grid; grid-template-columns:repeat(auto-fit,minmax(158px,1fr)); gap:14px}
.kpi{padding:14px 16px; border:1px solid var(--border); border-radius:10px}
.kpi .label{color:var(--muted); font-size:11.5px; letter-spacing:.03em}
.kpi .value{font-size:25px; font-weight:600; margin-top:5px; letter-spacing:-.01em}
.kpi .value small{font-size:13px; font-weight:500; color:var(--ink-2); margin-left:2px}
.kpi .note{color:var(--muted); font-size:11.5px; margin-top:3px}
.chart{width:100%; overflow-x:auto}
svg{display:block; width:100%; height:auto; max-width:100%}
.grid{stroke:var(--grid); stroke-width:1}
.axis{stroke:var(--axis); stroke-width:1}
.tick{fill:var(--muted); font-size:11px}
.seg{outline:none}
.seg:hover,.seg:focus{opacity:.82}
.s1{--c:var(--s1)} .s2{--c:var(--s2)} .s3{--c:var(--s3)}
.s4{--c:var(--s4)} .s5{--c:var(--s5)} .s6{--c:var(--s6)}
path.seg{fill:var(--c)}
.legend{display:flex; flex-wrap:wrap; gap:8px 18px; margin-top:14px;
        font-size:12px; color:var(--ink-2)}
.key{display:inline-flex; align-items:center; gap:7px}
.dot{width:9px; height:9px; border-radius:3px; background:var(--c); display:inline-block}
.spark-line{fill:none; stroke:var(--c); stroke-width:2; stroke-linejoin:round;
            stroke-linecap:round}
.spark-dot{fill:var(--c); stroke:var(--surface); stroke-width:2}
.spark-empty{color:var(--muted)}
.zero{stroke:var(--axis); stroke-width:1.5}
path.seg.spend{fill:var(--muted); opacity:.55}
.spend-dot{background:var(--muted); opacity:.55}
.cum-line{fill:none; stroke:var(--ink-2); stroke-width:2; stroke-linejoin:round;
          stroke-linecap:round}
.cum-dot{fill:var(--ink-2); stroke:var(--surface); stroke-width:2}
.cum-label{fill:var(--ink-2); font-size:11px; font-weight:600}
.line-key{width:14px; height:2px; background:var(--ink-2); display:inline-block;
          border-radius:2px}
table{width:100%; border-collapse:collapse; font-size:13px}
th{text-align:left; color:var(--muted); font-weight:600; font-size:11.5px;
   letter-spacing:.03em; padding:0 10px 9px; border-bottom:1px solid var(--border)}
td{padding:12px 10px; border-bottom:1px solid var(--border); vertical-align:middle}
tr:last-child td{border-bottom:none}
td.num,th.num{text-align:right; font-variant-numeric:tabular-nums}
.pname{display:flex; align-items:center; gap:9px; font-weight:500}
.sub{color:var(--muted); font-size:11.5px; font-weight:400}
.badge{display:inline-flex; align-items:center; gap:6px; font-size:12px;
       white-space:nowrap}
.badge i{width:8px; height:8px; border-radius:50%; flex:none}
.badge.good i{background:var(--good)} .badge.warning i{background:var(--warning)}
.badge.critical i{background:var(--critical)} .badge.serious i{background:var(--serious)}
.badge.neutral i{background:var(--s1)} .badge.muted i{background:var(--muted)}
.cols{display:grid; grid-template-columns:repeat(auto-fit,minmax(300px,1fr)); gap:16px}
.list{list-style:none; margin:0; padding:0}
.list li{display:flex; gap:10px; align-items:baseline; padding:9px 0;
         border-bottom:1px solid var(--border); font-size:13px}
.list li:last-child{border-bottom:none}
.list .tag{color:var(--muted); font-size:11.5px; white-space:nowrap; margin-left:auto}
.list .tag.alert{color:var(--critical); font-weight:600}
.alloc{display:flex; align-items:center; gap:12px; padding:9px 0}
.alloc .n{width:126px; font-size:13px; flex:none}
.alloc .h{width:64px; text-align:right; font-variant-numeric:tabular-nums;
          font-weight:600; flex:none}
.alloc .track{flex:1; height:9px; background:var(--track); border-radius:999px}
.alloc .fill{height:100%; background:var(--s1); border-radius:999px}
.empty{color:var(--muted); font-size:13px; margin:0}
.empty code{background:var(--track); padding:1px 6px; border-radius:4px; font-size:12px}
.note-line{color:var(--muted); font-size:12px; margin:14px 0 0}
.note-line code{background:var(--track); padding:1px 6px; border-radius:4px}
.hero-num.minus{color:var(--critical)}
.list.steps li{display:block; padding:12px 0}
.list.steps b{font-weight:600}
#tip{
  position:fixed; pointer-events:none; opacity:0; transition:opacity .12s;
  background:var(--ink); color:var(--surface); font-size:12px; padding:6px 10px;
  border-radius:6px; white-space:nowrap; z-index:9;
}
@media (max-width:600px){
  .hero-num{font-size:40px}
  .wrap{padding:20px 14px 48px}
  section{padding:16px}
}
"""

SCRIPT = """
(function(){
  var root=document.documentElement, key='pjt-dashboard-theme';
  try{ var saved=localStorage.getItem(key); if(saved) root.setAttribute('data-theme',saved); }
  catch(e){}
  var btn=document.getElementById('toggle');
  if(btn) btn.addEventListener('click',function(){
    var dark=getComputedStyle(root).getPropertyValue('--page').trim()==='#0d0d0d';
    var next=dark?'light':'dark';
    root.setAttribute('data-theme',next);
    try{ localStorage.setItem(key,next); }catch(e){}
  });
  var tip=document.getElementById('tip');
  function show(e,text){
    tip.textContent=text; tip.style.opacity='1';
    var x=e.clientX+14, y=e.clientY-34;
    if(x+tip.offsetWidth>window.innerWidth-8) x=window.innerWidth-tip.offsetWidth-8;
    tip.style.left=x+'px'; tip.style.top=Math.max(8,y)+'px';
  }
  document.querySelectorAll('[data-tip]').forEach(function(el){
    el.addEventListener('mousemove',function(e){ show(e,el.dataset.tip); });
    el.addEventListener('mouseleave',function(){ tip.style.opacity='0'; });
    el.addEventListener('focus',function(){
      var r=el.getBoundingClientRect();
      show({clientX:r.left+r.width/2,clientY:r.top},el.dataset.tip);
    });
    el.addEventListener('blur',function(){ tip.style.opacity='0'; });
  });
})();
"""


def render_hero(d: dict) -> str:
    """収益が出ていない時期は、目標達成率ではなく投資額と回収ラインを主役にする。"""
    t, prof = d["totals"], d["profile"]
    target = prof["target_income"]
    current = t["this_month"]

    if d["phase"] == "investment":
        run_rate = d["run_rate"]
        months = len(d["months"])
        period = f"{months}ヶ月" if months else "記録なし"
        goal = ""
        if run_rate:
            goal = f"""
      <div class="hero-goal">
        <div class="goal-row"><span>まず目指す線：支出と同額</span>
          <span>0 / {yen(run_rate)} 円　<b>0%</b></span></div>
        {meter(0)}
        <div class="goal-row" style="margin:8px 0 0">
          <span>ここを超えると、続けるほど損をする状態ではなくなります</span></div>
        <div class="goal-row" style="margin:14px 0 0">
          <span>その先の目標</span><span>月 {yen(target)} 円</span></div>
        {meter(0)}
      </div>"""
        return f"""
  <section>
    <div class="hero">
      <div>
        <div class="stamp">まだ回収していない額（投資フェーズ）</div>
        <div class="hero-num minus">−{yen(d["investment"])}<small>円</small></div>
        <div class="delta down">収益はまだ発生していません<span class="sub">
          （{esc(period)}継続・毎月 {yen(run_rate)}円 の支出）</span></div>
      </div>{goal}
    </div>
  </section>"""

    rate = round(current / target * 100) if target else 0
    prev = d["previous_month_revenue"]
    delta = ""
    if prev:
        change = round((current - prev) / prev * 100)
        tone = "up" if change >= 0 else "down"
        delta = (f'<div class="delta {tone}">前月比 {change:+d}%'
                 f'<span class="sub">（{yen(prev)}円 → {yen(current)}円）</span></div>')
    elif current:
        delta = '<div class="delta up">今月から収益が立ちました</div>'

    goal = ""
    if target:
        remain = max(0, target - current)
        recovered = (round(d["revenue_total"] / d["investment"] * 100)
                     if d["investment"] else 100)
        goal = f"""
      <div class="hero-goal">
        <div class="goal-row"><span>月間目標</span>
          <span>{yen(current)} / {yen(target)} 円　<b>{rate}%</b></span></div>
        {meter(rate, "good" if rate >= 100 else "")}
        <div class="goal-row" style="margin:8px 0 0">
          <span>{'目標を達成しています' if remain == 0 else f'あと {yen(remain)} 円'}</span>
          <span>投資 {yen(d["investment"])}円 の回収 {recovered}%</span></div>
      </div>"""

    return f"""
  <section>
    <div class="hero">
      <div>
        <div class="stamp">{esc(d["this_month"])} の収益</div>
        <div class="hero-num">{yen(current)}<small>円</small></div>
        {delta}
      </div>{goal}
    </div>
  </section>"""


def render_kpis(d: dict) -> str:
    t = d["totals"]
    hours = d["month_hours"]
    exp = d["expenses"]

    if d["phase"] == "investment":
        items = "　".join(f'{name} {v["monthly"]:,}円/月'
                          for name, v in list(exp["by_item"].items())[:2])
        tiles = [
            ("毎月の支出", f'{yen(d["run_rate"])}<small>円</small>',
             items or "経費が未登録です"),
            ("累計の投資額", f'{yen(d["investment"])}<small>円</small>',
             f'経費 {yen(exp["total"])} ＋ 制作原価 {yen(t["cost"])}'),
            ("投資期間", f'{len(d["months"])}<small>ヶ月</small>',
             f'投下 {t["hours"]:g} 時間' if t["hours"] else "作業時間の記録がありません"),
            ("プロジェクト", f'{t["count"]}<small>件</small>',
             "　".join(f'{pjt.STATE[k][0]} {v}' for k, v in sorted(t["states"].items()))
             or "未登録"),
        ]
    else:
        month_profit = t["this_month"] - d["month_cost"] - exp["this_month"]
        month_hourly = round(month_profit / hours) if hours else 0
        tiles = [
            ("累計の損益", f'{yen(d["net"])}<small>円</small>',
             f'収益 {yen(d["revenue_total"])} － 投資 {yen(d["investment"])}'),
            ("実績時給（累計）", f'{yen(t["hourly"])}<small>円</small>' if t["hourly"] else "—",
             f'投下 {t["hours"]:g} 時間'),
            ("今月の稼働", f'{hours:g}<small>時間</small>',
             f'今月の時給 {yen(month_hourly)} 円' if month_hourly
             else "時間の記録がありません"),
            ("プロジェクト", f'{t["count"]}<small>件</small>',
             "　".join(f'{pjt.STATE[k][0]} {v}' for k, v in sorted(t["states"].items()))
             or "未登録"),
        ]

    cards = "".join(
        f'<div class="kpi"><div class="label">{esc(label)}</div>'
        f'<div class="value">{value}</div><div class="note">{esc(note)}</div></div>'
        for label, value, note in tiles)
    return f'<section><h2>サマリー</h2><div class="kpis">{cards}</div></section>'


def render_first_yen(d: dict) -> str:
    """最初の1円までに何が要るかを、プロジェクトごとに具体的に出す。"""
    if d["phase"] != "investment" or not d["rows"]:
        return ""

    from .apps import model as app_model
    from .media import model as media_model

    target = d["profile"]["target_income"]
    items = []
    for r in d["rows"]:
        p, s = r["project"], r["stats"]
        released = bool(p.get("released_at"))
        age = round(pjt.months_since(p.get("started_at")), 1)

        if not released:
            step = "まず世に出すこと。公開しないかぎり収益は1円も発生しません"
            status = f"未公開・着手から {age}ヶ月"
        else:
            since = s["since_release"] or 0
            left = max(0, pjt.GIVEUP_MONTHS - since)
            step = ("検索評価やストア掲載が付くまでの期間です。"
                    "まだ判断しません"
                    if since < pjt.GRACE_MONTHS else
                    f"収益ゼロが続いています。撤退基準まで残り {left:.0f}ヶ月")
            status = f"公開から {since}ヶ月・収益 0円"

        if p["type"] == "app":
            need = app_model.required_installs(target)
            reference = (f'目標 月{yen(target)}円 には DAU {need["dau"]:,}人'
                         f'（日次インストール {need["daily_installs"]:,}件）が必要')
        elif p["type"] == "media":
            plan = media_model.plan(target)
            reference = (f'目標 月{yen(target)}円 には {plan["required_articles"]:,}記事'
                         f'（{plan["params"]["avg_rank"]}位想定・'
                         f'月間{plan["required_pv"]:,}PV）が必要')
        else:
            reference = ""

        items.append(f"""
      <li>
        <div>
          <b>{esc(p["name"])}</b>
          <span class="sub">　{esc(status)}</span>
          <div class="sub" style="margin-top:3px">→ {esc(step)}</div>
          {f'<div class="sub">参考: {esc(reference)}</div>' if reference else ""}
        </div>
      </li>""")

    return f"""
  <section>
    <h2>最初の1円までの距離</h2>
    <ul class="list steps">{"".join(items)}</ul>
    <p class="note-line">参考値は既定パラメータでの計算です。実測が出たら
      <code>app params</code> / <code>media params</code> で置き換えてください。</p>
  </section>"""


def render_expenses(d: dict) -> str:
    from . import profile as profile_mod

    exp = d["expenses"]
    if not exp["records"]:
        fee = profile_mod.monthly_fee(d["profile"])
        amount = fee or 3000
        return (f'<section><h2>経費</h2><p class="empty">'
                f'経費が未登録です。'
                f'<code>python main.py expense add {amount} --item "Claude利用料" '
                f'--from 2026-05</code> のように登録すると、'
                f'投資額と回収ラインが出ます。</p></section>')

    subscription_note = ""
    if profile_mod.is_subscription(d["profile"]):
        subscription_note = ("　定額制なので、作る量を増やしても支出は増えません"
                             "（費用面で量を絞る理由はありません）。")

    rows = "".join(
        f'<tr><td>{esc(name)}</td>'
        f'<td class="sub">{esc(expense_mod.CATEGORIES.get(v["category"], v["category"]))}</td>'
        f'<td class="num">{yen(v["monthly"])} 円</td>'
        f'<td class="num">{yen(v["total"])} 円</td>'
        f'<td class="num">{v["months"]} ヶ月</td></tr>'
        for name, v in exp["by_item"].items())

    return f"""
  <section>
    <h2>経費</h2>
    <table>
      <thead><tr><th>項目</th><th>種別</th><th class="num">月あたり</th>
        <th class="num">累計</th><th class="num">期間</th></tr></thead>
      <tbody>{rows}</tbody>
    </table>
    <p class="note-line">合計 {yen(exp["total"])} 円。
      これがそのまま「回収しなければならない額」です。{subscription_note}</p>
  </section>"""


def render_table(d: dict) -> str:
    if not d["rows"]:
        return ('<section><h2>プロジェクト</h2><p class="empty">'
                'プロジェクトが未登録です。<code>python main.py pjt add "名前" --type app</code>'
                ' で登録すると、ここに一覧が出ます。</p></section>')

    body = []
    for i, r in enumerate(d["rows"]):
        p, s, state = r["project"], r["stats"], r["state"]
        label, advice = pjt.STATE[state]
        tone = STATE_TONE[state]
        slot = min(i, len(SERIES_LIGHT) - 1) + 1
        values = [rec["revenue"] for rec in p.get("records", [])]

        growth = ""
        if s["growth"] is not None:
            g_tone = "up" if s["growth"] >= 0 else "down"
            growth = f'<span class="delta {g_tone}"> {s["growth"]:+d}%</span>'

        body.append(f"""
      <tr>
        <td><div class="pname"><i class="dot s{slot}"></i>{esc(p["name"])}</div>
            <div class="sub">{esc(pjt.TYPES.get(p["type"], p["type"]))}・{esc(p["status"])}</div></td>
        <td><span class="badge {tone}"><i></i>{esc(label)}</span>
            <div class="sub">{esc(advice)}</div></td>
        <td class="num">{yen(s["latest_revenue"])}{growth}</td>
        <td class="num">{yen(s["revenue"])}</td>
        <td class="num">{yen(s["hourly"]) + " 円" if s["hourly"] else "—"}</td>
        <td>{sparkline(values, slot)}</td>
      </tr>""")

    return f"""
  <section>
    <h2>プロジェクト</h2>
    <table>
      <thead><tr>
        <th>名称</th><th>判定</th><th class="num">今月</th>
        <th class="num">累計収益</th><th class="num">実績時給</th><th>推移</th>
      </tr></thead>
      <tbody>{"".join(body)}</tbody>
    </table>
    <p class="note-line">判定は実績からの自動分類です。撤退検討は「公開から
      {pjt.GIVEUP_MONTHS}ヶ月以上たって収益ゼロ」を指します。</p>
  </section>"""


def render_allocation(d: dict) -> str:
    rows = d["allocation"]
    if not rows:
        return ""
    total = d["profile"]["hours_per_week"]
    bars = []
    for r in rows:
        share = round(r["hours"] / total * 100) if total else 0
        bars.append(f"""
      <div class="alloc">
        <div class="n">{esc(r["project"]["name"][:12])}</div>
        <div class="track"><div class="fill" style="width:{share}%"></div></div>
        <div class="h">{r["hours"]:g} h</div>
      </div>""")
    return f"""
  <section>
    <h2>今週の時間配分の目安（週 {total:g} 時間）</h2>
    {"".join(bars)}
    <p class="note-line">判定ごとの方針で按分した目安です。最適化ではないので、
      納得できなければ自分の判断を優先してください。</p>
  </section>"""


def render_actions(d: dict) -> str:
    tasks, jobs, arts = d["tasks"], d["jobs"], d["articles"]
    panels = []

    items = []
    for t in tasks["overdue"][:4]:
        items.append(f'<li>{esc(t["title"])}<span class="tag alert">'
                     f'期限超過 {esc(t["due"])}</span></li>')
    for t in tasks["next"]:
        if any(t["id"] == o["id"] for o in tasks["overdue"]):
            continue
        due = f'〆{esc(t["due"])}' if t["due"] else "期限なし"
        items.append(f'<li>{esc(t["title"])}<span class="tag">{due}</span></li>')
    if tasks["total"]:
        panels.append(f"""
    <div>
      <h2>タスク　{tasks["done"]}/{tasks["total"]}　{tasks["rate"]}%</h2>
      {meter(tasks["rate"])}
      <ul class="list" style="margin-top:12px">{"".join(items[:6])}</ul>
    </div>""")

    if arts["total"]:
        queue = "".join(
            f'<li>{esc(a["keyword"])}<span class="tag">{esc(a["state"])}'
            + (f'　+{yen(a["upside"])}円' if a["upside"] else "") + "</span></li>"
            for a in arts["queue"])
        panels.append(f"""
    <div>
      <h2>記事　{arts["published"]}/{arts["total"]} 公開</h2>
      <div class="sub" style="margin-bottom:10px">月間 {yen(arts["pv"])} PV ・
        収益 {yen(arts["revenue"])} 円 ・ 制作原価 {yen(arts["cost"])} 円</div>
      <ul class="list">{queue or '<li class="sub">改善対象はありません</li>'}</ul>
    </div>""")

    if jobs["total"]:
        lines = []
        if jobs["pending"]:
            lines.append(f'<li>未処理の案件<span class="tag alert">'
                         f'{jobs["pending"]} 件</span></li>')
        if jobs["review"]:
            lines.append(f'<li>検品で止まっている案件<span class="tag alert">'
                         f'{jobs["review"]} 件</span></li>')
        if jobs["failed"]:
            lines.append(f'<li>実行に失敗した案件<span class="tag alert">'
                         f'{jobs["failed"]} 件</span></li>')
        if not lines:
            lines.append('<li class="sub">滞留している案件はありません</li>')
        panels.append(f"""
    <div>
      <h2>受託案件　{jobs["total"]} 件</h2>
      <div class="sub" style="margin-bottom:10px">API原価 累計 {yen(jobs["cost"])} 円</div>
      <ul class="list">{"".join(lines)}</ul>
    </div>""")

    if not panels:
        return ""
    return f'<section><div class="cols">{"".join(panels)}</div></section>'


def render(d: dict) -> str:
    name = d["profile"].get("experience") or ""
    chart = flow_chart(d)
    return f"""<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>収益ダッシュボード</title>
<style>{STYLE}</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>収益ダッシュボード</h1>
    <span class="stamp">{esc(d["generated_at"])} 時点{"　" + esc(name) if name else ""}</span>
    <button class="toggle" id="toggle" type="button">表示切替</button>
  </header>
{render_hero(d)}
{render_kpis(d)}
  <section>
    <h2>月次の収支と累積損益</h2>
    {chart}
  </section>
{render_table(d)}
{render_first_yen(d)}
{render_expenses(d)}
{render_allocation(d)}
{render_actions(d)}
  <p class="note-line">このファイルは <code>python main.py screen</code> で再生成されます。
    データは手元の data/ 配下のみを読み、外部への送信は行いません。</p>
</div>
<div id="tip"></div>
<script>{SCRIPT}</script>
</body>
</html>
"""


def build(output: Path = None) -> Path:
    """ダッシュボードを生成してパスを返す。"""
    path = Path(output) if output else OUTPUT
    path.write_text(render(collect()), encoding="utf-8")
    return path
