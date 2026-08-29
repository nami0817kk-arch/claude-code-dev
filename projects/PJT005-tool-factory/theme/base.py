"""ツール定義から HTML を組み立てる。

ここを1度作れば、以降は tools/ にツールを1本足すだけでページが1枚増える。
共通で入るもの:
  - SEO の meta / OGP / canonical
  - 構造化データ（SoftwareApplication・FAQPage・BreadcrumbList）
  - 広告枠（site.json で有効にしたときだけ）
  - アフィリエイト導線と PR 表記（アフィリを設定したページのみ・自動）
  - 同カテゴリの関連ツールへの内部リンク
"""
import html
import json
from datetime import datetime


def esc(text) -> str:
    return html.escape(str(text or ""), quote=True)


def js_string(text) -> str:
    """JS の文字列リテラルとして安全に埋め込む。"""
    return safe_json(str(text or ""))


def safe_json(value) -> str:
    """<script> の中に置いても壊れない JSON を返す。

    JSON をそのまま script 要素に入れると、文字列中の "</script>" が
    要素の終わりとみなされ、以降が HTML として解釈されてしまう。
    < と > と & をエスケープしておけば、JSON としての意味は変えずにこれを防げる。
    """
    return (json.dumps(value, ensure_ascii=False)
            .replace("<", "\\u003c")
            .replace(">", "\\u003e")
            .replace("&", "\\u0026"))


# ---------------------------------------------------------------- 部品

def render_field(f) -> str:
    hint = f'<span class="hint">{esc(f.hint)}</span>' if f.hint else ""
    unit = f'<span class="unit">{esc(f.unit)}</span>' if f.unit else ""

    if f.kind == "select":
        options = "".join(
            f'<option value="{esc(value)}"'
            f'{" selected" if str(value) == str(f.default) else ""}>{esc(label)}</option>'
            for label, value in f.options)
        control = f'<select id="in-{esc(f.key)}" name="{esc(f.key)}">{options}</select>'
    else:
        attrs = [f'id="in-{esc(f.key)}"', f'name="{esc(f.key)}"', 'type="number"',
                 f'step="{esc(f.step)}"', f'value="{esc(f.default)}"',
                 'inputmode="decimal"']
        if f.min is not None:
            attrs.append(f'min="{esc(f.min)}"')
        if f.max is not None:
            attrs.append(f'max="{esc(f.max)}"')
        control = f'<input {" ".join(attrs)}>'

    return f"""      <div class="field">
        <label for="in-{esc(f.key)}">{esc(f.label)}{hint}</label>
        <div class="control">{control}{unit}</div>
      </div>"""


def render_output(o) -> str:
    note = f"<small>{esc(o.note)}</small>" if o.note else ""
    unit = f"<span>{esc(o.unit)}</span>" if o.unit else ""
    cls = "result primary" if o.primary else "result"
    return f"""        <div class="{cls}" id="out-{esc(o.key)}">
          <div class="name">{esc(o.label)}{note}</div>
          <div class="value"><span id="val-{esc(o.key)}">—</span>{unit}</div>
        </div>"""


def render_spec_script(tool) -> str:
    """ブラウザ側に渡す計算定義。式は関数として埋め込む。"""
    inputs = ",\n      ".join(
        f'{{ key: {js_string(f.key)}, "default": {safe_json(f.default)} }}'
        for f in tool.inputs)
    outputs = ",\n      ".join(
        f'{{ key: {js_string(o.key)}, decimals: {o.decimals}, '
        f'compute: function (v) {{ with (v) {{ return ({o.expression}); }} }} }}'
        for o in tool.outputs)
    return f"""<script>
  window.TOOL_SPEC = {{
    inputs: [
      {inputs}
    ],
    outputs: [
      {outputs}
    ]
  }};
</script>"""


def render_promo(tool) -> str:
    a = tool.affiliate
    if not a:
        return ""
    fine = f'<span class="fine">{esc(a.note)}</span>' if a.note else ""
    return f"""
      <aside class="promo">
        <h2>{esc(a.heading)}</h2>
        <p>{esc(a.body)}</p>
        <a class="cta" href="{esc(a.url)}" rel="sponsored nofollow noopener"
           target="_blank">{esc(a.cta)}</a>{fine}
      </aside>"""


def render_related(tool, all_tools, limit: int = 4, prefix: str = "") -> str:
    same = [t for t in all_tools
            if t.category == tool.category and t.slug != tool.slug]
    others = [t for t in all_tools
              if t.category != tool.category and t.slug != tool.slug]
    picked = (same + others)[:limit]
    if not picked:
        return ""
    cards = "".join(
        f'<a href="{prefix}{esc(t.slug)}/"><span class="t">{esc(t.title)}</span>'
        f'<span class="d">{esc(t.description[:52])}</span></a>' for t in picked)
    return f"""
      <h2>関連するツール</h2>
      <div class="related">{cards}</div>"""


