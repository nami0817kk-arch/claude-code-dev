"""90日ロードマップの生成とタスク登録。

アイデアを「今週やること」まで落とし込むのが目的。
生成した行動リストはそのまま tracker に取り込む。
"""
from datetime import datetime, timedelta

from . import llm, store, tracker

NAME = "roadmap"

SYSTEM = """あなたは副業立ち上げの伴走コーチです。
本業を持つ人が、限られた稼働時間の中で確実に前に進める計画を作ります。

守ること:
- タスクは「今日の夜に着手できる」粒度まで具体的に割る
- 各フェーズに、達成したかどうかが数字で判定できる KPI を必ず置く
- 収益ゼロの期間が続く前提で、最初の1件を取る動きを最優先にする"""

PROMPT = """次のアイデアで副業を始めるための 90 日ロードマップを作成してください。

## 相談者のプロフィール
{profile}

## 実行するアイデア
名称: {name}
内容: {summary}
ターゲット: {target}
収益モデル: {revenue_model}
想定単価: {price_range}
最初の一歩: {first_step}
{research}

## 制約
- 週の稼働可能時間は {hours} 時間。全タスクの合計工数がこれを超えない配分にすること
- 3 フェーズ（1〜30日 / 31〜60日 / 61〜90日）に分ける

## 出力形式（JSON オブジェクトのみ）
- goal: 90日後のゴール（数字を含む1文）
- phases: フェーズの配列（3個）。各要素は次のキーを持つ
    - name: フェーズ名（例「Phase1 土台づくり」）
    - period: 期間（例「1〜30日」）
    - goal: このフェーズの目標（1文）
    - kpi: 達成判定できる指標（例「サンプル3本、問い合わせ2件」）
    - tasks: タスクの配列（4〜6個）。各要素は title（具体的な作業）と hours（想定工数・数値）を持つ
- weekly_routine: 毎週繰り返す習慣の配列（2〜3個）
- milestones: 節目の配列（2〜3個。各要素は day（日数・整数）と event（達成すべきこと））
- risk_plan: つまずきやすい点と対処の配列（2〜3個。各要素は risk と action）
"""


def _due_dates(phases: list, start: datetime) -> list:
    """フェーズ順に 30 日刻みの期限を割り当てる。"""
    dates = []
    for i, _ in enumerate(phases):
        dates.append((start + timedelta(days=30 * (i + 1))).strftime("%Y-%m-%d"))
    return dates


def generate(idea: dict, prof: dict, research: dict = None) -> dict:
    from . import profile as profile_mod

    research_text = ""
    if research:
        research_text = (
            "\n## 市場調査の結果\n"
            f"判定: {research.get('verdict','')}（{research.get('verdict_reason','')}）\n"
            f"需要: {research.get('demand','')}\n"
            f"価格方針: {research.get('price_advice','')}\n"
            f"集客経路: {'、'.join(c.get('channel','') for c in research.get('channels', []))}\n"
        )

    plan = llm.ask_json(
        PROMPT.format(
            profile=profile_mod.summary_text(prof),
            name=idea.get("name", ""),
            summary=idea.get("summary", ""),
            target=idea.get("target", ""),
            revenue_model=idea.get("revenue_model", ""),
            price_range=idea.get("price_range", ""),
            first_step=idea.get("first_step", ""),
            research=research_text,
            hours=prof["hours_per_week"],
        ),
        system=SYSTEM,
        max_tokens=6000,
    )
    plan["idea_id"] = idea.get("id")
    plan["idea_name"] = idea.get("name")
    plan["created_at"] = store.now()
    plan["start_date"] = store.today()

    saved = store.load(NAME, {})
    saved[str(idea.get("id"))] = plan
    store.save(NAME, saved)
    return plan


def load(idea_id) -> dict:
    return store.load(NAME, {}).get(str(idea_id))


def to_tasks(plan: dict) -> list:
    """ロードマップのタスクを tracker に登録する。"""
    start = datetime.strptime(plan.get("start_date", store.today()), "%Y-%m-%d")
    phases = plan.get("phases", [])
    dues = _due_dates(phases, start)

    items = []
    for phase, due in zip(phases, dues):
        for t in phase.get("tasks", []):
            items.append({
                "title": t.get("title", ""),
                "phase": phase.get("name", "フェーズ"),
                "due": due,
                "hours": t.get("hours", 0),
                "idea_id": plan.get("idea_id"),
            })
    return tracker.add_tasks(items)


def print_plan(plan: dict):
    print(f"\n{'='*70}")
    print(f"  90日ロードマップ  [{plan.get('idea_id')}] {plan.get('idea_name')}")
    print(f"{'='*70}")
    print(f"\n【90日後のゴール】\n  {plan.get('goal','')}")

    for phase in plan.get("phases", []):
        hours = sum(t.get("hours", 0) or 0 for t in phase.get("tasks", []))
        print(f"\n■ {phase.get('name','')}  ({phase.get('period','')})  想定 {hours:g}h")
        print(f"    目標: {phase.get('goal','')}")
        print(f"    KPI : {phase.get('kpi','')}")
        for t in phase.get("tasks", []):
            print(f"      - {t.get('title','')}  ({t.get('hours',0):g}h)")

    if plan.get("weekly_routine"):
        print("\n【毎週の習慣】")
        for r in plan["weekly_routine"]:
            print(f"  ・{r}")

    if plan.get("milestones"):
        print("\n【マイルストーン】")
        for m in plan["milestones"]:
            print(f"  {m.get('day','')}日目: {m.get('event','')}")

    if plan.get("risk_plan"):
        print("\n【つまずいたときの対処】")
        for r in plan["risk_plan"]:
            print(f"  ・{r.get('risk','')}\n      → {r.get('action','')}")
    print(f"\n{'='*70}")
