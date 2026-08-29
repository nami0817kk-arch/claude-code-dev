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
from src.auto import cost as cost_mod
from src.auto import jobs as jobs_mod
from src.auto import services as services_mod
from src.media import analytics as media_analytics
from src.media import articles as media_articles
from src.media import genre as media_genre
from src.media import keywords as media_keywords
from src.media import model as media_model
from src.apps import model as app_model
from src.portfolio import dashboard as pjt_dashboard
from src.portfolio import projects as pjt_mod
from src import expenses as expense_mod
from src import screen as screen_mod
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


def cmd_expense(args):
    if args.action == "add":
        if args.amount is None:
            print("金額を指定してください。")
            print('  例) python main.py expense add 3000 --item "Claude利用料" --from 2026-05')
            sys.exit(1)
        if args.since:
            added = expense_mod.add_monthly(args.amount, args.item,
                                            category=args.category, start=args.since,
                                            end=args.until, note=args.note)
            print(f"{len(added)}ヶ月分を記録しました: {args.item} "
                  f"{args.amount:,}円/月（{added[0]['month']}〜{added[-1]['month']}）")
        else:
            rec = expense_mod.add(args.amount, args.item, category=args.category,
                                  month=args.month, note=args.note)
            print(f"記録しました: {rec['month']}  {rec['item']}  {rec['amount']:,}円")
        expense_mod.print_expenses()

    elif args.action == "rm":
        if args.id is None:
            print("削除する番号を指定してください。")
            sys.exit(1)
        print("削除しました。" if expense_mod.remove(args.id)
              else f"経費 {args.id} が見つかりません。")

    else:
        expense_mod.print_expenses()


def cmd_screen(args):
    path = screen_mod.build(args.output)
    print(f"ダッシュボードを生成しました: {path}")
    if args.open:
        import webbrowser
        webbrowser.open(path.resolve().as_uri())
        print("  ブラウザで開きました。")
    else:
        print("  ブラウザで開くには --open を付けてください。")


# ------------------------------------------------------- ポートフォリオ

def _set_numeric_params(current: dict, defaults: dict, pairs: list, save) -> dict:
    """--set KEY=VALUE を数値パラメータに反映する（media / app 共通）。"""
    for pair in pairs:
        if "=" not in pair:
            print(f"書式が不正です: {pair}  （例: cvr=0.03）")
            sys.exit(1)
        key, raw = pair.split("=", 1)
        key = key.strip()
        if key not in defaults:
            print(f"不明な項目です: {key}")
            print(f"指定できる項目: {', '.join(defaults)}")
            sys.exit(1)
        try:
            value = float(raw)
        except ValueError:
            print(f"数値で指定してください: {pair}")
            sys.exit(1)
        current[key] = int(value) if isinstance(defaults[key], int) else value
    save(current)
    print("更新しました。")
    return current


