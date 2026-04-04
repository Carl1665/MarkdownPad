# MarkdownPad

一个使用 SwiftUI 构建的 macOS 原生 Markdown 编辑器。

## 功能特性

### 实时预览
- 左侧编辑，右侧实时预览
- 支持滚动同步，编辑器和预览区联动

### 编辑功能
- Markdown 语法高亮
- 支持中文输入法
- 工具栏快捷操作：
  - 加粗、斜体
  - 标题（H1-H6）
  - 有序/无序列表
  - 任务列表
  - 引用块
  - 代码块
  - 链接、图片
  - 表格
  - 分割线

### 多标签页支持
- 支持多文档编辑
- 标签页拖拽排序

### 文件操作
- 新建文档
- 打开本地 .md/.markdown 文件
- 拖拽文件到窗口打开
- 自动保存

### 其他
- 状态栏显示光标位置（行号、列号）
- 字数统计
- 明暗主题自动适配

## 系统要求

- macOS 14.0+
- Xcode 15.0+ (用于构建)

## 构建

```bash
# 克隆仓库
git clone https://github.com/Carl1665/MarkdownPad.git
cd MarkdownPad

# 构建
swift build -c release

# 打包为 .app
bash scripts/bundle.sh

# 运行
open build/MarkdownPad.app
```

## 技术栈

- SwiftUI
- AppKit (NSTextView)
- WebKit (WKWebView)
- swift-markdown (Markdown 解析)

## 许可证

MIT License
