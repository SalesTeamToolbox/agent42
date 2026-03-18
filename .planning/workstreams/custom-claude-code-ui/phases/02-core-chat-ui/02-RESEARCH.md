# Phase 2: Core Chat UI - Research

**Researched:** 2026-03-18
**Domain:** Vanilla JS chat UI, streaming DOM, markdown rendering, XSS sanitization, syntax highlighting
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CHAT-01 | User messages display in styled bubbles with avatar and timestamp | Existing `buildChatMsgHtml()` + `.chat-msg-user` CSS already does this; CC chat tab reuses the same pattern with a new container ID |
| CHAT-02 | Assistant messages display in styled bubbles with streaming text cursor during generation | Append-only DOM: create assistant bubble on first `text_delta`, then accumulate on subsequent deltas; CSS blinking cursor on the streaming span |
| CHAT-03 | Completed messages render markdown (headers, lists, bold, italic, links) via marked.js | marked.js v17.0.4 via CDN; `marked.parse()` returns HTML; pipe through DOMPurify before DOM insertion |
| CHAT-04 | Code blocks render with syntax highlighting via highlight.js | highlight.js v11.11.1 via CDN + marked-highlight v2.2.3 extension; `hljs.highlight(code, {language})` called per code block |
| CHAT-05 | All AI-generated HTML sanitized via DOMPurify before DOM insertion | DOMPurify v3.3.3 via CDN; `DOMPurify.sanitize(html)` wraps every `marked.parse()` output; non-negotiable locked decision in STATE.md |
| CHAT-06 | Streaming uses append-only DOM with 50ms batched updates; no re-render of previous messages | Buffer `text_delta` text client-side; `setInterval(50ms)` flushes accumulated text into active streaming bubble's span; never touch earlier message nodes |
| CHAT-07 | Auto-scroll pins to bottom during streaming; scrolling up stops auto-scroll; scroll-to-bottom button appears | `scrollTop + clientHeight >= scrollHeight - threshold` check in scroll handler; boolean `_ccAutoScroll` flag; floating button |
| CHAT-08 | Stop button cancels active generation (kills CC process) | Frontend sends `{"type":"stop"}` on WS; backend `cc_chat_ws` handles it with `proc.terminate()`; Stop button shown while `_ccSending === true` |
| CHAT-09 | Thinking/reasoning blocks display in collapsible sections with distinct styling | `thinking` content blocks wrapped in `<details><summary>` HTML with muted border/background CSS |
| INPUT-01 | Multi-line input box; Shift+Enter for newlines; Enter to send | `<textarea>` with `onkeydown`: `if(Enter && !shiftKey) { send(); preventDefault(); }` |
| INPUT-02 | Input supports paragraph breaks (multiple newlines preserved) | `user_message` sent as-is over WS; display uses `white-space: pre-wrap` on user bubble body |
| INPUT-03 | Input box auto-resizes vertically as content grows (up to configurable max height) | `scrollHeight` pattern: `textarea.style.height = "auto"; textarea.style.height = Math.min(textarea.scrollHeight, MAX_HEIGHT) + "px"` on every `input` event |
| INPUT-04 | Slash command autocomplete dropdown (e.g., /help, /clear, /compact) | Detect leading `/` in `oninput`; show positioned `<div>` dropdown with filtered commands; keyboard nav; close on Escape/blur |
</phase_requirements>

---

## Summary

Phase 2 builds a streaming chat panel that replaces the current raw xterm.js "Claude Code" tab in the IDE. The current `ideOpenClaude()` connects to `/ws/terminal?cmd=claude` (spawns an interactive shell running the `claude` CLI). Phase 2 replaces this with a proper chat UI connecting to `/ws/cc-chat` (the Phase 1 backend bridge).

The implementation is entirely in `dashboard/frontend/dist/app.js` and `style.css` — no build system, no npm, no bundler. All new libraries (marked.js, DOMPurify, highlight.js, marked-highlight) are loaded via CDN `<script>` tags added to `index.html`. The project uses vanilla JS with a global `state` object and direct DOM manipulation; all additions follow this existing pattern exactly.

The key architectural insight is that the streaming model is fundamentally different from the existing chat (which receives full messages). The CC WS bridge sends `text_delta` events one token at a time. This requires an append-only streaming bubble: create one assistant message node when the first `text_delta` arrives, buffer subsequent deltas at 50ms intervals, then finalize by running `marked.parse()` + `DOMPurify.sanitize()` on `turn_complete`. During streaming, show raw escaped text; on completion, replace with rendered markdown. This prevents re-parsing on every keystroke while keeping the UI responsive.

The markdown rendering upgrade (marked.js + DOMPurify + highlight.js) applies to CC chat only. The existing `renderMarkdown()` custom function continues serving the Agent42 chat page unchanged. The custom function is XSS-safe but lacks syntax highlighting. For the CC chat, REQUIREMENTS.md and STATE.md explicitly mandate these three libraries.

