"""アプリ収益モデルと、複数プロジェクトの横断管理のテスト。

  python -m unittest discover -s tests
"""
import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src import store
from src.apps import model as app_model
from src.portfolio import projects as pjt


def days_ago(days: int) -> str:
    return (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")


def months_ago(months: int) -> str:
    return days_ago(int(months * 30.4))


class TestRetention(unittest.TestCase):
    def setUp(self):
        self.p = dict(app_model.DEFAULTS)

    def test_curve_passes_through_the_measured_points(self):
        """D1 と D30 の実測値をそのまま通ること。"""
        self.assertAlmostEqual(app_model.retention(1, self.p), self.p["d1"], places=6)
        self.assertAlmostEqual(app_model.retention(30, self.p), self.p["d30"], places=6)

    def test_day_zero_is_everyone(self):
        self.assertEqual(app_model.retention(0, self.p), 1.0)

    def test_curve_decreases(self):
        values = [app_model.retention(d, self.p) for d in (1, 3, 7, 14, 30, 90)]
        self.assertEqual(values, sorted(values, reverse=True))

    def test_inconsistent_inputs_fall_back_safely(self):
        # D30 が D1 以上という取り違えでも落ちない
        weird = dict(self.p, d1=0.3, d30=0.5)
        self.assertEqual(app_model.retention(10, weird), 0.3)
        dead = dict(self.p, d1=0.0)
        self.assertEqual(app_model.retention(10, dead), 0.0)

    def test_retention_sum_exceeds_one(self):
        self.assertGreater(app_model.retention_sum(self.p), 1.0)

    def test_better_retention_contributes_more_dau(self):
        low = app_model.retention_sum(dict(self.p, d1=0.20, d30=0.02))
        high = app_model.retention_sum(dict(self.p, d1=0.50, d30=0.12))
        self.assertGreater(high, low)


class TestAppRevenue(unittest.TestCase):
    def setUp(self):
        self.p = dict(app_model.DEFAULTS)

    def test_dau_is_linear_in_installs(self):
        one = app_model.steady_dau(10, self.p)
        two = app_model.steady_dau(20, self.p)
        self.assertAlmostEqual(two, one * 2, places=6)

    def test_ad_arpdau_formula(self):
        # 6回 × 600円 ÷ 1000 = 3.6円
        self.assertAlmostEqual(app_model.ad_arpdau(self.p), 3.6)

    def test_iap_arpdau_is_the_monthly_amount_divided_by_thirty(self):
        # 1.5% × 1500円 ÷ 30 = 0.75円
        self.assertAlmostEqual(app_model.iap_arpdau(self.p), 0.75)

    def test_both_is_the_sum(self):
        self.assertAlmostEqual(app_model.arpdau("both", self.p),
                               app_model.ad_arpdau(self.p) + app_model.iap_arpdau(self.p))

    def test_required_dau_inverts_the_revenue_formula(self):
        dau = app_model.required_dau(50000, "both", self.p)
        self.assertAlmostEqual(app_model.monthly_revenue(dau, "both", self.p),
                               50000, places=0)

    def test_required_installs_is_consistent_with_dau(self):
        r = app_model.required_installs(50000, "both", self.p)
        self.assertAlmostEqual(app_model.steady_dau(r["daily_installs"], self.p),
                               r["dau"], delta=r["dau"] * 0.05)

    def test_better_retention_needs_fewer_installs(self):
        weak = app_model.required_installs(50000, "both",
                                           dict(self.p, d1=0.20, d30=0.02))
        strong = app_model.required_installs(50000, "both",
                                             dict(self.p, d1=0.50, d30=0.12))
        self.assertGreater(weak["daily_installs"], strong["daily_installs"])

    def test_ltv_is_lifetime_dau_times_arpdau(self):
        self.assertAlmostEqual(
            app_model.ltv(self.p),
            app_model.retention_sum(self.p) * app_model.arpdau("both", self.p))

    def test_paid_acquisition_is_unprofitable_at_default_values(self):
        """既定値では LTV < CPI になる。ここが逆転しない限り広告出稿は赤字。"""
        self.assertLess(app_model.ltv(self.p), self.p["cpi"])

    def test_organic_gap_reflects_current_acquisition(self):
        r = app_model.required_installs(50000, "both", self.p)
        self.assertEqual(r["organic_gap"],
                         r["daily_installs"] - self.p["organic_installs"])


class TestAppSimulation(unittest.TestCase):
    def setUp(self):
        self.p = dict(app_model.DEFAULTS)

    def test_dau_accumulates_then_flattens(self):
        sim = app_model.simulate(12, 20, p=self.p)
        daus = [r["dau"] for r in sim["rows"]]
        self.assertEqual(daus, sorted(daus))
        self.assertGreater(daus[0], 0)
        # 定常状態に近づくので、後半の伸びは前半より小さい
        self.assertLess(daus[-1] - daus[-2], daus[1] - daus[0])

    def test_growth_increases_installs(self):
        flat = app_model.simulate(12, 20, p=self.p)
        rising = app_model.simulate(12, 20, growth=0.2, p=self.p)
        self.assertGreater(rising["final_dau"], flat["final_dau"])

    def test_paid_installs_show_up_as_cost(self):
        free = app_model.simulate(6, 20, p=self.p)
        paid = app_model.simulate(6, 20, p=dict(self.p, paid_installs=10))
        self.assertEqual(free["rows"][0]["cost"], 0)
        self.assertGreater(paid["rows"][0]["cost"], 0)

    def test_unreachable_target_reports_none(self):
        sim = app_model.simulate(6, 1, target=1_000_000, p=self.p)
        self.assertIsNone(sim["target_month"])

    def test_params_round_trip(self):
        tmp = tempfile.TemporaryDirectory()
        original = store.DATA_DIR
        store.DATA_DIR = Path(tmp.name)
        try:
            app_model.save_params(dict(app_model.DEFAULTS, d1=0.5))
            self.assertEqual(app_model.load_params()["d1"], 0.5)
            self.assertEqual(app_model.load_params()["ecpm"], app_model.DEFAULTS["ecpm"])
        finally:
            store.DATA_DIR = original
            tmp.cleanup()


class PortfolioTestBase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self._orig = store.DATA_DIR
        store.DATA_DIR = Path(self._tmp.name)

    def tearDown(self):
        store.DATA_DIR = self._orig
        self._tmp.cleanup()


class TestProjectRegistry(PortfolioTestBase):
    def test_add_and_find(self):
        p = pjt.add("サッカーゲーム", kind="app", status="開発中")
        self.assertEqual(p["id"], 1)
        self.assertEqual(pjt.find(1)["name"], "サッカーゲーム")
        self.assertIsNone(pjt.find(99))

    def test_ids_increment_and_survive_removal(self):
        a = pjt.add("A")
        pjt.add("B")
        pjt.remove(a["id"])
        self.assertEqual(pjt.add("C")["id"], 3)

    def test_update_and_remove(self):
        p = pjt.add("A")
        pjt.update(p["id"], status="公開", released_at="2026-03-01")
        self.assertEqual(pjt.find(1)["status"], "公開")
        self.assertTrue(pjt.remove(1))
        self.assertFalse(pjt.remove(1))

    def test_record_creates_then_overwrites_the_same_month(self):
        p = pjt.add("A")
        pjt.record(p["id"], month="2026-08", revenue=1000, hours=10)
        pjt.record(p["id"], month="2026-08", revenue=2000)
        records = pjt.find(1)["records"]
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["revenue"], 2000)
        self.assertEqual(records[0]["hours"], 10)      # 指定しない項目は保持

    def test_records_stay_sorted_by_month(self):
        p = pjt.add("A")
        for month in ("2026-08", "2026-06", "2026-07"):
            pjt.record(p["id"], month=month, revenue=100)
        self.assertEqual([r["month"] for r in pjt.find(1)["records"]],
                         ["2026-06", "2026-07", "2026-08"])


