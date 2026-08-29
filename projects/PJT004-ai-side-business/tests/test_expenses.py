"""経費の記録と、投資フェーズの表示のテスト。

収益ゼロの期間こそ正しく映る必要があるので、そこを重点的に見る。

  python -m unittest discover -s tests
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src import expenses, screen, store
from src.portfolio import projects as pjt


class ExpenseTestBase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self._orig = store.DATA_DIR
        store.DATA_DIR = Path(self._tmp.name) / "data"

    def tearDown(self):
        store.DATA_DIR = self._orig
        self._tmp.cleanup()


class TestExpenses(ExpenseTestBase):
    def test_add_and_total(self):
        expenses.add(3000, "Claude利用料", month="2026-05")
        expenses.add(1500, "サーバー", category="infra", month="2026-05")
        self.assertEqual(expenses.total(), 4500)

    def test_same_item_in_the_same_month_is_overwritten(self):
        expenses.add(3000, "Claude利用料", month="2026-05")
        expenses.add(4000, "Claude利用料", month="2026-05")
        self.assertEqual(len(expenses.load()), 1)
        self.assertEqual(expenses.total(), 4000)

    def test_same_item_in_different_months_accumulates(self):
        expenses.add(3000, "Claude利用料", month="2026-05")
        expenses.add(3000, "Claude利用料", month="2026-06")
        self.assertEqual(len(expenses.load()), 2)
        self.assertEqual(expenses.total(), 6000)

    def test_next_month_rolls_over_the_year(self):
        self.assertEqual(expenses.next_month("2026-12"), "2027-01")
        self.assertEqual(expenses.next_month("2026-01"), "2026-02")

    def test_monthly_fills_every_month_in_the_range(self):
        added = expenses.add_monthly(3000, "Claude利用料",
                                     start="2026-11", end="2027-02")
        self.assertEqual([r["month"] for r in added],
                         ["2026-11", "2026-12", "2027-01", "2027-02"])
        self.assertEqual(expenses.total(), 12000)

    def test_monthly_handles_reversed_dates(self):
        added = expenses.add_monthly(1000, "X", start="2026-06", end="2026-04")
        self.assertEqual(len(added), 3)

    def test_by_item_reports_the_monthly_average(self):
        expenses.add_monthly(3000, "Claude利用料", start="2026-05", end="2026-08")
        expenses.add(1200, "ドメイン", category="infra", month="2026-05")
        items = expenses.by_item()

        self.assertEqual(items["Claude利用料"]["total"], 12000)
        self.assertEqual(items["Claude利用料"]["monthly"], 3000)
        self.assertEqual(items["Claude利用料"]["months"], 4)
        self.assertEqual(list(items)[0], "Claude利用料")   # 金額の大きい順

    def test_run_rate_uses_the_latest_month(self):
        expenses.add(3000, "A", month="2026-05")
        expenses.add(5000, "A", month="2026-06")
        self.assertEqual(expenses.monthly_run_rate(), 5000)
        self.assertEqual(expenses.months_elapsed(), 2)

    def test_remove(self):
        rec = expenses.add(3000, "A", month="2026-05")
        self.assertTrue(expenses.remove(rec["id"]))
        self.assertFalse(expenses.remove(rec["id"]))
        self.assertEqual(expenses.total(), 0)

    def test_empty_state(self):
        self.assertEqual(expenses.total(), 0)
        self.assertEqual(expenses.monthly_run_rate(), 0)
        self.assertEqual(expenses.by_item(), {})


class TestInvestmentPhase(ExpenseTestBase):
    def seed_costs_only(self):
        """収益ゼロ・支出だけの状態。立ち上げ期の実態。"""
        expenses.add_monthly(3000, "Claude利用料", start="2026-05", end="2026-08")
        pjt.add("サッカーゲームアプリ", kind="app", status="開発中", started="2026-05-01")
        pjt.add("株式ランキング", kind="media", status="開発中", started="2026-06-01")

    def test_phase_is_investment_without_revenue(self):
        self.seed_costs_only()
        d = screen.collect()
        self.assertEqual(d["phase"], "investment")
        self.assertEqual(d["revenue_total"], 0)
        self.assertEqual(d["investment"], 12000)
        self.assertEqual(d["net"], -12000)
        self.assertEqual(d["run_rate"], 3000)

    def test_phase_switches_once_revenue_appears(self):
        self.seed_costs_only()
        pjt.record(2, month="2026-08", revenue=500)
        self.assertEqual(screen.collect()["phase"], "growth")

    def test_flow_accumulates_the_deficit(self):
        self.seed_costs_only()
        flow = screen.collect()["flow"]
        self.assertEqual([f["cumulative"] for f in flow],
                         [-3000, -6000, -9000, -12000])
        self.assertTrue(all(f["income"] == 0 for f in flow))

    def test_flow_includes_project_costs(self):
        expenses.add(3000, "Claude利用料", month="2026-08")
        pjt.add("A", kind="media", status="運用", released="2026-01-01")
        pjt.record(1, month="2026-08", revenue=0, cost=500)

        d = screen.collect()
        self.assertEqual(d["investment"], 3500)
        self.assertEqual(d["flow"][-1]["spend"], 3500)

    def test_months_include_expense_only_months(self):
        """収益の記録が無い月も、支出があれば推移に出す。"""
        expenses.add_monthly(3000, "A", start="2026-05", end="2026-08")
        self.assertEqual(screen.collect()["months"],
                         ["2026-05", "2026-06", "2026-07", "2026-08"])

    def test_investment_hero_shows_the_deficit_not_a_goal_rate(self):
        self.seed_costs_only()
        page = screen.render(screen.collect())
        self.assertIn("まだ回収していない額", page)
        self.assertIn("−12,000", page)
        self.assertIn("収益はまだ発生していません", page)
        self.assertNotIn("前月比", page)

    def test_investment_page_shows_the_first_yen_panel(self):
        self.seed_costs_only()
        page = screen.render(screen.collect())
        self.assertIn("最初の1円までの距離", page)
        self.assertIn("公開しないかぎり収益は1円も発生しません", page)
        self.assertIn("DAU", page)          # アプリの参考値
        self.assertIn("記事", page)          # メディアの参考値

    def test_growth_page_hides_the_first_yen_panel(self):
        self.seed_costs_only()
        pjt.record(2, month="2026-08", revenue=5000)
        page = screen.render(screen.collect())
        self.assertNotIn("最初の1円までの距離", page)

    def test_expense_table_appears(self):
        self.seed_costs_only()
        page = screen.render(screen.collect())
        self.assertIn("Claude利用料", page)
        self.assertIn("回収しなければならない額", page)

    def test_no_expenses_prompts_registration(self):
        page = screen.render(screen.collect())
        self.assertIn("経費が未登録です", page)

    def test_chart_renders_with_expenses_only(self):
        """収益ゼロでもグラフが描けること（支出と累積線だけになる）。"""
        self.seed_costs_only()
        svg = screen.flow_chart(screen.collect())
        self.assertIn("<svg", svg)
        self.assertIn("累積", svg)
        self.assertIn("支出", svg)

    def test_recovery_rate_is_shown_once_revenue_exists(self):
        expenses.add(1000, "A", month="2026-08")
        pjt.add("B", kind="media", status="運用", released="2026-01-01")
        pjt.record(1, month=store.today()[:7], revenue=3000)
        page = screen.render(screen.collect())
        self.assertIn("の回収", page)


class TestNiceStep(unittest.TestCase):
    def test_step_divides_the_span_sensibly(self):
        for span in (1000, 12000, 45000, 250000):
            step = screen.nice_step(span)
            self.assertGreater(step, 0)
            self.assertLessEqual(span / step, 12)      # 目盛りが多すぎない
            self.assertGreaterEqual(span / step, 2)    # 少なすぎない

    def test_zero_span_has_a_fallback(self):
        self.assertEqual(screen.nice_step(0), 1000)

    def test_rounded_bottom_is_a_closed_path(self):
        d = screen.rounded_bottom(0, 100, 24, 40)
        self.assertTrue(d.startswith("M"))
        self.assertTrue(d.endswith("Z"))


if __name__ == "__main__":
    unittest.main()


class TestBillingMode(ExpenseTestBase):
    """定額制と従量課金で、原価の考え方が変わることを確かめる。"""

    def test_default_is_subscription(self):
        from src import profile as profile_mod
        self.assertTrue(profile_mod.is_subscription(profile_mod.load()))

    def test_monthly_fee_is_zero_when_metered(self):
        from src import profile as profile_mod
        metered = dict(profile_mod.DEFAULTS, cost_mode="従量", monthly_fee=3000)
        self.assertFalse(profile_mod.is_subscription(metered))
        self.assertEqual(profile_mod.monthly_fee(metered), 0)

    def test_units_to_cover_the_monthly_fee(self):
        from src.auto import cost
        self.assertEqual(cost.units_to_cover(3000, 3000), 1)
        self.assertEqual(cost.units_to_cover(3000, 2000), 2)   # 端数は切り上げ
        self.assertEqual(cost.units_to_cover(3000, 0), 0)
        self.assertEqual(cost.units_to_cover(0, 5000), 0)

    def test_dashboard_notes_that_volume_is_free(self):
        from src import profile as profile_mod, screen

        profile_mod.save(dict(profile_mod.DEFAULTS, cost_mode="定額", monthly_fee=3000))
        expenses.add(3000, "Claude利用料", month="2026-08")
        page = screen.render(screen.collect())
        self.assertIn("作る量を増やしても支出は増えません", page)

    def test_metered_mode_omits_that_note(self):
        from src import profile as profile_mod, screen

        profile_mod.save(dict(profile_mod.DEFAULTS, cost_mode="従量"))
        expenses.add(3000, "API利用料", month="2026-08")
        page = screen.render(screen.collect())
        self.assertNotIn("作る量を増やしても支出は増えません", page)

    def test_empty_expense_prompt_uses_the_known_fee(self):
        from src import profile as profile_mod, screen

        profile_mod.save(dict(profile_mod.DEFAULTS, cost_mode="定額", monthly_fee=4500))
        page = screen.render(screen.collect())
        self.assertIn("expense add 4500", page)
