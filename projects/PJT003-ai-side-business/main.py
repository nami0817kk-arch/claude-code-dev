"""AI 副業サポート AI  —  コマンドラインから使う副業立ち上げの伴走ツール。

  python main.py init          プロフィール登録
  python main.py ideas         副業アイデアの提案
  python main.py status        進捗ダッシュボード
"""
import argparse
import io
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent / ".env")
except ImportError:
    # python-dotenv 未導入でも、環境変数が直接設定されていれば動く
    pass

from src import coach, ideas, llm, pricing, proposal, research, roadmap, store, tracker
from src import profile as profile_mod
from src import report as report_mod


def _require_profile():
    if not profile_mod.exists():
        print("プロフィールが未登録です。まず `python main.py init` を実行してください。")
        sys.exit(1)
    return profile_mod.load()


def _require_idea(idea_id):
    idea = ideas.find(idea_id)
    if not idea:
        print(f"アイデア番号 {idea_id} が見つかりません。`python main.py ideas --list` で確認してください。")
        sys.exit(1)
    return idea


# ---------------------------------------------------------------- コマンド

def cmd_init(args):
    current = profile_mod.load()
    data = profile_mod.interactive_init(current)
    path = profile_mod.save(data)
    profile_mod.print_profile(data)
    print(f"\n保存しました: {path}")
    print("\n次のステップ: python main.py ideas   （AI が副業アイデアを提案します）")


def cmd_profile(args):
    data = profile_mod.load()
    if args.set:
        for pair in args.set:
            if "=" not in pair:
                print(f"書式が不正です: {pair}  （例: hours_per_week=15）")
                sys.exit(1)
            key, raw = pair.split("=", 1)
            key = key.strip()
            field = next((f for f in profile_mod.FIELDS if f[0] == key), None)
            if not field:
                print(f"不明な項目です: {key}")
                print(f"指定できる項目: {', '.join(f[0] for f in profile_mod.FIELDS)}")
                sys.exit(1)
            data[key] = profile_mod.parse_value(raw, field[2], data.get(key, field[3]))
        profile_mod.save(data)
        print("更新しました。")
    profile_mod.print_profile(data)


def cmd_ideas(args):
    prof = _require_profile()
    saved = ideas.load()

    if args.list or (saved and not args.refresh):
        if not saved:
            print("アイデアがまだありません。`python main.py ideas` で生成してください。")
            return
        ideas.print_ideas(saved[:args.top], detail=args.detail)
        if not args.list:
            print("  作り直す: python main.py ideas --refresh")
        return

    print("AI がアイデアを検討中です...（30秒ほどかかります）")
    result = ideas.generate(prof, n=args.count)
    ideas.print_ideas(result[:args.top], detail=args.detail)


def cmd_research(args):
    prof = _require_profile()
    idea = _require_idea(args.idea_id)

    cached = research.load(args.idea_id)
    if cached and not args.refresh:
        research.print_research(cached)
        print("  再調査する: python main.py research {} --refresh".format(args.idea_id))
        return

    print(f"「{idea['name']}」を調査中です...（30秒ほどかかります）")
    research.print_research(research.run(idea, prof))
    print(f"  計画を作る: python main.py plan {args.idea_id}")


def cmd_plan(args):
    prof = _require_profile()
    idea = _require_idea(args.idea_id)

    cached = roadmap.load(args.idea_id)
    if cached and not args.refresh:
        roadmap.print_plan(cached)
        print("  作り直す: python main.py plan {} --refresh".format(args.idea_id))
        return

    print(f"「{idea['name']}」の 90 日計画を作成中です...（30秒ほどかかります）")
    plan = roadmap.generate(idea, prof, research=research.load(args.idea_id))
    roadmap.print_plan(plan)

    if args.no_tasks:
        print("  タスク登録はスキップしました。登録する場合は --no-tasks を外して再実行してください。")
        return
    added = roadmap.to_tasks(plan)
    print(f"\nタスクを {len(added)} 件登録しました。")
    print("  確認: python main.py task list")


def cmd_task(args):
    if args.action == "add":
        if not args.title:
            print("タスク名を指定してください。 例) python main.py task add \"サンプルを3本作る\"")
            sys.exit(1)
        t = tracker.add_task(" ".join(args.title), phase=args.phase, due=args.due, hours=args.hours)
        print(f"追加しました: {t['id']}. {t['title']}")
    elif args.action == "done":
        t = tracker.set_status(args.id, "done")
        print(f"完了にしました: {t['id']}. {t['title']}" if t else f"タスク {args.id} が見つかりません。")
        if t:
            prog = tracker.progress()
            print(f"  進捗 {prog['done']}/{prog['total']}  {tracker.bar(prog['rate'])} {prog['rate']}%")
    elif args.action == "start":
        t = tracker.set_status(args.id, "doing")
        print(f"着手中にしました: {t['id']}. {t['title']}" if t else f"タスク {args.id} が見つかりません。")
    elif args.action == "undo":
        t = tracker.set_status(args.id, "todo")
        print(f"未着手に戻しました: {t['id']}. {t['title']}" if t else f"タスク {args.id} が見つかりません。")
    elif args.action == "rm":
        print("削除しました。" if tracker.remove_task(args.id) else f"タスク {args.id} が見つかりません。")
    else:
        tracker.print_tasks(show_done=args.all)


