"""ビルドの検証。

量産する以上、1本ごとに目視で確認していては速度が出ない。
「公開してはいけない状態のものがビルドを通らない」ことを機械で担保する。

  python -m unittest discover -s tests
"""
import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

import build  # noqa: E402
from theme import base  # noqa: E402
from tools._spec import Affiliate, Faq, Field, Output, Tool  # noqa: E402

SITE = {
    "name": "テストサイト",
    "description": "説明",
    "base_url": "https://example.com/",
    "adsense_client": "",
    "adsense_slots": {},
    "ga_id": "",
    "search_console_token": "",
}


def sample(**over) -> Tool:
    kwargs = dict(
        slug="sample", title="サンプル計算ツール", description="説明です",
        category="在庫管理",
        inputs=[Field("a", "入力A", default=10), Field("b", "入力B", default=2)],
        outputs=[Output("total", "合計", "a + b", unit="個", decimals=0)],
    )
    kwargs.update(over)
    return Tool(**kwargs)


class TestSpec(unittest.TestCase):
    def test_slug_must_be_url_safe(self):
        for bad in ("Sample", "sample_tool", "サンプル", "sample tool"):
            with self.assertRaises(ValueError, msg=bad):
                sample(slug=bad)

    def test_inputs_and_outputs_are_required(self):
        with self.assertRaises(ValueError):
            sample(inputs=[])
        with self.assertRaises(ValueError):
            sample(outputs=[])

    def test_duplicate_keys_are_rejected(self):
        """入力と出力で key が衝突すると JS 側で上書きされるので止める。"""
        with self.assertRaises(ValueError):
            sample(inputs=[Field("x", "X")], outputs=[Output("x", "X", "x")])

    def test_keys_must_be_javascript_identifiers(self):
        with self.assertRaises(ValueError):
            Field("1st", "だめ")
        with self.assertRaises(ValueError):
            Output("a-b", "だめ", "1")

    def test_first_output_becomes_primary(self):
        t = sample()
        self.assertTrue(t.outputs[0].primary)

    def test_explicit_primary_is_kept(self):
        t = sample(outputs=[Output("a1", "A", "a"), Output("b1", "B", "b", primary=True)])
        self.assertFalse(t.outputs[0].primary)
        self.assertTrue(t.outputs[1].primary)


