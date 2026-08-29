"""相談対応と週次レビュー。

数字（タスク・売上）を渡した上で Claude に助言させるので、
一般論ではなく現状に即した内容が返る。
"""
from . import llm, store, tracker

SYSTEM = """あなたは副業立ち上げの伴走コーチです。相談者は本業を持ちながら副業に取り組んでいます。

守ること:
- 一般論ではなく、渡された数字と状況に基づいて答える
- 精神論で励まさない。次にやる行動を具体的に指定する
- 進んでいない時は、原因を作業量ではなく「詰まっている一点」に絞って指摘する
- 稼げる保証はしない。うまくいかない可能性にも触れる"""

REVIEW_PROMPT = """今週の状況を振り返り、来週の動きを決めてください。

## プロフィール
{profile}

## 今週の実績
- 期間: {start} 〜 {end}
- 完了タスク: {done_count} 件
{done_list}
- 未完了タスク: {todo_count} 件
{todo_list}
- 期限超過: {overdue_count} 件
{overdue_list}
- 今月の売上: {month_amount:,} 円 / 目標 {target:,} 円
- 累計売上: {total_amount:,} 円

## 出力形式（JSON オブジェクトのみ）
- assessment: 今週の評価（率直に。80文字程度）
- bottleneck: いま最も進行を止めている一点（1文）
- keep: 続けるべきことの配列（1〜2個）
- fix: 変えるべきことの配列（1〜2個）
- next_week: 来週やるタスクの配列（3個。各要素は title と hours）
- question: 相談者自身に考えてほしい問い（1つ）
"""

ASK_PROMPT = """## 相談者のプロフィール
{profile}

## 現在の状況
- タスク進捗: {done}/{total} 完了（{rate}%）
- 今月の売上: {month_amount:,} 円 / 目標 {target:,} 円
- 取り組み中のアイデア: {idea}

## 相談内容
{question}

上記を踏まえて回答してください。前置きは書かず、結論から述べてください。
最後に「次にやること」を箇条書きで 2〜3 個示してください。"""


def _task_lines(tasks: list, limit: int = 8) -> str:
    if not tasks:
        return "  （なし）"
    return "\n".join(f"  - {t['title']}" for t in tasks[:limit])


def weekly_review(prof: dict) -> dict:
    from . import profile as profile_mod
    from . import report

    start, end = tracker.week_range()
    tasks = tracker.load_tasks()
    done_this_week = [t for t in tasks if t["status"] == "done" and start <= (t.get("done_at") or "") <= end]
    todo = [t for t in tasks if t["status"] != "done"]
    over = tracker.overdue(tasks)
    st = report.status(prof)

    result = llm.ask_json(
        REVIEW_PROMPT.format(
            profile=profile_mod.summary_text(prof),
            start=start, end=end,
            done_count=len(done_this_week), done_list=_task_lines(done_this_week),
            todo_count=len(todo), todo_list=_task_lines(todo),
            overdue_count=len(over), overdue_list=_task_lines(over),
            month_amount=st["month_amount"], target=st["target"],
            total_amount=st["total_amount"],
        ),
        system=SYSTEM,
        max_tokens=3000,
    )
    result["period"] = f"{start} 〜 {end}"
    result["created_at"] = store.now()

    saved = store.load("reviews", [])
    saved.append(result)
    store.save("reviews", saved[-20:])
    return result


def print_review(r: dict):
    print(f"\n{'='*70}")
    print(f"  週次レビュー  {r.get('period','')}")
    print(f"{'='*70}")
    print(f"\n【今週の評価】\n  {r.get('assessment','')}")
    print(f"\n【いちばんの詰まり】\n  {r.get('bottleneck','')}")

    if r.get("keep"):
        print("\n【続けること】")
        for x in r["keep"]:
            print(f"  ○ {x}")
    if r.get("fix"):
        print("\n【変えること】")
        for x in r["fix"]:
            print(f"  △ {x}")

    print("\n【来週のタスク】")
    for t in r.get("next_week", []):
        print(f"  - {t.get('title','')}  ({t.get('hours',0):g}h)")
    print(f"\n【考えておくこと】\n  {r.get('question','')}")
    print(f"\n{'='*70}")
    print("  来週のタスクを登録: python main.py review --apply")
    print(f"{'='*70}")


def apply_next_week(review: dict) -> list:
    """レビューで出た来週のタスクを tracker に登録する。"""
    start, end = tracker.week_range()
    items = [{
        "title": t.get("title", ""),
        "phase": "今週のタスク",
        "due": end,
        "hours": t.get("hours", 0),
    } for t in review.get("next_week", []) if t.get("title")]
    return tracker.add_tasks(items)


def ask(prof: dict, question: str, idea_name: str = "未選定") -> str:
    from . import profile as profile_mod
    from . import report

    st = report.status(prof)
    p = st["progress"]
    return llm.ask(
        ASK_PROMPT.format(
            profile=profile_mod.summary_text(prof),
            done=p["done"], total=p["total"], rate=p["rate"],
            month_amount=st["month_amount"], target=st["target"],
            idea=idea_name, question=question,
        ),
        system=SYSTEM,
        max_tokens=2500,
    )
