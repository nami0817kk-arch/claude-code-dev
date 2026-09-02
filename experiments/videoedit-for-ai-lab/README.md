# videoedit（ai-lab へ移すためのパッチ）

動画編集スキルの **Phase 0 / 1** の実装一式。中身は `ai-lab` に置くものだが、
作業したセッションで `ai-lab` が**読み取り専用**で attach されていて push できなかったため、
ここに退避してある。

計画は [`../../docs/video-editing-skill-plan.md`](../../docs/video-editing-skill-plan.md)。

## 中身

`0001-feat-videoedit-ffmpeg.patch` は ai-lab の `master` に当たるコミット1本。

| 追加 | 内容 |
|---|---|
| `src/videoedit/` | core / probe / presets / clip / thumbnail / cli |
| `tests/videoedit/` | 単体テスト + 結合テスト（計93件） |
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
git am ../claude-code-dev/experiments/videoedit-for-ai-lab/0001-feat-videoedit-ffmpeg.patch
pytest tests/videoedit
python -m ruff check src/videoedit tests/videoedit
git push -u origin claude/videoedit-phase0-1
```

移し終えたら、このフォルダは消してよい。

## 動作確認の状況

ffmpeg 6.1 を入れた Linux 環境で、テスト93件すべて通っている
（うち9件は実際に ffmpeg を起動する結合テスト）。ruff もクリーン。
Windows では未確認。