def cmd_pjt(args):
    action = args.pjt_command or "list"
    prof = profile_mod.load() if profile_mod.exists() else profile_mod.DEFAULTS

    if action == "add":
        name = " ".join(args.name)
        project = pjt_mod.add(name, kind=args.type, status=args.status, url=args.url,
                              note=args.note, started=args.started, released=args.released)
        print(f"登録しました: [{project['id']}] {project['name']}  "
              f"<{pjt_mod.TYPES[project['type']]} / {project['status']}>")
        print(f"  実績を記録: python main.py pjt record {project['id']} "
              "--revenue 3000 --hours 12")

    elif action == "show":
        project = pjt_mod.find(args.id)
        if not project:
            print(f"プロジェクト {args.id} が見つかりません。")
            sys.exit(1)
        pjt_dashboard.print_project(project)

    elif action == "set":
        fields = {}
        for key in ("status", "url", "note", "released", "type"):
            value = getattr(args, key, None)
            if value:
                fields["released_at" if key == "released" else key] = value
        if not fields:
            print("変更する項目を指定してください。 例) --status 公開 --released 2026-09-01")
            sys.exit(1)
        project = pjt_mod.update(args.id, **fields)
        if not project:
            print(f"プロジェクト {args.id} が見つかりません。")
            sys.exit(1)
        print("更新しました。")
        pjt_dashboard.print_project(project)

    elif action == "record":
        project = pjt_mod.record(args.id, month=args.month, revenue=args.revenue,
                                 cost=args.cost, hours=args.hours)
        if not project:
            print(f"プロジェクト {args.id} が見つかりません。")
            sys.exit(1)
        print(f"記録しました: {project['name']}")
        pjt_dashboard.print_project(project)

    elif action == "sync":
        project = pjt_mod.find(args.id)
        if not project:
            print(f"プロジェクト {args.id} が見つかりません。")
            sys.exit(1)
        r = pjt_dashboard.sync_service_revenue(args.id, month=args.month)
        print(f"受託案件の実績を取り込みました: {r['month']}  "
              f"収益 {r['revenue']:,}円 / 原価 {r['cost']:,}円")
        print("  ※ 作業時間は自動で取れないので、--hours で別途記録してください")

    elif action == "allocate":
        pjt_dashboard.print_allocation(args.hours or prof["hours_per_week"])

    elif action == "review":
        pjt_dashboard.print_review(prof["target_income"])

    elif action == "forecast":
        project = pjt_mod.find(args.id)
        if not project:
            print(f"プロジェクト {args.id} が見つかりません。")
            sys.exit(1)
        target = args.target or prof["target_income"]
        print(f"\n  [{project['id']}] {project['name']} の収益見通し")
        if project["type"] == "app":
            app_model.print_plan(target)
            app_model.print_simulation(
                app_model.simulate(args.months, args.installs, target=target), target)
        elif project["type"] == "media":
            media_model.print_plan(media_model.plan(
                target=target, avg_volume=args.volume, articles_per_month=args.per_month))
            media_model.print_simulation(media_model.simulate(
                months=args.months, articles_per_month=args.per_month,
                avg_volume=args.volume, target=target), target)
        else:
            print(f"  種別「{pjt_mod.TYPES.get(project['type'])}」には"
                  "収益モデルが用意されていません。")
            print("  app（アプリ）か media（メディア）に設定すると見通しを出せます。")

    elif action == "rm":
        print("削除しました。" if pjt_mod.remove(args.id)
              else f"プロジェクト {args.id} が見つかりません。")

    else:
        pjt_dashboard.print_projects(prof["target_income"])


def cmd_app(args):
    action = args.app_command or "params"

    if action == "params":
        params = app_model.load_params()
        if args.set:
            params = _set_numeric_params(params, app_model.DEFAULTS, args.set,
                                         app_model.save_params)
        app_model.print_params(params)

    elif action == "plan":
        target = args.target or (profile_mod.load()["target_income"]
                                 if profile_mod.exists() else 50000)
        app_model.print_plan(target, model=args.model)

    elif action == "simulate":
        target = args.target or (profile_mod.load()["target_income"]
                                 if profile_mod.exists() else 0)
        sim = app_model.simulate(args.months, args.installs, model=args.model,
                                 target=target, growth=args.growth)
        app_model.print_simulation(sim, target=target)


# ------------------------------------------------------- メディア運営

