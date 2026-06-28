import argparse
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / ".env")

from src.data.fetcher import fetch_price, fetch_info, save_price
from src.analysis.indicators import add_indicators
from src.report.chart import candlestick
from src.report.news import fetch_news, fetch_market_news, analyze_news
from src.analysis.screener import screen, load_watchlist
from src.selector import pick_from_news, pick_from_screen


def cmd_chart(args):
    print(f"取得中: {args.ticker} ({args.period})")
    df = fetch_price(args.ticker, period=args.period)
    if df.empty:
        print("データが取得できませんでした。ticker を確認してください。")
        sys.exit(1)

    df = add_indicators(df)

    # 直近 20 日分を表形式で表示
    display_cols = ["Close", "SMA20", "SMA75", "RSI14", "MACD", "BB_upper", "BB_lower"]
    display = df[display_cols].tail(20).copy()
    display.index = display.index.strftime("%Y-%m-%d")
    display = display.round(2)
    display.columns = ["終値", "SMA20", "SMA75", "RSI14", "MACD", "BB上限", "BB下限"]

    print(f"\n{'='*70}")
    print(f"  {args.ticker}  直近20日データ")
    print(f"{'='*70}")
    print(display.to_string())
    print(f"{'='*70}")

    latest = df.iloc[-1]
    print(f"\n【最新シグナル】")
    rsi = latest["RSI14"]
    rsi_sig = "売られすぎ" if rsi < 30 else "買われすぎ" if rsi > 70 else "中立"
    macd_sig = "買いシグナル" if latest["MACD"] > latest["MACD_signal"] else "売りシグナル"
    print(f"  RSI14 : {rsi:.1f}  → {rsi_sig}")
    print(f"  MACD  : {macd_sig}")

    if args.save:
        path = save_price(df, args.ticker)
        print(f"\nCSV 保存: {path}")

    if args.chart:
        fig = candlestick(df, args.ticker)
        fig.show()


def cmd_info(args):
    print(f"銘柄情報を取得中: {args.ticker}")
    info = fetch_info(args.ticker)
    fields = ["longName", "sector", "industry", "marketCap",
              "trailingPE", "dividendYield", "fiftyTwoWeekHigh", "fiftyTwoWeekLow"]
    print()
    for f in fields:
        val = info.get(f)
        if val is not None:
            if f == "marketCap":
                val = f"{val:,.0f}"
            elif f == "dividendYield" and val:
                val = f"{val*100:.2f}%"
            print(f"  {f:<20}: {val}")


def cmd_pick_news(args):
    print(f"\n{'='*70}")
    print(f"  自動株選定 ニュース起点  対象:{args.market or '日米全銘柄'}")
    print(f"{'='*70}\n")
    result = pick_from_news(market=args.market, top_n=args.top)
    print(f"\n{result}\n")
    print(f"{'='*70}")


def cmd_pick_screen(args):
    print(f"\n{'='*70}")
    print(f"  自動株選定 スクリーニング起点  対象:{args.market or '日米全銘柄'}")
    print(f"{'='*70}\n")
    result = pick_from_screen(market=args.market, top_n=args.top)
    print(f"\n{result}\n")
    print(f"{'='*70}")


def cmd_screen(args):
    print(f"スクリーニング中... (対象: {args.market or '全銘柄'})")
    print(f"条件: RSI {args.min_rsi}〜{args.max_rsi}", end="")
    if args.macd:
        print(f"  MACD:{args.macd}", end="")
    if args.below_sma20:
        print("  終値<SMA20", end="")
    if args.above_sma20:
        print("  終値>SMA20", end="")
    print()

    df = screen(
        market      = args.market,
        min_rsi     = args.min_rsi,
        max_rsi     = args.max_rsi,
        macd_signal = args.macd,
        below_sma20 = args.below_sma20,
        above_sma20 = args.above_sma20,
    )

    print(f"\n{'='*70}")
    if df.empty:
        print("  条件に合う銘柄が見つかりませんでした。")
    else:
        print(f"  {len(df)} 件ヒット")
        print(f"{'='*70}")
        print(df.to_string(index=False))
    print(f"{'='*70}")


