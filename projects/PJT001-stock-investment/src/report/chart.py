import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd


def candlestick(df: pd.DataFrame, ticker: str) -> go.Figure:
    """ローソク足 + SMA + BB + RSI + MACD の複合チャートを生成する"""
    fig = make_subplots(
        rows=3, cols=1,
        shared_xaxes=True,
        vertical_spacing=0.04,
        row_heights=[0.6, 0.2, 0.2],
        subplot_titles=(ticker, "RSI", "MACD"),
    )

    # ローソク足
    fig.add_trace(go.Candlestick(
        x=df.index, open=df["Open"], high=df["High"],
        low=df["Low"], close=df["Close"], name="価格",
        increasing_line_color="#26a69a", decreasing_line_color="#ef5350",
    ), row=1, col=1)

    # SMA
    for col, color in [("SMA20", "#2196F3"), ("SMA75", "#FF9800")]:
        if col in df.columns:
            fig.add_trace(go.Scatter(
                x=df.index, y=df[col], name=col,
                line=dict(color=color, width=1),
            ), row=1, col=1)

    # ボリンジャーバンド
    if "BB_upper" in df.columns:
        fig.add_trace(go.Scatter(
            x=df.index, y=df["BB_upper"], name="BB上限",
            line=dict(color="gray", width=1, dash="dot"),
        ), row=1, col=1)
        fig.add_trace(go.Scatter(
            x=df.index, y=df["BB_lower"], name="BB下限",
            line=dict(color="gray", width=1, dash="dot"),
            fill="tonexty", fillcolor="rgba(128,128,128,0.1)",
        ), row=1, col=1)

    # RSI
    if "RSI14" in df.columns:
        fig.add_trace(go.Scatter(
            x=df.index, y=df["RSI14"], name="RSI14",
            line=dict(color="#9C27B0", width=1),
        ), row=2, col=1)
        for level, color in [(70, "red"), (30, "green")]:
            fig.add_hline(y=level, line_dash="dot", line_color=color,
                          opacity=0.6, row=2, col=1)

    # MACD
    if "MACD" in df.columns:
        fig.add_trace(go.Scatter(
            x=df.index, y=df["MACD"], name="MACD",
            line=dict(color="#00BCD4", width=1),
        ), row=3, col=1)
        fig.add_trace(go.Scatter(
            x=df.index, y=df["MACD_signal"], name="Signal",
            line=dict(color="#FF5722", width=1),
        ), row=3, col=1)
        macd_hist = df["MACD"] - df["MACD_signal"]
        fig.add_trace(go.Bar(
            x=df.index, y=macd_hist, name="Hist",
            marker_color=macd_hist.apply(
                lambda v: "#26a69a" if v >= 0 else "#ef5350"
            ),
        ), row=3, col=1)

    fig.update_layout(
        template="plotly_dark",
        xaxis_rangeslider_visible=False,
        height=800,
        legend=dict(orientation="h", yanchor="bottom", y=1.02),
    )
    fig.update_yaxes(title_text="RSI", row=2, col=1, range=[0, 100])
    fig.update_yaxes(title_text="MACD", row=3, col=1)

    return fig