def cmd_media(args):
    action = args.media_command or "status"

    if action == "params":
        params = media_model.load_params()
        if args.set:
            params = _set_numeric_params(params, media_model.DEFAULTS, args.set,
                                         media_model.save_params)
        media_model.print_params(params)

    elif action == "plan":
        target = args.target or _require_profile()["target_income"]
        media_model.print_plan(media_model.plan(
            target=target, avg_volume=args.volume, model=args.model,
            articles_per_month=args.per_month))

    elif action == "simulate":
        target = args.target or (profile_mod.load()["target_income"]
                                 if profile_mod.exists() else 0)
        # 定額制なら記事を増やしても費用は増えないので、1本あたりは0円
        if profile_mod.is_subscription():
            article_cost = 0
        else:
            written = media_articles.load()
            article_cost = (sum(a["cost_jpy"] for a in written) / len(written)
                            if written else args.article_cost)
        sim = media_model.simulate(
            months=args.months, articles_per_month=args.per_month,
            avg_volume=args.volume, target=target, model=args.model,
            article_cost=article_cost)
        media_model.print_simulation(sim, target=target)

    elif action == "genre":
        prof = _require_profile()
        if media_genre.load() and not args.refresh:
            media_genre.print_genres(detail=args.detail)
            print("  作り直す: python main.py media genre --refresh")
            return
        print("ジャンルを検討中です...（30秒ほどかかります）")
        genres = media_genre.generate(prof, target=prof["target_income"],
                                      theme=args.theme, n=args.count,
                                      articles_per_month=args.per_month)
        media_genre.print_genres(genres, detail=args.detail)

    elif action == "keywords":
        if args.import_csv:
            try:
                r = media_keywords.import_volumes(args.import_csv)
            except FileNotFoundError:
                print(f"ファイルが見つかりません: {args.import_csv}")
                sys.exit(1)
            print(f"{r['read']} 件読み込み、{r['matched']}/{r['total']} 件のキーワードに"
                  "検索数を反映しました。")
            media_keywords.print_keywords(detail=args.detail)
            return

        saved = media_keywords.load()
        if args.list or (saved and not args.refresh):
            if not saved:
                print("キーワードがまだありません。"
                      '`python main.py media keywords --theme "テーマ"` を実行してください。')
                return
            media_keywords.print_keywords(top=args.top, detail=args.detail)
            if not args.list:
                print("  作り直す: python main.py media keywords --refresh")
            return

        prof = _require_profile()
        theme = args.theme or media_keywords.theme()
        if not theme:
            print('テーマを指定してください。 例) python main.py media keywords '
                  '--theme "業務効率化ツール"')
            sys.exit(1)
        print(f"「{theme}」のキーワードを設計中です...（30秒ほどかかります）")
        media_keywords.print_keywords(
            media_keywords.generate(prof, theme, n=args.count), detail=args.detail)

    elif action == "write":
        if not media_keywords.load():
            print("先にキーワードを設計してください: "
                  'python main.py media keywords --theme "テーマ"')
            sys.exit(1)
        media_articles.write_batch(kw_ids=args.ids, limit=args.limit,
                                   options=args.options, use_ai_qa=not args.no_qa)

    elif action == "publish":
        record = media_analytics.record(args.id, published=args.date or store.today())
        if not record:
            print(f"記事 {args.id} が見つかりません。")
            sys.exit(1)
        print(f"公開日を記録しました: [{record['keyword_id']}] {record['keyword']}  "
              f"{record['published_at']}")
        print(f"  検索評価が付くまで約{media_model.load_params()['seo_lag_months']}ヶ月です。"
              "その後に実績を記録してください。")

    elif action == "stats":
        if args.id:
            record = media_analytics.record(args.id, pv=args.pv, revenue=args.revenue,
                                            rank=args.rank)
            if not record:
                print(f"記事 {args.id} が見つかりません。")
                sys.exit(1)
            print(f"記録しました: [{record['keyword_id']}] {record['keyword']}  "
                  f"{record.get('rank') or '-'}位 / {record.get('pv', 0):,}PV / "
                  f"{record.get('revenue', 0):,}円")
        media_analytics.print_articles()

    elif action == "rewrite":
        media_analytics.print_rewrite_queue()

    elif action == "check":
        media_analytics.print_calibration()

    else:
        media_analytics.print_articles()
        media_analytics.print_rewrite_queue()


# ------------------------------------------------------- 自動化エンジン

def cmd_service(args):
    if args.action == "show":
        if not args.key:
            print("サービス名を指定してください。 例) python main.py service show minutes")
            sys.exit(1)
        service = services_mod.get(args.key)
        if not service:
            print(f"不明なサービス: {args.key}")
            print(f"指定できるのは: {', '.join(services_mod.keys())}")
            sys.exit(1)
        services_mod.print_service(service)
    else:
        services_mod.print_services()


def _read_input(args) -> str:
    """--input（ファイル）か --text（直接）から依頼内容を読む。"""
    if args.input:
        path = Path(args.input)
        if not path.exists():
            print(f"ファイルが見つかりません: {path}")
            sys.exit(1)
        return path.read_text(encoding="utf-8")
    if args.text:
        return " ".join(args.text)
    print("入力を指定してください。")
    print('  例) python main.py job add minutes --input meeting.txt --price 5000')
    print('      python main.py job add blog --text "テーマ: 副業の始め方" --price 8000')
    sys.exit(1)


