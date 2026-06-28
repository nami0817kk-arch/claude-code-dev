from pathlib import Path
from datetime import datetime
import openpyxl
from openpyxl.styles import PatternFill, Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter

OUTPUT_FILE = (
    Path(__file__).parent.parent.parent / "data" / "reports" / "株式投資推奨レポート.xlsx"
)

C_HEADER  = "1F4E79"
C_SUBHEAD = "2E75B6"
C_TIME    = "243F60"  # 実行時刻ブロックの背景
C_RANK1   = "FFF2CC"
C_RANK2   = "DEEAF1"
C_RANK3   = "E2EFDA"
C_DEFAULT = "F5F5F5"
RANK_COLORS = {1: C_RANK1, 2: C_RANK2, 3: C_RANK3}


def _fill(hex_color: str) -> PatternFill:
    return PatternFill("solid", fgColor=hex_color)


def _border() -> Border:
    s = Side(style="thin", color="CCCCCC")
    return Border(left=s, right=s, top=s, bottom=s)


def _cell(ws, row, col, value, bold=False, bg=None, fg="000000",
          align="left", size=10, wrap=False):
    c = ws.cell(row=row, column=col, value=value)
    c.font      = Font(bold=bold, color=fg, size=size, name="游ゴシック")
    c.alignment = Alignment(horizontal=align, vertical="center", wrap_text=wrap)
    c.border    = _border()
    if bg:
        c.fill = _fill(bg)
    return c


def _last_row(ws) -> int:
    """シートの最終使用行を返す（空なら0）"""
    return ws.max_row if ws.max_row and ws.max_row > 1 else 0


def _write_block(ws, result: dict, start_row: int, now: datetime):
    """1回分の結果ブロックを start_row から書き込む"""
    row = start_row

    # ── 実行時刻ヘッダー ────────────────────────
    ws.merge_cells(f"A{row}:J{row}")
    c = ws.cell(row=row, column=1,
                value=f"実行: {now.strftime('%H:%M')}　{result.get('flow','')}　{result.get('market','')}")
    c.font      = Font(bold=True, color="FFFFFF", size=11, name="游ゴシック")
    c.fill      = _fill(C_TIME)
    c.alignment = Alignment(horizontal="left", vertical="center")
    ws.row_dimensions[row].height = 22
    row += 1

    # ── 列ヘッダー ──────────────────────────────
    headers = ["順位", "銘柄コード", "銘柄名", "推奨度", "終値",
               "RSI14", "MACD", "SMA20比", "BB位置", "推奨理由"]
    for col, h in enumerate(headers, 1):
        c = ws.cell(row=row, column=col, value=h)
        c.font      = Font(bold=True, color="FFFFFF", size=10, name="游ゴシック")
        c.fill      = _fill(C_SUBHEAD)
        c.alignment = Alignment(horizontal="center", vertical="center")
        c.border    = _border()
    ws.row_dimensions[row].height = 18
    row += 1

    # ── ランキング ──────────────────────────────
    for item in result.get("rankings", []):
        rank = item.get("rank", row)
        bg   = RANK_COLORS.get(rank, C_DEFAULT)
        _cell(ws, row, 1,  rank,                   bold=True, bg=bg, align="center")
        _cell(ws, row, 2,  item.get("ticker", ""),            bg=bg, align="center")
        _cell(ws, row, 3,  item.get("name", ""),              bg=bg)
        _cell(ws, row, 4,  item.get("stars", ""),             bg=bg, align="center")
        _cell(ws, row, 5,  item.get("close"),                 bg=bg, align="right")
        _cell(ws, row, 6,  item.get("RSI14"),                 bg=bg, align="center")
        _cell(ws, row, 7,  item.get("MACD方向", ""),          bg=bg, align="center")
        _cell(ws, row, 8,  item.get("SMA20比", ""),           bg=bg, align="center")
        _cell(ws, row, 9,  item.get("BB位置", ""),            bg=bg, align="center")
        _cell(ws, row, 10, item.get("reason", ""),            bg=bg, wrap=True)
        ws.row_dimensions[row].height = 42
        row += 1

    # ── 総評 ────────────────────────────────────
    ws.merge_cells(f"A{row}:J{row}")
    c = ws.cell(row=row, column=1, value="【総評】")
    c.font      = Font(bold=True, color="FFFFFF", size=10, name="游ゴシック")
    c.fill      = _fill(C_SUBHEAD)
    c.alignment = Alignment(horizontal="left", vertical="center")
    ws.row_dimensions[row].height = 16
    row += 1

    ws.merge_cells(f"A{row}:J{row}")
    c = ws.cell(row=row, column=1, value=result.get("summary", ""))
    c.font      = Font(size=10, name="游ゴシック")
    c.alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)
    c.border    = _border()
    ws.row_dimensions[row].height = 55
    row += 1

    return row  # 次のブロック開始行を返す


def export(result: dict) -> Path:
    """
    結果を 株式投資推奨レポート.xlsx に書き込む。
    - シート名: YYYYMMDD（1日1シート）
    - 同日に複数回実行した場合は同シートに追記
    """
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    now        = datetime.now()
    sheet_name = now.strftime("%Y%m%d")

    if OUTPUT_FILE.exists():
        wb = openpyxl.load_workbook(OUTPUT_FILE)
    else:
        wb = openpyxl.Workbook()
        # デフォルトシートを削除
        if "Sheet" in wb.sheetnames:
            del wb["Sheet"]

    # 当日シートがあれば取得、なければ作成
    if sheet_name in wb.sheetnames:
        ws = wb[sheet_name]
        start_row = _last_row(ws) + 2  # 1行空けて追記
    else:
        ws = wb.create_sheet(title=sheet_name)
        # シートタイトル行
        ws.merge_cells("A1:J1")
        c = ws["A1"]
        c.value     = f"投資推奨レポート　{now.strftime('%Y年%m月%d日')}"
        c.font      = Font(bold=True, color="FFFFFF", size=14, name="游ゴシック")
        c.fill      = _fill(C_HEADER)
        c.alignment = Alignment(horizontal="center", vertical="center")
        ws.row_dimensions[1].height = 30
        # 列幅
        for col, w in enumerate([6, 12, 18, 12, 10, 8, 8, 10, 10, 50], 1):
            ws.column_dimensions[get_column_letter(col)].width = w
        ws.freeze_panes = "A3"
        start_row = 2

    _write_block(ws, result, start_row, now)
    wb.save(OUTPUT_FILE)
    return OUTPUT_FILE
