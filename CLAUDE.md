开发前先阅读本文档，了解项目架构后再行动，这样可以节省一些token消耗。

# MarkdownPad 项目索引

一个 macOS 原生 Markdown 编辑器，使用 SwiftUI + AppKit + WebKit 构建。

## 技术栈

- **UI 框架**: SwiftUI + AppKit (NSTextView)
- **预览渲染**: WebKit (WKWebView)
- **Markdown 解析**: swift-markdown (Apple 官方库)
- **最低版本**: macOS 14.0+

---

## 目录结构

```
Sources/MarkdownPad/
├── MarkdownPadApp.swift      # 应用入口
├── AppDelegate.swift         # 应用生命周期
├── ContentView.swift         # 主视图容器
├── Constants.swift           # 全局常量
├── Editor/                   # 编辑器模块
├── Preview/                  # 预览模块
├── Parser/                   # Markdown 解析
├── Models/                   # 数据模型
├── Views/                    # UI 组件
├── Sync/                     # 滚动同步
└── Theme/                    # 主题管理

Tests/MarkdownPadTests/       # 单元测试
```

---

## 核心文件索引

### 应用入口层

| 文件 | 职责 |
|------|------|
| `MarkdownPadApp.swift` | 应用入口，定义菜单命令（新建/打开/保存/关闭标签页/查找/格式化快捷键） |
| `AppDelegate.swift` | 窗口生命周期管理，禁止关闭最后窗口时自动退出 |
| `ContentView.swift` | 主视图容器，协调 TabBar/Toolbar/Editor/Preview/StatusBar，处理工具栏动作和文件拖放 |

### 编辑器模块 (`Editor/`)

| 文件 | 职责 |
|------|------|
| `EditorView.swift` | NSTextView 的 SwiftUI 包装，处理文本编辑、滚动事件、光标位置追踪、输入法兼容 |
| `SyntaxHighlighter.swift` | Markdown 语法高亮引擎，支持代码块/标题/加粗/斜体/链接/列表/引用等 |
| `FormatInserter.swift` | 格式化插入工具类，生成加粗/斜体/链接/表格/代码块等 Markdown 标记 |
| `LineNumbersRulerView.swift` | 自定义 NSRulerView，显示行号，随滚动更新 |

### 预览模块 (`Preview/`)

| 文件 | 职责 |
|------|------|
| `PreviewView.swift` | WKWebView 的 SwiftUI 包装，渲染 HTML 预览，处理滚动同步消息 |
| `PreviewCSS.swift` | 预览区 CSS 样式（印象笔记风格），包含 JavaScript 滚动同步逻辑 |

### 解析模块 (`Parser/`)

| 文件 | 职责 |
|------|------|
| `MarkdownParser.swift` | Markdown → HTML 转换器，使用 swift-markdown 库的 MarkupVisitor 模式，为每个元素添加 `data-source-line` 属性用于滚动同步 |

### 数据模型 (`Models/`)

| 文件 | 职责 |
|------|------|
| `MarkdownDocument.swift` | 文档模型，管理文本内容/文件路径/修改状态，支持自动保存(30s)、文件读写、编码检测 |
| `TabManager.swift` | 标签页管理器，管理文档列表/活动文档/错误消息 |
| `RecentFilesManager.swift` | 最近文件管理，最多保存 10 条，持久化到 UserDefaults |

### UI 组件 (`Views/`)

| 文件 | 职责 |
|------|------|
| `TabBarView.swift` | 标签栏，显示文档标签、新建按钮、关闭确认对话框 |
| `ToolbarView.swift` | 工具栏，提供格式化按钮（加粗/斜体/标题/列表/链接/表格等） |
| `StatusBarView.swift` | 状态栏，显示文档名/光标位置/字数/编码 |
| `PersistentSplitView.swift` | 分割视图，记住分隔线位置（持久化到 UserDefaults） |

### 同步模块 (`Sync/`)

| 文件 | 职责 |
|------|------|
| `ScrollSyncCoordinator.swift` | 滚动同步协调器，基于时间戳锁防止双向滚动反馈循环，追踪编辑器/预览的首可见行 |

### 主题模块 (`Theme/`)

| 文件 | 职责 |
|------|------|
| `ThemeManager.swift` | 主题管理器，定义 `EditorTheme` 结构体，当前使用印象笔记风格深色主题 |

---

## 核心数据流

```
用户输入 → EditorView (NSTextView)
    ↓ textDidChange
    ├→ SyntaxHighlighter (语法高亮)
    ├→ onTextChange 回调
    ↓
ContentView.onReceive(.editorTextDidChange)
    ↓
MarkdownParser.parse() → HTML
    ↓
PreviewView (WKWebView) 更新内容
```

---

## 滚动同步机制

1. **Editor → Preview**: EditorView 监听滚动 → `ScrollSyncCoordinator.editorDidScroll()` → PreviewView 收到 `scrollToLine` 参数 → JS `scrollToLine()`
2. **Preview → Editor**: WebView JS 监听滚动 → `window.webkit.messageHandlers.scrollSync.postMessage()` → PreviewView.Coordinator → `ScrollSyncCoordinator.previewDidScroll()` → EditorView 收到 `scrollToLine` 参数
3. **防循环**: 基于 `lastScrollTime` 的时间戳锁，0.3s 内忽略反向滚动

---

## 测试文件索引

| 文件 | 测试内容 |
|------|----------|
| `MarkdownParserTests.swift` | Markdown → HTML 转换测试 |
| `SyntaxHighlighterTests.swift` | 语法高亮规则测试 |
| `FormatInserterTests.swift` | 格式化插入工具测试 |
| `TabManagerTests.swift` | 标签页管理逻辑测试 |

---

## 常见修改场景

### 添加新的 Markdown 格式按钮
1. 在 `ToolbarView.ToolbarAction` 枚举添加新 case
2. 在 `ToolbarView.body` 添加对应按钮
3. 在 `ContentView.handleToolbarAction()` 处理新动作
4. 在 `FormatInserter` 添加插入逻辑（如需要）

### 修改语法高亮规则
- 编辑 `SyntaxHighlighter.swift` 的 `buildLinePatterns()` 或 `buildInlinePatterns()`

### 修改预览样式
- 编辑 `PreviewCSS.swift` 的 CSS 变量和样式规则

### 修改主题颜色
- 编辑 `ThemeManager.swift` 的 `evernoteDarkEditor` 静态属性

### 添加新的菜单命令
1. 在 `MarkdownPadApp.swift` 的 `.commands` 修饰符中添加
2. 如需全局状态，使用 `FocusedValue` 传递 `TabManager`

---

## 依赖项

| 包 | 版本 | 用途 |
|----|------|------|
| swift-markdown | 0.7.0+ | Markdown 解析和 AST 遍历 |

---

## 构建命令

```bash
# 开发构建
swift build

# 发布构建
swift build -c release

# 打包为 .app
bash scripts/bundle.sh

# 运行测试
swift test
```
