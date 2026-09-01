# MarkdownEditor

<p align="center">
  <a href="https://apps.apple.com/app/id6756916654"><img src="https://img.shields.io/badge/Mac%20App%20Store-Download-0D96F6?logo=apple&logoColor=white" alt="Mac App Store"></a>
  <img src="https://img.shields.io/badge/macOS-13.0%2B-lightgrey" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

[한국어](README.md) | [English](README.en.md) | **日本語** | [中文](README.zh.md)

macOS 向けの Markdown エディタです。リアルタイムプレビューとスクロール同期に対応しています。

> Mac App Store では **MarkChartEditor** という名前で公開しています。
> [App Store で入手](https://apps.apple.com/app/id6756916654)

## 主な機能

- **リアルタイムプレビュー**: エディタとプレビューを左右に並べて表示し、編集内容がすぐ反映されます。
- **スクロール同期**: ソース行を基準にエディタとプレビューが互いに追従します。ホイールやトラックパッドだけでなく、スクロールバーをドラッグしたときも同期します。
- **図と数式**: Mermaid、PlantUML の図、KaTeX の数式、コードのシンタックスハイライトに対応します。
- **ネイティブタブ**: Safari や Finder と同じ操作感のタブです。
  - Cmd+T で新しいタブ、Cmd+N で新しいウインドウ
  - タブをドラッグして別ウインドウに分離
  - Window > Merge All Windows でタブをまとめる
- **検索と置換**: エディタとプレビューの両方を検索し、該当箇所をハイライトします。
- **アウトラインサイドバー**: 見出しの一覧から目的の位置へ移動します（Shift+Cmd+O）。
- **集中モードとタイプライターモード**: 現在の段落だけを強調したり、カーソルを画面中央に固定します。
- **自動保存と外部変更の検知**: 入力が止まってから3秒で保存し、他のアプリがファイルを書き換えたら知らせます。
- **書き出し**: PDF と HTML で保存します。
- **画像の挿入**: ドラッグ＆ドロップ、貼り付け、ファイル選択（Ctrl+O）に対応します。
- **テーマ**: エディタとプレビューでライト／ダークを個別に選べます。
- **ウインドウサイズの記憶**: 最後に調整したサイズで次回も開きます（設定 > General で有効化）。
- **Quick Look プレビュー**（アプリ内課金）: Finder でスペースキーを押すと Markdown をそのまま表示します。

## スクリーンショット

![MarkdownEditor メイン画面](docs/images/screenshot-main.png)

*Mermaid のフローチャート、PlantUML のシーケンス図、表、チェックリストなどに対応*

## 動作環境

- macOS 13.0（Ventura）以降
- Apple Silicon（M1/M2/M3）または Intel Mac

## インストール

### Mac App Store（推奨）

[Mac App Store で入手](https://apps.apple.com/app/id6756916654)

### ソースからビルド

下の[ビルド](#ビルド)を参照してください。

## 標準アプリに設定する

### Finder から設定

1. 任意の `.md` ファイルを右クリック
2. 「情報を見る」を選択
3. 「このアプリケーションで開く」で MarkdownEditor を選択
4. 「すべてを変更...」をクリック

### ターミナルから設定

```bash
brew install duti
duti -s com.zerolive.MarkdownEditor .md all
duti -s com.zerolive.MarkdownEditor .markdown all
```

## ビルド

### 必要なもの

- Xcode 15.0 以降
- macOS 14.0 以降（ビルド環境）

### 手順

```bash
git clone git@github.com:leonardo204/MarkdownEditor.git
cd MarkdownEditor

xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor -configuration Release build
```

### 公証済み DMG の作成

```bash
# 事前準備: create-dmg をインストール
brew install create-dmg

# notarytool のプロファイルを Keychain に保存（初回のみ）
xcrun notarytool store-credentials "notarytool" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"

# ビルドと DMG 作成
./scripts/distribute.sh
```

## ライセンス

MIT License。詳しくは [LICENSE](LICENSE) を確認してください。

## お問い合わせ

zerolive7@gmail.com
