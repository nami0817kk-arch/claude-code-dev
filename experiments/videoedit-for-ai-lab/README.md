# videoedit（ai-lab へ移すためのパッチ）

動画編集スキルの **Phase 0 / 1 / 2** の実装一式。中身は `ai-lab` に置くものだが、
作業したセッションで `ai-lab` が**読み取り専用**で attach されていて push できなかったため、
ここに退避してある。

計画は [`../../docs/video-editing-skill-plan.md`](../../docs/video-editing-skill-plan.md)。

## 中身

ai-lab の `master` にそのまま当たるコミット2本。

| パッチ | 内容 |
|---|---|
| `0001-feat-videoedit-ffmpeg.patch` | Phase 0/1: probe / cut / concat / export / thumb |
| `0002-feat-videoedit.patch` | Phase 2: text（テロップ）/ build（台本駆動） |

| 追加 | 内容 |
|---|---|
| `src/videoedit/` | core / probe / presets / clip / overlay / timeline / thumbnail / cli |
| `tests/videoedit/` | 単体テスト + 結合テスト（計171件） |
| `.claude/skills/video-edit/SKILL.md` | Claude が読む手順書 |
| `docs/videoedit.md` | 設計メモ |

| 変更 | 内容 |
|---|---|
| `pyproject.toml` | `videoedit` の console script、`integration` マーカー |
| `.github/workflows/tests.yml` | ruff の対象に videoedit を追加 |
| `README.md` / `CLAUDE.md` | videoedit の節を追加 |

## 移し方

```bash
cd ../ai-lab                     # dev/ 直下に並んでいる ai-lab
git checkout -b claude/videoedit-phase0-1 master
git am ../claude-code-dev/experiments/videoedit-for-ai-lab/*.patch
pytest tests/videoedit
python -m ruff check src/videoedit tests/videoedit
git push -u origin claude/videoedit-phase0-1
```

移し終えたら、このフォルダは消してよい。

## 動作確認の状況

ffmpeg 6.1 を入れた Linux 環境で、テスト171件すべて通っている
（うち15件は実際に ffmpeg を起動する結合テスト）。ruff もクリーン。
`master` にパッチを当てた状態でも同じことを確認済み。

日本語テロップの焼き込みは、書き出した動画からフレームを抜いて目視でも確認した。
**Windows では未確認**（フォントのパスと `winget` での ffmpeg 導入のみ、コード側で対応済み）。