**Primary recommendation:** Replace `ideOpenClaude()` with `ideOpenCCChat()` that builds a structured chat panel inside `ide-cc-container`; connect to `/ws/cc-chat`; implement the streaming bubble lifecycle: create-on-first-delta, accumulate-with-buffer, finalize-on-turn-complete. Add backend stop-handler to `cc_chat_ws` in Phase 2 (not Phase 1).

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `marked.js` | 17.0.4 | Markdown to HTML parser | REQUIREMENTS.md explicitly names it; industry standard; used by VS Code extensions |
| `DOMPurify` | 3.3.3 | XSS sanitization of marked.js HTML output | REQUIREMENTS.md mandates it; STATE.md marks it as non-negotiable locked decision |
| `highlight.js` | 11.11.1 | Syntax highlighting for code blocks | REQUIREMENTS.md explicitly names it; integrates with marked via marked-highlight |
| `marked-highlight` | 2.2.3 | marked.js extension to pipe code blocks through highlight.js | Official markedjs package; avoids manual renderer override |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `xterm.js` | already loaded | Terminal emulation | Keep for existing shell terminal tabs; do NOT use for CC chat panel |
| Existing CSS classes | — | `.chat-msg`, `.chat-msg-user`, `.chat-msg-agent`, `.md-code-block` | Reuse for CC chat; only add CC-specific supplemental classes |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `marked.js` CDN | Existing custom `renderMarkdown()` | Custom function lacks syntax highlighting, no table support, no proper link handling — Requirements lock in marked.js |
| `DOMPurify` | Existing `esc()` function | `esc()` escapes everything (no HTML passthrough), incompatible with marked.js HTML output; DOMPurify allows safe HTML while stripping XSS vectors |
| `highlight.js` | Prism.js | highlight.js has better auto-detection; marked-highlight is an official marked.js extension targeting hljs specifically |
| Streaming via textContent append | Full re-render on each delta | Re-render thrashes DOM and re-parses invalid partial markdown fragments; append-only is the correct pattern |

**Installation (CDN script/link tags to add to `index.html`):**
```
highlight.js CSS (add to <head>):
https://cdn.jsdelivr.net/npm/highlight.js@11.11.1/styles/github-dark.min.css

Scripts (add before </body>, after Monaco scripts, load order matters):
1. https://cdn.jsdelivr.net/npm/marked@17.0.4/lib/marked.umd.js
2. https://cdn.jsdelivr.net/npm/marked-highlight@2.2.3/lib/index.umd.js
3. https://cdn.jsdelivr.net/npm/highlight.js@11.11.1/lib/highlight.min.js
4. https://cdn.jsdelivr.net/npm/dompurify@3.3.3/dist/purify.min.js
```

---

## Architecture Patterns

### Recommended Project Structure

```
dashboard/frontend/dist/
  index.html    -- Add 4 CDN script/link tags (marked, marked-highlight, hljs, DOMPurify)
  app.js        -- Replace ideOpenClaude() with ideOpenCCChat(); add streaming logic
  style.css     -- Add ~50 lines for .cc-chat-* classes and streaming cursor
```

No new files. All changes in 3 existing files. The `ide-cc-container` div (already in the IDE DOM) becomes the chat panel host.

### Pattern 1: CC Chat Tab Structure

**What:** A "Claude Code" tab in the IDE shows a structured chat panel instead of an xterm terminal.

**When to use:** When `ideOpenCCChat()` is called (replaces `ideOpenClaude()`).

Key difference from current xterm tab:
- Tab gets a new type flag: `tab.chatPanel = true` (in addition to `type: "claude"`)
- `tab.el` is a chat panel div, not an xterm terminal div
- No `tab.term`, no `tab.fitAddon` — these xterm fields are absent
- WS connects to `/ws/cc-chat?token=...&session_id=...` instead of `/ws/terminal`

Tab state object:
```
tab = {
  type: "claude",
  path: label,
  chatPanel: true,      // distinguishes from old xterm-based claude tabs
  el: chatDiv,          // the outer chat panel div
  ws: null,
  node: node,
  tabIdx: _ccTabCounter,
  sending: false,
  autoScroll: true,
  streamBuffer: "",
  streamMsgEl: null,    // DOM span receiving streaming text
  streamTimer: null,    // setInterval handle for 50ms flush
  ccSessionId: null,    // CC session ID for --resume
}
```

### Pattern 2: Streaming Bubble Lifecycle

**What:** Three phases of a CC response: pre-streaming (waiting), streaming (text_delta events), complete (turn_complete event).

**Phase 1 — First text_delta arrives:**
- Create assistant message bubble with streaming class
- Attach blinking cursor CSS to active streaming span
- Start 50ms setInterval that flushes `streamBuffer` via textContent update

**Phase 2 — Subsequent text_deltas:**
- Append to `tab.streamBuffer`
- 50ms timer updates `streamMsgEl.textContent = tab.streamBuffer`
- Auto-scroll if `tab.autoScroll === true`

**Phase 3 — turn_complete fires:**
- `clearInterval(tab.streamTimer)`
- Run `ccRenderMarkdown(tab.streamBuffer)` which returns sanitized HTML from DOMPurify
- Set `streamMsgEl` content to the rendered HTML (safe because DOMPurify has run)
- Remove streaming CSS class; remove blinking cursor
- Set `tab.sending = false`; hide Stop button; show Send button

**Edge cases:**
- `turn_complete` with no prior `text_delta` (tool-only turn): guard `if (tab.streamMsgEl && tab.streamBuffer)` before rendering; if empty, just reset state without creating a bubble
- `error` event: append an error bubble with distinct styling; reset sending state

### Pattern 3: marked.js + DOMPurify + highlight.js Setup