def cmd_revenue(args):
    prof = _require_profile()
    if args.action == "add":
        rec = tracker.add_revenue(args.amount, args.source, date=args.date,
                                  memo=args.memo, hours=args.hours)
        print(f"記録しました: {rec['date']}  {rec['amount']:,}円  {rec['source']}")
        tracker.print_revenue(prof["target_income"])
    else:
        tracker.print_revenue(prof["target_income"])


def cmd_status(args):
    report_mod.print_status(_require_profile())


def cmd_price(args):
    e = pricing.estimate(
        hours=args.hours, hourly=args.hourly, difficulty=args.difficulty,
        revisions=args.revisions, rush=args.rush, expenses=args.expenses,
        platform=args.platform,
    )
    pricing.print_estimate(e)
    if args.advice:
        print("\n提示の仕方を検討中です...")
        pricing.print_advice(pricing.advice(e, args.work or "AI を使った制作代行"))


def cmd_proposal(args):
    prof = _require_profile()
    service = args.service
    if not service:
        saved = ideas.load()
        if saved:
            top = saved[0]
            service = f"{top['name']}: {top.get('summary','')}"
            print(f"サービス未指定のため、最上位のアイデア「{top['name']}」を使います。")
        else:
            print("--service でサービス内容を指定するか、先に `python main.py ideas` を実行してください。")
            sys.exit(1)

    print("文面を作成中です...")
    proposal.print_proposal(proposal.generate(args.kind, prof, service, args.context))


def cmd_review(args):
    prof = _require_profile()

    if args.apply:
        saved = store.load("reviews", [])
        if not saved:
            print("レビューがありません。先に `python main.py review` を実行してください。")
            sys.exit(1)
        added = coach.apply_next_week(saved[-1])
        print(f"来週のタスクを {len(added)} 件登録しました。")
        tracker.print_tasks()
        return

    print("今週を振り返っています...")
    coach.print_review(coach.weekly_review(prof))


def cmd_ask(args):
    prof = _require_profile()
    question = " ".join(args.question)
    saved = ideas.load()
    idea_name = saved[0]["name"] if saved else "未選定"

    print("考え中です...\n")
    answer = coach.ask(prof, question, idea_name)
    print(f"{'='*70}")
    print(answer)
    print(f"{'='*70}")


def cmd_report(args):
    prof = _require_profile()
    path = report_mod.export_markdown(prof, idea_id=args.idea)
    print(f"レポートを出力しました: {path}")


# ---------------------------------------------------------------- CLI

