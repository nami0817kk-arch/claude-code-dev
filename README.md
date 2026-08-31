# claude-code-dev

Claude Code での開発ワークスペース。複数プロジェクトを1リポジトリにまとめている。

## プロジェクト一覧

| プロジェクト | 内容 | 技術 | 状態 |
|---|---|---|---|
| [PJT001-stock-investment](projects/PJT001-stock-investment/) | 日本株・米国株の投資支援（取得・指標・スクリーニング・レポート） | Python | 開発中 |
| [PJT002-ai-blog](projects/PJT002-ai-blog/) | AI活用のブログ生成・運営 | 未定 | 雛形のみ |
| [PJT003-soccer-manager](projects/PJT003-soccer-manager/) | サッカークラブ経営シミュレーション | Flutter + Flame | 開発中・Web版公開中 |

## フォルダ構成

| フォルダ | 用途 |
|---|---|
| `projects/` | 本格的なプロジェクトを配置 |
| `experiments/` | 試作・アイデア検証用 |
| `scripts/` | 繰り返し使う便利スクリプト |
| `templates/` | 新規プロジェクトのひな型 |
| `docs/` | メモ・調査記録 |

各プロジェクトの動かし方は、それぞれの README を見る。
このリポジトリ直下には共通のビルド設定は無く、プロジェクトごとに独立している。

## CI

`.github/workflows/` にプロジェクト単位のワークフローを置いている。
モノレポなので、**必ず `paths:` で対象プロジェクトに絞る**。
絞らないと、無関係な変更のたびに全プロジェクトのCIが回る。

| ワークフロー | 対象 |
|---|---|
| `pjt001-tests.yml` | PJT001 のテスト |
| `soccer-manager-web.yml` | PJT003 の Web版ビルドと GitHub Pages へのデプロイ |

## 新しいプロジェクトを始める

```bash
cd projects
mkdir PJT00X-name && cd PJT00X-name
```

README と CLAUDE.md を先に置くと、後から自分でも Claude でも辿りやすい。

## 環境

- OS: Windows 11
- Shell: PowerShell / Git Bash 両方利用可能
