# claude-code-dev

Claude Code での開発ワークスペース。

ここで持つのは PJT001 と PJT002 だけで、他のプロジェクトは独立したリポジトリとして
このリポジトリと同じ親フォルダに並べてある。プロジェクトが単独で運用できるように
なったら `projects/` から切り出し、その時点で PJT の採番は外す。

## プロジェクト一覧

| プロジェクト | 内容 | 技術 | 状態 |
|---|---|---|---|
| [PJT001-stock-investment](projects/PJT001-stock-investment/) | 日本株・米国株の投資支援（取得・指標・スクリーニング・レポート） | Python | 開発中 |
| [PJT002-ai-blog](projects/PJT002-ai-blog/) | AI活用のブログ生成・運営 | 未定 | 雛形のみ |

### 別リポジトリに切り出したもの

| リポジトリ | 内容 |
|---|---|
| `ai-lab` | **PJT ではない。** 各 PJT で使う機能・仕組みを開発する場所 |
| `soccer-manager` | サッカークラブ経営シミュレーション（Flutter + Flame） |
| `youtube-video-creation` | YouTube 動画の作成 |
| `kabu-agari-ranking` | 日本株 値上がり率ランキングの公開サイト |
| `quality-gainer-tracker` | 値上がりランキングから好業績銘柄を追跡 |
| `ir-analysis` | 適時開示(IR)の取得・分析と Excel 出力 |
| `ai-side-business` | AI 副業サポート |
| `tool-factory` | ツール量産テンプレートと Pages 公開 |
| `price-tracker` | 楽天の価格を日次記録して公開 |
| `cohabitation-budget` | 同棲の家計管理（単一ページ） |

## フォルダ構成

| フォルダ | 用途 |
|---|---|
| `projects/` | このリポジトリで持つプロジェクト（PJT001 / PJT002） |
| `experiments/` | 試作・アイデア検証用 |
| `scripts/` | 繰り返し使う便利スクリプト |
| `templates/` | 新規プロジェクトのひな型 |
| `docs/` | メモ・調査記録 |

各プロジェクトの動かし方は、それぞれの README を見る。
このリポジトリ直下には共通のビルド設定は無く、プロジェクトごとに独立している。

## CI

`.github/workflows/` にプロジェクト単位のワークフローを置いている。
複数プロジェクトが同居するので、**必ず `paths:` で対象プロジェクトに絞る**。
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
