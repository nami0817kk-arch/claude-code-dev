"""ページの組み立て。実行時にAIは使わず、データからHTMLを組む。"""
import hashlib
import html
import json
import re
from datetime import datetime

SAFE = re.compile(r"[^a-z0-9]+")


def esc(text) -> str:
    return html.escape(str(text if text is not None else ""), quote=True)


def safe_json(value) -> str:
    """JSON-LD に埋める。< > & を潰さないと商品名で </script> を作られる。"""
    return (json.dumps(value, ensure_ascii=False)
            .replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026"))


def slug(item_code: str) -> str:
    """商品コード（例 shop:1001）をURLに使える形にする。

    記号を潰すだけでは別商品が同じ綴りになりうるので、元のコードのハッシュを付ける。
    """
    base = SAFE.sub("-", str(item_code).lower()).strip("-")[:60] or "item"
    digest = hashlib.sha1(str(item_code).encode("utf-8")).hexdigest()[:8]
    return f"{base}-{digest}"


def yen(value) -> str:
    return f"{int(value):,}円"


def pct(value) -> str:
    return f"{value * 100:.1f}%"


def sparkline(tail: list, width: int = 220, height: int = 44) -> str:
    """価格推移の線。色は currentColor にして、明暗どちらのテーマでも読めるようにする。"""
    points = [p for _, p in tail if p]
    if len(points) < 2:
        return '<span class="spark-none">記録が足りません</span>'
    low, high = min(points), max(points)
    span = (high - low) or 1
    step = width / (len(points) - 1)
    coords = " ".join(
        f"{i * step:.1f},{height - 4 - (p - low) / span * (height - 8):.1f}"
        for i, p in enumerate(points))
    last_x = width
    last_y = height - 4 - (points[-1] - low) / span * (height - 8)
    return (f'<svg class="spark" viewBox="0 0 {width} {height}" role="img" '
            f'aria-label="直近{len(points)}日の価格推移">'
            f'<polyline points="{coords}" fill="none" stroke="currentColor" '
            f'stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>'
            f'<circle cx="{last_x:.1f}" cy="{last_y:.1f}" r="3" fill="currentColor"/>'
            f'</svg>')


FAVICON = ("data:image/svg+xml,"
           "%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E"
           "%3Crect width='32' height='32' rx='7' fill='%231f6f5c'/%3E"
           "%3Cpath d='M16 7v13m0 0l-6-6m6 6l6-6' stroke='%23fff' stroke-width='3' "
           "fill='none' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E")

AD_NOTICE = ('<p class="ad-notice">本サイトは楽天アフィリエイトを利用しており、'
             'リンク経由の購入により収益を得ています。</p>')

NAV = [("./", "今日の値下がり"), ("lows/", "最安値圏"), ("about/", "このサイトについて")]


def head(title: str, description: str, canonical: str, site: dict, prefix: str = "",
         extra: str = "") -> str:
    return f"""<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(description)}">
<link rel="canonical" href="{esc(canonical)}">
<meta name="robots" content="index,follow,max-image-preview:large">
<meta property="og:type" content="website">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(description)}">
<meta property="og:url" content="{esc(canonical)}">
<meta property="og:site_name" content="{esc(site['name'])}">
<meta name="twitter:card" content="summary">
<link rel="icon" href="{FAVICON}">
<link rel="stylesheet" href="{prefix}style.css">
{extra}
</head>
<body>
<header class="site-head"><div class="wrap">
  <a class="site-name" href="{prefix or './'}">{esc(site['name'])}</a>
  <nav class="site-nav">{"".join(f'<a href="{prefix}{href}">{esc(label)}</a>' for href, label in NAV)}</nav>
</div></header>
<main class="wrap">"""


def foot(site: dict, prefix: str = "", updated: str = "") -> str:
    stamp = f'<p class="updated">最終更新: {esc(updated)}</p>' if updated else ""
    owner = esc(site.get("owner") or site["name"])
    return f"""</main>
<footer class="site-foot"><div class="wrap">
  {stamp}
  <nav class="foot-nav">
    <a href="{prefix}about/">このサイトについて</a>
    <a href="{prefix}privacy/">プライバシーポリシー</a>
    <a href="{prefix}contact/">お問い合わせ</a>
  </nav>
  {AD_NOTICE}
  <p class="disclaimer">価格は当サイトが取得した時点のものです。実際の価格・在庫は
  必ずリンク先の楽天市場でご確認ください。「最安値」は当サイトが記録した期間内での比較であり、
  市場全体の最安値を意味するものではありません。</p>
  <p class="copy">© {datetime.now().year} {owner}</p>
</div></footer>
</body>
</html>"""


def buy_link(row: dict) -> str:
    """アフィリエイトリンク。sponsored を付けるのは検索エンジンへの申告として必須。"""
    if not row.get("url"):
        return ""
    return (f'<a class="buy" href="{esc(row["url"])}" '
            f'rel="sponsored nofollow noopener" target="_blank">楽天市場で見る</a>')


def badge(row: dict) -> str:
    if row["at_low"]:
        cls = "low"
    elif row["near_low"]:
        cls = "near"
    elif row["dropped"]:
        cls = "drop"
    else:
        cls = "flat"
    return f'<span class="badge {cls}">{esc(row["label"])}</span>'


def card(row: dict, prefix: str = "") -> str:
    href = f'{prefix}item/{slug(row["item_code"])}/'
    change = ""
    if row["dropped"]:
        change = (f'<span class="down">▼{pct(row["drop_pct"])}</span>'
                  f'<span class="was">{yen(row["prev"])} → </span>')
    img = (f'<img src="{esc(row["image"])}" alt="" loading="lazy" width="120" height="120">'
           if row.get("image") else '<span class="noimg"></span>')
    return f"""<li class="card">
  <a class="thumb" href="{href}">{img}</a>
  <div class="body">
    <a class="name" href="{href}">{esc(row["name"])}</a>
    <p class="price">{change}<strong>{yen(row["price"])}</strong> {badge(row)}</p>
    <p class="meta">{esc(row.get("shop", ""))}</p>
  </div>
</li>"""


def listing(title: str, lead: str, rows: list, site: dict, canonical: str,
            updated: str, prefix: str = "", empty: str = "該当する商品がありません。") -> str:
    body = ("".join(card(r, prefix) for r in rows) if rows
            else f'<li class="empty">{esc(empty)}</li>')
    return (head(f"{title}｜{site['name']}", lead, canonical, site, prefix)
            + f'<h1>{esc(title)}</h1><p class="lead">{esc(lead)}</p>'
            + AD_NOTICE
            + f'<ul class="cards">{body}</ul>'
            + foot(site, prefix, updated))


def item_page(row: dict, site: dict, updated: str) -> str:
    prefix = "../../"
    canonical = f'{site["base_url"].rstrip("/")}/item/{slug(row["item_code"])}/'
    title = f'{row["name"]}の価格推移'
    desc = (f'{row["name"]} の価格を毎日記録しています。'
            f'現在 {yen(row["price"])}、記録した中での最安値は {yen(row["low"])}。')

    rows_html = [("現在の価格", yen(row["price"])),
                 ("記録した中での最安値", f'{yen(row["low"])}（{esc(row.get("low_date") or "-")}）'),
                 ("記録した中での最高値", yen(row["high"])),
                 ("最安値との差", pct(row["vs_low_pct"]) if row["vs_low_pct"] else "最安値と同じ"),
                 ("記録日数", f'{row["days"]}日')]
    if row.get("prev"):
        rows_html.insert(1, ("前回の価格", yen(row["prev"])))
    table = "".join(f"<tr><th>{esc(k)}</th><td>{v}</td></tr>" for k, v in rows_html)

    # 商品情報の構造化データ。価格は当サイトの取得値であることを本文で明示している。
    ld = safe_json({
        "@context": "https://schema.org", "@type": "Product",
        "name": row["name"], "image": row.get("image") or None,
        "offers": {"@type": "Offer", "price": row["price"], "priceCurrency": "JPY",
                   "url": row.get("url") or canonical},
    })
    extra = f'<script type="application/ld+json">{ld}</script>'

    return (head(f"{title}｜{site['name']}", desc, canonical, site, prefix, extra)
            + f'<article class="item"><h1>{esc(row["name"])}</h1>'
            + AD_NOTICE
            + f'<p class="headline"><strong>{yen(row["price"])}</strong> {badge(row)}</p>'
            + f'<div class="chart">{sparkline(row.get("tail") or [])}</div>'
            + f'<table class="facts">{table}</table>'
            + f'<p class="cta">{buy_link(row)}</p>'
            + f'<p class="shop">販売店: {esc(row.get("shop", ""))}</p>'
            + '</article>'
            + foot(site, prefix, updated))