class TestProjectStats(PortfolioTestBase):
    def _with_records(self, revenues, **kwargs):
        p = pjt.add("A", **kwargs)
        for i, rev in enumerate(revenues):
            pjt.record(p["id"], month=f"2026-{i + 1:02d}", revenue=rev,
                       cost=100, hours=10)
        return pjt.find(p["id"])

    def test_totals_and_hourly(self):
        s = pjt.stats(self._with_records([1000, 2000]))
        self.assertEqual(s["revenue"], 3000)
        self.assertEqual(s["cost"], 200)
        self.assertEqual(s["profit"], 2800)
        self.assertEqual(s["hours"], 20.0)
        self.assertEqual(s["hourly"], 140)

    def test_growth_window_shrinks_for_short_histories(self):
        """記録が3ヶ月しか無くても伸びを判定できること。"""
        s = pjt.stats(self._with_records([1000, 2000, 4000]))
        self.assertEqual(s["growth_window"], 1)
        self.assertEqual(s["growth"], 100)          # 4000 対 2000

    def test_growth_uses_three_month_windows_when_available(self):
        s = pjt.stats(self._with_records([100, 100, 100, 200, 200, 200]))
        self.assertEqual(s["growth_window"], 3)
        self.assertEqual(s["growth"], 100)

    def test_growth_is_unknown_with_a_single_month(self):
        s = pjt.stats(self._with_records([1000]))
        self.assertIsNone(s["growth"])
        self.assertEqual(s["growth_window"], 0)

    def test_growth_from_zero_is_capped(self):
        s = pjt.stats(self._with_records([0, 5000]))
        self.assertEqual(s["growth"], 100)

    def test_empty_project_does_not_divide_by_zero(self):
        s = pjt.stats(pjt.add("A"))
        self.assertEqual(s["hourly"], 0)
        self.assertEqual(s["revenue"], 0)
        self.assertIsNone(s["growth"])


