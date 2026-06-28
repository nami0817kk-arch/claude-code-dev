import feedparser
import anthropic
import os

# 市況ニュース（フォールバック用）
MARKET_FEEDS = {
    "NHK経済":        "https://www.nhk.or.jp/rss/news/cat4.xml",
    "Yahoo Finance JP": "https://news.yahoo.co.jp/rss/topics/business.xml",
}

# Google News 検索 RSS のテンプレート（銘柄名を埋め込んで使う）
GOOGLE_NEWS_URL = "https://news.google.com/rss/search?q={query}&hl=ja&gl=JP&ceid=JP:ja"

# 証券コード → 検索キーワード
TICKER_KEYWORDS: dict[str, list[str]] = {
    "7203.T": ["トヨタ", "Toyota", "TOYOTA"],
    "6758.T": ["ソニー", "Sony", "SONY"],
    "9984.T": ["ソフトバンク", "SoftBank"],
    "6861.T": ["キーエンス", "KEYENCE"],
    "8306.T": ["三菱UFJ", "MUFG"],
    "7974.T": ["任天堂", "Nintendo"],
    "AAPL":   ["Apple", "アップル"],
    "MSFT":   ["Microsoft", "マイクロソフト"],
    "GOOGL":  ["Google", "Alphabet", "グーグル"],
    "AMZN":   ["Amazon", "アマゾン"],
    "NVDA":   ["NVIDIA", "エヌビディア"],
    "TSLA":   ["Tesla", "テスラ"],
}


def _keywords_for(ticker: str) -> list[str]:
    """ticker に対応する検索キーワードリストを返す"""
    keys = TICKER_KEYWORDS.get(ticker.upper(), [])
    # コード番号そのものも追加（例: "7203"）
    code = ticker.replace(".T", "").replace(".OS", "")
    return keys + [code]


def fetch_news(ticker: str, max_items: int = 10) -> list[dict]:
    """Google News RSS で銘柄関連ニュースを取得する"""
    keywords = _keywords_for(ticker)
    items = []
    seen = set()

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
                items.append({
                    "source":    "Google News",
                    "title":     title,
                    "summary":   entry.get("summary", "")[:200],
                    "published": entry.get("published", ""),
                    "link":      link,
                })
                if len(items) >= max_items:
                    break
        except Exception:
            continue

    return items


def fetch_market_news(max_items: int = 10) -> list[dict]:
    """銘柄を絞らず市況ニュースを取得する（フォールバック用）"""
    items = []
    for source, url in MARKET_FEEDS.items():
        try:
            feed = feedparser.parse(url)
            for entry in feed.entries[:3]:
                items.append({
                    "source":    source,
                    "title":     entry.get("title", ""),
                    "summary":   entry.get("summary", "")[:200],
                    "published": entry.get("published", ""),
                    "link":      entry.get("link", ""),
                })
        except Exception:
            continue
        if len(items) >= max_items:
            break
    return items


def analyze_news(news_items: list[dict], ticker: str) -> str:
    """Claude API でニュースを投資観点で分析する"""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        return "ANTHROPIC_API_KEY が設定されていません。"

    client = anthropic.Anthropic(api_key=api_key)

    headlines = "\n".join(
        f"- [{n['source']}] {n['title']}" for n in news_items
    )
    prompt = f"""{ticker} に関連する以下のニュース見出しを読み、投資家の視点で分析してください。

{headlines}

以下の形式で回答してください：
【シグナル】買い / 売り / 中立 のいずれか
【根拠】2〜3文で簡潔に
【注意点】リスク要因があれば1文で"""

    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=512,
        messages=[{"role": "user", "content": prompt}]
    )
    return message.content[0].text