def cmd_news(args):
    print(f"ニュース取得中: {args.ticker}")
    items = fetch_news(args.ticker, max_items=10)

    if not items:
        print(f"  '{args.ticker}' 関連のニュースが見つかりませんでした。市況ニュースを取得します。")
        items = fetch_market_news(max_items=8)

    print(f"\n{'='*70}")
    print(f"  {args.ticker}  関連ニュース ({len(items)} 件)")
    print(f"{'='*70}")
    for i, n in enumerate(items, 1):
        print(f"\n[{i}] {n['title']}")
        print(f"    出典: {n['source']}  {n['published'][:16]}")
        if n["summary"]:
            print(f"    {n['summary'][:100]}...")
        print(f"    {n['link']}")

    if not args.no_analysis and items:
        print(f"\n{'='*70}")
        print("  Claude による投資分析")
        print(f"{'='*70}")
        result = analyze_news(items, args.ticker)
        print(result)

    print(f"\n{'='*70}")


def main():
    parser = argparse.ArgumentParser(description="株価分析ツール")
    sub = parser.add_subparsers(dest="command")

    # chart コマンド
    p_chart = sub.add_parser("chart", help="株価チャートを表示")
    p_chart.add_argument("ticker", help="例: 7203.T (トヨタ) / AAPL")
    p_chart.add_argument("--period", default="6mo",
                         help="期間: 1mo 3mo 6mo 1y 2y (デフォルト: 6mo)")
    p_chart.add_argument("--save", action="store_true", help="CSV に保存する")
    p_chart.add_argument("--chart", action="store_true", help="グラフも表示する")

    # info コマンド
    p_info = sub.add_parser("info", help="銘柄基本情報を表示")
    p_info.add_argument("ticker", help="例: 7203.T / AAPL")

    # pick-news コマンド
    p_pn = sub.add_parser("pick-news", help="ニュース起点の自動株選定")
    p_pn.add_argument("--market", choices=["JP", "US"], help="市場絞り込み (JP/US)")
    p_pn.add_argument("--top", type=int, default=5, help="推奨件数 (デフォルト:5)")

    # pick-screen コマンド
    p_ps = sub.add_parser("pick-screen", help="スクリーニング起点の自動株選定")
    p_ps.add_argument("--market", choices=["JP", "US"], help="市場絞り込み (JP/US)")
    p_ps.add_argument("--top", type=int, default=5, help="推奨件数 (デフォルト:5)")

    # screen コマンド
    p_screen = sub.add_parser("screen", help="条件でスクリーニング")
    p_screen.add_argument("--market", choices=["JP", "US"], help="市場絞り込み (JP/US)")
    p_screen.add_argument("--min-rsi", type=float, default=0,   dest="min_rsi", help="RSI 下限 (デフォルト:0)")
    p_screen.add_argument("--max-rsi", type=float, default=100, dest="max_rsi", help="RSI 上限 (デフォルト:100)")
    p_screen.add_argument("--macd",    choices=["buy", "sell"],  help="MACD方向 buy/sell")
    p_screen.add_argument("--below-sma20", action="store_true", dest="below_sma20", help="終値がSMA20を下回る")
    p_screen.add_argument("--above-sma20", action="store_true", dest="above_sma20", help="終値がSMA20を上回る")

    # news コマンド
    p_news = sub.add_parser("news", help="ニュース収集 + Claude 分析")
    p_news.add_argument("ticker", help="例: 7203.T / AAPL")
    p_news.add_argument("--no-analysis", action="store_true", help="Claude 分析をスキップ")

    args = parser.parse_args()

    if args.command == "chart":
        cmd_chart(args)
    elif args.command == "info":
        cmd_info(args)
    elif args.command == "pick-news":
        cmd_pick_news(args)
    elif args.command == "pick-screen":
        cmd_pick_screen(args)
    elif args.command == "screen":
        cmd_screen(args)
    elif args.command == "news":
        cmd_news(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
