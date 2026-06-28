import feedparser
import anthropic
import os

MARKET_FEEDS = {
    "NHK経済":          "https://www.nhk.or.jp/rss/news/cat4.xml",
    "Yahoo Finance JP": "https://news.yahoo.co.jp/rss/topics/business.xml",
}

GOOGLE_NEWS_URL = "https://news.google.com/rss/search?q={query}&hl=ja&gl=JP&ceid=JP:ja"

TICKER_KEYWORDS: dict[str, list[str]] = {
    # 日本株
    "7203.T": ["トヨタ自動車", "Toyota", "TOYOTA"],
    "6758.T": ["ソニー", "Sony", "SONY"],
    "9984.T": ["ソフトバンク", "SoftBank"],
    "6861.T": ["キーエンス", "KEYENCE"],
    "8306.T": ["三菱UFJ", "MUFG"],
    "7974.T": ["任天堂", "Nintendo"],
    "6367.T": ["ダイキン", "Daikin"],
    "9433.T": ["KDDI", "au"],
    "4519.T": ["中外製薬", "Chugai"],
    "8035.T": ["東京エレクトロン", "TEL"],
    "9432.T": ["NTT", "日本電信電話"],
    "6954.T": ["ファナック", "FANUC"],
    "4063.T": ["信越化学", "Shin-Etsu"],
    "6501.T": ["日立", "Hitachi"],
    "7267.T": ["ホンダ", "Honda"],
    "6902.T": ["デンソー", "DENSO"],
    "6098.T": ["リクルート", "Recruit"],
    "4568.T": ["第一三共", "Daiichi Sankyo"],
    "9022.T": ["JR東海", "東海旅客鉄道"],
    "8058.T": ["三菱商事", "Mitsubishi Corp"],
    # 米国株
    "AAPL":  ["Apple", "アップル", "iPhone"],
    "MSFT":  ["Microsoft", "マイクロソフト"],
    "GOOGL": ["Google", "Alphabet", "グーグル"],
    "AMZN":  ["Amazon", "アマゾン"],
    "NVDA":  ["NVIDIA", "エヌビディア"],
    "TSLA":  ["Tesla", "テスラ"],
    "META":  ["Meta", "Facebook", "メタ"],
    "JPM":   ["JPMorgan", "ジェイピーモルガン"],
    "JNJ":   ["Johnson & Johnson", "J&J"],
    "V":     ["Visa", "ビザ"],
    "PG":    ["Procter & Gamble", "P&G"],
    "UNH":   ["UnitedHealth"],
    "HD":    ["Home Depot"],
    "MA":    ["Mastercard", "マスターカード"],
    "DIS":   ["Disney", "ディズニー"],
    "NFLX":  ["Netflix", "ネットフリックス"],
    "AMD":   ["AMD", "Advanced Micro Devices"],
    "CRM":   ["Salesforce", "セールスフォース"],
    "ADBE":  ["Adobe", "アドビ"],
    "ORCL":  ["Oracle", "オラクル"],
    "BAC":   ["Bank of America", "バンクオブアメリカ"],
    "GS":    ["Goldman Sachs", "ゴールドマン"],
    "XOM":   ["ExxonMobil", "エクソン"],
    "CVX":   ["Chevron", "シェブロン"],
}


def _keywords_for(ticker: str) -> list[str]:
    keys = TICKER_KEYWORDS.get(ticker.upper(), [])
    code = ticker.replace(".T", "").replace(".OS", "")
    return keys + [code]


def fetch_news(ticker: str, max_items: int = 10) -> list[dict]:
    """Google News RSS で銘柄関連ニュースを取得する"""
    keywords = _keywords_for(ticker)
    items = []
    seen  = set()

    for kw in keywords:
        if len(items) >= max_items:
            break
        url = GOOGLE_NEWS_URL.format(query=kw)
        try:
            feed = feedparser.parse(url)
            for entry in feed.entries:
                title = entry.get("title", "")
                link  = entry.get("link", "")
                if link in seen:
                    continue
                seen.add(link)
                # summary には記事の冒頭スニペットが含まれる
                summary = entry.get("summary", "")
                # HTML タグを除去
                import re
                summary = re.sub(r"<[^>]+>", "", summary)[:400]
                items.append({
                    "source":    entry.get("source", {}).get("title", "Google News"),
                    "title":     title,
                    "summary":   summary,
                    "published": entry.get("published", ""),
                    "link":      link,
                })
                if len(items) >= max_items:
                    break
        except Exception:
            continue

    return items


def fetch_market_news(max_items: int = 10) -> list[dict]:
    """市況ニュースを取得する（フォールバック用）"""
    items = []
    for source, url in MARKET_FEEDS.items():
        try:
            feed = feedparser.parse(url)
            for entry in feed.entries[:3]:
                import re
                summary = re.sub(r"<[^>]+>", "", entry.get("summary", ""))[:400]
                items.append({
                    "source":    source,
                    "title":     entry.get("title", ""),
                    "summary":   summary,
                    "published": entry.get("published", ""),
                    "link":      entry.get("link", ""),
                })
        except Exception:
            continue
        if len(items) >= max_items:
            break
    return items


def analyze_news(news_items: list[dict], ticker: str) -> str:
    """Claude でニュースを投資観点で分析する"""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        return "ANTHROPIC_API_KEY が設定されていません。"

    client = anthropic.Anthropic(api_key=api_key)
    headlines = "\n".join(
        f"- [{n['source']}] {n['title']}\n  {n['summary']}" for n in news_items
    )
    prompt = f"""{ticker} に関連する以下のニュースを読み、投資家の視点で分析してください。

{headlines}

以下の形式で回答してください：
【シグナル】買い / 売り / 中立 のいずれか
【根拠】2〜3文で簡潔に
【注意点】リスク要因があれば1文で"""

    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        messages=[{"role": "user", "content": prompt}]
    )
    return message.content[0].text