**What:** Initialize the markdown renderer once on first use (lazy init guards against CDN not yet loaded).

**CDN UMD access:** When loaded via `<script>` tag, the libraries expose globals:
- `marked` — the marked.js object (use `marked.parse()`, `marked.use()`)
- `markedHighlight` — namespace object; actual function is `markedHighlight.markedHighlight`
- `hljs` — highlight.js global
- `DOMPurify` — sanitizer global

```javascript
// Source: marked.js.org/using_advanced + marked-highlight README (verified 2026-03-18)
var _ccMarkdownReady = false;

function _initCCMarkdown() {
  if (typeof marked === "undefined" || typeof hljs === "undefined"
      || typeof markedHighlight === "undefined" || typeof DOMPurify === "undefined") {
    return false;
  }
  // markedHighlight exposes namespace.function (UMD pattern)
  var mhFn = markedHighlight.markedHighlight;
  marked.use(mhFn({
    emptyLangClass: "hljs",
    langPrefix: "hljs language-",
    highlight: function(code, lang) {
      var language = hljs.getLanguage(lang) ? lang : "plaintext";
      return hljs.highlight(code, { language: language }).value;
    }
  }));
  marked.use({ gfm: true, breaks: false });
  return true;
}

function ccRenderMarkdown(text) {
  if (!_ccMarkdownReady) _ccMarkdownReady = _initCCMarkdown();
  if (!_ccMarkdownReady || !text) return "<p>" + esc(text || "") + "</p>";
  var rawHtml = marked.parse(text);
  // DOMPurify sanitization is mandatory (CHAT-05, STATE.md locked decision)
  return DOMPurify.sanitize(rawHtml, {
    ALLOWED_TAGS: ["p","br","strong","em","b","i","h1","h2","h3","h4","h5","h6",
                   "ul","ol","li","blockquote","pre","code","a","table","thead",
                   "tbody","tr","th","td","hr","span","div","details","summary"],
    ALLOWED_ATTR: ["href","class","id","target","rel","open"],
  });
}
```

### Pattern 4: Auto-Resize Textarea (INPUT-03)

**What:** Textarea grows vertically as the user types, up to a max height.

**When to use:** On every `input` event.

```javascript
// Source: CSS-Tricks scrollHeight pattern (standard, widely verified)
var CC_INPUT_MAX_HEIGHT = 200; // px

function ccInputResize(textarea) {
  textarea.style.height = "auto";
  textarea.style.height = Math.min(textarea.scrollHeight, CC_INPUT_MAX_HEIGHT) + "px";
}
```

### Pattern 5: Scroll-Pin with Escape Hatch (CHAT-07)

**What:** Auto-scroll during streaming; stop when user scrolls up; show jump-to-bottom button.

```javascript
// Source: project convention — requestAnimationFrame scroll already in scrollChatToBottom()
function ccSetupScrollBehavior(tab) {
  var msgs = tab.el.querySelector(".cc-chat-messages");
  var scrollBtn = tab.el.querySelector(".cc-chat-scroll-anchor");
  if (!msgs) return;

  msgs.addEventListener("scroll", function() {
    var atBottom = msgs.scrollTop + msgs.clientHeight >= msgs.scrollHeight - 40;
    tab.autoScroll = atBottom;
    if (scrollBtn) scrollBtn.style.display = atBottom ? "none" : "block";
  });
}

function ccScrollToBottom(tabIdx) {
  var tab = _ideTabs.find(function(t) { return t.tabIdx === tabIdx; });
  if (!tab) return;
  var msgs = tab.el.querySelector(".cc-chat-messages");
  if (msgs) {
    requestAnimationFrame(function() { msgs.scrollTop = msgs.scrollHeight; });
  }
  tab.autoScroll = true;
  var scrollBtn = tab.el.querySelector(".cc-chat-scroll-anchor");
  if (scrollBtn) scrollBtn.style.display = "none";
}
```

### Pattern 6: Slash Command Dropdown (INPUT-04)

**What:** Show a filtered dropdown when user types `/` at start; keyboard navigable; close on selection/Escape/blur.

```javascript
// Source: project convention — vanilla JS DOM manipulation
var CC_SLASH_COMMANDS = [
  { cmd: "/help",    desc: "Show available commands" },
  { cmd: "/clear",   desc: "Clear current chat display" },
  { cmd: "/compact", desc: "Compact conversation context" },
];

function ccUpdateSlashDropdown(tab) {
  var input = document.getElementById("cc-input-" + tab.tabIdx);
  var dropdown = document.getElementById("cc-slash-" + tab.tabIdx);
  if (!input || !dropdown) return;

  var val = input.value;
  if (!val.startsWith("/") || val.includes(" ")) {
    dropdown.style.display = "none";
    return;
  }

  var filter = val.toLowerCase();
  var matches = CC_SLASH_COMMANDS.filter(function(c) {
    return c.cmd.startsWith(filter);
  });

  if (matches.length === 0) { dropdown.style.display = "none"; return; }

  dropdown.innerHTML = matches.map(function(c) {
    return "<div class='cc-slash-item' data-cmd='" + c.cmd + "'>"
         + "<span class='cc-slash-cmd'>" + esc(c.cmd) + "</span>"
         + "<span class='cc-slash-desc'>" + esc(c.desc) + "</span>"
         + "</div>";
  }).join("");
  dropdown.style.display = "block";

  // Wire click handlers after building HTML
  dropdown.querySelectorAll(".cc-slash-item").forEach(function(item) {
    item.addEventListener("click", function() {
      if (input) { input.value = item.dataset.cmd + " "; ccInputResize(input); }
      dropdown.style.display = "none";
      if (input) input.focus();
    });
  });
}
```

