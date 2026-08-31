import re
import json
import feedparser
import anthropic
import os
import requests
from bs4 import BeautifulSoup
from pathlib import Path
from datetime import datetime, timezone, timedelta

KABUTAN_URL  = "https://kabutan.jp/news/marketnews/"
YOUTUBE_RSS  = "https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}"
YOUTUBE_CHANNELS = [
    "UC5Qgc-tEFmm5iQX5tUy6TyA",   # 株リアルライブ
    "UClhsF9k783OGFLjK3SSjsAQ",   # 投深(投資)ハイスクール
    "UCaZTp74dZc8RnyeY6ef506g",   # テンバガー・高配当株発掘 TMNTGAMER
    "UCMrg0DqhgSL8d9q1_i_Tv2A",   # 毎日チャート分析ちゃんねる
]

_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36",
    "Accept-Language": "ja,en;q=0.9",
}

GOOGLE_NEWS_URL = "https://news.google.com/rss/search?q={query}&hl=ja&gl=JP&ceid=JP:ja"

# ペイウォール・スクレイピング不可サイト（本文取得をスキップ）
_BLOCKED_DOMAINS = {
    "nikkei.com", "wsj.com", "ft.com", "bloomberg.co.jp",
    "toyokeizai.net", "diamond.jp", "president.jp",
}


def fetch_article_body(url: str, max_chars: int = 400) -> str:
    """記事URLから本文テキストを取得する（失敗時は空文字）"""
    try:
        # ブロックドメインはスキップ
        for domain in _BLOCKED_DOMAINS:
            if domain in url:
                return ""
        resp = requests.get(url, headers=_HEADERS, timeout=6, allow_redirects=True)
        if resp.status_code != 200:
            return ""
        soup = BeautifulSoup(resp.content, "lxml")
        # 不要要素を除去
        for tag in soup(["script", "style", "nav", "header", "footer",
                         "aside", "form", "iframe", "figure", "noscript"]):
            tag.decompose()
        # 本文エリアを優先的に探す
        content = (
            soup.find("article") or
            soup.find("main") or
            soup.find(class_=re.compile(r"article|content|body|text|entry", re.I)) or
            soup.find("body")
        )
        if not content:
            return ""
        text = content.get_text(separator=" ", strip=True)
        text = re.sub(r"\s+", " ", text).strip()
        return text[:max_chars]
    except Exception:
        return ""

