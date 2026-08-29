"""案件キューの管理と自動実行。

案件を登録しておけば、`auto` コマンドが未処理をまとめて処理する。
納品まで終わったら売上にも自動記録するので、手で転記しない。
"""
from pathlib import Path

from .. import llm, store, tracker
from . import deliver, pipeline, services

NAME = "jobs"

STATUS_MARK = {
    "pending": "未処理", "done": "納品可", "review": "要確認",
    "failed": "失敗", "delivered": "納品済",
}


def load() -> list:
    return store.load(NAME, [])


def save(jobs: list):
    return store.save(NAME, jobs)


def find(job_id) -> dict:
    for j in load():
        if j["id"] == int(job_id):
            return j
    return None


def add(service_key: str, input_text: str, title: str = "", client: str = "",
        price: int = 0, options: str = "") -> dict:
    service = services.get(service_key)
    if not service:
        raise ValueError(f"不明なサービス: {service_key}")

    jobs = load()
    job = {
        "id": max((j["id"] for j in jobs), default=0) + 1,
        "service": service_key,
        "title": title or service.name,
        "client": client,
        "price": int(price or 0),
        "input": input_text,
        "options": options,
        "status": "pending",
        "created_at": store.now(),
        "run_at": "",
        "output_path": "",
        "chars": 0,
        "cost_jpy": 0.0,
        "qa_score": 0,
        "revisions": 0,
        "elapsed_sec": 0,
        "error": "",
        "usage": {},
        "revenue_recorded": False,
    }
    jobs.append(job)
    save(jobs)
    return job


def update(job_id: int, **fields) -> dict:
    jobs = load()
    for j in jobs:
        if j["id"] == int(job_id):
            j.update(fields)
            save(jobs)
            return j
    return None


def remove(job_id: int) -> bool:
    jobs = load()
    rest = [j for j in jobs if j["id"] != int(job_id)]
    if len(rest) == len(jobs):
        return False
    save(rest)
    return True


def profit(job: dict) -> float:
    return (job.get("price", 0) or 0) - (job.get("cost_jpy", 0) or 0)


def margin(job: dict) -> float:
    price = job.get("price", 0) or 0
    return round(profit(job) / price * 100, 1) if price else 0.0


# ---------------------------------------------------------------- 実行

def run(job: dict, record_revenue: bool = True, verbose: bool = True,
        use_ai_qa: bool = True) -> dict:
    """1件を生成〜検品〜納品ファイル出力まで実行する。"""
    service = services.get(job["service"])
    if not service:
        return update(job["id"], status="failed", error=f"不明なサービス: {job['service']}")

    if verbose:
        print(f"\n[{job['id']}] {job['title']}  <{service.name}>"
              f"{'  ' + job['client'] if job['client'] else ''}")

    try:
        result = pipeline.run(service, job["input"], job.get("options", ""),
                              use_ai_qa=use_ai_qa, verbose=verbose)
    except llm.LLMError as e:
        if verbose:
            print(f"  失敗: {e}")
        return update(job["id"], status="failed", error=str(e), run_at=store.now())

    path = deliver.write(job, result["output"], service.extension)

    updated = update(
        job["id"],
        status="review" if result["needs_human"] else "done",
        run_at=store.now(),
        output_path=str(path),
        chars=result["chars"],
        cost_jpy=result["cost_jpy"],
        qa_score=result["qa"].get("score", 0),
        revisions=result["revisions"],
        elapsed_sec=result["elapsed_sec"],
        usage=result["usage"],
        error="",
    )

    # 検品を通ったものだけ売上に計上する。
    # 「要確認」は人が直してから `job delivered` で計上する。
    if record_revenue and updated["status"] == "done":
        record_sale(updated)

    if verbose:
        print(f"  完了: {result['chars']:,}文字 / {result['elapsed_sec']}秒 / "
              f"原価 {result['cost_jpy']:.1f}円")
        if job.get("price"):
            p = job["price"] - result["cost_jpy"]
            print(f"  売価 {job['price']:,}円 → 粗利 {p:,.0f}円（粗利率 {p/job['price']*100:.1f}%）")
        if result["needs_human"]:
            print("  ⚠ 検品で指摘が残りました。納品前に確認してください。")
            from . import qa
            qa.print_qa(result["qa"])
        print(f"  納品ファイル: {path}")

    return updated


def record_sale(job: dict) -> bool:
    """案件の売価を売上に計上する。二重計上はしない。"""
    if job.get("revenue_recorded") or not job.get("price"):
        return False
    service = services.get(job["service"])
    tracker.add_revenue(
        job["price"],
        f"{service.name if service else job['service']}／{job['title']}",
        hours=round((service.auto_minutes if service else 3) / 60, 2),
        memo=f"自動生成 job#{job['id']} 原価{job.get('cost_jpy', 0):.0f}円",
    )
    update(job["id"], revenue_recorded=True)
    job["revenue_recorded"] = True
    return True


