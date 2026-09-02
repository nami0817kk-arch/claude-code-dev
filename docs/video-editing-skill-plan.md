# 動画編集スキル 導入プラン

Claude が動画編集をできるようにするための計画。2026-09-02 時点の検討記録。

## 決定事項

| 項目 | 決定 | 理由 |
|---|---|---|
| 方式 | **ffmpeg を直接叩く**（Claude Code Skill 化） | 無料・依存が軽い・完全に再現可能・CI で回せる |
| 置き場所 | **`ai-lab`**（`src/videoedit/` + `.claude/skills/video-edit/`） | 汎用の仕組みは PJT に直接書かない、という方針どおり |
| 呼び出し元 | `youtube-video-creation` | 動画の企画・台本はあちら、編集エンジンはこちら |

### 検討して採らなかった方式

| 方式 | 内容 | 採らなかった理由 |
|---|---|---|
| Python 編集ライブラリ（MoviePy 等） | コードでクリップを合成 | 遅い・依存が重い・内部は結局 ffmpeg。凝った合成が要るときだけ後から足せばよい |
| タイムライン出力のみ（EDL / OTIO / Premiere XML） | Claude は編集判断だけ、仕上げは人が DaVinci 等で | 品質は高いが完全自動にならない。Phase 4 以降の選択肢として残す |

`audiogen` が「生成 AI ではなく手続き的合成」を選んだのと同じ判断軸
（依存ゼロ・即座に動く・同じ入力なら同じ出力）を、動画側にも適用する。
ffmpeg は外部バイナリなので **Python の依存パッケージは増えない**。

## 成果物（`ai-lab` に追加するもの）

```
src/videoedit/
  core.py        ffmpeg / ffprobe の実行ラッパ、コマンド組み立て、--dry-run
  probe.py       尺・解像度・fps・音声トラックのメタ情報取得
  clip.py        トリム・カット・連結・速度変更・トランジション
  overlay.py     テロップ(drawtext)・画像/ロゴ合成・ワイプ
  audio.py       BGM ミックス・ダッキング・音量正規化(loudnorm)
  subtitle.py    SRT/ASS の生成と、焼き込み / ソフトサブの切り替え
  timeline.py    台本(YAML/JSON) → ffmpeg コマンド列への変換
  presets.py     書き出しプリセット(YouTube 1080p / Shorts 縦 / 軽量プレビュー)
  thumbnail.py   サムネ用フレーム抽出
  cli.py, __main__.py
.claude/skills/video-edit/SKILL.md   Claude が読む手順書
docs/videoedit.md                    設計メモ（audiogen.md と同じ体裁）
tests/videoedit/                     コマンド組み立ての単体テスト
pyproject.toml                       [project.scripts] に videoedit を追加
```

## CLI の形

`audiogen` と同じく、サブコマンド方式の薄い CLI にする。

```bash
python -m videoedit probe in.mp4                       # メタ情報
python -m videoedit cut in.mp4 --from 00:01:30 --to 00:02:10 -o out.mp4
python -m videoedit concat a.mp4 b.mp4 -o out.mp4 --transition crossfade --duration 0.5
python -m videoedit text in.mp4 --text "ここがポイント" --at 3 --for 4 --pos bottom
python -m videoedit bgm in.mp4 bgm.wav -o out.mp4 --duck --gain -18
python -m videoedit subtitle in.mp4 subs.srt --burn
python -m videoedit export in.mp4 --preset youtube-1080p
python -m videoedit thumb in.mp4 --at 00:00:12
python -m videoedit build script.yaml -o out.mp4       # 台本駆動で一発ビルド
python -m videoedit build script.yaml --dry-run        # 実行せず ffmpeg コマンドだけ表示
```

`--dry-run` を全サブコマンドに付ける。Claude が動画を壊す前に、
組み立てたコマンドを人が確認できるようにするため。

## 台本 YAML の形（Phase 2）

```yaml
output: output/ep01.mp4
preset: youtube-1080p
audio:
  bgm: assets/bgm/calm.wav
  bgm_gain: -18
  duck: true            # ナレーションが乗る所で BGM を下げる
scenes:
  - source: raw/opening.mp4
    trim: [0, 12.5]
    text:
      - { at: 1.0, for: 3.0, value: "今日のテーマ", pos: bottom }
  - source: raw/main.mp4
    trim: [30, 210]
    transition: { type: crossfade, duration: 0.5 }
    narration: assets/tts/main.wav
subtitle:
  file: output/ep01.srt
  burn: true
```

## 実装フェーズ

1 フェーズ = 1 PR。各フェーズ単体で使える状態にして進める。

| フェーズ | 内容 | 完了条件 |
|---|---|---|
| 0 | 環境整備。ffmpeg の導入手順、`core.py` の実行ラッパ、`probe` サブコマンド | `python -m videoedit probe in.mp4` が尺と解像度を返す |
| 1 | 最小編集。`cut` / `concat` / `export` プリセット / `thumb` | 素材2本 → 1本の動画とサムネが出る |
| 2 | 台本駆動。`timeline.py` と `build` サブコマンド、`text` のテロップ | `videoedit build script.yaml` で完成品が出る |
| 3 | 音声。`bgm`（ミックス・ダッキング・loudnorm）と `subtitle`（SRT 焼き込み） | BGM 付き・字幕入りの動画が台本から出る |
| 4 | 連携。ai-lab の画像生成/audiogen をサムネ・BGM に接続、`youtube-video-creation` から呼ぶ | 台本 → 公開用ファイル一式が 1 コマンドで揃う |

字幕の自動生成（Whisper）と TTS ナレーションは Phase 3 の先。
どちらも外部依存が増えるので、pyproject の extras に切り出して既定では入れない。

## テスト方針

CI に ffmpeg が無い前提で組む。

- 中心は **ffmpeg コマンド文字列を組み立てる純粋関数のテスト**。
  実行は `core.py` の 1 箇所に閉じ込め、そこだけモックする。
- 実際に書き出すテストは `@pytest.mark.skipif(shutil.which("ffmpeg") is None)` で任意実行にする。
- `.github/workflows/` に videoedit 用 job を足す。**`paths:` で `src/videoedit/**` に絞る**。

## 環境準備（Windows 11）

```powershell
winget install Gyan.FFmpeg     # または scoop install ffmpeg
ffmpeg -version                # PATH が通っているか確認
```

`core.py` は起動時に `shutil.which("ffmpeg")` を見て、無ければ導入手順を出して終了する。

## 想定されるつまずきと対処

| 問題 | 対処 |
|---|---|
| `drawtext` のエスケープが地獄（`:` `'` `\` 日本語） | テキストは直接埋め込まず `textfile=` でファイル経由にする |
| 長尺の再エンコードが遅い | 切り貼りだけなら `-c copy` でストリームコピー。確認用は低解像度プレビューを別プリセットで出す |
| 日本語が豆腐になる | `fontfile` の明示指定を必須にする。既定値は設定ファイルで持つ（Windows なら `C:/Windows/Fonts/meiryo.ttc`） |
| `filter_complex` が巨大化して読めない・壊れる | シーン単位で中間ファイルに書き出して段階ビルドする。中間物はハッシュでキャッシュし、変更のあったシーンだけ作り直す |
| 素材の解像度・fps がバラバラで連結に失敗 | `concat` の前に共通フォーマットへ正規化する工程を挟む |

## 次にやること

Phase 0 と Phase 1 に着手する。`ai-lab` 側にブランチを切って作業する。