class TestRender(unittest.TestCase):
    def setUp(self):
        self.tool = sample()
        self.html = base.render_tool(self.tool, SITE, [self.tool])

    def test_page_is_well_formed(self):
        self.assertTrue(self.html.startswith("<!doctype html>"))
        self.assertIn('<html lang="ja">', self.html)
        self.assertTrue(self.html.rstrip().endswith("</html>"))

    def test_seo_tags_are_present(self):
        self.assertIn('<link rel="canonical" href="https://example.com/sample/">', self.html)
        self.assertIn('<meta name="description" content="説明です">', self.html)
        self.assertIn('property="og:title"', self.html)
        self.assertIn('<link rel="icon"', self.html)

    def test_structured_data_is_valid_json(self):
        blocks = re.findall(
            r'<script type="application/ld\+json">(.*?)</script>', self.html, re.S)
        self.assertGreaterEqual(len(blocks), 2)
        types = []
        for b in blocks:
            data = json.loads(b)          # 壊れた JSON なら例外で落ちる
            types.append(data["@type"])
        self.assertIn("SoftwareApplication", types)
        self.assertIn("BreadcrumbList", types)

    def test_faq_adds_faq_schema(self):
        html = base.render_tool(
            sample(faq=[Faq("質問は？", "回答です。")]), SITE, [])
        blocks = re.findall(
            r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
        types = [json.loads(b)["@type"] for b in blocks]
        self.assertIn("FAQPage", types)

    def test_no_faq_means_no_faq_schema(self):
        blocks = re.findall(
            r'<script type="application/ld\+json">(.*?)</script>', self.html, re.S)
        self.assertNotIn("FAQPage", [json.loads(b)["@type"] for b in blocks])

    def test_inputs_and_outputs_are_rendered(self):
        self.assertIn('id="in-a"', self.html)
        self.assertIn('id="in-b"', self.html)
        self.assertIn('id="out-total"', self.html)
        self.assertIn('id="val-total"', self.html)

    def test_select_field_renders_options(self):
        html = base.render_tool(sample(inputs=[
            Field("mode", "選択", kind="select", default=2,
                  options=[("低", 1), ("高", 2)])]), SITE, [])
        self.assertIn("<select", html)
        self.assertIn('<option value="2" selected>高</option>', html)

    def test_spec_script_carries_the_formula(self):
        self.assertIn("window.TOOL_SPEC", self.html)
        self.assertIn("return (a + b);", self.html)


class TestDisclosure(unittest.TestCase):
    """ステマ規制。アフィリリンクのあるページには必ず広告表記を入れる。"""

    def test_affiliate_page_always_shows_the_notice(self):
        html = base.render_tool(sample(affiliate=Affiliate(
            heading="見出し", body="本文", cta="詳しく見る",
            url="https://example.com/ad")), SITE, [])
        self.assertIn("広告を含みます", html)
        self.assertIn('rel="sponsored nofollow noopener"', html)

    def test_page_without_affiliate_has_no_notice(self):
        self.assertNotIn("広告を含みます", self.plain)
        self.assertNotIn("sponsored", self.plain)

    def setUp(self):
        self.plain = base.render_tool(sample(), SITE, [])


class TestEscaping(unittest.TestCase):
    def test_text_is_escaped(self):
        html = base.render_tool(
            sample(title='<script>alert(1)</script>', description='"危険" & <b>'),
            SITE, [])
        self.assertNotIn("<script>alert(1)</script>", html)
        self.assertIn("&lt;script&gt;", html)
        self.assertIn("&quot;", html)

    def test_affiliate_url_is_escaped(self):
        html = base.render_tool(sample(affiliate=Affiliate(
            heading="h", body="b", cta="c", url='https://x/"><img src=y>')), SITE, [])
        self.assertNotIn('"><img src=y>', html)

    def test_js_strings_are_json_encoded(self):
        self.assertEqual(base.js_string('a"b'), '"a\\"b"')


class TestAdSlots(unittest.TestCase):
    def test_no_ad_markup_without_configuration(self):
        self.assertNotIn("adsbygoogle", base.render_tool(sample(), SITE, []))

    def test_ad_markup_appears_when_configured(self):
        site = dict(SITE, adsense_client="ca-pub-000",
                    adsense_slots={"bottom": "111"})
        html = base.render_tool(sample(), site, [])
        self.assertIn("adsbygoogle", html)
        self.assertIn('data-ad-slot="111"', html)

    def test_analytics_only_when_configured(self):
        self.assertNotIn("googletagmanager", base.render_tool(sample(), SITE, []))
        html = base.render_tool(sample(), dict(SITE, ga_id="G-XXX"), [])
        self.assertIn("googletagmanager", html)


class TestInternalLinks(unittest.TestCase):
    def test_same_category_tools_are_linked_first(self):
        me = sample(slug="me")
        same = sample(slug="same", category="在庫管理", title="同じ分野")
        other = sample(slug="other", category="品質管理", title="別の分野")
        html = base.render_tool(me, SITE, [me, same, other])
        self.assertLess(html.index("同じ分野"), html.index("別の分野"))

    def test_a_tool_does_not_link_to_itself(self):
        me = sample(slug="me", title="自分自身")
        related = base.render_related(me, [me])
        self.assertEqual(related, "")


class TestSiteFiles(unittest.TestCase):
    def setUp(self):
        self.tools = [sample(slug="a"), sample(slug="b", category="品質管理")]

    def test_sitemap_lists_every_page(self):
        xml = build.sitemap(SITE, self.tools)
        self.assertIn("<loc>https://example.com/</loc>", xml)
        self.assertIn("<loc>https://example.com/a/</loc>", xml)
        self.assertIn("<loc>https://example.com/b/</loc>", xml)

    def test_robots_points_at_the_sitemap(self):
        self.assertIn("Sitemap: https://example.com/sitemap.xml",
                      build.robots(SITE))

    def test_index_groups_by_category(self):
        html = base.render_index(SITE, self.tools)
        self.assertIn("在庫管理", html)
        self.assertIn("品質管理", html)
        self.assertIn("全 2 ツール", html)


class TestRealTools(unittest.TestCase):
    """実際に置いてあるツールが、公開できる状態かを見る。"""

    @classmethod
    def setUpClass(cls):
        cls.tools = build.load_tools()

    def test_at_least_one_tool_exists(self):
        self.assertTrue(self.tools)

    def test_every_tool_is_complete(self):
        for t in self.tools:
            with self.subTest(t.slug):
                self.assertTrue(t.description, "description が空")
                self.assertGreaterEqual(len(t.description), 30, "description が短すぎる")
                self.assertTrue(t.lead, "lead が空")
                self.assertTrue(t.faq, "FAQ が無い")
                self.assertTrue(t.steps, "使い方が無い")
                self.assertTrue(t.formula_note, "計算式の説明が無い")

    def test_every_tool_has_a_revenue_path(self):
        """広告だけでは分岐点に届かないので、導線の無いツールは作らない。"""
        for t in self.tools:
            with self.subTest(t.slug):
                self.assertIsNotNone(t.affiliate, "収益導線が未設定")

    def test_slugs_are_unique(self):
        slugs = [t.slug for t in self.tools]
        self.assertEqual(len(slugs), len(set(slugs)))

    def test_every_page_renders(self):
        for t in self.tools:
            with self.subTest(t.slug):
                html = base.render_tool(t, SITE, self.tools)
                self.assertIn(t.title, html)
                for block in re.findall(
                        r'<script type="application/ld\+json">(.*?)</script>', html, re.S):
                    json.loads(block)


if __name__ == "__main__":
    unittest.main()


class TestStaticPages(unittest.TestCase):
    """ASP・広告配信の審査で見られる固定ページ。"""

    def setUp(self):
        from theme import pages as static_pages
        self.pages = static_pages.PAGES
        self.tool = sample(affiliate=Affiliate(
            heading="h", body="b", cta="c", url="https://example.com/ad"))

    def render(self, slug, site=None, has_affiliate=True):
        page = next(p for p in self.pages if p["slug"] == slug)
        return base.render_page(page, site or SITE, 10, has_affiliate)

    def test_all_three_pages_exist(self):
        self.assertEqual({p["slug"] for p in self.pages},
                         {"about", "privacy", "contact"})

    def test_pages_render_as_full_documents(self):
        for page in self.pages:
            with self.subTest(page["slug"]):
                html = self.render(page["slug"])
                self.assertTrue(html.startswith("<!doctype html>"))
                self.assertIn(page["title"], html)
                self.assertIn('<link rel="canonical" '
                              f'href="https://example.com/{page["slug"]}/">', html)

    def test_privacy_always_covers_the_basics(self):
        html = self.render("privacy")
        for heading in ("入力された数値の取り扱い", "免責事項", "著作権について"):
            self.assertIn(heading, html)

    def test_privacy_omits_analytics_when_not_used(self):
        """使っていない解析ツールについて書かない。"""
        html = self.render("privacy", SITE)
        self.assertNotIn("Google アナリティクス", html)

    def test_privacy_mentions_analytics_when_configured(self):
        html = self.render("privacy", dict(SITE, ga_id="G-XXX"))
        self.assertIn("Google アナリティクス", html)

    def test_privacy_omits_ads_when_not_configured(self):
        self.assertNotIn("広告の配信について", self.render("privacy", SITE))

    def test_privacy_mentions_ads_when_configured(self):
        html = self.render("privacy", dict(SITE, adsense_client="ca-pub-1"))
        self.assertIn("広告の配信について", html)

    def test_privacy_mentions_affiliate_only_when_present(self):
        self.assertIn("アフィリエイトプログラム", self.render("privacy", has_affiliate=True))
        self.assertNotIn("アフィリエイトプログラム",
                         self.render("privacy", has_affiliate=False))

    def test_about_shows_the_owner_and_tool_count(self):
        html = self.render("about", dict(SITE, owner="山田 太郎"))
        self.assertIn("山田 太郎", html)
        self.assertIn("10 のツール", html)

    def test_about_flags_a_missing_owner(self):
        self.assertIn("site.json に設定してください", self.render("about", SITE))

    def test_contact_obfuscates_the_email(self):
        html = self.render("contact", dict(SITE, contact_email="info@example.com"))
        self.assertNotIn("info@example.com", html)
        self.assertIn("[at]", html)
        self.assertIn("info", html)

    def test_contact_prefers_a_form_url(self):
        html = self.render("contact", dict(SITE, contact_email="info@example.com",
                                           contact_form_url="https://forms.example/x"))
        self.assertIn("https://forms.example/x", html)
        self.assertNotIn("[at]", html)

    def test_footer_links_to_every_page(self):
        html = base.render_tool(self.tool, SITE, [self.tool])
        for page in self.pages:
            with self.subTest(page["slug"]):
                self.assertIn(f'href="../{page["slug"]}/"', html)

    def test_sitemap_includes_the_static_pages(self):
        xml = build.sitemap(SITE, [sample(slug="a")])
        for page in self.pages:
            self.assertIn(f"<loc>https://example.com/{page['slug']}/</loc>", xml)
