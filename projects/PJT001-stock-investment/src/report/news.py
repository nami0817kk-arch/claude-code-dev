import feedparser
import anthropic
import os


RSS_FEEDS = {
    "日本経済新聞": "https://www.nikkei.com/rss/",
    "Reuters JP":   "https://feeds.reuters.com/reuters/JPbusinessNews",
}


def fetch_news(ticker: str, max_items: int = 10) -> list[dict]:
    """RSS フィードから銘柄関連ニュースを取得する"""
    items = []
    for source, url in RSS_FEEDS.items():
        feed = feedparser.parse(url)
        for entry in feed.entries[:max_items]:
            title = entry.get("title", "")
            if ticker.replace(".T", "") in title or not ticker:
                items.append({
                    "source":    source,
                    "title":     title,
                    "summary":   entry.get("summary", ""),
                    "published": entry.get("published", ""),
                    "link":      entry.get("link", ""),
                })
    return items


def analyze_news(news_items: list[dict], ticker: str) -> str:
    """Claude API でニュースを要約・投資観点で分析する"""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        return "ANTHROPIC_API_KEY が設定されていません。.env ファイルを確認してください。"

    client = anthropic.Anthropic(api_key=api_key)

    headlines = "\n".join(f"- {n['title']}" for n in news_items[:10])
    prompt = f"""以下は {ticker} に関連するニュース見出しです。
投資家の観点から、買い・売り・中立のシグナルと、その根拠を200字以内で要約してください。

{headlines}"""

    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        messages=[{"role": "user", "content": prompt}]
    )
    return message.content[0].text
