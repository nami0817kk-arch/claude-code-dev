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

    args = parser.parse_args()

    if args.command == "chart":
        cmd_chart(args)
    elif args.command == "info":
        cmd_info(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