def cmd_job(args):
    if args.action == "add":
        if not args.service:
            print(f"サービスを指定してください: {', '.join(services_mod.keys())}")
            sys.exit(1)
        if not services_mod.get(args.service):
            print(f"不明なサービス: {args.service}")
            print(f"指定できるのは: {', '.join(services_mod.keys())}")
            sys.exit(1)
        job = jobs_mod.add(args.service, _read_input(args), title=args.title,
                           client=args.client, price=args.price, options=args.options)
        print(f"登録しました: [{job['id']}] {job['title']}  "
              f"<{services_mod.get(job['service']).name}>")
        print("  実行: python main.py auto")

    elif args.action == "run":
        if not args.id:
            print("案件番号を指定してください。 例) python main.py job run 1")
            sys.exit(1)
        job = jobs_mod.find(args.id)
        if not job:
            print(f"案件 {args.id} が見つかりません。")
            sys.exit(1)
        jobs_mod.run(job, record_revenue=not args.no_revenue, use_ai_qa=not args.no_qa)

    elif args.action == "show":
        if not args.id:
            print("案件番号を指定してください。 例) python main.py job show 1")
            sys.exit(1)
        job = jobs_mod.find(args.id)
        if not job:
            print(f"案件 {args.id} が見つかりません。")
            sys.exit(1)
        jobs_mod.print_job(job)

    elif args.action == "delivered":
        job = jobs_mod.find(args.id)
        if not job:
            print(f"案件 {args.id} が見つかりません。")
            sys.exit(1)
        recorded = jobs_mod.record_sale(job)
        jobs_mod.update(args.id, status="delivered")
        print(f"納品済みにしました: [{job['id']}] {job['title']}")
        if recorded:
            print(f"  売上 {job['price']:,}円 を計上しました。")

    elif args.action == "rm":
        print("削除しました。" if jobs_mod.remove(args.id) else f"案件 {args.id} が見つかりません。")

    else:
        jobs_mod.print_jobs(show_all=args.all)


def cmd_auto(args):
    jobs_mod.run_pending(record_revenue=not args.no_revenue, use_ai_qa=not args.no_qa,
                         limit=args.limit, retry_failed=args.retry)


def cmd_cost(args):
    prof = profile_mod.load()
    target = prof["target_income"] if profile_mod.exists() else 0
    if args.estimate:
        # 定額制なら1件あたりの追加費用は発生しないので、表の意味が変わる
        if profile_mod.is_subscription(prof) and not args.api:
            cost_mod.print_subscription_estimates(prof, target_income=target)
        else:
            cost_mod.print_estimates(target_income=target)
    else:
        cost_mod.print_summary(prof)


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

支出を記録する（収益より先に出ていくもの）:
  expense add 3000 --item "Claude利用料" --from 2026-05

結果を画面で確認する:
  screen --open   ブラウザで開けるダッシュボードを生成する

複数のプロジェクトを並行して回す場合:
  pjt add       プロジェクトを登録する
  pjt record    月次の収益・原価・投下時間を記録する
  pjt           横断ダッシュボード（今どれが稼いでいるか）
  pjt allocate  週の時間をどこに割くかの目安
  pjt review    伸ばす / てこ入れ / 撤退検討 の判定
  pjt forecast  種別に応じた収益見通し

アプリで収益化する場合:
  app params    継続率・eCPM・課金率を実測に合わせる
  app plan      目標月収に必要なDAU・インストール数を逆算
  app simulate  月ごとのDAU・収益の推移

アフィリエイト・広告収入（ストック型）の場合:
  media genre     ジャンル候補を到達月数で比較する
  media plan      目標月収から必要なPV・記事数を逆算する
  media keywords  狙うキーワードを設計する
  media write     記事を生成する
  media stats     公開後の実績を記録する
  media rewrite   直すべき記事を期待増加額の順に出す

