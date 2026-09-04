# videoedit（ai-lab へ移すためのパッチ）

動画編集スキルの **Phase 0 / 1 / 2 / 3** の実装一式。中身は `ai-lab` に置くものだが、
作業したセッションで `ai-lab` が**読み取り専用**で attach されていて push できなかったため、
ここに退避してある。

計画は [`../../docs/video-editing-skill-plan.md`](../../docs/video-editing-skill-plan.md)。

## 中身

ai-lab の `master` にそのまま当たるコミット3本。

| パッチ | 内容 |
|---|---|
| `0001-feat-videoedit-ffmpeg.patch` | Phase 0/1: probe / cut / concat / export / thumb |
| `0002-feat-videoedit.patch` | Phase 2: text（テロップ）/ build（台本駆動） |
| `0003-feat-videoedit-BGM.patch` | Phase 3: bgm / normalize / subtitle と台本への統合 |

| 追加 | 内容 |
|---|---|
| `src/videoedit/` | core / probe / presets / clip / overlay / audio / subtitle / timeline / thumbnail / cli |
| `tests/videoedit/` | 単体テスト + 結合テスト（計226件） |
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

ffmpeg 6.1 を入れた Linux 環境で、テスト226件すべて通っている
（うち24件は実際に ffmpeg を起動する結合テスト）。ruff もクリーン。
`master` にパッチを当てた状態でも同じことを確認済み。

出来上がりの中身も実測で確かめてある。

- 音量: `normalize` 後 -13.99 LUFS、台本フル構成のビルドで -14.06 LUFS（目標 -14）
- ダッキング: しゃべり続ける素材に BGM を 0dB で重ね、無しが +3.3dB、有りが +1.0dB
- 日本語のテロップと字幕: 書き出した動画からフレームを抜いて目視で確認

**Windows では未確認**（フォントのパスと `winget` での ffmpeg 導入のみ、コード側で対応済み）。