### Pattern 7: Stop Button — Frontend + Backend (CHAT-08)

**What:** Frontend sends `{"type":"stop"}` on WS. Backend terminates the subprocess.

**Frontend side:**
```javascript
// Source: Phase 1 WS message schema
function ccStop(tabIdx) {
  var tab = _ideTabs.find(function(t) { return t.tabIdx === tabIdx; });
  if (!tab || !tab.ws || tab.ws.readyState !== 1) return;
  tab.ws.send(JSON.stringify({ type: "stop" }));
  // Backend responds with turn_complete after proc.terminate()
}
```

**Backend side (server.py — new code for Phase 2):**
The current `cc_chat_ws` does not handle stop messages. Phase 2 must add handling in the `cc_chat_ws` message receive loop. The architecture challenge: `proc` is spawned and then the loop awaits `read_task`. A stop message cannot be received while `read_task` is being awaited in the current sequential structure.

**Solution:** Use `asyncio.wait()` with two awaitables — one for the stdout reader, one for a receive-next-message task. This allows concurrent WS message receipt and subprocess output reading. When a stop message arrives, cancel the read_task and terminate proc.

Alternatively: Use WS close from browser side (the existing `finally` block in `cc_chat_ws` already calls `proc.terminate()` on any disconnect). So the simplest stop implementation is: frontend closes the WS, backend terminates proc. But this drops the session. Better: implement the `asyncio.wait()` approach for graceful stop.

### Pattern 8: Thinking Block Display (CHAT-09)

**What:** CC emits thinking content blocks when using extended thinking models. Display in collapsible sections.

**Backend requirement:** `_parse_cc_event` must map `content_block_start` with type `"thinking"` to a `thinking_start` envelope, and accumulate thinking deltas into a `thinking_complete` envelope. This is a Phase 2 backend extension of Phase 1 code.

**Frontend:**
```javascript
// Source: project HTML patterns; details/summary is standard HTML5
function ccAppendThinkingBlock(tab, text) {
  var container = tab.el.querySelector(".cc-chat-messages");
  var block = document.createElement("details");
  block.className = "cc-thinking-block";
  var summary = document.createElement("summary");
  summary.className = "cc-thinking-summary";
  summary.textContent = "Thinking...";
  block.appendChild(summary);
  var content = document.createElement("div");
  content.className = "cc-thinking-content";
  content.textContent = text; // Use textContent (not innerHTML) — thinking is unformatted
  block.appendChild(content);
  container.appendChild(block);
}
```

### Pattern 9: ideActivateTab() Update (Critical)

**What:** The existing `ideActivateTab()` function has a `tab.type === "claude"` branch that calls `tab.fitAddon.fit()`. CC chat tabs have no fitAddon, so this crashes.

**How to fix:** Add a `chatPanel` check before the fitAddon call:
```javascript
// Modified ideActivateTab() branch for type === "claude"
if (tab.type === "claude") {
  if (container) container.style.display = "none";
  if (welcome) welcome.style.display = "none";
  if (ccContainer) {
    ccContainer.style.display = "block";
    var ccDivs = ccContainer.querySelectorAll(".ide-cc-term, .ide-cc-chat");
    ccDivs.forEach(function(d) { d.style.display = "none"; });
    if (tab.el) tab.el.style.display = "flex";
    // Only call fitAddon for old xterm tabs (chatPanel tabs have no fitAddon)
    if (!tab.chatPanel && tab.fitAddon) {
      try { tab.fitAddon.fit(); } catch(e) {}
    }
  }
}
```

### Anti-Patterns to Avoid

- **Running `marked.parse()` on partial markdown during streaming:** Mid-stream text is invalid markdown (unclosed code fences, incomplete links). Always buffer in `streamBuffer` and call `marked.parse()` only on `turn_complete`.
- **Omitting DOMPurify:** CHAT-05 is locked in STATE.md as non-negotiable. Every `marked.parse()` output MUST pass through `DOMPurify.sanitize()` before insertion. No exceptions.
- **Using `xterm.js` for the CC chat tab:** Old `ideOpenClaude()` used xterm. Phase 2 replaces this entirely with `ideOpenCCChat()`. Do not mix xterm and chat panel in the same tab type.
- **WS connecting to `/ws/terminal?cmd=claude`:** New function must connect to `/ws/cc-chat?token=...&session_id=...`.
- **Loading `highlight.js` core without languages:** `core.min.js` has zero language definitions. Use `highlight.min.js` (all languages) for simplicity.
- **Multiple scroll event listeners on tab revisit:** Guard with a flag `tab._scrollListenerAttached` to prevent duplicate registration on SPA navigation.
- **Not updating `ideReattachCCTabs()` for chat panel tabs:** The SPA navigation reattach function assumes xterm structure. It must also handle `chatPanel: true` tabs.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown parsing | Extended custom `renderMarkdown()` | `marked.js` v17.0.4 | Table support, proper nested lists, link rendering, GFM — regex chains can't handle all edge cases |
| XSS sanitization | Custom allowlist filter | `DOMPurify` v3.3.3 | Maintained by security experts; handles SVG injection, DOM clobbering, mXSS — a custom filter will miss these |
| Syntax highlighting | Regex-based coloring | `highlight.js` v11.11.1 | Language auto-detection, 190+ languages, nested constructs; regex coloring fails on complex cases |
| Auto-resize textarea | contenteditable div | scrollHeight pattern (3 lines) | contenteditable produces browser-dependent HTML (divs vs br elements); textarea is simpler and consistent |
| Slash command autocomplete | External library | Custom 30-line implementation | Fixed 3-5 commands; a full autocomplete library adds unnecessary weight |

