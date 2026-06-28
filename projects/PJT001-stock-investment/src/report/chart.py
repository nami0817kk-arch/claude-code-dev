import plotly.graph_objects as go
import pandas as pd


def candlestick(df: pd.DataFrame, ticker: str) -> go.Figure:
    """ローソク足チャートに SMA・BB を重ねて表示する"""
    fig = go.Figure()

    fig.add_trace(go.Candlestick(
        x=df.index, open=df["Open"], high=df["High"],
        low=df["Low"], close=df["Close"], name=ticker
    ))

    for col, color in [("SMA20", "blue"), ("SMA75", "orange"),
                       ("BB_upper", "gray"), ("BB_lower", "gray")]:
        if col in df.columns:
            fig.add_trace(go.Scatter(
                x=df.index, y=df[col], name=col,
                line=dict(color=color, width=1, dash="dot" if "BB" in col else "solid")
            ))

    fig.update_layout(title=ticker, xaxis_rangeslider_visible=False,
                      template="plotly_dark")
    return fig


def portfolio_pie(summary_df: pd.DataFrame) -> go.Figure:
    """ポートフォリオの時価構成比をパイチャートで表示する"""
    fig = go.Figure(go.Pie(
        labels=summary_df["name"],
        values=summary_df["value"],
        hole=0.4
    ))
    fig.update_layout(title="ポートフォリオ構成", template="plotly_dark")
    return fig