def run_pending(record_revenue: bool = True, verbose: bool = True,
                use_ai_qa: bool = True, limit: int = 0, retry_failed: bool = False) -> list:
    """未処理の案件をまとめて処理する。これが自動運転の本体。

    retry_failed=True なら、前回失敗した案件も対象に含める
    （APIの一時的な障害やキー未設定で落ちた分の再実行用）。
    """
    targets = {"pending", "failed"} if retry_failed else {"pending"}
    pending = [j for j in load() if j["status"] in targets]
    if limit:
        pending = pending[:limit]

    if not pending:
        if verbose:
            print("未処理の案件はありません。")
            if any(j["status"] == "failed" for j in load()):
                print("  失敗した案件があります。再実行するには --retry を付けてください。")
        return []

    if verbose:
        print(f"\n{'#'*74}")
        label = "未処理・失敗" if retry_failed else "未処理"
        print(f"  自動実行  {label} {len(pending)} 件")
        print(f"{'#'*74}")

    done = []
    for job in pending:
        done.append(run(job, record_revenue=record_revenue, verbose=verbose,
                        use_ai_qa=use_ai_qa))

    ok = sum(1 for j in done if j and j["status"] == "done")
    review = sum(1 for j in done if j and j["status"] == "review")
    failed = sum(1 for j in done if j and j["status"] == "failed")
    cost = sum(j.get("cost_jpy", 0) for j in done if j)
    sales = sum(j.get("price", 0) for j in done if j and j["status"] == "done")

    if verbose:
        print(f"\n{'#'*74}")
        print(f"  完了 {ok} 件 / 要確認 {review} 件 / 失敗 {failed} 件")
        if failed:
            print("  ※ 失敗した案件は `python main.py auto --retry` で再実行できます")
        print(f"  計上売上 {sales:,}円 － 原価 {cost:,.0f}円 ＝ 粗利 {sales - cost:,.0f}円")
        if review:
            print(f"  ※ 要確認 {review} 件は未計上。内容を直して `job delivered <ID>` で計上します")
        print(f"{'#'*74}")
    return done


# ---------------------------------------------------------------- 表示

def print_jobs(jobs: list = None, show_all: bool = False):
    jobs = load() if jobs is None else jobs
    if not jobs:
        print("案件がありません。`python main.py job add <サービス> --input <ファイル>` で登録します。")
        return

    shown = jobs if show_all else [j for j in jobs if j["status"] != "delivered"]
    print(f"\n{'='*74}")
    print(f"  {'ID':>3} {'状態':<6} {'サービス':<12} {'案件':<18}{'売価':>9}{'原価':>8}{'粗利率':>8}")
    print(f"{'-'*74}")
    for j in shown:
        service = services.get(j["service"])
        name = service.name if service else j["service"]
        title = (j["title"] or "")[:16]
        price = f"{j['price']:,}" if j["price"] else "-"
        cost = f"{j['cost_jpy']:.0f}" if j["cost_jpy"] else "-"
        mg = f"{margin(j):.1f}%" if j["price"] and j["cost_jpy"] else "-"
        print(f"  {j['id']:>3} {STATUS_MARK.get(j['status'], j['status']):<6} "
              f"{name:<12} {title:<18}{price:>9}{cost:>8}{mg:>8}")
    print(f"{'='*74}")

    pending = sum(1 for j in jobs if j["status"] == "pending")
    review = sum(1 for j in jobs if j["status"] == "review")
    if pending:
        print(f"  未処理 {pending} 件  → python main.py auto")
    if review:
        print(f"  要確認 {review} 件  → python main.py job show <ID>")


def print_job(job: dict):
    service = services.get(job["service"])
    print(f"\n{'='*74}")
    print(f"  [{job['id']}] {job['title']}  <{service.name if service else job['service']}>")
    print(f"{'='*74}")
    print(f"  状態     : {STATUS_MARK.get(job['status'], job['status'])}")
    print(f"  クライアント: {job['client'] or '-'}")
    print(f"  売価     : {job['price']:,} 円" if job["price"] else "  売価     : -")
    if job["cost_jpy"]:
        print(f"  原価     : {job['cost_jpy']:.1f} 円（粗利 {profit(job):,.0f}円 / "
              f"粗利率 {margin(job):.1f}%）")
        print(f"  品質     : {job['qa_score']}点 / 修正{job['revisions']}回 / "
              f"{job['chars']:,}文字 / {job['elapsed_sec']}秒")
    if job["output_path"]:
        print(f"  納品物   : {job['output_path']}")
    if job["error"]:
        print(f"  エラー   : {job['error']}")
    print(f"  登録     : {job['created_at']}   実行: {job['run_at'] or '-'}")

    if job["output_path"] and Path(job["output_path"]).exists():
        text = Path(job["output_path"]).read_text(encoding="utf-8")
        print(f"\n{'-'*74}")
        print(text[:1500])
        if len(text) > 1500:
            print(f"\n（以下略。全文は {job['output_path']}）")
    print(f"{'='*74}")