**Key insight:** All three CDN libraries (marked + DOMPurify + highlight.js) are load-once, no-npm, no-bundler compatible and expose global variables — exactly how Monaco is already loaded in this project. No toolchain changes required.

---

## Common Pitfalls

### Pitfall 1: marked.js v17 API — Use `marked.parse()` Not `marked()`

**What goes wrong:** `marked(text)` still works as a deprecated alias in v17 but logs a deprecation warning to console.
**Why it happens:** API was renamed in v5; old call syntax is preserved as alias.
**How to avoid:** Always use `marked.parse(text)`.
**Warning signs:** Console warning "marked(): `marked` was called as a function..."

### Pitfall 2: highlight.js `core.min.js` Has Zero Languages

**What goes wrong:** `hljs.highlight(code, {language: 'python'})` returns un-highlighted output.
**Why it happens:** `core.min.js` is the engine without any language definitions.
**How to avoid:** Use `highlight.min.js` (full bundle, all languages) from CDN. Do NOT use `core.min.js`.
**Warning signs:** Code blocks render without color; no `hljs-keyword` spans in DOM.

### Pitfall 3: marked-highlight CDN UMD Namespace

**What goes wrong:** `markedHighlight(...)` throws "markedHighlight is not a function".
**Why it happens:** CDN UMD script exposes `globalThis.markedHighlight.markedHighlight` (namespace.function), not `globalThis.markedHighlight` directly.
**How to avoid:** Use `var mhFn = markedHighlight.markedHighlight;` before calling it.
**Warning signs:** `TypeError: markedHighlight is not a function` in console.

### Pitfall 4: Streaming Buffer Race — `streamMsgEl` Null on `turn_complete`

**What goes wrong:** `turn_complete` fires before any `text_delta`. `streamMsgEl` is null. Crash on null access.
**Why it happens:** CC can emit `turn_complete` for tool-only turns with no text output.
**How to avoid:** Guard `if (tab.streamMsgEl && tab.streamBuffer)` before rendering. If empty, just reset sending state without creating a bubble.
**Warning signs:** `TypeError: Cannot set properties of null`.

### Pitfall 5: `ideActivateTab()` Crashes on Chat Panel Tabs

**What goes wrong:** Switching to a CC chat tab throws `TypeError: Cannot read properties of undefined (reading 'fit')`.
**Why it happens:** `ideActivateTab()` calls `tab.fitAddon.fit()` for all `type === "claude"` tabs; chat panel tabs have no `fitAddon`.
**How to avoid:** Check `tab.chatPanel` before calling `fitAddon.fit()`. This is a required change to `ideActivateTab()` in Phase 2.
**Warning signs:** Tab switch crashes with fitAddon error.

### Pitfall 6: Multiple WS Connections on SPA Navigation

**What goes wrong:** Navigating away and back creates a second WS connection for the same tab.
**Why it happens:** SPA re-initialization may call `ideOpenCCChat()` again. The `ideReattachCCTabs()` path may also reconnect.
**How to avoid:** Check `tab.ws && tab.ws.readyState <= 1` before opening new WS. Follow existing `ideReattachCCTabs()` pattern.
**Warning signs:** Two WS entries for same session in browser DevTools Network tab.

### Pitfall 7: Stop Handler Requires Concurrent WS Receive

**What goes wrong:** Stop button click has no effect; generation continues.
**Why it happens:** The current `cc_chat_ws` loop does `await read_task` which blocks the WS receive path. Stop messages cannot be received while waiting for subprocess output.
**How to avoid:** Implement concurrent await using `asyncio.wait([read_task, receive_task], return_when=FIRST_COMPLETED)`. When stop message received, cancel read_task and terminate proc. See Pattern 7 above.
**Warning signs:** Stop button sends WS message (visible in DevTools) but subprocess keeps running.

### Pitfall 8: highlight.js CSS Theme Conflicts with Existing `.md-code-block` Styles

**What goes wrong:** Code blocks in the CC chat have double-styled backgrounds or mismatched fonts because both the custom `.md-code-block` CSS and highlight.js github-dark CSS apply.
**Why it happens:** highlight.js CSS is global; it applies to all `pre code` elements.
**How to avoid:** Scope highlight.js styles to `.cc-chat-messages pre code` only. Add a CSS rule in `style.css` that overrides or resets for `.cc-chat-messages` specifically.
**Warning signs:** Code blocks look different in CC chat vs regular Agent42 chat.

---

## Code Examples

### CDN Tags for `index.html`

