"""ストック型メディア（アフィリエイト・広告収入）のテスト。

収益モデルの計算式が正しいことと、実測に基づく判定が意図どおり動くことを見る。

  python -m unittest discover -s tests
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src import llm, store
from src.media import analytics, articles, genre, keywords, model


class FakeUsage:
    input_tokens = 5000
    output_tokens = 6000
    cache_read_input_tokens = 0
    cache_creation_input_tokens = 0


ARTICLE = ("# タイトル\n※本記事はプロモーションを含みます\n\n"
           + "本文の詳細な解説。" * 400 + "\n## まとめ\n以上です。")


class MediaTestBase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        tmp = Path(self._tmp.name)
        self._orig = (store.DATA_DIR, articles.ARTICLE_DIR, llm.ask, llm.ask_json)
        store.DATA_DIR = tmp / "data"
        articles.ARTICLE_DIR = tmp / "articles"

    def tearDown(self):
        store.DATA_DIR, articles.ARTICLE_DIR, llm.ask, llm.ask_json = self._orig
        self._tmp.cleanup()

    def mock_llm(self, output=ARTICLE, verdict="合格", score=85):
        def ask(prompt, system="", **kwargs):
            if llm._meter is not None:
                llm._meter.add(FakeUsage(), model="claude-opus-5")
            return output

        def ask_json(prompt, system="", **kwargs):
            if llm._meter is not None:
                llm._meter.add(FakeUsage(), model="claude-opus-5")
            return {"score": score, "issues": [], "verdict": verdict, "comment": ""}

        llm.ask, llm.ask_json = ask, ask_json


class TestRevenueModel(unittest.TestCase):
    def setUp(self):
        self.p = dict(model.DEFAULTS)

    def test_ctr_decreases_with_rank(self):
        ranks = [1, 2, 3, 5, 8, 10]
        ctrs = [model.ctr(r) for r in ranks]
        self.assertEqual(ctrs, sorted(ctrs, reverse=True))

    def test_below_first_page_is_nearly_zero(self):
        self.assertLess(model.ctr(15), model.ctr(10))
        self.assertEqual(model.ctr(11), model.ctr(50))
        self.assertEqual(model.ctr(0), 0.0)

    def test_pv_is_volume_times_ctr(self):
        self.assertAlmostEqual(model.pv_from_volume(1000, 1), 280.0)
        self.assertAlmostEqual(model.pv_from_volume(1000, 8), 30.0)

    def test_affiliate_revenue_formula(self):
        # 10000PV × 5% × 2% × 75% = 7.5件 × 3000円 = 22,500円
        self.assertAlmostEqual(model.affiliate_revenue(10000, self.p), 22500.0)

    def test_ad_revenue_formula(self):
        # 10000PV ÷ 1000 × 300円 = 3,000円
        self.assertAlmostEqual(model.ad_revenue(10000, self.p), 3000.0)

    def test_both_model_is_the_sum(self):
        self.assertAlmostEqual(
            model.revenue(10000, "both", self.p),
            model.revenue(10000, "affiliate", self.p) + model.revenue(10000, "ad", self.p))

    def test_required_pv_inverts_the_revenue_formula(self):
        pv = model.required_pv(50000, "both", self.p)
        self.assertAlmostEqual(model.revenue(pv, "both", self.p), 50000, places=0)

    def test_higher_unit_price_needs_less_traffic(self):
        cheap = model.required_pv(50000, "affiliate", dict(self.p, unit_price=1000))
        rich = model.required_pv(50000, "affiliate", dict(self.p, unit_price=30000))
        self.assertGreater(cheap, rich * 10)

    def test_params_round_trip(self):
        tmp = tempfile.TemporaryDirectory()
        original = store.DATA_DIR
        store.DATA_DIR = Path(tmp.name)
        try:
            model.save_params(dict(model.DEFAULTS, cvr=0.05))
            self.assertEqual(model.load_params()["cvr"], 0.05)
            # 保存されていない項目は既定値で埋まる
            self.assertEqual(model.load_params()["rpm"], model.DEFAULTS["rpm"])
        finally:
            store.DATA_DIR = original
            tmp.cleanup()


class TestPlan(unittest.TestCase):
    def setUp(self):
        self.p = dict(model.DEFAULTS)

    def test_plan_is_internally_consistent(self):
        pl = model.plan(50000, avg_volume=1000, articles_per_month=8, p=self.p)
        self.assertAlmostEqual(
            pl["required_articles"] * pl["pv_per_article"], pl["required_pv"],
            delta=pl["pv_per_article"])

    def test_better_rank_needs_fewer_articles(self):
        pl = model.plan(50000, p=self.p)
        by_rank = {r["rank"]: r["articles"] for r in pl["by_rank"]}
        self.assertLess(by_rank[3], by_rank[5])
        self.assertLess(by_rank[5], by_rank[8])
        self.assertLess(by_rank[8], by_rank[10])

    def test_higher_price_needs_fewer_articles(self):
        pl = model.plan(50000, p=self.p)
        counts = [r["articles"] for r in pl["by_price"]]
        self.assertEqual(counts, sorted(counts, reverse=True))

    def test_seo_lag_is_added_to_the_timeline(self):
        pl = model.plan(50000, articles_per_month=8, p=self.p)
        self.assertEqual(pl["months_to_target"],
                         pl["months_to_write"] + self.p["seo_lag_months"])

    def test_ad_only_model_has_no_price_sensitivity(self):
        self.assertEqual(model.plan(50000, model="ad", p=self.p)["by_price"], [])


class TestSimulation(unittest.TestCase):
    def setUp(self):
        self.p = dict(model.DEFAULTS)

    def test_first_month_earns_nothing(self):
        sim = model.simulate(12, 8, 1000, p=self.p)
        self.assertEqual(sim["rows"][0]["revenue"], 0)

    def test_revenue_grows_month_over_month(self):
        sim = model.simulate(12, 8, 1000, p=self.p)
        revenues = [r["revenue"] for r in sim["rows"]]
        self.assertEqual(revenues, sorted(revenues))
        self.assertGreater(revenues[-1], 0)

    def test_cumulative_starts_negative(self):
        sim = model.simulate(12, 8, 1000, article_cost=45, p=self.p)
        self.assertLess(sim["rows"][0]["cumulative"], 0)
        self.assertLessEqual(sim["max_drawdown"], 0)

    def test_longer_lag_delays_revenue(self):
        fast = model.simulate(12, 8, 1000, p=dict(self.p, seo_lag_months=2))
        slow = model.simulate(12, 8, 1000, p=dict(self.p, seo_lag_months=8))
        self.assertGreater(fast["final_revenue"], slow["final_revenue"])

    def test_breakeven_is_the_first_positive_cumulative_month(self):
        sim = model.simulate(36, 8, 1000, article_cost=45, p=self.p)
        if sim["breakeven_month"]:
            rows = {r["month"]: r["cumulative"] for r in sim["rows"]}
            self.assertGreater(rows[sim["breakeven_month"]], 0)
            self.assertLessEqual(rows[sim["breakeven_month"] - 1], 0)

    def test_unreachable_target_reports_none(self):
        sim = model.simulate(6, 1, 100, target=1_000_000, p=self.p)
        self.assertIsNone(sim["target_month"])

    def test_article_count_accumulates(self):
        sim = model.simulate(5, 10, 1000, p=self.p)
        self.assertEqual(sim["total_articles"], 50)


class TestKeywords(unittest.TestCase):
    def setUp(self):
        self.p = dict(model.DEFAULTS)

    def _kw(self, **over):
        base = {"keyword": "テスト", "intent": "Know", "volume_hint": "中",
                "difficulty": 3, "profitability": 3, "article_type": "解説",
                "title": "タイトル", "reason": "理由", "role": "集客記事"}
        base.update(over)
        return base

    def test_difficulty_maps_to_an_achievable_rank(self):
        self.assertEqual(keywords.expected(self._kw(difficulty=1), self.p)["rank"], 3)
        self.assertEqual(keywords.expected(self._kw(difficulty=5), self.p)["rank"], 15)

    def test_easier_keywords_earn_more_at_the_same_volume(self):
        easy = keywords.expected(self._kw(difficulty=1), self.p)["revenue"]
        hard = keywords.expected(self._kw(difficulty=5), self.p)["revenue"]
        self.assertGreater(easy, hard)

    def test_profitability_scales_the_affiliate_share(self):
        low = keywords.expected(self._kw(profitability=1), self.p)["revenue"]
        high = keywords.expected(self._kw(profitability=5), self.p)["revenue"]
        self.assertGreater(high, low)

    def test_real_volume_is_flagged_as_not_estimated(self):
        self.assertTrue(keywords.expected(self._kw(), self.p)["estimated"])
        self.assertFalse(keywords.expected(self._kw(volume=800), self.p)["estimated"])
        self.assertEqual(keywords.expected(self._kw(volume=800), self.p)["volume"], 800)

    def test_score_all_sorts_by_expected_revenue_and_numbers_them(self):
        scored = keywords.score_all([
            self._kw(keyword="弱い", difficulty=5, profitability=1),
            self._kw(keyword="強い", difficulty=1, profitability=5),
        ])
        self.assertEqual(scored[0]["keyword"], "強い")
        self.assertEqual([k["id"] for k in scored], [1, 2])

    def test_totals_counts_money_articles_and_estimates(self):
        scored = keywords.score_all([
            self._kw(role="収益記事"), self._kw(role="集客記事", volume=500),
        ])
        t = keywords.totals(scored)
        self.assertEqual(t["count"], 2)
        self.assertEqual(t["money"], 1)
        self.assertEqual(t["estimated"], 1)


class TestVolumeImport(MediaTestBase):
    def _write_csv(self, rows: str) -> str:
        path = Path(self._tmp.name) / "volumes.csv"
        path.write_text(rows, encoding="utf-8")
        return str(path)

    def test_import_matches_keywords_and_rescores(self):
        store.save(keywords.NAME, {"theme": "テスト", "keywords": keywords.score_all([
            {"keyword": "在庫管理 ツール", "difficulty": 3, "profitability": 5,
             "volume_hint": "中", "role": "収益記事"},
            {"keyword": "在庫管理 エクセル", "difficulty": 2, "profitability": 3,
             "volume_hint": "中", "role": "集客記事"},
        ])})

        csv_path = self._write_csv(
            "キーワード,月間検索数\n在庫管理 ツール,\"2,400\"\n在庫管理 エクセル,880\n無関係,100\n")
        result = keywords.import_volumes(csv_path)

        self.assertEqual(result["matched"], 2)
        self.assertEqual(result["total"], 2)
        loaded = {k["keyword"]: k for k in keywords.load()}
        self.assertEqual(loaded["在庫管理 ツール"]["volume"], 2400)     # カンマを除去
        self.assertFalse(loaded["在庫管理 ツール"]["expected"]["estimated"])

    def test_header_rows_are_skipped(self):
        store.save(keywords.NAME, {"keywords": keywords.score_all(
            [{"keyword": "テスト", "difficulty": 3, "profitability": 3,
              "volume_hint": "中", "role": "集客記事"}])})
        result = keywords.import_volumes(self._write_csv("keyword,volume\nテスト,500\n"))
        self.assertEqual(result["read"], 1)      # ヘッダー行は数値が無いので読まない
        self.assertEqual(result["matched"], 1)

    def test_missing_file_raises(self):
        with self.assertRaises(FileNotFoundError):
            keywords.import_volumes("/存在しない/volumes.csv")


class TestGenre(unittest.TestCase):
    def _genre(self, **over):
        base = {"genre": "テスト", "price_band": "中", "competition": 3,
                "monetization": "両方", "ymyl": False}
        base.update(over)
        return base

    def test_higher_price_band_needs_fewer_articles(self):
        cheap = genre.evaluate(self._genre(price_band="低"), 50000)
        rich = genre.evaluate(self._genre(price_band="特に高い"), 50000)
        self.assertGreater(cheap["required_articles"], rich["required_articles"])

    def test_stronger_competition_needs_more_articles(self):
        weak = genre.evaluate(self._genre(competition=1), 50000)
        strong = genre.evaluate(self._genre(competition=5), 50000)
        self.assertGreater(strong["required_articles"], weak["required_articles"])
        self.assertLess(weak["assumed_rank"], strong["assumed_rank"])

    def test_ad_only_genre_ignores_the_price_band(self):
        low = genre.evaluate(self._genre(price_band="低", monetization="広告主体"), 50000)
        high = genre.evaluate(self._genre(price_band="特に高い", monetization="広告主体"), 50000)
        self.assertEqual(low["required_articles"], high["required_articles"])

    def test_ranking_puts_the_fastest_genre_first(self):
        ranked = genre.rank_genres([
            self._genre(genre="遠い", price_band="低", competition=5),
            self._genre(genre="近い", price_band="特に高い", competition=1),
        ], target=50000)
        self.assertEqual(ranked[0]["genre"], "近い")
        self.assertEqual([g["id"] for g in ranked], [1, 2])

    def test_timeline_includes_the_seo_lag(self):
        e = genre.evaluate(self._genre(), 50000, articles_per_month=8)
        self.assertGreaterEqual(e["months_to_target"], model.DEFAULTS["seo_lag_months"])


class TestArticleService(unittest.TestCase):
    def test_money_articles_require_a_disclosure(self):
        money = articles.build_service({"id": 1, "keyword": "k", "role": "収益記事",
                                        "article_type": "比較"})
        info = articles.build_service({"id": 2, "keyword": "k", "role": "集客記事",
                                       "article_type": "解説"})
        self.assertTrue(money.disclosure_required)
        self.assertFalse(info.disclosure_required)

    def test_template_survives_formatting(self):
        """内部リンク付きのテンプレートが format で壊れないこと。"""
        service = articles.build_service(
            {"id": 1, "keyword": "k", "role": "集客記事", "article_type": "比較"},
            related=[{"keyword": "関連", "title": "関連記事"}])
        rendered = service.template.format(input="キーワード", options="")
        self.assertIn("キーワード", rendered)
        self.assertIn("関連", rendered)

    def test_comparison_articles_have_a_higher_bar(self):
        compare = articles.build_service({"id": 1, "keyword": "k", "role": "集客記事",
                                          "article_type": "比較"})
        explain = articles.build_service({"id": 2, "keyword": "k", "role": "集客記事",
                                          "article_type": "解説"})
        self.assertGreater(compare.min_chars, explain.min_chars)

    def test_unknown_article_type_falls_back(self):
        service = articles.build_service({"id": 1, "keyword": "k", "role": "集客記事",
                                          "article_type": "存在しない型"})
        self.assertIn("まとめ", service.template)


class TestArticleWriting(MediaTestBase):
    def _seed(self):
        store.save(keywords.NAME, {"theme": "テスト", "keywords": keywords.score_all([
            {"keyword": "在庫管理 ツール", "difficulty": 3, "profitability": 5,
             "volume_hint": "中", "role": "収益記事", "article_type": "比較",
             "title": "おすすめ7選", "intent": "Buy", "reason": "検討層"},
            {"keyword": "在庫管理 エクセル", "difficulty": 2, "profitability": 3,
             "volume_hint": "中", "role": "集客記事", "article_type": "解説",
             "title": "Excelの限界", "intent": "Know", "reason": "課題層"},
        ])})

    def _money_keyword(self) -> dict:
        """収益記事のキーワードを役割で引く（並び順は期待収益で決まるため）。"""
        return next(k for k in keywords.load() if k["role"] == "収益記事")

    def test_write_saves_the_file_and_the_record(self):
        self._seed()
        self.mock_llm()
        record = articles.write(self._money_keyword(), verbose=False)

        self.assertTrue(Path(record["path"]).exists())
        self.assertGreater(record["cost_jpy"], 0)
        self.assertFalse(record["needs_human"])
        self.assertEqual(articles.find(record["keyword_id"])["keyword"],
                         record["keyword"])

    def test_missing_disclosure_is_escalated(self):
        self._seed()
        # 十分な長さがあり必須項目も揃っているが、広告表記だけが無い記事
        self.mock_llm(output="# タイトル\n" + "本文。" * 1200 + "\n## まとめ\n以上")
        record = articles.write(self._money_keyword(), verbose=False)
        self.assertTrue(record["needs_human"], "収益記事に広告表記が無くても通ってしまう")

        # 同じ本文に広告表記を足せば通る
        self.mock_llm(output="# タイトル\n※本記事はプロモーションを含みます\n"
                             + "本文。" * 1200 + "\n## まとめ\n以上")
        record = articles.write(self._money_keyword(), verbose=False)
        self.assertFalse(record["needs_human"])

    def test_batch_skips_already_written_articles(self):
        self._seed()
        self.mock_llm()
        first = articles.write_batch(verbose=False)
        self.assertEqual(len(first), 2)
        self.assertEqual(articles.write_batch(verbose=False), [])

    def test_batch_respects_the_limit(self):
        self._seed()
        self.mock_llm()
        self.assertEqual(len(articles.write_batch(limit=1, verbose=False)), 1)
        self.assertEqual(len(articles.load()), 1)

    def test_rewriting_replaces_the_record(self):
        self._seed()
        self.mock_llm()
        kw = self._money_keyword()
        articles.write(kw, verbose=False)
        articles.write(kw, verbose=False)
        self.assertEqual(len(articles.load()), 1)


class TestAnalytics(MediaTestBase):
    def _article(self, **over):
        base = {"keyword_id": 1, "keyword": "テスト", "role": "集客記事",
                "published_at": "2025-01-01", "pv": 0, "revenue": 0, "rank": 0,
                "cost_jpy": 50.0}
        base.update(over)
        return base

    def test_diagnosis_covers_the_four_states(self):
        self.assertEqual(analytics.diagnose(self._article(pv=500, revenue=3000)), "expand")
        self.assertEqual(analytics.diagnose(self._article(pv=500, revenue=0)), "monetize")
        self.assertEqual(analytics.diagnose(self._article(pv=20, rank=12)), "rewrite")
        self.assertEqual(analytics.diagnose(self._article(pv=20, rank=2)), "retire")

    def test_unpublished_and_new_articles_are_left_alone(self):
        self.assertEqual(analytics.diagnose(self._article(published_at="")), "wait")
        self.assertEqual(
            analytics.diagnose(self._article(published_at=store.today(), pv=5)), "wait")

    def test_upside_uses_measured_pv_to_infer_volume(self):
        # 9位で420PV → 実質検索数は 420 / 0.025 = 16,800
        gain = analytics.upside(self._article(pv=420, rank=9), target_rank=3)
        expected_pv = 420 / model.ctr(9) * (model.ctr(3) - model.ctr(9))
        self.assertEqual(gain, round(expected_pv * model.revenue_per_pv("both")))

    def test_no_upside_when_already_ranking_well(self):
        self.assertEqual(analytics.upside(self._article(pv=500, rank=2)), 0)
        self.assertEqual(analytics.upside(self._article(pv=500, rank=0)), 0)

    def test_rewrite_queue_is_ordered_by_upside(self):
        store.save(articles.NAME, [
            self._article(keyword_id=1, keyword="小", pv=50, rank=9),
            self._article(keyword_id=2, keyword="大", pv=400, rank=9),
        ])
        queue = analytics.rewrite_queue()
        self.assertEqual([a["keyword"] for a in queue], ["大", "小"])

    def test_healthy_articles_stay_out_of_the_queue(self):
        store.save(articles.NAME, [self._article(pv=500, revenue=3000)])
        self.assertEqual(analytics.rewrite_queue(), [])

    def test_record_updates_only_given_fields(self):
        store.save(articles.NAME, [self._article(pv=100, rank=5, revenue=200)])
        updated = analytics.record(1, pv=300)
        self.assertEqual(updated["pv"], 300)
        self.assertEqual(updated["rank"], 5)        # 触っていない値は保持
        self.assertEqual(updated["revenue"], 200)
        self.assertIsNone(analytics.record(99, pv=1))

    def test_totals_and_calibration(self):
        store.save(articles.NAME, [
            self._article(keyword_id=1, pv=1000, revenue=500, rank=6),
            self._article(keyword_id=2, pv=1000, revenue=500, rank=10),
        ])
        t = analytics.totals()
        self.assertEqual(t["pv"], 2000)
        self.assertEqual(t["revenue"], 1000)
        self.assertEqual(t["rpv"], 0.5)
        self.assertEqual(t["profit"], 1000 - 100.0)

        c = analytics.calibrate()
        self.assertEqual(c["measured_rpv"], 0.5)
        self.assertEqual(c["avg_rank"], 8.0)
        self.assertLess(c["ratio"], 1)          # 想定より実測が悪い

    def test_calibration_handles_no_data(self):
        c = analytics.calibrate()
        self.assertEqual(c["pv"], 0)
        self.assertIsNone(c["ratio"])
        self.assertIsNone(c["avg_rank"])


if __name__ == "__main__":
    unittest.main()
