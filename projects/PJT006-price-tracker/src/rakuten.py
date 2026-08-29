"""楽天ウェブサービスのクライアント。

この環境からは楽天へ到達できない（ネットワークポリシーで遮断）ため、
実際の通信は GitHub Actions 上でのみ行う。ここでは
- レスポンス形の揺れを吸収する解釈処理
- 1秒1回のリクエスト制限の遵守
をテストで検証できるように、通信と解釈を分けて実装する。
"""
import json
import os
import time
import urllib.parse
import urllib.request

SEARCH_URL = "https://app.rakuten.co.jp/services/api/IchibaItem/Search/20220601"
GENRE_URL = "https://app.rakuten.co.jp/services/api/IchibaGenre/Search/20120723"

# 楽天の制限は「1アプリIDにつき1秒1回」。余裕を持たせる。
MIN_INTERVAL = 1.1
MAX_HITS = 30          # 1リクエストで取れる上限
MAX_PAGE = 100


class RakutenError(RuntimeError):
    pass


def credentials() -> tuple[str, str]:
    """アプリIDとアフィリエイトIDを環境変数から読む。

    アプリIDはリクエストURLに乗る準公開の識別子だが、それでもリポジトリには置かない。
    GitHub Actions のシークレットから環境変数として渡す。
    """
    app_id = os.environ.get("RAKUTEN_APP_ID", "").strip()
    if not app_id:
        raise RakutenError(
            "RAKUTEN_APP_ID が設定されていません。"
            "GitHub のリポジトリ設定 > Secrets and variables > Actions に登録してください。")
    return app_id, os.environ.get("RAKUTEN_AFFILIATE_ID", "").strip()


class Throttle:
    """最後のリクエストから MIN_INTERVAL 秒空ける。"""

    def __init__(self, interval: float = MIN_INTERVAL, sleep=time.sleep, clock=time.monotonic):
        self.interval = interval
        self._sleep = sleep
        self._clock = clock
        self._last = None

    def wait(self) -> float:
        now = self._clock()
        if self._last is None:
            self._last = now
            return 0.0
        delay = self.interval - (now - self._last)
        if delay > 0:
            self._sleep(delay)
            self._last = self._clock()
            return delay
        self._last = now
        return 0.0


def item_of(entry: dict) -> dict:
    """API のバージョンによって Items の要素が
    {"Item": {...}} だったり {...} そのものだったりするので吸収する。
    """
    if isinstance(entry, dict) and isinstance(entry.get("Item"), dict):
        return entry["Item"]
    return entry if isinstance(entry, dict) else {}


def _first_image(item: dict) -> str:
    for key in ("mediumImageUrls", "smallImageUrls"):
        urls = item.get(key) or []
        for u in urls:
            url = u.get("imageUrl") if isinstance(u, dict) else u
            if url:
                # 末尾の ?_ex=128x128 を外すと大きい画像が得られる
                return str(url).split("?")[0]
    return ""


def parse_items(payload: dict) -> list[dict]:
    """検索レスポンスを、こちらで扱う形に正規化する。

    価格が取れない・商品コードが無い要素は捨てる。あとの計算がすべて
    価格に依存するので、ここで落としておかないと壊れた行が下流に流れる。
    """
    out = []
    for entry in payload.get("Items") or []:
        item = item_of(entry)
        code = str(item.get("itemCode") or "").strip()
        try:
            price = int(item.get("itemPrice"))
        except (TypeError, ValueError):
            continue
        if not code or price <= 0:
            continue
        try:
            review_average = float(item.get("reviewAverage") or 0)
        except (TypeError, ValueError):
            review_average = 0.0
        try:
            review_count = int(item.get("reviewCount") or 0)
        except (TypeError, ValueError):
            review_count = 0
        out.append({
            "item_code": code,
            "name": str(item.get("itemName") or "").strip(),
            "price": price,
            "shop": str(item.get("shopName") or "").strip(),
            # affiliateUrl はアフィリエイトIDを渡したときだけ返る。
            # 無ければ通常URLにフォールバックする（収益は出ないが表示は壊れない）。
            "url": str(item.get("affiliateUrl") or item.get("itemUrl") or "").strip(),
            "is_affiliate": bool(item.get("affiliateUrl")),
            "image": _first_image(item),
            "review_count": review_count,
            "review_average": review_average,
            "genre_id": str(item.get("genreId") or "").strip(),
        })
    return out


def _get(url: str, params: dict, throttle: Throttle, opener=urllib.request.urlopen) -> dict:
    query = urllib.parse.urlencode({k: v for k, v in params.items() if v not in (None, "")})
    throttle.wait()
    req = urllib.request.Request(f"{url}?{query}", headers={"User-Agent": "price-tracker/1.0"})
    with opener(req, timeout=30) as res:
        return json.loads(res.read().decode("utf-8"))


def search_genre(genre_id: str, hits: int, throttle: Throttle,
                 opener=urllib.request.urlopen) -> list[dict]:
    """ジャンル内の商品を売れ筋順に hits 件ぶん取る。"""
    app_id, affiliate_id = credentials()
    items, page = [], 1
    while len(items) < hits and page <= MAX_PAGE:
        payload = _get(SEARCH_URL, {
            "applicationId": app_id,
            "affiliateId": affiliate_id,
            "genreId": genre_id,
            "hits": min(MAX_HITS, hits - len(items)),
            "page": page,
            "sort": "standard",
            "format": "json",
            "formatVersion": 2,
        }, throttle, opener)
        batch = parse_items(payload)
        if not batch:
            break
        items.extend(batch)
        if page >= int(payload.get("pageCount") or 1):
            break
        page += 1
    return items[:hits]


def genre_children(genre_id: str, throttle: Throttle,
                   opener=urllib.request.urlopen) -> list[dict]:
    """ジャンルの直下の子ジャンルを返す。狙う分野をデータから決めるために使う。"""
    app_id, _ = credentials()
    payload = _get(GENRE_URL, {
        "applicationId": app_id,
        "genreId": genre_id,
        "format": "json",
        "formatVersion": 2,
    }, throttle, opener)
    out = []
    for child in payload.get("children") or []:
        node = child.get("child") if isinstance(child.get("child"), dict) else child
        gid = str(node.get("genreId") or "").strip()
        if gid:
            out.append({"genre_id": gid, "name": str(node.get("genreName") or "").strip()})
    return out
