# Stack Research

**Domain:** VS Code-style Claude Code chat UI — vanilla JS SPA, no build step
**Researched:** 2026-03-17
**Confidence:** HIGH (CDN URLs verified, versions confirmed on cdnjs/jsDelivr)

---

## Context: What Already Exists

The Agent42 dashboard is a vanilla JS SPA (`dashboard/frontend/dist/app.js`, ~5000 LOC).
No build step — changes go directly to dist files. `index.html` currently loads:

- Monaco Editor `0.52.2` via jsDelivr CDN (AMD loader pattern — must preserve)
- xterm.js + FitAddon bundled locally at `/xterm/`
- `app.js` served from FastAPI static files

New CDN libraries are added as script tags in `index.html` or lazy-loaded inside `app.js`
(the existing `termLoadXterm()` pattern shows how lazy CDN loading works).
All libraries must be UMD or IIFE format — no ES module import statements, no npm required.

---

## Recommended Stack

### Core Technologies (NEW additions only)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| marked.js | 16.3.0 | Markdown to HTML parsing | De facto standard for browser markdown. UMD build confirmed available. 10k+ GitHub stars. Used by GitLab, Ghost, others. |
| marked-highlight | 2.2.3 | Wires highlight.js into marked | Official marked extension for syntax highlighting. Tiny (3KB). UMD build confirmed at `/lib/index.umd.js`. |
| highlight.js | 11.11.1 | Syntax highlighting for code blocks | Industry standard. 185+ languages. Zero dependencies. Already the highlight engine in diff2html. |
| DOMPurify | 3.2.7 | XSS sanitization of rendered markdown | Non-negotiable when rendering AI output as HTML. Maintained by cure53 (security researchers). ~30KB. |
| diff2html | 3.4.56 | Unified/side-by-side diff viewer | GitHub-quality diff rendering. Parses raw unified diff text into visual HTML. Uses highlight.js (already loaded) for syntax. Pre-built UI bundle works with no config. |
| ansi_up | 6.0.6 | ANSI escape codes to HTML spans | CLI output from CC processes contains ANSI color codes. ansi_up converts them to colored span tags. Single file, UMD compatible, zero deps. |

### CDN URLs

| Library | CDN URL |
|---------|---------|
| marked.js 16.3.0 | `https://cdnjs.cloudflare.com/ajax/libs/marked/16.3.0/marked.umd.min.js` |
| marked-highlight 2.2.3 | `https://cdn.jsdelivr.net/npm/marked-highlight@2.2.3/lib/index.umd.js` |
| highlight.js 11.11.1 JS | `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/highlight.min.js` |
| highlight.js 11.11.1 CSS | `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/styles/github-dark.min.css` |
| DOMPurify 3.2.7 | `https://cdnjs.cloudflare.com/ajax/libs/dompurify/3.2.7/purify.min.js` |
| ansi_up 6.0.6 | `https://cdn.jsdelivr.net/npm/ansi_up@6.0.6/ansi_up.js` |
| diff2html 3.4.56 JS (lazy) | `https://cdn.jsdelivr.net/npm/diff2html@3.4.56/bundles/js/diff2html-ui.min.js` |
| diff2html 3.4.56 CSS (lazy) | `https://cdn.jsdelivr.net/npm/diff2html@3.4.56/bundles/css/diff2html.min.css` |

### Backend Technologies (Python)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| sse-starlette | 3.3.2 | SSE streaming endpoint for chat | FastAPI-native SSE with EventSourceResponse. Handles connection lifecycle, disconnect detection, and proper text/event-stream headers. Active, healthy package. |
| anthropic SDK | existing | Claude API streaming | Already present. Use `client.messages.stream()` async context manager for token-by-token streaming. |

### No New Frontend HTTP Libraries Needed

SSE streaming on the frontend uses the **native browser `EventSource` API** — no library needed.
`EventSource` is supported in all modern browsers (Chrome 6+, Firefox 6+, Safari 5+, Edge 79+).
For chat input, the existing `apiFetch()` helper (POST with JWT token) is sufficient.

---

## Installation

```bash
# No npm install for frontend — CDN only.

# Backend: add to requirements.txt
pip install sse-starlette==3.3.2
```

Add to `dashboard/frontend/dist/index.html` BEFORE the Monaco loader script tag:

```html
<!-- Markdown rendering stack (load before Monaco loader) -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/styles/github-dark.min.css">
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/highlight.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/marked/16.3.0/marked.umd.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/marked-highlight@2.2.3/lib/index.umd.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/dompurify/3.2.7/purify.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/ansi_up@6.0.6/ansi_up.js"></script>
<!-- diff2html is lazy-loaded on first diff render — do NOT add here -->
```

