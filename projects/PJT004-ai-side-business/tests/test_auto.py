"""自動化エンジンのテスト。Claude の応答はモックに差し替えて実行する。

  python -m unittest discover -s tests
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src import llm, store, tracker
from src.auto import cost, deliver, jobs, pipeline, qa, services


class FakeUsage:
    """messages.create のレスポンスに入っている usage の代わり。"""
    input_tokens = 4000
    output_tokens = 3000
    cache_read_input_tokens = 1000
    cache_creation_input_tokens = 0


GOOD_MINUTES = (
    "# 議事録\n\n## 決定事項\n- 10月から新価格を適用する\n\n"
    "## ToDo\n| 担当 | 内容 | 期限 |\n| 山田 | 価格表改訂 | 9/10 |\n\n"
    "## 議論の要点\n" + "価格改定の背景を確認した。" * 40
)
BAD_MINUTES = "以下が議事録です。\n承知しました。"


class AutoTestBase(unittest.TestCase):
    """data/ と deliverables/ を一時ディレクトリに逃がす。"""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        tmp = Path(self._tmp.name)
        self._orig = (store.DATA_DIR, deliver.DELIVER_DIR, llm.ask, llm.ask_json)
        store.DATA_DIR = tmp / "data"
        deliver.DELIVER_DIR = tmp / "deliverables"
        self.service = services.get("minutes")

    def tearDown(self):
        store.DATA_DIR, deliver.DELIVER_DIR, llm.ask, llm.ask_json = self._orig
        self._tmp.cleanup()

    def mock_llm(self, outputs, verdict="合格", score=90, issues=None):
        """outputs を順に返すモック。使用量も計測に流す。"""
        seq = list(outputs)

        def ask(prompt, system="", **kwargs):
            if llm._meter is not None:
                llm._meter.add(FakeUsage(), model="claude-opus-5")
            return seq.pop(0) if len(seq) > 1 else seq[0]

        def ask_json(prompt, system="", **kwargs):
            if llm._meter is not None:
                llm._meter.add(FakeUsage(), model="claude-opus-5")
            return {"score": score, "issues": issues or [],
                    "verdict": verdict, "comment": ""}

        llm.ask, llm.ask_json = ask, ask_json


class TestServices(unittest.TestCase):
    def test_every_service_is_well_formed(self):
        for s in services.SERVICES:
            self.assertIn("{input}", s.template, f"{s.key}: 入力の差し込み口がない")
            self.assertIn("{options}", s.template, f"{s.key}: 追加指定の差し込み口がない")
            self.assertLess(s.price_min, s.price_max, f"{s.key}: 単価の範囲が不正")
            self.assertGreater(s.manual_hours, s.auto_minutes / 60,
                               f"{s.key}: 自動化しても速くならない")
            self.assertTrue(s.qa_points, f"{s.key}: 検品の観点が無い")

    def test_keys_are_unique(self):
        keys = [s.key for s in services.SERVICES]
        self.assertEqual(len(keys), len(set(keys)))

    def test_lookup(self):
        self.assertEqual(services.get("blog").name, "ブログ記事執筆")
        self.assertIsNone(services.get("存在しない"))


class TestMechanicalQA(unittest.TestCase):
    def setUp(self):
        self.service = services.get("minutes")

    def test_clean_output_has_no_issues(self):
        self.assertEqual(qa.mechanical(GOOD_MINUTES, self.service), [])

    def test_detects_short_output(self):
        issues = qa.mechanical("短い", self.service)
        self.assertTrue(any("文字数不足" in i for i in issues))

    def test_detects_missing_required_sections(self):
        text = GOOD_MINUTES.replace("## ToDo", "## やること")
        self.assertTrue(any("ToDo" in i for i in qa.mechanical(text, self.service)))

    def test_detects_forbidden_expressions(self):
        text = GOOD_MINUTES + "\nこの施策は絶対に儲かる。"
        self.assertTrue(any("景品表示法" in i for i in qa.mechanical(text, self.service)))

    def test_detects_ai_preamble_and_placeholders(self):
        issues = qa.mechanical(BAD_MINUTES, self.service)
        self.assertTrue(any("前置き" in i for i in issues))
        self.assertTrue(any("返事" in i for i in issues))
        self.assertTrue(any("プレースホルダ" in i
                            for i in qa.mechanical(GOOD_MINUTES + "\nTODO", self.service)))

    def test_mechanical_failure_overrides_ai_pass(self):
        """AI が合格と言っても、機械チェックに引っかかれば不合格。"""
        original = llm.ask_json
        llm.ask_json = lambda *a, **k: {"score": 95, "issues": [],
                                        "verdict": "合格", "comment": ""}
        try:
            result = qa.check(BAD_MINUTES, self.service, "議事録", use_ai=True)
        finally:
            llm.ask_json = original
        self.assertEqual(result["verdict"], "要修正")
        self.assertLessEqual(result["score"], 60)

    def test_ai_review_failure_does_not_break_the_check(self):
        original = llm.ask_json

        def boom(*a, **k):
            raise llm.LLMError("APIエラー")

        llm.ask_json = boom
        try:
            result = qa.check(GOOD_MINUTES, self.service, "議事録", use_ai=True)
        finally:
            llm.ask_json = original
        self.assertEqual(result["verdict"], "合格")
        self.assertIn("スキップ", result["comment"])


class TestPipeline(AutoTestBase):
    def test_passing_draft_needs_no_revision(self):
        self.mock_llm([GOOD_MINUTES])
        result = pipeline.run(self.service, "会議メモ", verbose=False)
        self.assertEqual(result["revisions"], 0)
        self.assertFalse(result["needs_human"])
        self.assertGreater(result["cost_jpy"], 0)
        self.assertEqual(result["chars"], len(GOOD_MINUTES))

    def test_failing_draft_is_revised_once(self):
        self.mock_llm([BAD_MINUTES, GOOD_MINUTES])
        result = pipeline.run(self.service, "会議メモ", verbose=False)
        self.assertEqual(result["revisions"], 1)
        self.assertFalse(result["needs_human"])
        self.assertEqual(result["output"], GOOD_MINUTES)

    def test_unfixable_draft_is_escalated_to_a_human(self):
        self.mock_llm([BAD_MINUTES])
        result = pipeline.run(self.service, "会議メモ", verbose=False)
        self.assertEqual(result["revisions"], 1)   # 1回試して駄目なら上げる
        self.assertTrue(result["needs_human"])

    def test_revision_limit_is_respected(self):
        self.mock_llm([BAD_MINUTES])
        result = pipeline.run(self.service, "会議メモ", max_revisions=0, verbose=False)
        self.assertEqual(result["revisions"], 0)
        self.assertTrue(result["needs_human"])

    def test_usage_is_metered_per_run(self):
        self.mock_llm([GOOD_MINUTES])
        result = pipeline.run(self.service, "会議メモ", verbose=False)
        self.assertEqual(result["usage"]["calls"], 2)      # 生成 + 検品
        self.assertEqual(result["usage"]["model"], "claude-opus-5")


class TestJobs(AutoTestBase):
    def test_add_and_find(self):
        job = jobs.add("minutes", "会議メモ", title="定例", client="A社", price=5000)
        self.assertEqual(job["status"], "pending")
        self.assertEqual(jobs.find(job["id"])["title"], "定例")
        self.assertIsNone(jobs.find(999))

    def test_unknown_service_is_rejected(self):
        with self.assertRaises(ValueError):
            jobs.add("存在しない", "入力")

    def test_run_delivers_file_and_books_revenue(self):
        self.mock_llm([GOOD_MINUTES])
        job = jobs.add("minutes", "会議メモ", title="定例", client="A社", price=6000)
        done = jobs.run(job, verbose=False)

        self.assertEqual(done["status"], "done")
        self.assertTrue(Path(done["output_path"]).exists())
        self.assertEqual(Path(done["output_path"]).read_text(encoding="utf-8"), GOOD_MINUTES)
        self.assertGreater(done["cost_jpy"], 0)
        self.assertLess(done["cost_jpy"], 6000)          # 原価が売価を超えない
        self.assertTrue(done["revenue_recorded"])
        self.assertEqual(len(tracker.load_revenue()), 1)
        self.assertEqual(tracker.load_revenue()[0]["amount"], 6000)

    def test_failed_qa_is_not_booked_as_revenue(self):
        self.mock_llm([BAD_MINUTES])
        job = jobs.add("minutes", "会議メモ", price=5000)
        done = jobs.run(job, verbose=False)

        self.assertEqual(done["status"], "review")
        self.assertFalse(done["revenue_recorded"])
        self.assertEqual(tracker.load_revenue(), [])

    def test_revenue_is_booked_once_on_delivery(self):
        self.mock_llm([BAD_MINUTES])
        job = jobs.add("minutes", "会議メモ", price=5000)
        jobs.run(job, verbose=False)

        self.assertTrue(jobs.record_sale(jobs.find(job["id"])))
        self.assertFalse(jobs.record_sale(jobs.find(job["id"])))   # 二重計上しない
        self.assertEqual(len(tracker.load_revenue()), 1)

    def test_api_error_marks_the_job_failed(self):
        def boom(*a, **k):
            raise llm.LLMError("APIエラー")

        llm.ask = boom
        job = jobs.add("minutes", "会議メモ", price=5000)
        done = jobs.run(job, verbose=False)

        self.assertEqual(done["status"], "failed")
        self.assertIn("APIエラー", done["error"])
        self.assertEqual(tracker.load_revenue(), [])

    def test_run_pending_processes_the_whole_queue(self):
        self.mock_llm([GOOD_MINUTES])
        for i in range(3):
            jobs.add("minutes", f"会議メモ{i}", price=5000)
        done = jobs.run_pending(verbose=False)

        self.assertEqual(len(done), 3)
        self.assertTrue(all(j["status"] == "done" for j in done))
        self.assertEqual([j["status"] for j in jobs.load()], ["done"] * 3)

    def test_run_pending_respects_limit_and_skips_finished(self):
        self.mock_llm([GOOD_MINUTES])
        for i in range(3):
            jobs.add("minutes", f"会議メモ{i}", price=5000)

        jobs.run_pending(limit=1, verbose=False)
        self.assertEqual(sum(1 for j in jobs.load() if j["status"] == "pending"), 2)

        jobs.run_pending(verbose=False)
        self.assertEqual(sum(1 for j in jobs.load() if j["status"] == "pending"), 0)

    def test_failed_jobs_are_retried_only_with_the_flag(self):
        def boom(*a, **k):
            raise llm.LLMError("APIエラー")

        llm.ask = boom
        jobs.add("minutes", "会議メモ", price=5000)
        jobs.run_pending(verbose=False)
        self.assertEqual(jobs.find(1)["status"], "failed")

        # 既定では失敗分を拾わない
        self.mock_llm([GOOD_MINUTES])
        self.assertEqual(jobs.run_pending(verbose=False), [])

        # --retry 相当なら再実行して復帰する
        done = jobs.run_pending(verbose=False, retry_failed=True)
        self.assertEqual(len(done), 1)
        self.assertEqual(done[0]["status"], "done")
        self.assertEqual(done[0]["error"], "")

    def test_profit_and_margin(self):
        job = {"price": 5000, "cost_jpy": 50.0}
        self.assertEqual(jobs.profit(job), 4950.0)
        self.assertEqual(jobs.margin(job), 99.0)
        self.assertEqual(jobs.margin({"price": 0, "cost_jpy": 50.0}), 0.0)


class TestDeliver(AutoTestBase):
    def test_filename_is_filesystem_safe(self):
        self.assertEqual(deliver.safe_name("株式会社/テスト *社内*"), "株式会社_テスト_社内")
        self.assertEqual(deliver.safe_name(""), "無題")

    def test_write_creates_the_directory(self):
        job = {"id": 1, "created_at": "2026-08-29 10:00", "client": "A社",
               "title": "定例", "service": "minutes"}
        path = deliver.write(job, "本文", "md")
        self.assertTrue(path.exists())
        self.assertIn("A社", path.name)
        self.assertTrue(path.name.endswith(".md"))

    def test_cover_note_mentions_open_items(self):
        job = {"client": "A社"}
        note = deliver.cover_note(job, {"chars": 100, "needs_human": True},
                                  services.get("minutes"))
        self.assertIn("A社 様", note)
        self.assertIn("要確認", note)


class TestCost(AutoTestBase):
    def test_estimate_is_positive_and_profitable(self):
        for key in services.keys():
            e = cost.estimate(key)
            self.assertGreater(e["cost_jpy"], 0, key)
            self.assertLess(e["cost_jpy"], e["price_min"], f"{key}: 最低単価で赤字")
            self.assertGreater(e["margin_min"], 0, key)

    def test_summary_counts_only_booked_sales(self):
        self.mock_llm([GOOD_MINUTES])
        jobs.run(jobs.add("minutes", "メモ", price=6000), verbose=False)
        self.mock_llm([BAD_MINUTES])
        jobs.run(jobs.add("minutes", "メモ", price=9000), verbose=False)   # 要確認

        s = cost.summary()
        self.assertEqual(s["count"], 2)          # 原価は2件ぶん発生している
        self.assertEqual(s["sales"], 6000)       # 売上は合格した1件だけ
        self.assertGreater(s["cost"], 0)
        self.assertAlmostEqual(s["profit"], s["sales"] - s["cost"], places=1)
        self.assertGreater(s["saved_hours"], 0)

    def test_summary_handles_empty_state(self):
        s = cost.summary()
        self.assertEqual(s["count"], 0)
        self.assertEqual(s["margin"], 0.0)


class TestUsageAndCost(unittest.TestCase):
    def test_cost_matches_the_published_rates(self):
        u = llm.Usage("claude-opus-5")
        u.input_tokens = 1_000_000
        u.output_tokens = 1_000_000
        self.assertAlmostEqual(u.cost_usd(), 30.0, places=2)   # $5 + $25

    def test_cached_tokens_are_cheaper(self):
        plain = llm.Usage("claude-opus-5")
        plain.input_tokens = 100_000
        cached = llm.Usage("claude-opus-5")
        cached.cache_read_tokens = 100_000
        self.assertLess(cached.cost_usd(), plain.cost_usd())

    def test_model_choice_changes_the_cost(self):
        def cost_of(model):
            u = llm.Usage(model)
            u.input_tokens = u.output_tokens = 100_000
            return u.cost_usd()

        self.assertGreater(cost_of("claude-opus-5"), cost_of("claude-sonnet-5"))
        self.assertGreater(cost_of("claude-sonnet-5"), cost_of("claude-haiku-4-5"))

    def test_meter_accumulates_and_nests(self):
        with llm.meter("claude-opus-5") as outer:
            outer.add(FakeUsage())
            with llm.meter("claude-opus-5") as inner:
                inner.add(FakeUsage())
            self.assertEqual(inner.calls, 1)
        self.assertEqual(outer.calls, 2)      # 内側の分も外側に合算される

    def test_usage_round_trips_through_json(self):
        u = llm.Usage("claude-sonnet-5")
        u.add(FakeUsage())
        restored = llm.Usage.from_dict(u.to_dict())
        self.assertEqual(restored.to_dict(), u.to_dict())


if __name__ == "__main__":
    unittest.main()
