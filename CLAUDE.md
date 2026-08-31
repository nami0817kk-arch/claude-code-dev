# Claude Code 開発ワークスペース

## このリポジトリの範囲

PJT001 と PJT002 だけを持つ。他のプロジェクトは**独立したリポジトリ**として
このリポジトリと同じ親フォルダ（`dev/`）に並べてある。

プロジェクトが育って単独で運用できるようになったら、`projects/` から出して
独立リポジトリに切り出す。切り出した時点で PJT の採番は外し、リポジトリ名で呼ぶ。

## フォルダ構成

| フォルダ | 用途 |
|---|---|
| `projects/` | このリポジトリで持つプロジェクト（PJT001 / PJT002） |
| `experiments/` | 試作・アイデア検証用 |
| `scripts/` | 繰り返し使う便利スクリプト |
| `templates/` | 新規プロジェクトのひな型 |
| `docs/` | メモ・調査記録 |

## 同じ親フォルダにある他のリポジトリ

| リポジトリ | 内容 |
|---|---|
| `ai-lab` | **PJT ではない。** 各 PJT で使う機能・仕組みを開発する場所（画像生成・音素材合成・ブラウザ操作・サイト生成・全PJTの定期点検） |
| `soccer-manager` | サッカークラブ経営シミュレーション（Flutter + Flame） |
| `youtube-video-creation` | YouTube 動画の作成 |
| `kabu-agari-ranking` | 日本株 値上がり率ランキングの公開サイト |
| `quality-gainer-tracker` | 値上がりランキングから好業績銘柄を追跡 |
| `ir-analysis` | 適時開示(IR)の取得・分析と Excel 出力 |
| `ai-side-business` | AI 副業サポート（自動化・原価計算・ダッシュボード） |
| `tool-factory` | ツール量産テンプレートと GitHub Pages 公開 |
| `price-tracker` | 楽天の価格を日次記録して公開 |
| `cohabitation-budget` | 同棲の家計管理（単一ページ） |

汎用的な仕組みが要るときは、PJT に直接書かずに `ai-lab` に作って共通化する。

## 環境

- OS: Windows 11
- Shell: PowerShell / Git Bash 両方利用可能

## CI

`.github/workflows/` にプロジェクト単位のワークフローを置いている。
複数プロジェクトが同居するので、**必ず `paths:` で対象プロジェクトに絞る**。
絞らないと、無関係な変更のたびに全プロジェクトのCIが回る。

## よく使うコマンド

```bash
# 新しいプロジェクトを始める場合
cd projects
mkdir PJT0XX-name && cd PJT0XX-name

# 実験コードを試す場合
cd experiments
mkdir trial-name && cd trial-name
```