---

## Integration Patterns

### 1. Markdown Rendering with Syntax Highlighting

Wire marked + marked-highlight + highlight.js together once at app init.
Global variables after CDN loads: `window.marked`, `window.markedHighlight`, `window.hljs`,
`window.DOMPurify`.

Pattern (call once, after all CDN scripts load):
- Call `marked.use(markedHighlight({ langPrefix: 'hljs language-', highlight: fn }))`
- The highlight function uses `hljs.getLanguage(lang)` to validate, falls back to 'plaintext'
- Render function: call `marked.parse(rawText)`, then wrap result in `DOMPurify.sanitize()`
- Assign sanitized HTML to the message bubble element

**Why DOMPurify is mandatory:** AI-generated markdown can include arbitrary HTML. If a user
prompt causes CC to output script tags or event handler attributes, rendering directly
to an element's HTML property creates XSS. DOMPurify strips dangerous elements while
preserving code, pre, strong, em, a, etc.

**Do NOT call `hljs.highlightAll()`** — it will re-process every code block on the page
including Monaco's output. Use `hljs.highlightElement(el)` on specific blocks only, or
rely on marked-highlight to pre-process at parse time.

### 2. SSE Streaming (Chat Messages)

Frontend uses native `EventSource` (no library). Key behavior:
- Create `new EventSource('/api/chat/stream?token=...&msg=...')` for the connection
- On `onmessage`: accumulate text, display as plain text (textContent) during streaming
- On `data: [DONE]` sentinel: close connection, render accumulated text as markdown
- On `onerror`: close connection, show error state

**Why plain text during streaming, markdown only at end:** Parsing markdown incrementally
causes flicker when partial syntax (like `**bo`) renders as literal asterisks then flips
to bold. This matches VS Code Copilot Chat behavior: stream as plain text, render markdown
on completion. Total latency impact: one additional parse call at end (~1ms for typical
responses).

**EventSource is GET-only** by browser spec. For multi-turn conversations, pass a session
ID as a query parameter and load history server-side.

Backend pattern with sse-starlette:
- Endpoint returns `EventSourceResponse(async_generator_function)`
- Generator yields `{"data": text_chunk}` for each token
- Generator yields `{"data": "[DONE]"}` when stream ends
- FastAPI auth via `Depends(get_current_user)` does NOT work with EventSource (no auth header).
  Use token-in-query-param pattern with existing JWT validation.

### 3. Diff Viewer (Lazy-Loaded)

diff2html is not loaded at page startup — only injected when a diff message appears.

Lazy-load trigger: when a chat message contains unified diff text (detect `--- a/` or an
explicit `type: "diff"` field in the message payload):
- Check if `window.Diff2HtmlUI` exists
- If not: dynamically inject the CSS link and JS script into document.head
- On script onload: instantiate `new Diff2HtmlUI(targetElement, unifiedDiff, config)` and call `draw()`
- Config: `drawFileList: true`, `matching: 'lines'`, `outputFormat: 'line-by-line'`, `highlight: true`
- diff2html uses hljs internally (already loaded) — no additional setup needed

### 4. ANSI CLI Output Rendering

