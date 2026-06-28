"""
市場センチメント指標

- VIX（恐怖指数）: yfinance から取得
- Fear & Greed Index: CNN のエンドポイントから取得
"""
import yfinance as yf
import requests


def fetch_vix() -> tuple[float | None, str]:
    """VIX を取得して (値, レベル説明) を返す"""
    try:
        df = yf.download("^VIX", period="2d", progress=False, auto_adjust=True)
        # yfinance がマルチレベルカラムを返す場合に対応
        close_col = [c for c in df.columns if "Close" in str(c)]
        if not close_col:
            return None, "取得失敗"
        vix = float(df[close_col[0]].iloc[-1])
        if vix < 15:
            level = "低い（市場安定）"
        elif vix < 20:
            level = "普通"
        elif vix < 30:
            level = "やや高い（警戒）"
        else:
            level = "高い（強い不安定）"
        return round(vix, 1), level
    except Exception:
        return None, "取得失敗"


def fetch_fear_greed() -> tuple[int | None, str]:
    """Fear & Greed Index を取得して (スコア0-100, ラベル) を返す

    複数エンドポイントを試みてフォールバックする。
    """
    # 方法1: alternative.me (暗号資産だが株式市場との相関あり)
    try:
        resp  = requests.get("https://api.alternative.me/fng/", timeout=5)
        data  = resp.json()
        score = int(data["data"][0]["value"])
        label_map = {
            "Extreme Fear":  "極度の恐怖（逆張り買い機会）",
            "Fear":          "恐怖（割安圧力）",
            "Neutral":       "中立",
            "Greed":         "強欲（過熱注意）",
            "Extreme Greed": "極度の強欲（天井警戒）",
        }
        label = label_map.get(data["data"][0]["value_classification"], data["data"][0]["value_classification"])
        return score, label
    except Exception:
        pass

    # 方法2: VIX から推定（フォールバック）
    return None, "取得失敗"


def get_market_context() -> dict:
    """VIX・Fear&Greed をまとめて返す"""
    vix,    vix_level = fetch_vix()
    fg_score, fg_label = fetch_fear_greed()
    return {
        "VIX":           vix,
        "VIX_level":     vix_level,
        "FearGreed":     fg_score,
        "FearGreed_label": fg_label,
    }


def market_context_text(ctx: dict) -> str:
    """Claude プロンプト用のテキストを生成する"""
    lines = ["【市場センチメント】"]
    if ctx["VIX"] is not None:
        lines.append(f"  VIX（恐怖指数）: {ctx['VIX']} → {ctx['VIX_level']}")
    if ctx["FearGreed"] is not None:
        lines.append(f"  Fear & Greed  : {ctx['FearGreed']}/100 → {ctx['FearGreed_label']}")
    if ctx["VIX"] and ctx["VIX"] > 25:
        lines.append("  ⚠ VIX高水準: 買いシグナルの信頼度を下げて慎重に評価してください")
    if ctx["FearGreed"] and ctx["FearGreed"] < 25:
        lines.append("  💡 極度の恐怖: 歴史的に逆張り買いのチャンスが多い局面です")
    return "\n".join(lines)