class TestDiagnosis(PortfolioTestBase):
    def _project(self, status="運用", released=None, started=None, revenues=()):
        p = pjt.add("A", status=status, started=started or days_ago(30),
                    released=released or "")
        for i, rev in enumerate(revenues):
            pjt.record(p["id"], month=f"2026-{i + 1:02d}", revenue=rev, hours=5)
        return pjt.find(p["id"])

    def test_building_projects(self):
        self.assertEqual(
            pjt.diagnose(self._project(status="開発中", started=months_ago(1))), "build")

    def test_long_development_is_flagged(self):
        self.assertEqual(
            pjt.diagnose(self._project(status="開発中",
                                       started=months_ago(pjt.STALL_MONTHS + 1))),
            "release")

    def test_stopped_projects_are_left_alone(self):
        self.assertEqual(pjt.diagnose(self._project(status="停止")), "stopped")

    def test_new_releases_get_a_grace_period(self):
        self.assertEqual(
            pjt.diagnose(self._project(released=months_ago(1), revenues=[0])), "wait")

    def test_no_revenue_after_the_grace_period_needs_attention(self):
        self.assertEqual(
            pjt.diagnose(self._project(released=months_ago(pjt.GRACE_MONTHS + 1),
                                       revenues=[0, 0])), "fix")

    def test_no_revenue_after_a_long_time_is_a_retire_candidate(self):
        self.assertEqual(
            pjt.diagnose(self._project(released=months_ago(pjt.GIVEUP_MONTHS + 1),
                                       revenues=[0, 0])), "retire")

    def test_flat_revenue_is_kept(self):
        self.assertEqual(
            pjt.diagnose(self._project(released=months_ago(6),
                                       revenues=[1000, 1000, 1000, 1000])), "keep")

    def test_growing_revenue_is_expanded(self):
        self.assertEqual(
            pjt.diagnose(self._project(released=months_ago(6),
                                       revenues=[1000, 3000])), "expand")