```html
Source: jsdelivr.com verified versions (2026-03-18)
Add to <head>:
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/highlight.js@11.11.1/styles/github-dark.min.css">

Add before </body>, after Monaco scripts:
  <script src="https://cdn.jsdelivr.net/npm/marked@17.0.4/lib/marked.umd.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/marked-highlight@2.2.3/lib/index.umd.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/highlight.js@11.11.1/lib/highlight.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/dompurify@3.3.3/dist/purify.min.js"></script>
```

### Sending a User Message via WS

```javascript
// Source: Phase 1 WS message schema (Phase 1 RESEARCH.md)
function ccSend(tabIdx) {
  var tab = _ideTabs.find(function(t) { return t.tabIdx === tabIdx; });
  var input = document.getElementById("cc-input-" + tabIdx);
  if (!tab || !input || tab.sending) return;

  var text = input.value.trim();
  if (!text) return;

  // Handle /clear locally without sending to CC
  if (text === "/clear") {
    var msgs = tab.el.querySelector(".cc-chat-messages");
    if (msgs) msgs.textContent = "";
    input.value = "";
    ccInputResize(input);
    return;
  }

  // Append user bubble immediately (CHAT-01)
  ccAppendUserBubble(tab, text);

  // Send to backend WS
  if (tab.ws && tab.ws.readyState === 1) {
    tab.ws.send(JSON.stringify({ message: text }));
    tab.sending = true;
    ccSetSendingState(tab, true);
  }

  input.value = "";
  ccInputResize(input);
}
```

### Backend Stop Handler Addition (server.py Phase 2 change)

```python
# Source: asyncio.wait() pattern from Python asyncio docs
# Add inside cc_chat_ws while True: loop — concurrent receive + stop handling
# Replace: raw_msg = await websocket.receive_text()
# With: asyncio.wait() selecting between receive and active read_task

async def _receive_msg():
    return await websocket.receive_text()

receive_task = _asyncio.create_task(_receive_msg())
done, pending = await _asyncio.wait(
    {read_task, receive_task},
    return_when=_asyncio.FIRST_COMPLETED
)
if receive_task in done:
    raw_msg = receive_task.result()
    msg_data_inner = {}
    try:
        msg_data_inner = _json.loads(raw_msg)
    except Exception:
        pass
    if msg_data_inner.get("type") == "stop":
        read_task.cancel()
        if proc.returncode is None:
            proc.terminate()
        await websocket.send_json({"type": "turn_complete", "data": {
            "session_id": session_state.get("cc_session_id"),
            "cost_usd": None, "input_tokens": 0, "output_tokens": 0
        }})
        continue
    user_message = msg_data_inner.get("message", raw_msg)
else:
    receive_task.cancel()
    # read_task finished (turn complete) -- user_message remains from outer scope
```

### CSS for CC Chat Panel (additions to style.css)

