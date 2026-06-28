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


def _unique_sheet_name(wb: openpyxl.Workbook, name: str) -> str:
    """既存シート名と重複する場合は末尾に _2, _3 ... を付ける"""
    existing = wb.sheetnames
    if name not in existing:
        return name
    i = 2
    while f"{name}_{i}" in existing:
        i += 1
    return f"{name}_{i}"


def _write_sheet(ws, result: dict):
    """1シート分のデータを書き込む"""
    # タイトル
    ws.merge_cells("A1:J1")
    c = ws["A1"]
    c.value     = f"投資推奨レポート　{result.get('flow','')}　{result.get('market','')}　{result.get('date','')}"
    c.font      = Font(bold=True, color="FFFFFF", size=13, name="游ゴシック")
    c.fill      = _fill(C_HEADER)
    c.alignment = Alignment(horizontal="center", vertical="center")
    ws.row_dimensions[1].height = 28

    # ヘッダー
    headers = ["順位", "銘柄コード", "銘柄名", "推奨度", "終値",
               "RSI14", "MACD", "SMA20比", "BB位置", "推奨理由"]
    for col, h in enumerate(headers, 1):
        c = ws.cell(row=2, column=col, value=h)
        c.font      = Font(bold=True, color="FFFFFF", size=10, name="游ゴシック")
        c.fill      = _fill(C_SUBHEAD)
        c.alignment = Alignment(horizontal="center", vertical="center")
        c.border    = _border()
    ws.row_dimensions[2].height = 18

    # ランキング
    for i, item in enumerate(result.get("rankings", []), start=3):
        rank = item.get("rank", i - 2)
        bg   = RANK_COLORS.get(rank, C_DEFAULT)
        _cell(ws, i, 1,  rank,                      bold=True, bg=bg, align="center")
        _cell(ws, i, 2,  item.get("ticker", ""),               bg=bg, align="center")
        _cell(ws, i, 3,  item.get("name", ""),                 bg=bg)
        _cell(ws, i, 4,  item.get("stars", ""),                bg=bg, align="center")
        _cell(ws, i, 5,  item.get("close"),                    bg=bg, align="right")
        _cell(ws, i, 6,  item.get("RSI14"),                    bg=bg, align="center")
        _cell(ws, i, 7,  item.get("MACD方向", ""),             bg=bg, align="center")
        _cell(ws, i, 8,  item.get("SMA20比", ""),              bg=bg, align="center")
        _cell(ws, i, 9,  item.get("BB位置", ""),               bg=bg, align="center")
        _cell(ws, i, 10, item.get("reason", ""),               bg=bg, wrap=True)
        ws.row_dimensions[i].height = 45

    # 総評
    sr = len(result.get("rankings", [])) + 4
    ws.merge_cells(f"A{sr}:J{sr}")
    c = ws.cell(row=sr, column=1, value="【総評】")
    c.font      = Font(bold=True, color="FFFFFF", size=10, name="游ゴシック")
    c.fill      = _fill(C_SUBHEAD)
    c.alignment = Alignment(horizontal="left", vertical="center")
    ws.row_dimensions[sr].height = 16

    sr += 1
    ws.merge_cells(f"A{sr}:J{sr}")
    c = ws.cell(row=sr, column=1, value=result.get("summary", ""))
    c.font      = Font(size=10, name="游ゴシック")
    c.alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)
    c.border    = _border()
    ws.row_dimensions[sr].height = 60

    # 列幅
    for col, w in enumerate([6, 12, 18, 12, 10, 8, 8, 10, 10, 50], 1):
        ws.column_dimensions[get_column_letter(col)].width = w

    ws.freeze_panes = "A3"


def export(result: dict) -> Path:
    """
    結果を 株式投資推奨レポート.xlsx の新シートに追記する。
    シート名: MMDD_HHmm_ニュース / MMDD_HHmm_スクリーニング
    """
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    now       = datetime.now()
    flow_name = "ニュース" if "ニュース" in result.get("flow", "") else "スクリーニング"
    sheet_name = _unique_sheet_name(
        openpyxl.load_workbook(OUTPUT_FILE) if OUTPUT_FILE.exists() else openpyxl.Workbook(),
        now.strftime("%m%d_%H%M_") + flow_name
    )

    if OUTPUT_FILE.exists():
        wb = openpyxl.load_workbook(OUTPUT_FILE)
        # デフォルトの空シートが残っていれば削除
        if "Sheet" in wb.sheetnames and len(wb.sheetnames) == 1:
            del wb["Sheet"]
        ws = wb.create_sheet(title=sheet_name)
    else:
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = sheet_name

    _write_sheet(ws, result)
    wb.save(OUTPUT_FILE)
    return OUTPUT_FILE
