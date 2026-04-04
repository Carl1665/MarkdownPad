enum PreviewCSS {
    static let html = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
    :root {
        --text: #212121;
        --bg: #ffffff;
        --heading: #1a3a5c;
        --link: #2a6496;
        --code-bg: #f5f5f5;
        --code-text: #c7500f;
        --border: #e0e0e0;
        --blockquote-border: #d0d0d0;
        --blockquote-text: #555;
        --table-stripe: #f9f9f9;
    }
    @media (prefers-color-scheme: dark) {
        :root {
            --text: #d4d4d4;
            --bg: #1e1e1e;
            --heading: #6fa3d6;
            --link: #5a9fd4;
            --code-bg: #2a2a2a;
            --code-text: #e09050;
            --border: #3a3a3a;
            --blockquote-border: #444;
            --blockquote-text: #999;
            --table-stripe: #252525;
        }
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
        font-family: -apple-system, "PingFang SC", "SF Pro Text", sans-serif;
        font-size: 16px;
        line-height: 1.75;
        color: var(--text);
        background: var(--bg);
        padding: 24px 32px;
        max-width: 100%;
    }
    h1, h2, h3, h4, h5, h6 {
        color: var(--heading);
        margin-top: 1.4em;
        margin-bottom: 0.6em;
        font-weight: 600;
        line-height: 1.3;
    }
    h1 { font-size: 1.8em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
    h2 { font-size: 1.5em; border-bottom: 1px solid var(--border); padding-bottom: 0.2em; }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1.1em; }
    p { margin-bottom: 1em; white-space: pre-wrap; }
    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }
    strong { font-weight: 600; }
    code {
        font-family: "Menlo", "SF Mono", monospace;
        font-size: 0.9em;
        background: var(--code-bg);
        color: var(--code-text);
        padding: 0.15em 0.4em;
        border-radius: 4px;
    }
    pre {
        background: var(--code-bg);
        padding: 16px;
        border-radius: 8px;
        overflow-x: auto;
        margin-bottom: 1em;
    }
    pre code {
        background: none;
        padding: 0;
        font-size: 0.85em;
        line-height: 1.5;
    }
    blockquote {
        border-left: 4px solid var(--blockquote-border);
        padding: 0.5em 1em;
        margin: 0 0 1em 0;
        color: var(--blockquote-text);
    }
    ul, ol { padding-left: 2em; margin-bottom: 1em; }
    li { margin-bottom: 0.3em; }
    li input[type="checkbox"] { margin-right: 0.5em; }
    hr {
        border: none;
        border-top: 1px solid var(--border);
        margin: 1.5em 0;
    }
    img { max-width: 100%; border-radius: 4px; }
    table {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 1em;
    }
    th, td {
        border: 1px solid var(--border);
        padding: 8px 12px;
        text-align: left;
    }
    th { background: var(--code-bg); font-weight: 600; }
    tr:nth-child(even) { background: var(--table-stripe); }
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
        // If no element has top >= 0, return the last one (scrolled past everything)
        if (elements.length > 0) {
            return parseInt(elements[elements.length - 1].getAttribute('data-source-line'), 10);
        }
        return 1;
    }
    // Report scroll position to native side
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