def render_faq(tool) -> str:
    if not tool.faq:
        return ""
    items = "".join(
        f'<details><summary>{esc(q.question)}</summary>'
        f'<div class="body">{esc(q.answer)}</div></details>' for q in tool.faq)
    return f"""
      <h2>よくある質問</h2>
      {items}"""


def render_steps(tool) -> str:
    if not tool.steps:
        return ""
    items = "".join(f"<li>{esc(s)}</li>" for s in tool.steps)
    return f"""
      <h2>使い方</h2>
      <ol>{items}</ol>"""


def render_formula(tool) -> str:
    if not tool.formula_note:
        return ""
    return f"""
      <h2>計算式</h2>
      <div class="formula">{esc(tool.formula_note)}</div>"""


# ---------------------------------------------------------------- 構造化データ

def structured_data(tool, site) -> str:
    base = site["base_url"].rstrip("/")
    url = base + tool.url_path

    blocks = [{
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": tool.title,
        "description": tool.description,
        "url": url,
        "applicationCategory": "BusinessApplication",
        "operatingSystem": "Web",
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "JPY"},
    }, {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": site["name"], "item": base + "/"},
            {"@type": "ListItem", "position": 2, "name": tool.category,
             "item": base + "/#" + tool.category},
            {"@type": "ListItem", "position": 3, "name": tool.title, "item": url},
        ],
    }]

    if tool.faq:
        blocks.append({
            "@context": "https://schema.org",
            "@type": "FAQPage",
            "mainEntity": [{
                "@type": "Question",
                "name": q.question,
                "acceptedAnswer": {"@type": "Answer", "text": q.answer},
            } for q in tool.faq],
        })

    return "\n".join(
        f'<script type="application/ld+json">{safe_json(b)}</script>'
        for b in blocks)


# ---------------------------------------------------------------- 骨格

# 追加のリクエストを作らないよう、favicon は data URI で埋め込む
FAVICON = (
    "data:image/svg+xml,"
    "%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E"
    "%3Crect width='32' height='32' rx='7' fill='%231d5a80'/%3E"
    "%3Cpath d='M8 21h4v3H8zm6-6h4v9h-4zm6-7h4v16h-4z' fill='%23fff'/%3E"
    "%3C/svg%3E"
)


def head(title: str, description: str, canonical: str, site: dict,
         extra: str = "", prefix: str = "") -> str:
    """prefix はページからサイト直下までの相対パス。

    絶対パス（/style.css）にすると、GitHub Pages のプロジェクトサイトのように
    サブディレクトリで配信したときにドメイン直下を指してしまい 404 になる。
    相対パスにしておけば、直下・サブパス・ローカルファイルのどれでも動く。
    """
    ads = ""
    if site.get("adsense_client"):
        ads = (f'\n<script async crossorigin="anonymous"\n'
               f'  src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js'
               f'?client={esc(site["adsense_client"])}"></script>')
    analytics = ""
    if site.get("ga_id"):
        gid = esc(site["ga_id"])
        analytics = (f'\n<script async src="https://www.googletagmanager.com/gtag/js?id={gid}"></script>'
                     f'\n<script>window.dataLayer=window.dataLayer||[];'
                     f'function gtag(){{dataLayer.push(arguments);}}'
                     f'gtag("js",new Date());gtag("config","{gid}");</script>')
    verify = ""
    if site.get("search_console_token"):
        verify = (f'\n<meta name="google-site-verification" '
                  f'content="{esc(site["search_console_token"])}">')

    return f"""<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(description)}">
<link rel="canonical" href="{esc(canonical)}">{verify}
<meta property="og:type" content="website">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(description)}">
<meta property="og:url" content="{esc(canonical)}">
<meta property="og:site_name" content="{esc(site['name'])}">
<meta name="twitter:card" content="summary">
<link rel="icon" href="{FAVICON}">
<link rel="stylesheet" href="{prefix}style.css">{ads}{analytics}
{extra}
</head>
<body>
<header class="site-head">
  <div class="wrap">
    <a class="site-name" href="{prefix or './'}">{esc(site['name'])}</a>
    <nav class="site-nav"><a href="{prefix or './'}">ツール一覧</a></nav>
  </div>
</header>"""


