"""外部 API を使わない部分の単体テスト。

  python -m unittest discover -s tests
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src import ideas, llm, pricing, profile, report, roadmap, store, tracker


class TempDataMixin:
    """data/ を一時ディレクトリに差し替えて、実データを汚さない。"""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self._orig_data = store.DATA_DIR
        self._orig_report = report.REPORT_DIR
        store.DATA_DIR = Path(self._tmp.name)
        report.REPORT_DIR = Path(self._tmp.name) / "reports"

    def tearDown(self):
        store.DATA_DIR = self._orig_data
        report.REPORT_DIR = self._orig_report
        self._tmp.cleanup()


class TestProfile(unittest.TestCase):
    def test_parse_int_handles_japanese_input(self):
        self.assertEqual(profile.parse_value("5万", "int", 0), 50000)
        self.assertEqual(profile.parse_value("50,000円", "int", 0), 50000)
        self.assertEqual(profile.parse_value("3.5万", "int", 0), 35000)
        self.assertEqual(profile.parse_value("10万5000", "int", 0), 105000)

    def test_parse_int_falls_back_to_default(self):
        self.assertEqual(profile.parse_value("", "int", 7), 7)
        self.assertEqual(profile.parse_value("なし", "int", 7), 7)

    def test_parse_list_accepts_japanese_comma(self):
        self.assertEqual(profile.parse_value("Excel、Python, 資料作成", "list", []),
                         ["Excel", "Python", "資料作成"])

    def test_summary_text_covers_all_fields(self):
        text = profile.summary_text(profile.load())
        for label in ("スキル", "週の稼働可能時間", "目標月収", "初期投資の上限"):
            self.assertIn(label, text)


class TestIdeaScore(unittest.TestCase):
    def setUp(self):
        self.prof = dict(profile.DEFAULTS,
                         hours_per_week=10, target_income=50000,
                         budget=30000, deadline_months=6)

    def _idea(self, **over):
        base = dict(skill_match=3, hours_per_week=10, startup_cost=30000,
                    months_to_first_sale=6, monthly_potential=50000, competition=3)
        base.update(over)
        return base

    def test_score_is_within_range(self):
        for idea in (self._idea(), self._idea(skill_match=5, competition=1),
                     self._idea(skill_match=1, hours_per_week=99, startup_cost=999999)):
            total = ideas.score(idea, self.prof)["total"]
            self.assertGreaterEqual(total, 0)
            self.assertLessEqual(total, 100)

    def test_better_fit_scores_higher(self):
        good = ideas.score(self._idea(skill_match=5, hours_per_week=5,
                                      startup_cost=5000, months_to_first_sale=1,
                                      monthly_potential=100000, competition=1), self.prof)
        bad = ideas.score(self._idea(skill_match=1, hours_per_week=40,
                                     startup_cost=200000, months_to_first_sale=12,
                                     monthly_potential=10000, competition=5), self.prof)
        self.assertGreater(good["total"], bad["total"])

    def test_over_budget_scores_zero_on_capital(self):
        idea = self._idea(startup_cost=self.prof["budget"] * 3)
        self.assertEqual(ideas.score(idea, self.prof)["breakdown"]["capital"], 0.0)

    def test_breakdown_sums_to_total(self):
        sc = ideas.score(self._idea(), self.prof)
        self.assertAlmostEqual(sum(sc["breakdown"].values()), sc["total"], places=1)

    def test_stars_are_five_characters(self):
        for total in (0, 1, 45, 80, 100):
            self.assertEqual(len(ideas.stars(total)), 5)


class TestPricing(unittest.TestCase):
    def test_round_price_rounds_up_by_unit(self):
        self.assertEqual(pricing.round_price(4200), 4500)
        self.assertEqual(pricing.round_price(23100), 24000)
        self.assertEqual(pricing.round_price(101000), 105000)

    def test_plans_keep_the_target_hourly_rate(self):
        e = pricing.estimate(hours=8, hourly=3000, difficulty=3, revisions=1)
        for plan in e["plans"]:
            self.assertGreaterEqual(plan["effective_hourly"], 3000)

    def test_platform_fee_is_passed_on_to_the_client(self):
        direct = pricing.estimate(hours=8, hourly=3000, platform="direct")
        via = pricing.estimate(hours=8, hourly=3000, platform="crowdworks")
        self.assertGreater(via["floor"], direct["floor"])
        std = next(p for p in via["plans"] if p["name"] == "標準")
        self.assertGreaterEqual(std["net"], direct["floor"] * 0.95)

    def test_rush_and_difficulty_raise_the_price(self):
        base = pricing.estimate(hours=8, hourly=3000)["floor"]
        self.assertGreater(pricing.estimate(hours=8, hourly=3000, rush=True)["floor"], base)
        self.assertGreater(pricing.estimate(hours=8, hourly=3000, difficulty=5)["floor"], base)

    def test_expenses_are_added_on_top(self):
        base = pricing.estimate(hours=4, hourly=3000)["floor"]
        with_exp = pricing.estimate(hours=4, hourly=3000, expenses=10000)["floor"]
        self.assertGreaterEqual(with_exp - base, 10000)


class TestTracker(TempDataMixin, unittest.TestCase):
    def test_task_lifecycle(self):
        t = tracker.add_task("サンプルを作る", phase="Phase1")
        self.assertEqual(t["status"], "todo")

        tracker.set_status(t["id"], "doing")
        self.assertEqual(tracker.load_tasks()[0]["status"], "doing")

        done = tracker.set_status(t["id"], "done")
        self.assertEqual(done["done_at"], store.today())

        self.assertTrue(tracker.remove_task(t["id"]))
        self.assertEqual(tracker.load_tasks(), [])

    def test_ids_do_not_collide_after_removal(self):
        a = tracker.add_task("A")
        b = tracker.add_task("B")
        tracker.remove_task(a["id"])
        c = tracker.add_task("C")
        self.assertNotIn(c["id"], (b["id"],))

    def test_progress_by_phase(self):
        tracker.add_tasks([
            {"title": "A", "phase": "P1"},
            {"title": "B", "phase": "P1"},
            {"title": "C", "phase": "P2"},
        ])
        tracker.set_status(1, "done")
        prog = tracker.progress()
        self.assertEqual((prog["done"], prog["total"], prog["rate"]), (1, 3, 33))
        self.assertEqual(prog["phases"]["P1"]["rate"], 50)
        self.assertEqual(prog["phases"]["P2"]["rate"], 0)

    def test_overdue_ignores_done_tasks(self):
        tracker.add_task("遅れている", due="2000-01-01")
        tracker.add_task("完了済み", due="2000-01-01")
        tracker.set_status(2, "done")
        self.assertEqual([t["id"] for t in tracker.overdue()], [1])

    def test_monthly_revenue_and_hourly_rate(self):
        tracker.add_revenue(5000, "A", date="2026-08-10", hours=2)
        tracker.add_revenue(15000, "B", date="2026-08-25", hours=3)
        tracker.add_revenue(30000, "C", date="2026-09-01", hours=5)

        months = tracker.monthly_revenue()
        self.assertEqual(months["2026-08"]["amount"], 20000)
        self.assertEqual(months["2026-08"]["count"], 2)
        self.assertEqual(months["2026-09"]["amount"], 30000)
        self.assertEqual(tracker.hourly_rate(), 5000)

    def test_hourly_rate_is_none_without_recorded_hours(self):
        tracker.add_revenue(5000, "A", date="2026-08-10")
        self.assertIsNone(tracker.hourly_rate())

    def test_bar_length_is_fixed(self):
        for rate in (0, 33, 100):
            self.assertEqual(len(tracker.bar(rate)), 20)


class TestStore(TempDataMixin, unittest.TestCase):
    def test_missing_file_returns_default(self):
        self.assertEqual(store.load("nope", {"a": 1}), {"a": 1})

    def test_broken_file_is_quarantined_not_raised(self):
        store.DATA_DIR.mkdir(parents=True, exist_ok=True)
        (store.DATA_DIR / "broken.json").write_text("{ これは JSON ではない", encoding="utf-8")
        self.assertEqual(store.load("broken", []), [])
        self.assertFalse((store.DATA_DIR / "broken.json").exists())
        self.assertTrue(list(store.DATA_DIR.glob("broken.broken-*.json")))

    def test_round_trip_keeps_japanese(self):
        store.save("x", {"名前": "議事録AI代行"})
        self.assertEqual(store.load("x")["名前"], "議事録AI代行")


class TestLLMParsing(unittest.TestCase):
    def test_extracts_json_from_code_fence(self):
        self.assertEqual(llm.extract_json('```json\n{"a": 1}\n```'), {"a": 1})

    def test_extracts_json_surrounded_by_prose(self):
        self.assertEqual(llm.extract_json('こちらです [1, 2] 以上です'), [1, 2])

    def test_plain_json_passes_through(self):
        self.assertEqual(llm.extract_json('{"a": [1, 2]}'), {"a": [1, 2]})

    def test_unparseable_text_raises_llm_error(self):
        with self.assertRaises(llm.LLMError):
            llm.extract_json("JSON はありません")


class TestRoadmapToTasks(TempDataMixin, unittest.TestCase):
    def test_phase_tasks_get_staggered_due_dates(self):
        plan = {
            "idea_id": 1, "start_date": "2026-01-01",
            "phases": [
                {"name": "P1", "tasks": [{"title": "A", "hours": 2}]},
                {"name": "P2", "tasks": [{"title": "B", "hours": 3}]},
                {"name": "P3", "tasks": [{"title": "C", "hours": 4}]},
            ],
        }
        added = roadmap.to_tasks(plan)
        self.assertEqual([t["due"] for t in added],
                         ["2026-01-31", "2026-03-02", "2026-04-01"])
        self.assertEqual([t["phase"] for t in added], ["P1", "P2", "P3"])
        self.assertEqual(len(tracker.load_tasks()), 3)


class TestGenerationWithMockedLLM(TempDataMixin, unittest.TestCase):
    """Claude の応答を差し替えて、生成〜保存〜再読み込みまでを通しで確認する。"""

    FAKE_IDEAS = [
        {"name": "議事録AI代行", "category": "代行", "summary": "会議の録音を要約して納品",
         "target": "中小企業", "revenue_model": "5,000円×12件", "price_range": "1件5,000円",
         "startup_cost": 5000, "hours_per_week": 6, "months_to_first_sale": 1,
         "monthly_potential": 60000, "skill_match": 5, "competition": 3, "ai_leverage": 5,
         "first_step": "サンプルを作る", "risks": ["守秘義務"], "tools": ["Claude"]},
        {"name": "AI動画量産", "category": "コンテンツ", "summary": "広告収益を狙う",
         "target": "視聴者", "revenue_model": "広告", "price_range": "-",
         "startup_cost": 80000, "hours_per_week": 25, "months_to_first_sale": 9,
         "monthly_potential": 200000, "skill_match": 2, "competition": 5, "ai_leverage": 4,
         "first_step": "企画", "risks": ["長期戦"], "tools": ["Claude"]},
        {"不正な項目": "name が無いので捨てられる"},
    ]

    def setUp(self):
        super().setUp()
        self.prof = dict(profile.DEFAULTS, hours_per_week=10, target_income=50000,
                         budget=30000, deadline_months=6)
        self._orig_ask_json = llm.ask_json

    def tearDown(self):
        llm.ask_json = self._orig_ask_json
        super().tearDown()

    def _mock(self, payload):
        ideas.llm.ask_json = lambda *a, **k: payload
        roadmap.llm.ask_json = lambda *a, **k: payload

    def test_generate_sorts_scores_and_drops_malformed(self):
        self._mock(list(self.FAKE_IDEAS))
        result = ideas.generate(self.prof, n=3)

        self.assertEqual(len(result), 2)                       # 不正な項目は除外される
        self.assertEqual(result[0]["name"], "議事録AI代行")      # 適合度の高い順
        self.assertEqual([i["id"] for i in result], [1, 2])
        self.assertGreater(result[0]["score"]["total"], result[1]["score"]["total"])

        self.assertEqual(ideas.load()[0]["name"], "議事録AI代行")  # 保存されている
        self.assertEqual(ideas.find(2)["name"], "AI動画量産")
        self.assertIsNone(ideas.find(99))

    def test_generate_accepts_object_wrapped_response(self):
        self._mock({"ideas": list(self.FAKE_IDEAS[:1])})
        self.assertEqual(len(ideas.generate(self.prof, n=1)), 1)

    def test_plan_generates_and_registers_tasks(self):
        self._mock({
            "goal": "月5万円",
            "phases": [
                {"name": "P1", "period": "1〜30日", "goal": "型を作る", "kpi": "サンプル3本",
                 "tasks": [{"title": "サンプル作成", "hours": 6}]},
                {"name": "P2", "period": "31〜60日", "goal": "初受注", "kpi": "提案30件",
                 "tasks": [{"title": "提案文送付", "hours": 8}]},
            ],
            "weekly_routine": ["日曜に振り返り"],
            "milestones": [{"day": 30, "event": "初受注"}],
            "risk_plan": [{"risk": "返信が無い", "action": "文面を変える"}],
        })
        idea = {"id": 1, "name": "議事録AI代行"}
        plan = roadmap.generate(idea, self.prof)

        self.assertEqual(plan["idea_id"], 1)
        self.assertEqual(roadmap.load(1)["goal"], "月5万円")

        added = roadmap.to_tasks(plan)
        self.assertEqual(len(added), 2)
        self.assertEqual([t["phase"] for t in added], ["P1", "P2"])
        self.assertTrue(all(t["due"] for t in added))


class TestReport(TempDataMixin, unittest.TestCase):
    def test_status_reflects_tasks_and_revenue(self):
        prof = dict(profile.DEFAULTS, target_income=50000)
        tracker.add_tasks([{"title": "A", "phase": "P1"}, {"title": "B", "phase": "P1"}])
        tracker.set_status(1, "done")
        tracker.add_revenue(25000, "案件", date=store.today())

        s = report.status(prof)
        self.assertEqual(s["progress"]["rate"], 50)
        self.assertEqual(s["month_amount"], 25000)
        self.assertEqual(s["achievement"], 50)

    def test_status_handles_empty_data(self):
        s = report.status(dict(profile.DEFAULTS, target_income=0))
        self.assertEqual(s["progress"]["total"], 0)
        self.assertEqual(s["achievement"], 0)

    def test_markdown_report_is_written(self):
        prof = dict(profile.DEFAULTS, skills=["Excel"])
        tracker.add_task("A", phase="P1")
        path = report.export_markdown(prof)
        text = path.read_text(encoding="utf-8")
        self.assertIn("AI 副業 進捗レポート", text)
        self.assertIn("- [ ] A", text)


if __name__ == "__main__":
    unittest.main()