def build_parser():
    parser = argparse.ArgumentParser(
        description="AI 副業サポート AI — アイデア出しから収益管理まで伴走するツール",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""使う順番の目安:
  1. init      プロフィールを登録する
  2. ideas     AI に副業アイデアを出させる
  3. research  気になったアイデアの需要と競合を調べる
  4. plan      90日ロードマップを作り、タスクに落とす
  5. task/revenue  実行して結果を記録する
  6. status / review  数字で確認し、毎週やり方を直す
""")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("init", help="プロフィールを対話形式で登録する")

    p_prof = sub.add_parser("profile", help="プロフィールの表示・更新")
    p_prof.add_argument("--set", nargs="+", metavar="KEY=VALUE",
                        help="項目を更新する 例) --set hours_per_week=15 target_income=10万")

    p_ideas = sub.add_parser("ideas", help="AI 副業アイデアの提案")
    p_ideas.add_argument("--count", type=int, default=6, help="生成する件数 (デフォルト:6)")
    p_ideas.add_argument("--top", type=int, default=10, help="表示する件数 (デフォルト:10)")
    p_ideas.add_argument("--detail", action="store_true", help="詳細も表示する")
    p_ideas.add_argument("--refresh", action="store_true", help="生成しなおす")
    p_ideas.add_argument("--list", action="store_true", help="保存済みを表示するだけ（API を呼ばない）")

    p_res = sub.add_parser("research", help="アイデアの市場調査・実現性検証")
    p_res.add_argument("idea_id", type=int, help="アイデア番号")
    p_res.add_argument("--refresh", action="store_true", help="調査しなおす")

    p_plan = sub.add_parser("plan", help="90日ロードマップを作成しタスク登録する")
    p_plan.add_argument("idea_id", type=int, help="アイデア番号")
    p_plan.add_argument("--refresh", action="store_true", help="作りなおす")
    p_plan.add_argument("--no-tasks", action="store_true", dest="no_tasks",
                        help="タスク登録をせず計画の表示だけ行う")

    p_task = sub.add_parser("task", help="タスクの確認・追加・完了")
    p_task.add_argument("action", nargs="?", default="list",
                        choices=["list", "add", "start", "done", "undo", "rm"],
                        help="操作 (デフォルト:list)")
    p_task.add_argument("title", nargs="*", help="add のときのタスク名")
    p_task.add_argument("--id", type=int, help="start/done/undo/rm の対象タスク番号")
    p_task.add_argument("--phase", default="その他", help="add のときのフェーズ名")
    p_task.add_argument("--due", default="", help="add のときの期限 YYYY-MM-DD")
    p_task.add_argument("--hours", type=float, default=0, help="add のときの想定工数")
    p_task.add_argument("--all", action="store_true", help="完了済みも表示する")

    p_rev = sub.add_parser("revenue", help="売上の記録・確認")
    p_rev.add_argument("action", nargs="?", default="list", choices=["list", "add"],
                       help="操作 (デフォルト:list)")
    p_rev.add_argument("amount", nargs="?", type=int, help="add のときの金額(円)")
    p_rev.add_argument("--source", default="", help="案件名・売上の内訳")
    p_rev.add_argument("--date", default="", help="日付 YYYY-MM-DD (デフォルト:今日)")
    p_rev.add_argument("--hours", type=float, default=0, help="かかった作業時間")
    p_rev.add_argument("--memo", default="", help="メモ")

    sub.add_parser("status", help="進捗・売上のダッシュボード")

    p_price = sub.add_parser("price", help="見積もり金額を計算する")
    p_price.add_argument("--hours", type=float, required=True, help="想定作業時間")
    p_price.add_argument("--hourly", type=int, default=3000, help="確保したい時給 (デフォルト:3000)")
    p_price.add_argument("--difficulty", type=int, default=3, help="難易度 1〜5 (デフォルト:3)")
    p_price.add_argument("--revisions", type=int, default=1, help="想定修正回数 (デフォルト:1)")
    p_price.add_argument("--rush", action="store_true", help="特急対応（+30%%）")
    p_price.add_argument("--expenses", type=int, default=0, help="立て替え経費(円)")
    p_price.add_argument("--platform", default="direct",
                         choices=list(pricing.PLATFORM_FEE), help="手数料の対象 (デフォルト:direct)")
    p_price.add_argument("--advice", action="store_true", help="提示の仕方も AI に相談する")
    p_price.add_argument("--work", default="", help="案件内容（--advice 用）")

    p_prop = sub.add_parser("proposal", help="提案文・営業文を作る")
    p_prop.add_argument("kind", nargs="?", default="apply", choices=list(proposal.KINDS),
                        help="文面の種類 (デフォルト:apply)")
    p_prop.add_argument("--service", default="", help="提供するサービス内容")
    p_prop.add_argument("--context", default="", help="相手・案件の情報")

    p_review = sub.add_parser("review", help="週次レビュー")
    p_review.add_argument("--apply", action="store_true", help="直近レビューの来週タスクを登録する")

    p_ask = sub.add_parser("ask", help="副業について相談する")
    p_ask.add_argument("question", nargs="+", help="相談内容")

    p_report = sub.add_parser("report", help="Markdown レポートを出力する")
    p_report.add_argument("--idea", type=int, help="調査・計画も含めるアイデア番号")

    return parser


COMMANDS = {
    "init": cmd_init, "profile": cmd_profile, "ideas": cmd_ideas,
    "research": cmd_research, "plan": cmd_plan, "task": cmd_task,
    "revenue": cmd_revenue, "status": cmd_status, "price": cmd_price,
    "proposal": cmd_proposal, "review": cmd_review, "ask": cmd_ask,
    "report": cmd_report,
}


def main():
    parser = build_parser()
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    if args.command == "task" and args.action in ("start", "done", "undo", "rm"):
        # `task done 3` のように位置引数で番号を渡せるようにする
        if args.id is None and args.title:
            try:
                args.id = int(args.title[0])
            except ValueError:
                args.id = None
        if args.id is None:
            print(f"タスク番号を指定してください。 例) python main.py task {args.action} 3")
            sys.exit(1)

    if args.command == "revenue" and args.action == "add" and args.amount is None:
        print("金額を指定してください。 例) python main.py revenue add 5000 --source \"議事録作成\"")
        sys.exit(1)

    try:
        COMMANDS[args.command](args)
    except llm.LLMError as e:
        print(f"\n{e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n中断しました。")
        sys.exit(130)


if __name__ == "__main__":
    main()