```css
/* Source: project style conventions; follows existing chat CSS patterns */
.ide-cc-chat { display: flex; flex-direction: column; height: 100%; overflow: hidden; }
.cc-chat-messages { flex: 1; overflow-y: auto; padding: 1rem; }
.cc-chat-composer { padding: 0.75rem; border-top: 1px solid var(--border);
                    display: flex; gap: 0.5rem; align-items: flex-end; }
.cc-chat-input { flex: 1; resize: none; min-height: 38px; max-height: 200px;
                 background: var(--bg-tertiary); color: var(--text-primary);
                 border: 1px solid var(--border); border-radius: 6px;
                 padding: 0.5rem 0.75rem; font-family: var(--sans);
                 font-size: 0.9rem; line-height: 1.5; overflow-y: auto; }
.cc-chat-input:focus { outline: none; border-color: var(--accent); }
.cc-send-btn { padding: 0.5rem 1rem; background: var(--accent); color: white;
               border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; }
.cc-stop-btn { padding: 0.5rem 1rem; background: var(--danger, #ef4444); color: white;
               border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; }
.cc-chat-scroll-anchor { position: sticky; bottom: 0; text-align: center;
                          padding: 0.25rem; }
.cc-slash-dropdown { position: absolute; bottom: 100%; left: 0; right: 0;
                     background: var(--bg-secondary); border: 1px solid var(--border);
                     border-radius: 6px; z-index: 100; max-height: 160px; overflow-y: auto; }
.cc-slash-item { display: flex; justify-content: space-between; padding: 0.4rem 0.75rem;
                 cursor: pointer; }
.cc-slash-item:hover { background: var(--bg-hover); }
.cc-slash-cmd { font-weight: 600; color: var(--accent); font-family: var(--mono); }
.cc-slash-desc { color: var(--text-muted); font-size: 0.8rem; }
.cc-streaming-body::after { content: "\u258C"; animation: ccBlink 1s step-end infinite; }
@keyframes ccBlink { 50% { opacity: 0; } }
.cc-thinking-block { border: 1px solid var(--border); border-radius: 6px;
                     margin: 0.5rem 0; background: var(--bg-tertiary); }
.cc-thinking-summary { cursor: pointer; padding: 0.4rem 0.75rem;
                       color: var(--text-muted); font-size: 0.85rem; }
.cc-thinking-content { padding: 0.75rem; font-size: 0.85rem; white-space: pre-wrap;
                       color: var(--text-secondary); }
/* Scope highlight.js to CC chat only (prevents conflict with existing .md-code-block) */
.cc-chat-messages .hljs { background: transparent; }
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `claude` tab = raw xterm terminal via `/ws/terminal?cmd=claude` | `claude` tab = structured chat UI via `/ws/cc-chat` | Phase 2 (this phase) | Markdown rendering, streaming cursors, stop button; no more raw terminal UX |
| Custom `renderMarkdown()` regex chain | `marked.parse()` + `DOMPurify.sanitize()` + `hljs` | Phase 2 (this phase) | Proper GFM, tables, nested lists, syntax highlighting, XSS protection |
| Typing indicator (3-dot animation) | Streaming text cursor (blinking block after last character) | Phase 2 (this phase) | Token-by-token streaming visible to user |
| `marked(text)` (old call syntax) | `marked.parse(text)` (v5+ API) | marked.js v5 (~2023) | Old syntax still aliases in v17 but is deprecated |

**Deprecated/outdated in Phase 2:**
- `ideOpenClaude()`: Replaced by `ideOpenCCChat()` — old function uses xterm + `/ws/terminal`
- `ideReattachCCTabs()`: Must be updated to handle `chatPanel: true` tabs (currently assumes xterm structure with `fitAddon`)
- xterm-based `type: "claude"` tab structure: Replaced by chat panel structure; old xterm claude tabs can still exist for users who had them, but new ones use chat panels

---

## Open Questions

1. **Stop handler concurrency in `cc_chat_ws`**
   - What we know: Current sequential `await read_task` structure blocks WS receive while subprocess is running. Stop messages cannot be received in this flow.
   - What's unclear: Whether `asyncio.wait()` with concurrent receive/read tasks introduces complexity that outweighs the benefit vs. simpler alternatives (e.g., WS close-and-reopen).
   - Recommendation: Implement `asyncio.wait()` concurrent pattern (Pattern 7). This is the correct asyncio idiom. Add a backend test to `test_cc_bridge.py::TestCCChatStop` that verifies `{"type":"stop"}` handling in source.

2. **Thinking block event type from backend**
   - What we know: CC emits `content_block_start` with `type: "thinking"` for extended thinking models. Phase 1 `_parse_cc_event` handles `content_block_start` for `tool_use` type but not `thinking` type — it currently falls through to the empty-list return.
   - What's unclear: Should thinking block accumulation happen in the backend (full thinking text in `thinking_complete`) or client-side (thinking deltas streamed as `thinking_delta`)?
   - Recommendation: Extend `_parse_cc_event` in Phase 2 to emit `thinking_complete` envelope when a `thinking` content block ends. This minimizes frontend complexity.

3. **highlight.js CSS scoping with existing `.md-code-block`**
   - What we know: `github-dark.min.css` sets backgrounds on `.hljs` elements globally. The existing `.md-code-block pre` CSS also sets styling.
   - What's unclear: Whether adding `github-dark.min.css` globally will visually break the existing Agent42 chat page code blocks.
   - Recommendation: Add a CSS override in `style.css` to scope highlight.js styles to `.cc-chat-messages` only (see CSS example above). Test both chat pages after integration.

4. **Session ID generation for CC chat tabs**
   - What we know: Phase 1 accepts `session_id` as WS query param; generates UUID if absent. Phase 2 needs to pass a client-generated ID for multi-session support.
   - What's unclear: Whether `crypto.randomUUID()` is available in all target browsers (it requires HTTPS or localhost).
   - Recommendation: Use `crypto.randomUUID()` with fallback to `Math.random().toString(36)` pattern already used in `renderMarkdown()` code block IDs.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pytest with pytest-asyncio |
| Config file | `pyproject.toml` — `asyncio_mode = "auto"` |
| Quick run command | `python -m pytest tests/test_cc_chat_ui.py -x -q` |
| Full suite command | `python -m pytest tests/ -x -q` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CHAT-01 | User bubble HTML class pattern in source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatRendering::test_user_bubble_structure -x` | No — Wave 0 |
| CHAT-02 | Streaming bubble created for `text_delta`; streaming class in source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatRendering::test_streaming_bubble_class -x` | No — Wave 0 |
| CHAT-03 | `marked.parse` present in `ccRenderMarkdown` source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatRendering::test_uses_marked_parse -x` | No — Wave 0 |
| CHAT-04 | `markedHighlight` present in source; hljs integration wired | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatRendering::test_uses_marked_highlight -x` | No — Wave 0 |
| CHAT-05 | `DOMPurify.sanitize` called in render function in source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatRendering::test_dompurify_called -x` | No — Wave 0 |
| CHAT-06 | `setInterval` with 50 present in streaming section of source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatRendering::test_50ms_batch_interval -x` | No — Wave 0 |
| CHAT-07 | `autoScroll` flag and scroll anchor button in source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatScrolling::test_autoscroll_flag -x` | No — Wave 0 |
| CHAT-08 (FE) | `ccStop` sends `{"type":"stop"}` in source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatStop::test_stop_sends_type_stop -x` | No — Wave 0 |
| CHAT-08 (BE) | `cc_chat_ws` handles `"type": "stop"` in server.py source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatStop::test_backend_handles_stop -x` | No — Wave 0 |
| CHAT-09 | `details` element present in thinking block code in source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatRendering::test_thinking_uses_details -x` | No — Wave 0 |
| INPUT-01 | `<textarea>` and `shiftKey` guard in source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatInput::test_textarea_shift_enter -x` | No — Wave 0 |
| INPUT-02 | `pre-wrap` or `pre-line` in CC chat CSS | unit (CSS inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatInput::test_multiline_preserved -x` | No — Wave 0 |
| INPUT-03 | `ccInputResize` calls `scrollHeight` in source | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatInput::test_autoresize_scrollheight -x` | No — Wave 0 |
| INPUT-04 | `ccUpdateSlashDropdown` defined in source; `/` detection present | unit (source inspect) | `pytest tests/test_cc_chat_ui.py::TestCCChatInput::test_slash_dropdown_defined -x` | No — Wave 0 |
| CHAT-03/04 | index.html contains marked.js and highlight.js CDN script tags | unit (file content) | `pytest tests/test_cc_chat_ui.py::TestCCChatDeps::test_cdn_scripts_in_index -x` | No — Wave 0 |
| CHAT-05 | index.html contains DOMPurify CDN script tag | unit (file content) | `pytest tests/test_cc_chat_ui.py::TestCCChatDeps::test_dompurify_in_index -x` | No — Wave 0 |

**Testing strategy:** All tests follow the `test_ide_html.py` pattern — source text inspection of `app.js`, `index.html`, and `style.css` via `Path.read_text()`. No browser automation. Backend stop handler verified by extending with `test_cc_chat_ui.py::TestCCChatStop`.

### Sampling Rate

- **Per task commit:** `python -m pytest tests/test_cc_chat_ui.py -x -q`
- **Per wave merge:** `python -m pytest tests/ -x -q`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/test_cc_chat_ui.py` — all 16 test functions listed above; follows `test_ide_html.py` class structure

No other gaps — existing pytest infrastructure covers all requirements.

---

## Sources

### Primary (HIGH confidence)

- `dashboard/frontend/dist/app.js` (direct read 2026-03-18) — `renderMarkdown()`, `buildChatMsgHtml()`, `ideOpenClaude()`, `ideActivateTab()`, `esc()`, `scrollChatToBottom()`, `appendChatMsgToDOM()` all confirmed present with exact line numbers
- `dashboard/frontend/dist/index.html` (direct read 2026-03-18) — Monaco CDN pattern confirmed; model for adding new CDN scripts
- `dashboard/frontend/dist/style.css` (direct read 2026-03-18) — `.chat-msg*`, `.md-code-block`, `.ide-cc-container`, `.ide-cc-term`, `.chat-typing*` confirmed
- `.planning/workstreams/custom-claude-code-ui/REQUIREMENTS.md` (read 2026-03-18) — CHAT-01 through INPUT-04 requirements confirmed; marked.js/DOMPurify/highlight.js explicitly named
- `.planning/workstreams/custom-claude-code-ui/STATE.md` (read 2026-03-18) — locked decisions confirmed: DOMPurify non-negotiable, append-only DOM, scroll-pin must be initial implementation
- Phase 1 `01-RESEARCH.md` (read 2026-03-18) — WS message schema (`text_delta`, `turn_complete`, etc.) confirmed HIGH confidence
- https://marked.js.org/using_advanced (WebFetch 2026-03-18) — `marked.parse()` API confirmed; DOMPurify integration pattern documented
- https://github.com/cure53/DOMPurify/blob/main/README.md (WebFetch 2026-03-18) — `DOMPurify.sanitize()` API, ALLOWED_TAGS config confirmed
- https://github.com/markedjs/marked-highlight (WebFetch 2026-03-18) — CDN UMD access pattern `markedHighlight.markedHighlight` confirmed; version 2.2.3

### Secondary (MEDIUM confidence)

- https://www.jsdelivr.com/package/npm/marked (WebFetch 2026-03-18) — version 17.0.4 confirmed
- https://www.jsdelivr.com/package/npm/dompurify (WebFetch 2026-03-18) — version 3.3.3 confirmed
- https://www.jsdelivr.com/package/npm/highlight.js (WebFetch 2026-03-18) — version 11.11.1 confirmed
- CSS-Tricks scrollHeight textarea pattern — widely confirmed standard approach, multiple sources agree

### Tertiary (LOW confidence)

- Thinking block event type in backend — CC thinking support from training knowledge; exact backend normalized event type not verified from live CC session; flagged as Open Question 2
- Stop handler `asyncio.wait()` correctness — analysis of `cc_chat_ws` code structure; exact behavior under concurrent stop+read not tested against live server; flagged as Open Question 1

---

## Metadata

**Confidence breakdown:**

- Standard stack (libraries + versions): HIGH — all versions confirmed via jsDelivr WebFetch on 2026-03-18
- CDN UMD access pattern for marked-highlight: HIGH — confirmed from official GitHub README
- Architecture (streaming lifecycle): HIGH — derived directly from Phase 1 WS schema + reading 5600+ lines of app.js
- Existing CSS/DOM patterns: HIGH — direct code read of all three files
- Pitfalls (fitAddon crash, duplicate listeners): HIGH — derived from direct code reading of `ideActivateTab()` and tab state object
- Thinking block backend events: LOW — not verified from live CC session; open question
- Stop handler concurrency: LOW — asyncio analysis; not tested live

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (marked/hljs/DOMPurify are stable; re-verify if CC CLI version bumps significantly)
