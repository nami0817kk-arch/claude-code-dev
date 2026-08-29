"""ダッシュボード画面のテスト。

生成物は手元で開くだけの静的 HTML なので、
「データが無くても壊れない」「入力が HTML に化けない」を中心に見る。

  python -m unittest discover -s tests
"""
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src import screen, store, tracker
from src.portfolio import projects as pjt


class ScreenTestBase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self._orig = store.DATA_DIR
        store.DATA_DIR = Path(self._tmp.name) / "data"

    def tearDown(self):
        store.DATA_DIR = self._orig
        self._tmp.cleanup()

    def seed(self):
        pjt.add("株式ランキング", kind="media", status="運用",
                started="2026-01-10", released="2026-02-15")
        for month, rev in (("2026-06", 2800), ("2026-07", 3600), ("2026-08", 5200)):
            pjt.record(1, month=month, revenue=rev, cost=1500, hours=10)


class TestHelpers(unittest.TestCase):
    def test_month_range_fills_the_gaps(self):
        self.assertEqual(screen.month_range(["2026-11", "2027-02"]),
                         ["2026-11", "2026-12", "2027-01", "2027-02"])

    def test_month_range_handles_a_single_month_and_empty(self):
        self.assertEqual(screen.month_range(["2026-08"]), ["2026-08"])
        self.assertEqual(screen.month_range([]), [])

    def test_nice_ceiling_never_undershoots(self):
        for value in (1, 400, 23_200, 52_500, 99_999, 1_234_567):
            self.assertGreaterEqual(screen.nice_ceiling(value), value)

    def test_nice_ceiling_stays_close_to_the_value(self):
        """軸の上限が実データより極端に高くならないこと。"""
        for value in (23_200, 52_500, 7_800, 310_000):
            self.assertLess(screen.nice_ceiling(value), value * 1.6)

    def test_nice_ceiling_handles_zero(self):
        self.assertEqual(screen.nice_ceiling(0), 1000)

    def test_rounded_top_is_a_closed_path(self):
        d = screen.rounded_top(10, 20, 24, 40)
        self.assertTrue(d.startswith("M"))
        self.assertTrue(d.endswith("Z"))

    def test_rounded_top_survives_a_tiny_bar(self):
        """高さ1pxの棒でも角丸半径が高さを超えないこと。"""
        self.assertIn("Z", screen.rounded_top(0, 0, 24, 1))

    def test_meter_clamps_out_of_range_values(self):
        self.assertIn("width:100%", screen.meter(250))
        self.assertIn("width:0%", screen.meter(-30))

    def test_sparkline_needs_two_points(self):
        self.assertIn("—", screen.sparkline([100], 1))
        self.assertIn("<svg", screen.sparkline([100, 200], 1))

    def test_sparkline_survives_all_zero_values(self):
        self.assertIn("<svg", screen.sparkline([0, 0, 0], 1))


class TestEscaping(ScreenTestBase):
    def test_project_names_are_escaped(self):
        """プロジェクト名は自由入力なので、HTML として解釈させない。"""
        pjt.add("<script>alert(1)</script>", kind="app", status="運用",
                released="2026-01-01")
        pjt.record(1, month="2026-08", revenue=100, hours=1)
        page = screen.render(screen.collect())

        self.assertNotIn("<script>alert(1)</script>", page)
        self.assertIn("&lt;script&gt;", page)

    def test_task_titles_are_escaped(self):
        title = 'タスク "危険" & <b>危ない</b>'
        tracker.add_task(title, due="2000-01-01")
        page = screen.render(screen.collect())

        self.assertNotIn(title, page)                  # 生のままでは出ない
        self.assertNotIn("<b>危ない</b>", page)          # タグとして解釈されない
        self.assertIn("&lt;b&gt;危ない&lt;/b&gt;", page)
        self.assertIn("&quot;危険&quot;", page)

    def test_tooltip_text_is_escaped(self):
        pjt.add('A"><img src=x>', kind="app", status="運用", released="2026-01-01")
        pjt.record(1, month="2026-08", revenue=500, hours=1)
        page = screen.render(screen.collect())
        self.assertNotIn('<img src=x>', page)