受注して納品する場合（つなぎの即金）:
  service      自動化できるサービスを確認する
  job add      依頼を登録する
  auto         未処理をまとめて生成・検品・納品ファイル出力（人手ゼロ）
  cost         API原価と粗利率を確認する
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

    # ---- 自動化エンジン ----
    p_svc = sub.add_parser("service", help="自動化できるサービスの一覧・詳細")
    p_svc.add_argument("action", nargs="?", default="list", choices=["list", "show"])
    p_svc.add_argument("key", nargs="?", help="show のときのサービス名")

    p_job = sub.add_parser("job", help="案件の登録・実行・確認")
    p_job.add_argument("action", nargs="?", default="list",
                       choices=["list", "add", "run", "show", "delivered", "rm"])
    p_job.add_argument("service", nargs="?", help="add のときのサービス名")
    p_job.add_argument("--id", type=int, help="run/show/delivered/rm の対象案件番号")
    p_job.add_argument("--input", help="依頼内容のファイルパス")
    p_job.add_argument("--text", nargs="+", help="依頼内容を直接指定")
    p_job.add_argument("--title", default="", help="案件名")
    p_job.add_argument("--client", default="", help="クライアント名")
    p_job.add_argument("--price", type=int, default=0, help="受注金額(円)")
    p_job.add_argument("--options", default="", help="追加の指定（トーン・文字数など）")
    p_job.add_argument("--all", action="store_true", help="納品済みも表示する")
    p_job.add_argument("--no-revenue", action="store_true", dest="no_revenue",
                       help="売上に自動記録しない")
    p_job.add_argument("--no-qa", action="store_true", dest="no_qa",
                       help="AI検品をスキップする（機械チェックのみ・原価を抑える）")

    p_auto = sub.add_parser("auto", help="未処理の案件をまとめて自動処理する")
    p_auto.add_argument("--limit", type=int, default=0, help="処理する件数の上限")
    p_auto.add_argument("--no-revenue", action="store_true", dest="no_revenue",
                        help="売上に自動記録しない")
    p_auto.add_argument("--no-qa", action="store_true", dest="no_qa",
                        help="AI検品をスキップする（機械チェックのみ）")
    p_auto.add_argument("--retry", action="store_true",
                        help="前回失敗した案件も再実行する")

    p_exp = sub.add_parser("expense", help="経費（利用料・サーバー代など）の記録",
                           description="収益より先に出ていく支出を記録し、"
                                       "回収すべき額をはっきりさせる")
    p_exp.add_argument("action", nargs="?", default="list", choices=["list", "add", "rm"])
    p_exp.add_argument("amount", nargs="?", type=int, help="add のときの金額(円)")
    p_exp.add_argument("--item", default="経費", help="項目名 例) Claude利用料")
    p_exp.add_argument("--category", default="tool", choices=list(expense_mod.CATEGORIES),
                       help="種別 (既定:tool)")
    p_exp.add_argument("--month", default="", help="対象月 YYYY-MM (既定:今月)")
    p_exp.add_argument("--from", dest="since", default="",
                       help="毎月かかる固定費として、この月から今月まで一括登録する")
    p_exp.add_argument("--until", default="", help="--from と併用。既定は今月")
    p_exp.add_argument("--note", default="", help="メモ")
    p_exp.add_argument("--id", type=int, help="rm の対象番号")

    p_screen = sub.add_parser("screen", help="結果を確認するダッシュボード画面を生成する")
    p_screen.add_argument("--open", action="store_true", help="生成後にブラウザで開く")
    p_screen.add_argument("--output", help="出力先（既定: dashboard.html）")

    # ---- ポートフォリオ（複数プロジェクトの横断管理） ----
    p_pjt = sub.add_parser("pjt", help="複数プロジェクトの横断管理",
                           description="収益源を横に並べて比較し、時間配分と撤退を判断する")
    psub = p_pjt.add_subparsers(dest="pjt_command")

    j_add = psub.add_parser("add", help="プロジェクトを登録する")
    j_add.add_argument("name", nargs="+", help="プロジェクト名")
    j_add.add_argument("--type", default="other", choices=list(pjt_mod.TYPES),
                       help="種別 (既定:other)")
    j_add.add_argument("--status", default="企画", choices=pjt_mod.STATUSES,
                       help="状態 (既定:企画)")
    j_add.add_argument("--url", default="", help="公開URL・ストアURL")
    j_add.add_argument("--note", default="", help="メモ（収益化の方針など）")
    j_add.add_argument("--started", default="", help="着手日 YYYY-MM-DD (既定:今日)")
    j_add.add_argument("--released", default="", help="公開日 YYYY-MM-DD")

    j_show = psub.add_parser("show", help="プロジェクトの詳細と月次推移")
    j_show.add_argument("id", type=int)

    j_set = psub.add_parser("set", help="プロジェクトの情報を更新する")
    j_set.add_argument("id", type=int)
    j_set.add_argument("--status", choices=pjt_mod.STATUSES)
    j_set.add_argument("--type", choices=list(pjt_mod.TYPES))
    j_set.add_argument("--url")
    j_set.add_argument("--note")
    j_set.add_argument("--released", help="公開日 YYYY-MM-DD")

    j_rec = psub.add_parser("record", help="月次の実績を記録する")
    j_rec.add_argument("id", type=int)
    j_rec.add_argument("--month", default="", help="対象月 YYYY-MM (既定:今月)")
    j_rec.add_argument("--revenue", type=int, help="収益(円)")
    j_rec.add_argument("--cost", type=int, help="原価・経費(円)")
    j_rec.add_argument("--hours", type=float, help="投下時間")

    j_sync = psub.add_parser("sync", help="受託案件の実績を月次記録に取り込む")
    j_sync.add_argument("id", type=int)
    j_sync.add_argument("--month", default="", help="対象月 YYYY-MM (既定:今月)")

    j_alloc = psub.add_parser("allocate", help="週の時間をどこに割くかの目安")
    j_alloc.add_argument("--hours", type=float, help="週の稼働時間（既定:プロフィールの値）")

    psub.add_parser("review", help="判定ごとにまとめて次の一手を出す")

    j_fc = psub.add_parser("forecast", help="種別に応じた収益見通しを出す")
    j_fc.add_argument("id", type=int)
    j_fc.add_argument("--target", type=int, help="目標月収（既定:プロフィールの値）")
    j_fc.add_argument("--months", type=int, default=18, help="期間 (既定:18ヶ月)")
    j_fc.add_argument("--installs", type=float, default=20,
                      help="アプリ: 日次インストール数 (既定:20)")
    j_fc.add_argument("--volume", type=int, default=1000,
                      help="メディア: 想定検索数 (既定:1000)")
    j_fc.add_argument("--per-month", type=int, default=8, dest="per_month",
                      help="メディア: 月に書く記事数 (既定:8)")

    j_rm = psub.add_parser("rm", help="プロジェクトを削除する")
    j_rm.add_argument("id", type=int)

    # ---- アプリ収益 ----
    p_app = sub.add_parser("app", help="アプリ（ゲーム・ツール）の収益設計",
                           description="DAU × ARPDAU の構造で、必要インストール数を逆算する")
    asub = p_app.add_subparsers(dest="app_command")

    a_params = asub.add_parser("params", help="継続率・eCPM・課金率などを確認・変更")
    a_params.add_argument("--set", nargs="+", metavar="KEY=VALUE",
                          help="例) --set d1=0.42 ecpm=800 paying_rate=0.02")

    a_plan = asub.add_parser("plan", help="目標月収から必要DAU・インストール数を逆算")
    a_plan.add_argument("--target", type=int, help="目標月収（既定:プロフィールの値）")
    a_plan.add_argument("--model", default="both", choices=["both", "ad", "iap"],
                        help="収益モデル (既定:both)")

    a_sim = asub.add_parser("simulate", help="月ごとのDAU・収益をシミュレーション")
    a_sim.add_argument("--months", type=int, default=18, help="期間 (既定:18ヶ月)")
    a_sim.add_argument("--installs", type=float, default=20,
                       help="日次インストール数 (既定:20)")
    a_sim.add_argument("--growth", type=float, default=0.0,
                       help="インストール数の月次成長率 例) 0.1 で毎月10%%増")
    a_sim.add_argument("--target", type=int, help="目標月収（既定:プロフィールの値）")
    a_sim.add_argument("--model", default="both", choices=["both", "ad", "iap"])

    # ---- メディア運営（アフィリエイト・広告収入） ----
    p_media = sub.add_parser(
        "media", help="アフィリエイト・広告収入のメディア運営",
        description="ストック型（アフィリエイト・広告）の収益設計から記事生成・改善まで")
    msub = p_media.add_subparsers(dest="media_command")

    m_params = msub.add_parser("params", help="収益モデルのパラメータを確認・変更")
    m_params.add_argument("--set", nargs="+", metavar="KEY=VALUE",
                          help="例) --set cvr=0.03 unit_price=10000")

    m_plan = msub.add_parser("plan", help="目標月収から必要なPV・記事数を逆算")
    m_plan.add_argument("--target", type=int, help="目標月収（既定:プロフィールの値）")
    m_plan.add_argument("--volume", type=int, default=1000, help="想定検索数 (既定:1000)")
    m_plan.add_argument("--per-month", type=int, default=8, dest="per_month",
                        help="月に書く記事数 (既定:8)")
    m_plan.add_argument("--model", default="both", choices=["both", "affiliate", "ad"],
                        help="収益モデル (既定:both)")

    m_sim = msub.add_parser("simulate", help="月ごとの収益・累積損益をシミュレーション")
    m_sim.add_argument("--months", type=int, default=24, help="期間 (既定:24ヶ月)")
    m_sim.add_argument("--per-month", type=int, default=8, dest="per_month",
                       help="月に書く記事数 (既定:8)")
    m_sim.add_argument("--volume", type=int, default=1000, help="想定検索数 (既定:1000)")
    m_sim.add_argument("--target", type=int, help="目標月収（既定:プロフィールの値）")
    m_sim.add_argument("--model", default="both", choices=["both", "affiliate", "ad"])
    m_sim.add_argument("--article-cost", type=float, default=45, dest="article_cost",
                       help="1記事あたりのAPI原価（実績があればそちらを使用）")

    m_genre = msub.add_parser("genre", help="ジャンル候補を出して到達月数で比較")
    m_genre.add_argument("--theme", default="", help="検討したい方向性")
    m_genre.add_argument("--count", type=int, default=6, help="候補数 (既定:6)")
    m_genre.add_argument("--per-month", type=int, default=8, dest="per_month",
                         help="月に書ける記事数 (既定:8)")
    m_genre.add_argument("--detail", action="store_true", help="詳細も表示")
    m_genre.add_argument("--refresh", action="store_true", help="出し直す")

    m_kw = msub.add_parser("keywords", help="キーワード設計と優先順位付け")
    m_kw.add_argument("--theme", default="", help="メディアのテーマ")
    m_kw.add_argument("--count", type=int, default=20, help="設計する件数 (既定:20)")
    m_kw.add_argument("--top", type=int, default=0, help="表示件数")
    m_kw.add_argument("--detail", action="store_true", help="タイトル案・狙う理由も表示")
    m_kw.add_argument("--refresh", action="store_true", help="設計し直す")
    m_kw.add_argument("--list", action="store_true", help="保存済みを表示（APIを呼ばない）")
    m_kw.add_argument("--import", dest="import_csv", metavar="CSV",
                      help="検索ボリュームのCSVを取り込む（1列目:キーワード 2列目:検索数）")

    m_write = msub.add_parser("write", help="キーワードから記事を生成")
    m_write.add_argument("ids", nargs="*", type=int, help="キーワード番号（省略時は未執筆すべて）")
    m_write.add_argument("--limit", type=int, default=0, help="生成する本数の上限")
    m_write.add_argument("--options", default="", help="追加の指定（トーン・文字数など）")
    m_write.add_argument("--no-qa", action="store_true", dest="no_qa",
                         help="AI検品をスキップ（機械チェックのみ）")

    m_pub = msub.add_parser("publish", help="記事の公開日を記録する")
    m_pub.add_argument("id", type=int, help="キーワード番号")
    m_pub.add_argument("--date", default="", help="公開日 YYYY-MM-DD (既定:今日)")

    m_stats = msub.add_parser("stats", help="記事の実績を記録・確認する")
    m_stats.add_argument("id", nargs="?", type=int, help="キーワード番号")
    m_stats.add_argument("--pv", type=int, help="月間PV")
    m_stats.add_argument("--rank", type=int, help="検索順位")
    m_stats.add_argument("--revenue", type=int, help="月間収益(円)")

    msub.add_parser("rewrite", help="改善すべき記事を期待増加額の順に出す")
    msub.add_parser("check", help="実測とモデルのズレを確認する")

    p_cost = sub.add_parser("cost", help="原価・粗利のレポート")
    p_cost.add_argument("--estimate", action="store_true",
                        help="実行前の概算（サービス別の想定原価と粗利率）")
    p_cost.add_argument("--api", action="store_true",
                        help="定額制でも、従量課金だった場合の試算を表示する")

    return parser


COMMANDS = {
    "init": cmd_init, "profile": cmd_profile, "ideas": cmd_ideas,
    "research": cmd_research, "plan": cmd_plan, "task": cmd_task,
    "revenue": cmd_revenue, "status": cmd_status, "price": cmd_price,
    "proposal": cmd_proposal, "review": cmd_review, "ask": cmd_ask,
    "report": cmd_report,
    "service": cmd_service, "job": cmd_job, "auto": cmd_auto, "cost": cmd_cost,
    "media": cmd_media, "pjt": cmd_pjt, "app": cmd_app, "screen": cmd_screen,
    "expense": cmd_expense,
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

    if args.command == "job" and args.action in ("run", "show", "delivered", "rm"):
        # `job run 1` のように位置引数で番号を渡せるようにする
        if args.id is None and args.service:
            try:
                args.id = int(args.service)
            except ValueError:
                args.id = None
        if args.id is None:
            print(f"案件番号を指定してください。 例) python main.py job {args.action} 1")
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