TICKER_KEYWORDS: dict[str, list[str]] = {
    # 日本株（大型）
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
    # 日本株（中型）
    "3697.T": ["SHIFT", "シフト"],
    "6532.T": ["ベイカレント", "BayCurrent"],
    "4480.T": ["メドレー", "MEDLEY"],
    "3769.T": ["GMOペイメントゲートウェイ", "GMO-PG"],
    "4385.T": ["メルカリ", "Mercari"],
    "2413.T": ["エムスリー", "M3"],
    "9697.T": ["カプコン", "CAPCOM"],
    "4751.T": ["サイバーエージェント", "CyberAgent"],
    "3092.T": ["ZOZO", "ゾゾ", "ZOZOTOWN"],
    "4443.T": ["Sansan", "サンサン"],
    "4776.T": ["サイボウズ", "Cybozu"],
    "2379.T": ["ディップ", "dip"],
    "7564.T": ["ワークマン", "Workman"],
    "3923.T": ["ラクス", "Rakus"],
    "8698.T": ["マネックス", "Monex"],
    # 日本株（小型）
    "4478.T": ["フリー", "freee"],
    "3994.T": ["マネーフォワード", "Money Forward"],
    "6200.T": ["インソース", "Insource"],
    "4552.T": ["JCRファーマ", "JCR Pharmaceuticals"],
    "4565.T": ["そーせい", "Sosei"],
    "6089.T": ["ウィルグループ", "Will Group"],
    # 米国株（大型）
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
    # 米国株（中型）
    "BILL":  ["Bill.com", "ビルコム"],
    "GTLB":  ["GitLab", "ギットラブ"],
    "DOCN":  ["DigitalOcean", "デジタルオーシャン"],
    "RELY":  ["Remitly", "リミットリー"],
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


def fetch_kabutan_news(max_items: int = 15) -> list[dict]:
    """株探マーケットニュースをスクレイピングする"""
    try:
        resp = requests.get(KABUTAN_URL, headers=_HEADERS, timeout=10)
        resp.encoding = "utf-8"
        soup  = BeautifulSoup(resp.content, "lxml")
        items = []
        seen  = set()
        for a in soup.find_all("a", href=True):
            href  = a.get("href", "")
            title = a.get_text(strip=True)
            if "/news/" not in href or len(title) < 10 or title in seen:
                continue
            seen.add(title)
            link = "https://kabutan.jp" + href if href.startswith("/") else href
            items.append({
                "source":    "株探",
                "title":     title,
                "summary":   "",
                "published": "",
                "link":      link,
            })
            if len(items) >= max_items:
                break
        return items
    except Exception:
        return []


YAHOO_FINANCE_URLS = [
    ("https://finance.yahoo.co.jp/news/market",     "Yahoo市況"),
    ("https://finance.yahoo.co.jp/news/settlement", "Yahoo決算速報"),
    ("https://finance.yahoo.co.jp/news/stocks",     "Yahooビジネス"),
]


def fetch_yahoo_finance_news(max_items: int = 20) -> list[dict]:
    """Yahoo!ファイナンスのニュースをスクレイピングする"""
    items = []
    seen  = set()
    per_page = max(max_items // len(YAHOO_FINANCE_URLS), 5)
    for url, source in YAHOO_FINANCE_URLS:
        try:
            resp = requests.get(url, headers=_HEADERS, timeout=10)
            soup = BeautifulSoup(resp.content, "lxml")
            for a in soup.find_all("a", href=True):
                href  = a.get("href", "")
                title = a.get_text(strip=True)
                if "/news/detail/" not in href or len(title) < 10 or title in seen:
                    continue
                seen.add(title)
                link = href if href.startswith("http") else "https://finance.yahoo.co.jp" + href
                items.append({
                    "source":    source,
                    "title":     title,
                    "summary":   "",
                    "published": "",
                    "link":      link,
                })
                if sum(1 for i in items if i["source"] == source) >= per_page:
                    break
        except Exception:
            continue
    return items[:max_items]


def fetch_youtube_news(channel_id: str, max_items: int = 5) -> list[dict]:
    """YouTube チャンネルの最新動画タイトルをRSSで取得する"""
    try:
        feed  = feedparser.parse(YOUTUBE_RSS.format(channel_id=channel_id))
        ch    = feed.feed.get("title", "YouTube")
        items = []
        for entry in feed.entries[:max_items]:
            desc = entry.get("summary", "")
            desc = re.sub(r"<[^>]+>", "", desc)[:300]
            items.append({
                "source":    f"YouTube:{ch}",
                "title":     entry.get("title", ""),
                "summary":   desc,
                "published": entry.get("published", "")[:10],
                "link":      entry.get("link", ""),
            })
        return items
    except Exception:
        return []


_TRANSCRIPT_CACHE = Path(__file__).parent.parent.parent / "data" / "cache" / "yt_transcripts.json"
_CACHE_TTL_HOURS  = 24


def _load_cache() -> dict:
    if _TRANSCRIPT_CACHE.exists():
        try:
            return json.loads(_TRANSCRIPT_CACHE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {}


def _save_cache(cache: dict) -> None:
    _TRANSCRIPT_CACHE.parent.mkdir(parents=True, exist_ok=True)
    _TRANSCRIPT_CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")


def _is_within_hours(iso_str: str, hours: int = 24) -> bool:
    """RSSのpublished文字列が指定時間以内かどうか判定"""
    try:
        import email.utils
        dt = email.utils.parsedate_to_datetime(iso_str)
        now = datetime.now(timezone.utc)
        return (now - dt.astimezone(timezone.utc)) <= timedelta(hours=hours)
    except Exception:
        try:
            dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
            now = datetime.now(timezone.utc)
            return (now - dt.astimezone(timezone.utc)) <= timedelta(hours=hours)
        except Exception:
            return True  # 判定できない場合は対象とする


def fetch_transcript_cached(video_id: str, max_chars: int = 1500) -> str:
    """文字起こしをキャッシュ付きで取得する（24時間キャッシュ）"""
    cache = _load_cache()
    now   = datetime.now(timezone.utc).isoformat()

    # キャッシュヒット確認
    if video_id in cache:
        fetched_at = cache[video_id].get("fetched_at", "")
        try:
            dt = datetime.fromisoformat(fetched_at)
            if (datetime.now(timezone.utc) - dt.astimezone(timezone.utc)) < timedelta(hours=_CACHE_TTL_HOURS):
                return cache[video_id].get("transcript", "")
        except Exception:
            pass

    # 新規取得
    try:
        from youtube_transcript_api import YouTubeTranscriptApi
        api      = YouTubeTranscriptApi()
        fetched  = api.fetch(video_id, languages=["ja", "en"])
        text     = " ".join(t.text for t in fetched)
        text     = re.sub(r"\s+", " ", text).strip()[:max_chars]
        cache[video_id] = {"transcript": text, "fetched_at": now}
        _save_cache(cache)
        return text
    except Exception:
        # 取得失敗もキャッシュに記録して再試行しない
        cache[video_id] = {"transcript": "", "fetched_at": now}
        _save_cache(cache)
        return ""


def fetch_youtube_with_transcripts(max_videos: int = 40) -> list[dict]:
    """24時間以内の動画のみ取得し、文字起こしをキャッシュ付きで付加する"""
    items    = []
    per_ch   = max(max_videos // len(YOUTUBE_CHANNELS), 3)
    for ch_id in YOUTUBE_CHANNELS:
        try:
            feed = feedparser.parse(YOUTUBE_RSS.format(channel_id=ch_id))
            ch   = feed.feed.get("title", "YouTube")
            for entry in feed.entries[:per_ch * 3]:  # 多めに取って24h以内でフィルタ
                published = entry.get("published", "")
                # 24時間以内のみ
                if not _is_within_hours(published, hours=24):
                    continue
                title = entry.get("title", "")
                link  = entry.get("link", "")
                # Shortsはスキップ
                if "#shorts" in title.lower() or "shorts" in link.lower():
                    continue
                m = re.search(r"v=([^&]+)", link)
                if not m:
                    continue
                vid_id     = m.group(1)
                transcript = fetch_transcript_cached(vid_id)
                items.append({
                    "source":     f"YouTube:{ch}",
                    "title":      title,
                    "summary":    entry.get("summary", "")[:150],
                    "published":  published[:10],
                    "link":       link,
                    "transcript": transcript,
                })
                if len(items) >= max_videos:
                    break
        except Exception:
            continue
    return items[:max_videos]


def fetch_market_news(max_items: int = 75) -> list[dict]:
    """株探・YouTubeから市況ニュースを取得する"""
    items = []

    # 株探（最大15件）
    items += fetch_kabutan_news(max_items=15)

    # YouTube 各チャンネル（1チャンネルあたり最大15件）
    for ch_id in YOUTUBE_CHANNELS:
        items += fetch_youtube_news(channel_id=ch_id, max_items=15)

    return items[:max_items]


def fetch_youtube_only_news(max_items: int = 40) -> list[dict]:
    """YouTubeチャンネルのみから市況動画タイトルを取得する（株探を除外）"""
    items = []
    per_ch = max(max_items // len(YOUTUBE_CHANNELS), 5)
    for ch_id in YOUTUBE_CHANNELS:
        items += fetch_youtube_news(channel_id=ch_id, max_items=per_ch)
    return items[:max_items]


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
        model="claude-haiku-4-5-20251001",
        max_tokens=512,
        messages=[{"role": "user", "content": prompt}]
    )
    return message.content[0].text