def foot(site: dict, prefix: str = "") -> str:
    year = datetime.now().year
    from .pages import PAGES
    links = "".join(
        f'<a href="{prefix}{page["slug"]}/">{esc(page["nav"])}</a>' for page in PAGES)
    return f"""<footer class="site-foot">
  <div class="wrap">
    <nav class="foot-nav">{links}</nav>
    計算はすべてお使いのブラウザ内で完結し、入力値が送信されることはありません。<br>
    結果は目安です。実際の運用にあたっては各社の条件・自社の実績値をご確認ください。<br>
    © {year} {esc(site['name'])}
  </div>
</footer>
</body>
</html>"""


def ad_slot(site: dict, slot_key: str) -> str:
    """広告枠。site.json に設定が無ければ何も出さない。"""
    client = site.get("adsense_client")
    slot = (site.get("adsense_slots") or {}).get(slot_key)
    if not (client and slot):
        return ""
    return f"""
      <div class="ad">
        <ins class="adsbygoogle" style="display:block"
             data-ad-client="{esc(client)}" data-ad-slot="{esc(slot)}"
             data-ad-format="auto" data-full-width-responsive="true"></ins>
        <script>(adsbygoogle = window.adsbygoogle || []).push({{}});</script>
      </div>"""


# ---------------------------------------------------------------- ページ

def render_tool(tool, site: dict, all_tools: list) -> str:
    base = site["base_url"].rstrip("/")
    canonical = base + tool.url_path
    page_title = f"{tool.title}｜{site['name']}"

    # アフィリエイトリンクがあるページには必ず表示する（ステマ規制）
    pr = '<div class="pr-note">広告を含みます</div>' if tool.has_affiliate else ""
    updated = (f'<p class="updated">最終更新 {esc(tool.updated)}</p>'
               if tool.updated else "")
    lead = f'<p class="lead">{esc(tool.lead)}</p>' if tool.lead else ""

    return f"""{head(page_title, tool.description, canonical, site,
                     structured_data(tool, site), prefix="../")}
<main class="wrap">
  <nav class="crumbs"><a href="../">ツール一覧</a> ／ {esc(tool.category)}</nav>
  {pr}
  <h1>{esc(tool.title)}</h1>
  {lead}
  {updated}

  <form class="calc" id="calc" autocomplete="off">
    <div class="fields">
{chr(10).join(render_field(f) for f in tool.inputs)}
    </div>
    <div class="actions">
      <button type="button" class="primary" id="copy">この結果のリンクをコピー</button>
      <button type="button" id="reset">入力をリセット</button>
    </div>
    <div class="results">
{chr(10).join(render_output(o) for o in tool.outputs)}
    </div>
  </form>
{render_promo(tool)}
{ad_slot(site, "after_tool")}
  <div class="prose">
{render_steps(tool)}
{render_formula(tool)}
{render_faq(tool)}
  </div>
{render_related(tool, all_tools, prefix="../")}
{ad_slot(site, "bottom")}
</main>
{render_spec_script(tool)}
<script src="../app.js" defer></script>
{foot(site, "../")}"""


def render_index(site: dict, all_tools: list) -> str:
    base = site["base_url"].rstrip("/")
    groups = {}
    for t in all_tools:
        groups.setdefault(t.category, []).append(t)

    sections = []
    for category, tools in groups.items():
        cards = "".join(
            f'<a href="{esc(t.slug)}/"><span class="t">{esc(t.title)}</span>'
            f'<span class="d">{esc(t.description)}</span></a>' for t in tools)
        sections.append(f'<section class="cat"><h2>{esc(category)}</h2>'
                        f'<div class="related">{cards}</div></section>')

    return f"""{head(site['name'], site['description'], base + "/", site)}
<main class="wrap">
  <h1>{esc(site['name'])}</h1>
  <p class="lead">{esc(site['description'])}</p>
  <p class="updated">全 {len(all_tools)} ツール　すべて無料・登録不要・ブラウザ内で完結</p>
{"".join(sections)}
{ad_slot(site, "bottom")}
</main>
{foot(site)}"""


def render_page(page: dict, site: dict, tool_count: int, has_affiliate: bool) -> str:
    """プライバシーポリシーなどの固定ページ。"""
    from .pages import body_for

    base = site["base_url"].rstrip("/")
    canonical = f"{base}/{page['slug']}/"
    return f"""{head(f"{page['title']}｜{site['name']}", page["description"],
                     canonical, site, prefix="../")}
<main class="wrap">
  <nav class="crumbs"><a href="../">ツール一覧</a></nav>
  <h1>{esc(page['title'])}</h1>
  <div class="prose">
{body_for(page["slug"], site, tool_count, has_affiliate)}
  </div>
</main>
{foot(site, "../")}"""