class TestRendering(ScreenTestBase):
    def test_renders_with_no_data_at_all(self):
        page = screen.render(screen.collect())
        self.assertIn("<!doctype html>", page)
        self.assertIn("収益ダッシュボード", page)
        self.assertIn("プロジェクトが未登録です", page)

    def test_renders_with_data(self):
        self.seed()
        page = screen.render(screen.collect())
        self.assertIn("株式ランキング", page)
        self.assertIn("月次の収益推移", page)
        self.assertIn("<svg", page)

    def test_page_is_self_contained(self):
        """オフラインで開けるよう、外部リソースを参照しないこと。"""
        self.seed()
        page = screen.render(screen.collect())
        for marker in ("http://", "https://", "<link", "src=\"//"):
            self.assertNotIn(marker, page, f"外部参照が含まれている: {marker}")

    def test_both_themes_are_defined(self):
        page = screen.render(screen.collect())
        self.assertIn("prefers-color-scheme: dark", page)
        self.assertIn(':root[data-theme="dark"]', page)

    def test_legend_appears_for_multiple_series(self):
        self.seed()
        pjt.add("議事録代行", kind="service", status="運用", released="2026-01-01")
        pjt.record(2, month="2026-08", revenue=18000, hours=7)
        page = screen.render(screen.collect())
        self.assertIn('class="legend"', page)
        self.assertIn("議事録代行", page)

    def test_falls_back_to_revenue_records_without_projects(self):
        """プロジェクト未登録でも、受託の売上記録があれば推移を出す。"""
        tracker.add_revenue(5000, "議事録", date="2026-07-10")
        tracker.add_revenue(8000, "議事録", date="2026-08-10")
        data = screen.collect()
        self.assertEqual(len(data["rows"]), 1)
        self.assertEqual(data["months"], ["2026-07", "2026-08"])
        self.assertIn("受託（売上記録）", screen.render(data))

    def test_build_writes_the_file(self):
        self.seed()
        out = Path(self._tmp.name) / "out.html"
        path = screen.build(out)
        self.assertTrue(path.exists())
        self.assertIn("収益ダッシュボード", path.read_text(encoding="utf-8"))

    def test_bar_heights_stay_inside_the_plot(self):
        """棒が描画領域からはみ出さないこと。"""
        self.seed()
        svg = screen.stacked_chart(screen.collect())
        ys = [float(m) for m in re.findall(r'M[\d.]+,([\d.]+)', svg)]
        self.assertTrue(ys)
        self.assertTrue(all(0 <= y <= 300 for y in ys), f"範囲外の座標: {ys}")


class TestSummaries(ScreenTestBase):
    def test_task_summary_lists_overdue_first(self):
        tracker.add_task("遅れている", due="2000-01-01")
        tracker.add_task("これから", due="2099-01-01")
        s = screen.task_summary()
        self.assertEqual(len(s["overdue"]), 1)
        self.assertEqual(s["overdue"][0]["title"], "遅れている")

    def test_summaries_handle_empty_state(self):
        self.assertEqual(screen.task_summary()["total"], 0)
        self.assertEqual(screen.job_summary()["total"], 0)
        self.assertEqual(screen.article_summary()["total"], 0)

    def test_collect_reports_the_previous_month(self):
        pjt.add("A", kind="media", status="運用", released="2026-01-01")
        pjt.record(1, month="2026-07", revenue=1000, hours=1)
        pjt.record(1, month=store.today()[:7], revenue=3000, hours=1)
        self.assertEqual(screen.collect()["previous_month_revenue"], 1000)


if __name__ == "__main__":
    unittest.main()
