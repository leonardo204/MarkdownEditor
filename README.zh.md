# MarkdownEditor

<p align="center">
  <a href="https://apps.apple.com/app/id6756916654"><img src="https://img.shields.io/badge/Mac%20App%20Store-Download-0D96F6?logo=apple&logoColor=white" alt="Mac App Store"></a>
  <img src="https://img.shields.io/badge/macOS-13.0%2B-lightgrey" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

[한국어](README.md) | [English](README.en.md) | [日本語](README.ja.md) | **中文**

一款 macOS 上的 Markdown 编辑器，支持实时预览与滚动同步。

> 在 Mac App Store 上的名称为 **MarkChartEditor**。
> [在 App Store 获取](https://apps.apple.com/app/id6756916654)

## 主要功能

- **实时预览**：编辑器与预览左右并排显示，改动立即呈现。
- **滚动同步**：以源文件行号为基准，编辑器与预览互相跟随。滚轮、触控板，以及拖动滚动条时都能同步。
- **图表与公式**：支持 Mermaid、PlantUML 图表、KaTeX 公式和代码高亮。
- **原生标签页**：与 Safari、Finder 一致的标签页体验。
  - Cmd+T 新建标签页，Cmd+N 新建窗口
  - 拖出标签页可独立成窗口
  - Window > Merge All Windows 可将窗口合并为标签页
- **查找与替换**：在编辑器和预览中同时查找，并高亮匹配结果。
- **大纲侧栏**：从标题列表直接跳转到对应位置（Shift+Cmd+O）。
- **专注模式与打字机模式**：只突出当前段落，或让光标固定在屏幕中央。
- **自动保存与外部改动检测**：停止输入 3 秒后自动保存；文件被其他程序修改时会提示。
- **导出**：可保存为 PDF 和 HTML。
- **插入图片**：支持拖放、粘贴和选择文件（Ctrl+O）。
- **主题**：编辑器与预览可分别选择浅色或深色。
- **记住窗口大小**：下次以上次调整的大小打开（在 设置 > General 中开启）。
- **Quick Look 预览**（应用内购买）：在 Finder 中按空格键即可查看排版后的 Markdown。

## 截图

![MarkdownEditor 主界面](docs/images/screenshot-main.png)

*支持 Mermaid 流程图、PlantUML 时序图、表格、清单等多种 Markdown 元素*

## 系统要求

- macOS 13.0（Ventura）或更高版本
- Apple Silicon（M1/M2/M3）或 Intel Mac

## 安装

### Mac App Store（推荐）

[在 Mac App Store 获取](https://apps.apple.com/app/id6756916654)

### 从源码构建

请参阅下方的[构建](#构建)。

## 设为默认应用

### 在 Finder 中设置

1. 右键点击任意 `.md` 文件
2. 选择“显示简介”
3. 在“打开方式”中选择 MarkdownEditor
4. 点击“全部更改...”

### 在终端中设置

```bash
brew install duti
duti -s com.zerolive.MarkdownEditor .md all
duti -s com.zerolive.MarkdownEditor .markdown all
```

## 构建

### 环境要求

- Xcode 15.0 或更高版本
- macOS 14.0 或更高版本（构建环境）

### 步骤

```bash
git clone git@github.com:leonardo204/MarkdownEditor.git
cd MarkdownEditor

xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor -configuration Release build
```

### 生成经过公证的 DMG

```bash
# 前置条件：安装 create-dmg
brew install create-dmg

# 将 notarytool 配置保存到 Keychain（仅首次）
xcrun notarytool store-credentials "notarytool" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"

# 构建并生成 DMG
./scripts/distribute.sh
```

## 许可证

MIT License，详见 [LICENSE](LICENSE)。

## 联系方式

zerolive7@gmail.com
