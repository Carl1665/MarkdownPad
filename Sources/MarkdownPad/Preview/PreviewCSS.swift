enum PreviewCSS {
    static let html = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
    /* 印象笔记 Markdown 预览区样式 */
    :root {
        --bg: #FFFFFF;
        --text: #333333;
        --heading: #1A1A1A;
        --link: #2F73B3;
        --code-fg: #C7254E;
        --code-bg: #F3F3F3;
        --codeblock-bg: #F6F6F6;
        --blockquote-bg: #F7F7F7;
        --blockquote-bar: #CCCCCC;
        --table-border: #DDDDDD;
        --table-header: #F0F0F0;
        --hr: #DDDDDD;
        --highlight-bg: #FFF3B0;
    }

    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
        font-family: -apple-system, "PingFang SC", "Microsoft YaHei", "Noto Sans SC", sans-serif;
        font-size: 15px;
        line-height: 1.75;
        color: var(--text);
        background: var(--bg);
        padding: 24px 32px;
        max-width: 780px;
    }

    /* 标题层级 */
    h1, h2, h3, h4, h5, h6 {
        color: var(--heading);
        font-weight: 700;
        line-height: 1.3;
    }
    h1 {
        font-size: 28px;
        margin-top: 32px;
        margin-bottom: 16px;
    }
    h2 {
        font-size: 22px;
        margin-top: 28px;
        margin-bottom: 12px;
        border-bottom: 1px solid #EEEEEE;
        padding-bottom: 8px;
    }
    h3 {
        font-size: 18px;
        margin-top: 24px;
        margin-bottom: 8px;
    }
    h4 {
        font-size: 16px;
        margin-top: 20px;
        margin-bottom: 8px;
    }

    /* 段落 */
    p {
        margin-bottom: 14px;
        white-space: pre-wrap;
    }

    /* 链接 */
    a {
        color: var(--link);
        text-decoration: none;
    }
    a:hover {
        text-decoration: underline;
    }

    /* 强调 */
    strong {
        font-weight: 700;
        color: #1A1A1A;
    }
    em {
        font-style: italic;
    }
    del {
        text-decoration: line-through;
        color: #999999;
    }

    /* 行内代码 */
    code {
        font-family: "Menlo", "Consolas", "Source Code Pro", monospace;
        font-size: 14px;
        background: var(--code-bg);
        color: var(--code-fg);
        padding: 2px 6px;
        border-radius: 3px;
    }

    /* 代码块 */
    pre {
        background: var(--codeblock-bg);
        padding: 16px;
        border-radius: 4px;
        border: 1px solid #E8E8E8;
        overflow-x: auto;
        margin-bottom: 16px;
    }
    pre code {
        background: none;
        padding: 0;
        font-size: 13px;
        line-height: 1.5;
        color: var(--text);
    }

    /* 引用块 */
    blockquote {
        border-left: 3px solid var(--blockquote-bar);
        background: var(--blockquote-bg);
        padding: 12px 16px;
        margin: 16px 0;
        color: #555555;
    }

    /* 列表 */
    ul, ol {
        padding-left: 24px;
        margin-bottom: 14px;
    }
    li {
        margin-bottom: 4px;
    }
    li input[type="checkbox"] {
        margin-right: 8px;
    }
    ul ul, ol ol, ul ol, ol ul {
        margin-top: 4px;
        padding-left: 20px;
    }

    /* 分隔线 */
    hr {
        border: none;
        border-top: 1px solid var(--hr);
        margin: 24px 0;
    }

    /* 图片 */
    img {
        max-width: 100%;
        border-radius: 4px;
        margin: 16px 0;
        display: block;
    }

    /* 表格 */
    table {
        width: 100%;
        border-collapse: collapse;
        margin: 16px 0;
    }
    th, td {
        border: 1px solid var(--table-border);
        padding: 8px 12px;
        text-align: left;
    }
    th {
        background: var(--table-header);
        font-weight: 600;
        color: var(--heading);
    }
    tr:nth-child(even) {
        background: #FAFAFA;
    }

    /* 高亮标记 */
    mark {
        background: var(--highlight-bg);
        padding: 1px 4px;
        border-radius: 2px;
    }
    </style>
    </head>
    <body>
    <div id="content"></div>
    <script>
    function updateContent(html) {
        document.getElementById('content').innerHTML = html;
    }
    function scrollToLine(line) {
        var elements = document.querySelectorAll('[data-source-line]');
        var target = null;
        for (var i = 0; i < elements.length; i++) {
            var elLine = parseInt(elements[i].getAttribute('data-source-line'), 10);
            if (elLine <= line) {
                target = elements[i];
            } else {
                break;
            }
        }
        if (target) {
            window._isScrollingFromEditor = true;
            window.scrollTo({ top: target.offsetTop, behavior: 'auto' });
            setTimeout(function() { window._isScrollingFromEditor = false; }, 50);
        }
    }
    function getFirstVisibleLine() {
        var elements = document.querySelectorAll('[data-source-line]');
        for (var i = 0; i < elements.length; i++) {
            var rect = elements[i].getBoundingClientRect();
            if (rect.top >= 0) {
                return parseInt(elements[i].getAttribute('data-source-line'), 10);
            }
        }
        if (elements.length > 0) {
            return parseInt(elements[elements.length - 1].getAttribute('data-source-line'), 10);
        }
        return 1;
    }
    let scrollTimer = null;
    window.addEventListener('scroll', function() {
        if (window._isScrollingFromEditor) return;
        clearTimeout(scrollTimer);
        scrollTimer = setTimeout(function() {
            if (window._isScrollingFromEditor) return;
            var line = getFirstVisibleLine();
            window.webkit.messageHandlers.scrollSync.postMessage({ line: line });
        }, 16);
    });
    </script>
    </body>
    </html>
    """
}
