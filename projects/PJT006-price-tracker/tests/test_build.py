import json
import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

import build as builder  # noqa: E402
from src import store, theme  # noqa: E402

CONFIG = {
    "name": "テストサイト", "base_url": "https://example.test/price",
    "description": "テスト", "owner": "テスト運営", "contact_email": "test@example.test",
    "genres": [{"genre_id": "1"}], "hits_per_genre": 30,
    "drop_threshold": 0.05, "near_low_threshold": 0.02, "history_tail_days": 90,
}


def make_data(tmp: Path, items: dict, series: dict):
    """series: {item_code: [価格を古い順に]} から履歴を組み立てる。"""
    summary = {}
    days = max(len(v) for v in series.values())
    for i in range(days):
        day = f"2026-07-{i + 1:02d}"
        rows = [{"item_code": c, "price": p[i], "review_count": 0, "review_average": 0.0}
                for c, p in series.items() if i < len(p)]
        summary = store.update_summary(summary, rows, day, 90)
    store.save_json(tmp / "data" / "summary.json", summary)
    store.save_json(tmp / "data" / "items.json", items)
    store.save_json(tmp / "config.json", CONFIG)


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        make_data(cls.root, {
            "shop:falling": {"name": "値下がりした商品", "shop": "店A",
                             "url": "https://hb.afl.rakuten.co.jp/x/1",
                             "image": "https://img.test/1.jpg", "genre_id": "1"},
            "shop:cheap": {"name": "最安値の商品", "shop": "店B",
                           "url": "https://hb.afl.rakuten.co.jp/x/2",
                           "image": "", "genre_id": "1"},
            "shop:evil</script><script>alert(1)</script>": {
                "name": '危険な名前</script><script>alert(1)</script>&"', "shop": "店C",
                "url": "https://hb.afl.rakuten.co.jp/x/3", "image": "", "genre_id": "1"},
            "shop:gone": {"name": "履歴のない商品", "shop": "店D", "url": "", "image": "",
                          "genre_id": "1"},
        }, {
            "shop:falling": [10000] * 9 + [8000],
            "shop:cheap": [5000] * 8 + [4000, 4000],
            "shop:evil</script><script>alert(1)</script>": [3000] * 10,
        })
        cls.out = cls.root / "dist"
        cls.stats = builder.build(cls.root, cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def read(self, *parts) -> str:
        return (self.out.joinpath(*parts)).read_text(encoding="utf-8")

    # --- 構成 ---
    def test_expected_pages_exist(self):
        for path in ("index.html", "lows/index.html", "about/index.html",
                     "privacy/index.html", "contact/index.html",
                     "sitemap.xml", "robots.txt", "style.css"):
            with self.subTest(path=path):
                self.assertTrue((self.out / path).exists(), path)

    def test_item_without_history_gets_no_page(self):
        """今日の価格が無い商品を出すと、古い値を今日の値として見せてしまう。"""
        self.assertEqual(self.stats["items"], 3)
        self.assertNotIn("履歴のない商品", self.read("index.html") + self.read("lows", "index.html"))

    def test_drop_is_listed_on_the_front_page(self):
        page = self.read("index.html")
        self.assertIn("値下がりした商品", page)
        self.assertIn("▼20.0%", page)
        self.assertIn("10,000円", page)   # 変更前の価格

    def test_low_is_listed(self):
        self.assertIn("最安値の商品", self.read("lows", "index.html"))

    # --- 収益と法令 ---
    def test_every_affiliate_link_is_marked_sponsored(self):
        """rel の申告が無いリンクは検索エンジンへの違反になる。"""
        for path in self.out.rglob("*.html"):
            html = path.read_text(encoding="utf-8")
            for link in re.findall(r'<a\b[^>]*href="https://hb\.afl\.rakuten\.co\.jp[^"]*"[^>]*>', html):
                with self.subTest(path=path.name):
                    self.assertIn('rel="sponsored nofollow noopener"', link)

    def test_disclosure_appears_on_every_page(self):
        """ステマ規制。広告である旨の表示が無いページがあってはならない。"""
        for path in self.out.rglob("*.html"):
            with self.subTest(path=str(path.relative_to(self.out))):
                self.assertIn("楽天アフィリエイト", path.read_text(encoding="utf-8"))

    def test_lowest_price_claim_is_qualified(self):
        """「最安値」が市場全体の最安値だと誤解されないよう、範囲を明示する。"""
        self.assertIn("当サイトが記録した期間内での比較", self.read("index.html"))

    # --- 安全性 ---
    def test_item_name_cannot_break_out_of_the_json_ld_block(self):
        page = self.read("item", theme.slug("shop:evil</script><script>alert(1)</script>"),
                         "index.html")
        block = re.search(r'<script type="application/ld\+json">(.*?)</script>', page, re.S)
        self.assertIsNotNone(block)
        self.assertNotIn("<script>alert", block.group(1))
        parsed = json.loads(block.group(1))   # 妥当なJSONとして読めること
        self.assertIn("alert(1)", parsed["name"])   # 中身は失われていない

    def test_item_name_is_escaped_in_the_body(self):
        page = self.read("item", theme.slug("shop:evil</script><script>alert(1)</script>"),
                         "index.html")
        self.assertNotIn("<script>alert(1)</script>", page.split("application/ld+json")[0])

    def test_slugs_are_url_safe_and_unique(self):
        a = theme.slug("shop:evil</script>")
        b = theme.slug("shop:evil<script>")
        self.assertRegex(a, r"^[a-z0-9-]+$")
        self.assertNotEqual(a, b)   # 記号を潰しても別商品が衝突しないこと

    # --- 配信 ---
    def test_asset_paths_are_relative(self):
        """GitHub Pages のサブディレクトリ配信で絶対パスは 404 になる。"""
        self.assertIn('href="style.css"', self.read("index.html"))
        self.assertIn('href="../style.css"', self.read("lows", "index.html"))
        self.assertIn('href="../../style.css"',
                      self.read("item", theme.slug("shop:cheap"), "index.html"))

    def test_no_absolute_asset_paths_anywhere(self):
        for path in self.out.rglob("*.html"):
            with self.subTest(path=path.name):
                self.assertNotIn('href="/style.css"', path.read_text(encoding="utf-8"))

    def test_canonical_uses_the_public_url(self):
        self.assertIn('<link rel="canonical" href="https://example.test/price/">',
                      self.read("index.html"))

    def test_sitemap_lists_every_generated_page(self):
        sm = self.read("sitemap.xml")
        self.assertEqual(sm.count("<loc>"), self.stats["pages"])
        self.assertIn("https://example.test/price/lows/", sm)

    def test_rebuild_is_clean(self):
        """消した商品のページが残り続けないこと。"""
        stale = self.out / "item" / "stale-page"
        stale.mkdir(parents=True, exist_ok=True)
        (stale / "index.html").write_text("old", encoding="utf-8")
        builder.build(self.root, self.out)
        self.assertFalse(stale.exists())


class EmptyDataTest(unittest.TestCase):
    def test_builds_without_crashing_when_there_is_no_data_yet(self):
        """初回、データが無い状態でも公開できる形にはなること。"""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            store.save_json(root / "config.json", CONFIG)
            out = root / "dist"
            stats = builder.build(root, out)
            self.assertEqual(stats["items"], 0)
            self.assertIn("判定できるほどの値下がりはありません",
                          (out / "index.html").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
