"""副業アイデアの生成とスコアリング。

Claude が案を出し、適合スコアはこちら側の式で決定的に計算する。
「なぜこの順位なのか」を数字で説明できるようにするため。
"""
from . import llm, store

NAME = "ideas"

# スコア配点（合計 100）
WEIGHTS = {
    "skill":       25,   # 今のスキルで戦えるか
    "time":        20,   # 週の稼働時間に収まるか
    "capital":     15,   # 初期投資が予算内か
    "speed":       15,   # 初報酬までが期限内か
    "ceiling":     15,   # 目標月収に届く天井があるか
    "competition": 10,   # 競合の少なさ
}

SYSTEM = """あなたは日本の副業・スモールビジネスに詳しい事業コンサルタントです。
AI（生成AI）を活用した副業の立ち上げを支援します。

守ること:
- 相談者のスキル・稼働時間・予算の範囲で「本当に始められる」案だけを出す
- 「AIで稼げる」といった曖昧な案ではなく、誰に何をいくらで売るかまで具体化する
- 情報商材の転売や、実体のない高額塾のような案は出さない
- 日本国内の実情（クラウドソーシング、SNS、副業規定、確定申告）を前提にする"""

PROMPT = """次のプロフィールの人が、生成AIを活用して始められる副業アイデアを {n} 個提案してください。

## プロフィール
{profile}

## 出力形式
以下のキーを持つオブジェクトの JSON 配列だけを出力してください。

- name: アイデア名（20文字以内）
- category: 種別（受託 / コンテンツ / 商品販売 / ツール提供 / 代行 のいずれか）
- summary: 内容の説明（80文字程度）
- target: 顧客像と、解決する困りごと
- revenue_model: 収益の上げ方（単価×件数の形で）
- price_range: 想定単価（例「1件 30,000〜50,000円」）
- startup_cost: 初期費用の目安（円・整数）
- hours_per_week: 必要な週稼働時間（整数）
- months_to_first_sale: 初報酬までの月数（整数）
- monthly_potential: 軌道に乗った場合の月収目安（円・整数）
- skill_match: このプロフィールのスキルとの合致度（1〜5の整数）
- competition: 競合の激しさ（1〜5の整数。5が最も激しい）
- ai_leverage: AI活用による優位性（1〜5の整数）
- first_step: 最初の1週間でやること（1文）
- risks: 想定リスクの配列（2〜3個）
- tools: 使うツールの配列（3〜5個）
"""


def _ratio(value, limit, higher_is_better=True):
    """0〜1 に正規化する。limit を基準に、超過/未達をなだらかに評価する。"""
    if not limit:
        return 0.5
    if value is None:
        return 0.5
    r = value / limit
    if higher_is_better:
        return min(r, 1.0)
    # 小さいほど良い項目: 基準内なら満点、超えるほど減点
    return 1.0 if r <= 1 else max(0.0, 1.0 - (r - 1))


def score(idea: dict, prof: dict) -> dict:
    """アイデアの適合スコア（0〜100）と内訳を返す。"""
    parts = {
        "skill":       _ratio(idea.get("skill_match", 3), 5),
        "time":        _ratio(idea.get("hours_per_week"), prof["hours_per_week"], higher_is_better=False),
        "capital":     _ratio(idea.get("startup_cost"), prof["budget"] or 1, higher_is_better=False),
        "speed":       _ratio(idea.get("months_to_first_sale"), prof["deadline_months"], higher_is_better=False),
        "ceiling":     _ratio(idea.get("monthly_potential"), prof["target_income"]),
        "competition": _ratio(6 - idea.get("competition", 3), 5),
    }
    breakdown = {k: round(WEIGHTS[k] * v, 1) for k, v in parts.items()}
    return {"total": round(sum(breakdown.values()), 1), "breakdown": breakdown}


def stars(total: float) -> str:
    """スコアを星 5 段階に変換する。"""
    n = max(1, min(5, int(total // 20) + (1 if total % 20 else 0)))
    return "★" * n + "☆" * (5 - n)


def generate(prof: dict, n: int = 6) -> list:
    """Claude にアイデアを出させ、スコア順に並べて保存する。"""
    from . import profile as profile_mod

    raw = llm.ask_json(
        PROMPT.format(n=n, profile=profile_mod.summary_text(prof)),
        system=SYSTEM,
        max_tokens=6000,
    )
    if isinstance(raw, dict):
        raw = raw.get("ideas", [raw])

    ideas = []
    for item in raw:
        if not isinstance(item, dict) or "name" not in item:
            continue
        item["score"] = score(item, prof)
        ideas.append(item)

    ideas.sort(key=lambda x: x["score"]["total"], reverse=True)
    for i, item in enumerate(ideas, 1):
        item["id"] = i

    store.save(NAME, {"generated_at": store.now(), "ideas": ideas})
    return ideas


def load() -> list:
    return store.load(NAME, {}).get("ideas", [])


def find(idea_id: int) -> dict:
    for item in load():
        if item["id"] == int(idea_id):
            return item
    return None


LABELS = {
    "skill": "スキル適合", "time": "稼働時間", "capital": "初期費用",
    "speed": "収益化速度", "ceiling": "収益の天井", "competition": "競合の少なさ",
}


def print_ideas(ideas: list, detail: bool = False):
    if not ideas:
        print("アイデアがまだありません。`python main.py ideas` を実行してください。")
        return

    print(f"\n{'='*70}")
    print("  AI 副業アイデア  適合スコア順")
    print(f"{'='*70}")
    for item in ideas:
        sc = item["score"]
        print(f"\n[{item['id']}] {item['name']}  {stars(sc['total'])} {sc['total']}点  <{item.get('category','-')}>")
        print(f"    {item.get('summary','')}")
        print(f"    単価 {item.get('price_range','-')} / 週 {item.get('hours_per_week','-')}h "
              f"/ 初期費用 {item.get('startup_cost',0):,}円 / 初報酬まで {item.get('months_to_first_sale','-')}ヶ月")
        print(f"    月収目安 {item.get('monthly_potential',0):,}円  AI活用度 {'●'*item.get('ai_leverage',0)}")
        if detail:
            print(f"    ターゲット : {item.get('target','')}")
            print(f"    収益モデル : {item.get('revenue_model','')}")
            print(f"    最初の一歩 : {item.get('first_step','')}")
            print(f"    ツール     : {'、'.join(item.get('tools', []))}")
            for r in item.get("risks", []):
                print(f"    リスク     : {r}")
            inner = "  ".join(f"{LABELS[k]}{v}" for k, v in sc["breakdown"].items())
            print(f"    スコア内訳 : {inner}")
    print(f"\n{'='*70}")
    print("  詳しく見る: python main.py research <番号>   計画を作る: python main.py plan <番号>")
    print(f"{'='*70}")
