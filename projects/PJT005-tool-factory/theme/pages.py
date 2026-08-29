"""固定ページ（プライバシーポリシー・運営者情報・お問い合わせ）。

ASP と広告配信の審査では、これらのページの有無が見られる。
内容は site.json の設定から組み立てるので、実際にやっていないこと
（使っていない解析ツールなど）が書かれることはない。
"""
from .base import esc


def privacy_body(site: dict, has_affiliate: bool) -> str:
    """実際の設定に合わせてポリシー本文を組み立てる。"""
    sections = []

    sections.append("""
      <h2>入力された数値の取り扱い</h2>
      <p>当サイトの計算ツールは、すべてお使いのブラウザ内で計算を行います。
      入力された数値が当サイトのサーバーへ送信されることはなく、
      保存も収集もいたしません。計算結果のリンクを共有された場合、
      その URL には入力値が含まれますので、共有先にはご注意ください。</p>""")

    if site.get("ga_id"):
        sections.append("""
      <h2>アクセス解析について</h2>
      <p>当サイトでは、サイトの利用状況を把握するために Google アナリティクスを
      利用しています。Google アナリティクスは Cookie を使用して匿名のデータを収集します。
      個人を特定する情報は含まれません。</p>
      <p>Cookie の利用を望まれない場合は、お使いのブラウザの設定で無効にできます。
      Google によるデータの取り扱いについては、Google のプライバシーポリシーをご確認ください。</p>""")

    if site.get("adsense_client"):
        sections.append("""
      <h2>広告の配信について</h2>
      <p>当サイトでは第三者配信の広告サービスを利用しています。
      広告配信事業者は、利用者の興味に応じた広告を表示するために Cookie を使用することがあります。
      Cookie を無効にする方法、および第三者配信事業者による Cookie の利用については、
      各事業者のポリシーをご確認ください。</p>""")

    if has_affiliate:
        sections.append("""
      <h2>アフィリエイトプログラムについて</h2>
      <p>当サイトは、アフィリエイトプログラムに参加しています。
      当サイトを経由して商品やサービスのお申し込みがあった場合、
      当サイトが広告主から紹介料を受け取ることがあります。</p>
      <p>紹介料の有無が、掲載内容やツールの計算結果に影響することはありません。
      広告を含むページには、その旨を明示しています。</p>""")

    sections.append("""
      <h2>免責事項</h2>
      <p>当サイトの計算ツールおよび掲載内容は、実務の目安としてご利用いただくものです。
      正確性には努めておりますが、内容の完全性・正確性を保証するものではありません。</p>
      <p>計算結果をもとに行われた判断・行為によって生じた損害について、
      当サイトは責任を負いかねます。実際の運用にあたっては、
      各社の条件・自社の実績値・関係する法令をご確認のうえ、ご自身の判断でご利用ください。</p>
      <p>法令に関する記載は、記事作成時点の内容に基づいています。
      制度改正により内容が変わる場合がありますので、最新の情報は所管の官庁等でご確認ください。</p>""")

    sections.append("""
      <h2>著作権について</h2>
      <p>当サイトに掲載している文章・計算式の解説等の著作権は、当サイト運営者に帰属します。
      引用の範囲を超えた無断転載はご遠慮ください。</p>""")

    sections.append("""
      <h2>本ポリシーの変更</h2>
      <p>本プライバシーポリシーは、必要に応じて予告なく変更することがあります。
      変更後の内容は、当ページに掲載した時点から適用されます。</p>""")

    return "".join(sections)


def about_body(site: dict, tool_count: int) -> str:
    owner = site.get("owner") or "（運営者名を site.json に設定してください）"
    contact = contact_line(site)
    published = site.get("published_at")
    published_row = (f"<tr><th>公開</th><td>{esc(published)}</td></tr>"
                     if published else "")

    return f"""
      <h2>このサイトについて</h2>
      <p>{esc(site['description'])}</p>
      <p>製造業の生産管理・品質管理・原価管理の実務で使う計算を、
      その場で確かめられるようにしたサイトです。現在 {tool_count} のツールを公開しています。</p>
      <p>いずれのツールも、計算はお使いのブラウザ内で完結します。
      入力された数値がサーバーへ送信されることはありません。
      会員登録も不要で、すべて無料でご利用いただけます。</p>

      <h2>運営者</h2>
      <table class="info">
        <tr><th>運営者</th><td>{esc(owner)}</td></tr>
        <tr><th>サイト名</th><td>{esc(site['name'])}</td></tr>
        {published_row}
        <tr><th>連絡先</th><td>{contact}</td></tr>
      </table>

      <h2>計算式の根拠について</h2>
      <p>各ツールには計算式とその意味を掲載しています。
      在庫管理・品質管理の指標は一般に用いられている定義に基づいており、
      法令に関わるもの（有給休暇の付与日数など）は、
      根拠となる条文を本文中に示しています。</p>
      <p>解釈に幅がある項目や、実務上の注意点は各ツールのよくある質問に記載しています。
      内容に誤りを見つけられた場合は、ご連絡いただけますと幸いです。</p>"""


def contact_line(site: dict) -> str:
    email = site.get("contact_email")
    form = site.get("contact_form_url")
    if form:
        return (f'<a href="{esc(form)}" rel="noopener" target="_blank">'
                f"お問い合わせフォーム</a>")
    if email:
        # そのまま書くと収集されやすいので、表示だけ分けておく
        name, _, domain = email.partition("@")
        return (f'<span class="mail">{esc(name)}<span aria-hidden="true"> [at] </span>'
                f'<span class="sr">@</span>{esc(domain)}</span>')
    return "（連絡先を site.json に設定してください）"


def contact_body(site: dict) -> str:
    # アドレスを伏せ字で出しているときだけ、置き換えの案内を添える
    note = ""
    if site.get("contact_email") and not site.get("contact_form_url"):
        note = ('<p class="note">迷惑メール対策のため、アドレスの一部を記号で表記しています。'
                "送信の際は [at] を @ に置き換えてください。</p>")

    return f"""
      <h2>お問い合わせ</h2>
      <p>計算式の誤り、掲載内容へのご指摘、掲載のご依頼などは、
      下記までご連絡ください。</p>
      <p class="contact-value">{contact_line(site)}</p>
      {note}

      <h2>いただいたご連絡について</h2>
      <p>内容を確認のうえ、必要に応じて返信いたします。
      ただし、すべてのご連絡に返信をお約束するものではありません。</p>
      <p>個別の実務に関するご相談・コンサルティングのご依頼はお受けしておりません。
      各ツールの計算式と注意点は、それぞれのページに記載しています。</p>

      <h2>計算式の誤りについて</h2>
      <p>誤りのご指摘は特に歓迎いたします。
      該当するツール名と、どの箇所がどう誤っているかをお知らせいただけますと、
      確認と修正がスムーズです。</p>"""


PAGES = [
    {"slug": "about", "title": "運営者情報", "nav": "運営者情報",
     "description": "サイトの目的と運営者について。"},
    {"slug": "privacy", "title": "プライバシーポリシー", "nav": "プライバシーポリシー",
     "description": "入力値の取り扱い、免責事項、著作権についてのご案内です。"},
    {"slug": "contact", "title": "お問い合わせ", "nav": "お問い合わせ",
     "description": "計算式の誤りのご指摘、掲載内容へのご連絡はこちらから。"},
]


def body_for(slug: str, site: dict, tool_count: int, has_affiliate: bool) -> str:
    if slug == "privacy":
        return privacy_body(site, has_affiliate)
    if slug == "about":
        return about_body(site, tool_count)
    return contact_body(site)