For displaying terminal/process output inside chat message bubbles (not in xterm.js):
- Instantiate `new AnsiUp()` per render call (it's a constructor, not a singleton)
- Set `ansiUp.use_classes = true` to use CSS classes instead of inline styles
- Call `ansiUp.ansi_to_html(text)` to get HTML with span tags
- Wrap result in `DOMPurify.sanitize()` before assigning to element HTML
- Wrap in a pre element with a CSS class like `cli-output` for monospace display

Note: xterm.js already handles ANSI codes for the terminal panel. ansi_up is only for
rendering CLI-style output snippets inside chat bubbles (e.g., test results, build output
that CC surfaces in its response text).

### 5. AMD Conflict Guard (CRITICAL)

The existing codebase handles the Monaco AMD/require conflict in `termLoadXterm()`.
New CDN libraries loaded via script tags use UMD format, which checks for AMD loaders.

**Solution:** Load all new CDN libraries in `index.html` BEFORE the Monaco `loader.js` script.
This is simpler than the save/restore pattern and avoids conflicts entirely.
diff2html is lazy-loaded via dynamic script injection after Monaco is initialized — the
dynamic injection approach is safe because by that point AMD is already claimed by Monaco.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| marked.js 16.x | markdown-it | If you need extensive plugin ecosystem (tables, footnotes, custom syntax). marked is simpler for render-only use case. |
| marked.js 16.x | Showdown.js | Never — Showdown last released 2022, effectively unmaintained. |
| highlight.js 11.11.1 | Prism.js | If you need exact tokenizer control. highlight.js auto-detects language, which is better for AI output where lang tag may be absent. |
| DOMPurify | No sanitizer | Never skip sanitization on AI-generated HTML. |
| Native EventSource | reconnecting-eventsource | Only if you need custom retry logic with auth header rotation on reconnect. |
| sse-starlette | Manual StreamingResponse | Only if you specifically need to avoid adding a dependency and are willing to hand-roll SSE framing, disconnect detection, and graceful shutdown. |
| diff2html lazy-loaded | Monaco diff editor | Use Monaco diff editor for interactive editing diffs (the agent proposes a change, user reviews inline). Use diff2html for passive display of git/unified diff text in chat. |
| plain text stream then render | streaming-markdown v0.2.0 | Only when streaming-markdown reaches stable release (v1.0+). Currently WIP. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| React/Vue/Svelte | No build step exists. Rewriting 5000+ LOC app.js is out of scope. | Vanilla JS — existing pattern |
| AI HTML output rendered without DOMPurify | XSS from AI-generated script tags or event handlers | Always sanitize with DOMPurify after marked.parse() |
| streaming-markdown v0.2.0 | Marked WIP, 14 open issues, parser state bugs in production | Plain text during stream, markdown on completion |
| hljs.highlightAll() globally | Re-processes Monaco output, causes double-highlight conflicts | hljs.highlightElement(specificEl) only on chat bubbles |
| Unpinned CDN URLs (marked@latest) | marked v16 had breaking changes; v17 may break again | Always pin: `marked@16.3.0`, `marked-highlight@2.2.3` |
| EventSource with POST body | EventSource is GET-only per spec | Pass session ID as query param, load history server-side |
| CommonJS require() in browser | No Node.js in browser | UMD globals from script tags: window.marked, window.hljs |

---

## Version Compatibility

| Package | Version | Compatible With | Notes |
|---------|---------|-----------------|-------|
| marked@16.3.0 | UMD | Any browser | v16 removed CJS build. Use `marked.umd.min.js` URL explicitly. |
| marked-highlight@2.2.3 | UMD | marked@16.x | Call `marked.use(markedHighlight({...}))` after both scripts load. |
| highlight.js@11.11.1 | UMD | Any browser | Do NOT call hljs.highlightAll() — use hljs.highlightElement(el). |
| DOMPurify@3.2.7 | UMD | Any browser | Must be called AFTER marked.parse(), BEFORE element HTML assignment. |
| diff2html@3.4.56 | UMD bundle | highlight.js@11.x | Uses hljs internally. Load highlight.js first. Diff2HtmlUI global from UI bundle. |
| ansi_up@6.0.6 | UMD | Any browser | Constructor: new AnsiUp(). Not a singleton. Sanitize output with DOMPurify. |
| sse-starlette@3.3.2 | Python | FastAPI + Starlette | Use EventSourceResponse. Incompatible with Depends(get_current_user) — use token-in-query-param. |
| Monaco@0.52.2 | AMD | All UMD libs must load BEFORE Monaco loader.js | Load order in index.html is critical. |

---

## Sources

- cdnjs.com/libraries/marked — version 16.3.0 confirmed (HIGH confidence, direct CDN check)
- cdnjs.com/libraries/highlight.js — version 11.11.1 confirmed (HIGH confidence, direct CDN check)
- cdnjs.com/libraries/dompurify — version 3.2.7 confirmed (HIGH confidence, direct CDN check)
- jsdelivr.com/package/npm/diff2html — version 3.4.56 confirmed January 2026 (HIGH confidence)
- jsdelivr.com/package/npm/ansi_up — version 6.0.6 confirmed May 2025 (HIGH confidence)
- jsdelivr.com/package/npm/marked-highlight — version 2.2.3, UMD at `/lib/index.umd.js` confirmed (HIGH confidence)
- github.com/markedjs/marked/releases/tag/v16.0.0 — v16 breaking changes: CJS removed, UMD still available (HIGH confidence)
- pypi.org/project/sse-starlette — version 3.3.2, healthy project (HIGH confidence)
- github.com/thetarnav/streaming-markdown — v0.2.0 WIP status (MEDIUM confidence — WIP)
- MDN EventSource API — native browser API, no polyfill needed (HIGH confidence)
- platform.claude.com/docs/en/build-with-claude/streaming — Anthropic SDK streaming pattern (HIGH confidence)
- fastapi.tiangolo.com/tutorial/server-sent-events — FastAPI SSE official docs (HIGH confidence)

---

*Stack research for: Custom Claude Code Chat UI — vanilla JS, CDN-only, no build step*
*Researched: 2026-03-17*
