"""固定ページ。アフィリエイトを使う以上、運営者情報とポリシーの掲示は必須。"""
from .theme import esc, foot, head

PAGES = [
    {"slug": "about", "title": "このサイトについて"},
    {"slug": "privacy", "title": "プライバシーポリシー"},
    {"slug": "contact", "title": "お問い合わせ"},
]


def about_body(site: dict) -> str:
    return f"""
<p>{esc(site['name'])}は、楽天市場の商品価格を毎日記録し、その履歴から
値下がりと最安値圏を機械的に判定して公開しているサイトです。</p>

<h2>どうやって判定しているか</h2>
<p>判定はすべて計算式で行っており、人の主観や生成AIによる文章は含みません。</p>
<ul>
  <li><strong>値下がり</strong>: 前回記録した価格より一定割合以上安くなったもの</li>
  <li><strong>記録した中で最安</strong>: 当サイトが記録している期間の最安値と同じか、それを下回るもの</li>
  <li><strong>最安値に近い</strong>: 記録した最安値との差が小さいもの</li>
</ul>

<h2>「最安値」の意味</h2>
<p>当サイトが表示する最安値は<strong>当サイトが記録を開始してからの期間内での最安値</strong>であり、
市場全体・全期間の最安値ではありません。記録日数が短い商品については判定を行わず
「記録中」と表示します。</p>

<h2>価格について</h2>
<p>価格は取得時点のものです。表示後に変更される場合があるため、購入前に必ず
リンク先の楽天市場で最新の価格・在庫をご確認ください。当サイトは購入に関する
一切の責任を負いません。</p>

<h2>運営者</h2>
<p>{esc(site.get('owner') or '（準備中）')}</p>
"""


def privacy_body(site: dict) -> str:
    contact = esc(site.get("contact_email") or "（準備中）")
    return f"""
<h2>アクセス解析</h2>
<p>本サイトでは現在、独自のアクセス解析ツールを設置していません。
今後設置する場合は、本ページに記載したうえで運用します。</p>

<h2>アフィリエイトプログラム</h2>
<p>本サイトは楽天アフィリエイトに参加しています。当サイトのリンクを経由して
商品が購入された場合、当サイトは楽天グループ株式会社から成果報酬を受け取ります。
リンク先での購入において、利用者が当サイトに支払う費用は一切ありません。</p>
<p>商品情報および価格は楽天ウェブサービスを通じて取得しています。</p>

<h2>Cookie について</h2>
<p>リンク先の楽天市場では、成果の計測のために Cookie が使用されることがあります。
これは楽天グループ株式会社によるものであり、その取り扱いは同社のプライバシーポリシーに従います。</p>

<h2>免責事項</h2>
<p>掲載内容には正確を期していますが、その完全性・正確性を保証するものではありません。
本サイトの情報を利用して生じたいかなる損害についても責任を負いかねます。</p>

<h2>お問い合わせ</h2>
<p>{contact}</p>
"""


def contact_body(site: dict) -> str:
    email = site.get("contact_email")
    if email:
        # 表記を割ってあるのは、そのまま収集されるのを避けるため。
        shown = esc(email.replace("@", "[at]"))
        body = (f'<p>下記までご連絡ください。'
                f'<code>{shown}</code>（[at] を @ に置き換えてください）</p>')
    else:
        body = '<p>お問い合わせ先は準備中です。</p>'
    return f"""
<p>掲載内容の誤り、削除のご依頼、その他のご連絡はこちらへお願いします。</p>
{body}
<p>商品そのものに関するお問い合わせ（在庫・発送・返品など）は、
販売元の各店舗または楽天市場へお願いいたします。当サイトでは対応できません。</p>
"""


BODIES = {"about": about_body, "privacy": privacy_body, "contact": contact_body}


def render(page: dict, site: dict, updated: str) -> str:
    prefix = "../"
    canonical = f'{site["base_url"].rstrip("/")}/{page["slug"]}/'
    desc = f'{site["name"]}の{page["title"]}です。'
    return (head(f'{page["title"]}｜{site["name"]}', desc, canonical, site, prefix)
            + f'<article class="static"><h1>{esc(page["title"])}</h1>'
            + BODIES[page["slug"]](site) + '</article>'
            + foot(site, prefix, updated))