class TestAllocation(PortfolioTestBase):
    def test_hours_are_split_across_projects(self):
        pjt.add("伸びている", status="運用", released=months_ago(6))
        pjt.record(1, month="2026-07", revenue=1000, hours=5)
        pjt.record(1, month="2026-08", revenue=3000, hours=5)
        pjt.add("開発中", status="開発中", started=months_ago(1))

        rows = pjt.allocate(10)
        self.assertAlmostEqual(sum(r["hours"] for r in rows), 10, delta=1)
        self.assertEqual(rows[0]["project"]["name"], "伸びている")
        self.assertGreater(rows[0]["hours"], rows[1]["hours"])

    def test_retire_candidates_get_no_time(self):
        pjt.add("死んでいる", status="運用", released=months_ago(pjt.GIVEUP_MONTHS + 2))
        pjt.record(1, month="2026-07", revenue=0, hours=5)
        pjt.record(1, month="2026-08", revenue=0, hours=5)
        pjt.add("生きている", status="運用", released=months_ago(6))
        pjt.record(2, month="2026-08", revenue=5000, hours=5)

        rows = {r["project"]["name"]: r["hours"] for r in pjt.allocate(10)}
        self.assertEqual(rows["死んでいる"], 0)
        self.assertGreater(rows["生きている"], 0)

    def test_empty_portfolio_is_handled(self):
        self.assertEqual(pjt.allocate(10), [])


class TestPortfolioTotals(PortfolioTestBase):
    def test_totals_aggregate_across_projects(self):
        month = store.today()[:7]
        pjt.add("A", status="運用", released=months_ago(6))
        pjt.record(1, month=month, revenue=3000, cost=500, hours=10)
        pjt.add("B", status="運用", released=months_ago(6))
        pjt.record(2, month=month, revenue=2000, cost=300, hours=5)

        t = pjt.totals()
        self.assertEqual(t["count"], 2)
        self.assertEqual(t["revenue"], 5000)
        self.assertEqual(t["this_month"], 5000)
        self.assertEqual(t["profit"], 4200)
        self.assertEqual(t["hourly"], 280)

    def test_totals_on_an_empty_portfolio(self):
        t = pjt.totals()
        self.assertEqual(t["count"], 0)
        self.assertEqual(t["hourly"], 0)


class TestServiceSync(PortfolioTestBase):
    def test_only_booked_jobs_count_as_revenue(self):
        from src.auto import jobs as jobs_mod
        from src.portfolio import dashboard

        month = store.today()[:7]
        run_at = f"{month}-15 10:00"
        store.save(jobs_mod.NAME, [
            {"id": 1, "service": "minutes", "title": "A", "price": 6000,
             "cost_jpy": 30.0, "run_at": run_at, "revenue_recorded": True,
             "status": "done"},
            {"id": 2, "service": "minutes", "title": "B", "price": 9000,
             "cost_jpy": 40.0, "run_at": run_at, "revenue_recorded": False,
             "status": "review"},
            {"id": 3, "service": "minutes", "title": "C", "price": 5000,
             "cost_jpy": 20.0, "run_at": "2020-01-01 10:00", "revenue_recorded": True,
             "status": "done"},
        ])
        pjt.add("受託", kind="service", status="運用")

        result = dashboard.sync_service_revenue(1)
        self.assertEqual(result["revenue"], 6000)      # 計上済みの1件のみ
        self.assertEqual(result["cost"], 70)           # 当月に走った2件ぶんの原価
        self.assertEqual(pjt.find(1)["records"][0]["revenue"], 6000)


if __name__ == "__main__":
    unittest.main()
