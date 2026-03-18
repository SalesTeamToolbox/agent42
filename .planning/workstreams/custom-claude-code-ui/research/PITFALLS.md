# Pitfalls Research

**Domain:** AI chat UI added to existing vanilla JS SPA — Claude Code integration
**Researched:** 2026-03-17
**Confidence:** HIGH (primary pitfalls from direct codebase inspection + verified against official docs and community reports)

---

## Critical Pitfalls

### Pitfall 1: ANSI Escape Sequences Split Across WebSocket Frames

**What goes wrong:**
Claude CLI emits ANSI escape sequences (color codes, cursor movement, progress spinners) as raw terminal output. When the backend forwards this byte-by-byte over WebSocket, a multi-byte escape sequence can arrive split across two message frames. A naive renderer that processes each message independently will display garbage characters (e.g., `ESC[32m` rendered as literal text) or corrupt the chat bubble content.

**Why it happens:**
WebSocket messages are not aligned to terminal escape sequence boundaries. The backend's `ws.send(data)` fires on whatever chunk arrives from the subprocess. ANSI sequences like `ESC[38;2;255;128;0m` (24-bit color) are 13+ bytes. If the process flushes mid-sequence, two frames arrive: `ESC[38;2;` and `255;128;0m`.

**How to avoid:**
Maintain a buffer per stream. Before processing, append incoming data to the buffer, then parse complete escape sequences only. Any incomplete sequence at the end of the buffer stays buffered. The `ansi-to-html` npm package handles this correctly if you use its stateful streaming API (not the one-shot `.toHtml(str)` method). For the xterm.js terminal path, this is handled automatically — xterm.js has internal ANSI state. The problem only affects custom chat-bubble rendering that bypasses xterm.js.

**Warning signs:**
- Chat bubbles contain literal ESC characters or `[32m` text
- Color formatting appears on wrong messages (the escape code from message N bleeds into message N+1)
- Spinner characters appear as `|`, `-`, `\`, `/` sequences in text rather than animated

**Phase to address:**
Phase where streaming message rendering is first implemented. The buffer must be part of the initial architecture, not retrofitted.

---

### Pitfall 2: Markdown Rendered Without Sanitization

**What goes wrong:**
LLM output contains markdown that gets parsed into HTML and injected via `innerHTML`. If the AI output (or an adversarial prompt injection) contains script tags, `img onerror` attributes, or `javascript:` protocol URLs in links, the user's browser executes arbitrary JavaScript. Agent42's existing `esc()` helper escapes text but does not handle HTML markup, so it cannot be used for rendered markdown.

**Why it happens:**
`marked.js` (the most common vanilla JS markdown library) explicitly does NOT sanitize output — it documents this as intentional. Developers assume the AI won't generate malicious HTML, forgetting that:
1. Users can inject via prompts (prompt injection attacks)
2. Tool output (bash command results, file contents) can contain HTML
3. Code blocks with HTML content get rendered as markup if not escaped inside `pre`

CVE-2025-24981 (Nuxt MDC XSS via javascript: protocol bypass) shows sanitization libraries themselves can have bypasses — defense in depth is required.

**How to avoid:**
Run `DOMPurify.sanitize(markedOutput)` on every markdown-to-HTML conversion AFTER marked.js processes the input, not before. The order matters: sanitize before parsing breaks markdown; sanitize after removes dangerous HTML. Additionally:
- Set `marked({ mangle: false, headerIds: false })` to reduce attack surface
- Use `DOMPurify.addHook('afterSanitizeAttributes', ...)` to strip `javascript:` from hrefs
- Load DOMPurify as a local bundle (not CDN) to prevent CDN-based attacks

**Warning signs:**
- Tool output containing HTML tags renders as formatted text instead of showing literal tags
- File contents with HTML fragments appear rendered
- No DOMPurify in the dependency list anywhere in the codebase

**Phase to address:**
Phase 1 of chat rendering. Never merge message rendering code without sanitization already in place.

---

### Pitfall 3: stream-json Event Type Brittleness — Unknown Events Crash Parser

**What goes wrong:**
Claude CLI's `--output-format=stream-json` emits JSONL with multiple top-level types: `system`, `assistant`, `user`, `stream_event`, `result`. The `stream_event` subtype includes: `message_start`, `content_block_start`, `content_block_delta` (with `text_delta` and `input_json_delta` variants), `content_block_stop`, `message_delta`, `message_stop`. A parser that only handles the expected happy-path events will throw or silently drop data when Anthropic adds new event types (they do, without major version bumps).

Additionally, tool call inputs arrive as **partial JSON strings** via `input_json_delta` events — you must accumulate all deltas for a content block and parse JSON only after `content_block_stop`. Attempting to parse intermediate deltas produces a `SyntaxError` every time.

**Why it happens:**
The CC CLI docs only show a `text_delta` example. The full event type reference is only in the Agent SDK docs at platform.claude.com, not the CLI docs at code.claude.com. Teams building against the CLI miss the Agent SDK docs. GitHub issue #24596 on anthropics/claude-code confirms this is a known documentation gap.

**How to avoid:**
- Write the parser as a state machine with explicit unknown-event handling: log unknown event types rather than throwing
- Accumulate tool input JSON in a per-block buffer keyed by `content_block.index`; parse only on `content_block_stop`
- Test against a real CC session capture (record then replay) rather than mocking, so unknown events surface during development
- Pin the CC CLI version in your tests to detect when Anthropic adds new events

**Warning signs:**
- Parser works in demos but throws in production when CC starts a tool call
- Tool use cards show blank input (input_json_delta events silently dropped)
- Any JSON.parse call on a delta.text field that could be a partial JSON string

**Phase to address:**
Phase where stream-json parsing is first implemented. The accumulator state machine must be part of the initial design.

---

### Pitfall 4: Scroll-Jump Fighting — User Scroll vs Auto-Scroll

**What goes wrong:**
Auto-scroll to the bottom fires on every streaming token. When the user scrolls up to re-read an earlier message (while Claude is still streaming), the auto-scroll immediately jumps them back to the bottom. The experience becomes unusable for long responses.

The inverse problem also exists: if auto-scroll is disabled entirely, new content arrives silently off-screen and the user thinks Claude stopped responding.

**Why it happens:**
Naive implementation: `messageContainer.scrollTop = messageContainer.scrollHeight` called directly in the WebSocket `onmessage` handler. No check for whether the user has scrolled away.

**How to avoid:**
Track user scroll intent with a "user has scrolled up" flag. Algorithm:
1. On every `scroll` event: if `scrollHeight - scrollTop - clientHeight > threshold` (e.g., 80px), set `userScrolledUp = true`; if within threshold, set `userScrolledUp = false`
2. In the streaming token handler: only auto-scroll if `userScrolledUp === false`
3. Show a "scroll to bottom" button (floating, bottom-right) when `userScrolledUp === true` and streaming is active

Use `requestAnimationFrame` for the actual scroll call, not inline in the message handler, to avoid forced reflow on every token.

**Warning signs:**
- QA testers report "scrolling up breaks the UI"
- Auto-scroll works in demos (single short responses) but not in real 60-second multi-step tasks
- No scroll position tracking anywhere in the chat rendering code

**Phase to address:**
Phase where streaming rendering is first built. The scroll intent tracking must be part of the first implementation, not a later fix.

---

### Pitfall 5: DOM Thrash — Rebuilding the Entire Message List on Each Token

**What goes wrong:**
Setting `chatContainer.innerHTML = buildAllMessages(messages)` on every incoming token causes the browser to destroy and recreate the entire DOM subtree 10-50 times per second. At 20+ messages in a conversation, this causes visible stuttering and prevents user interaction (text selections lost, scroll position reset, focus stolen from input field).

**Why it happens:**
The pattern that works for loading initial state (render full HTML from data array) is incorrectly reused for streaming updates. It feels simple and correct until load testing with real LLM output latency.

**How to avoid:**
Use an append-only update strategy for streaming:
1. On message start: create the message element once, append it to the container, store a reference in the session object (`session.currentMessageEl`)
2. On each token: append only to `session.currentMessageEl.querySelector('.content')`, never rebuild parent
3. On message end: finalize the element (re-render markdown fully, add copy button, etc.)
4. Only use full rebuild for initial load of conversation history

For content updates during streaming: `el.textContent += newToken` for plain text, or re-render the full accumulated text into a limited-scope element for markdown — but never rebuild the whole message list.

**Warning signs:**
- Text selection in chat disappears while Claude is still typing
- Input focus is lost mid-stream
- Browser DevTools performance profiler shows "Recalculate Style" consuming more than 50% of frame time

**Phase to address:**
Phase 1 of streaming rendering. Append-only is the only acceptable pattern for streaming updates.

---

### Pitfall 6: WebSocket Reconnect Creates Ghost Sessions — Old Handlers Still Fire

**What goes wrong:**
On WebSocket reconnection, a new `WebSocket` object is created and assigned to `session.ws`. The old WebSocket's event handlers still fire if the old connection sends data before closing. Two handlers now write to the same message element. The result: duplicate tokens, doubled content, or (worst case) the old `onclose` handler triggers another reconnect loop, creating unbounded connection growth.

**Why it happens:**
WebSocket event handlers are registered on the object. When you replace `session.ws = new WebSocket(...)`, the old object's handlers still reference the old closure variables. The reconnect code in 19.1-RESEARCH.md pattern correctly re-creates the WebSocket, but the old WebSocket handlers must be explicitly nulled before replacement.

**How to avoid:**
Before creating a new WebSocket, null the old handlers:

```javascript
if (session.ws) {
  session.ws.onmessage = null;
  session.ws.onerror = null;
  session.ws.onclose = null;  // Prevent old close from triggering another reconnect
}
session.ws = new WebSocket(wsUrl);
```

Also track a `session.reconnectId` counter — each reconnect increments it. Handlers check if the current reconnect ID matches before acting.

**Warning signs:**
- Messages appear duplicated during reconnection
- Console shows multiple "Reconnected" messages for a single reconnect event
- Server logs show a single client making multiple simultaneous WebSocket connections

**Phase to address:**
Phase where WebSocket connection management is built. The null-handler pattern must be part of the initial `ccConnectWs` implementation.

---

### Pitfall 7: CC Session Resume Breaks After Page Navigation

**What goes wrong:**
Claude Code supports `--resume <session-id>` to continue a previous conversation. The session ID is captured from CC output and stored in browser state. When the user navigates away from the IDE page and returns (SPA navigation), the session ID is lost unless explicitly persisted. The new CC process starts fresh, losing all context.

Additionally: `--resume` requires the session file on disk. If CC is running remotely (via SSH), the session files are on the remote machine. Passing `--resume` to a local CC instance after previously using a remote instance silently starts a new session instead of failing with a clear error.

**Why it happens:**
SPA navigation calls the render function for each page but clears in-memory state. `_termSessions` is a module-level array in app.js — it survives within a page session but resets on hard reload. The CC session ID is not stored in sessionStorage or the backend.

**How to avoid:**
- Store active CC session IDs in `sessionStorage` (not localStorage — session-scoped, not accessible cross-tab) keyed by connection type (local/remote)
- On CC process creation, check for a stored session ID; if present, pass `--resume <id>` to the CC process
- Parse the session ID from CC's startup output and update the stored ID
- For remote sessions, store the session ID server-side since the session file lives on the remote machine

**Warning signs:**
- Users lose conversation context on every page refresh
- No session ID extraction logic in the CC output parser
- The `--resume` flag never appears in the process spawn command

**Phase to address:**
Phase where CC integration is first built. Session persistence is a foundation concern, not a polish concern.

---

## Moderate Pitfalls

### Pitfall 8: Markdown Code Block Flicker During Streaming

**What goes wrong:**
Markdown parsers identify code blocks by matching triple-backtick pairs. During streaming, an opening set of backticks arrives but the closing set has not yet. The parser renders the rest of the message as a code block (applying syntax highlighting, monospace font) until the closing delimiter arrives. This causes a jarring flash that can last several seconds on long code outputs.

**Why it happens:**
Most markdown parsers are designed for complete documents. They don't have a "streaming incomplete" mode.

**How to avoid:**
During active streaming, do not run full markdown parsing. Render as plain text with basic inline formatting only. Apply full markdown parse on `message_stop`. If the incomplete-code-block flash is unacceptable even briefly, detect open code blocks by counting backtick-fence occurrences (odd count = open block) and inject a temporary closing fence before parsing.

Strategy 1 (defer full parse) is simpler and correct for this project's no-build-step constraint.

**Warning signs:**
- Entire tail of a message switches to code formatting mid-stream
- Syntax highlighting flickers on and off as tokens arrive

**Phase to address:**
Phase where streaming markdown rendering is implemented. The decision to defer full markdown rendering must be made up front.

---

### Pitfall 9: Monaco Diff Editor Timeout on Large Files

**What goes wrong:**
Monaco's diff editor has a built-in computation timeout defaulting to 5000ms. For files over approximately 200,000 lines, it silently gives up and shows no diff. For files with complex change patterns, the computation saturates CPU for the full timeout duration, blocking UI interaction.

**Why it happens:**
The diff editor runs synchronously in the main thread. Monaco's `maxComputationTimeMs` option is not commonly known, and its default failure mode (no diff shown, no error) is silent.

**How to avoid:**
- Set `maxComputationTimeMs: 2000` explicitly (fail fast, don't block the UI)
- Set `maxFileSize: 10` (MB limit before diff is disabled)
- When diff computation is skipped, show a clear message: "File too large for inline diff — open in editor"
- For very large diffs, offer a "Download patch" option rather than trying to render all hunks

**Warning signs:**
- Diff viewer shows blank content for large files without any error message
- UI freezes briefly when opening diffs for files with many changes
- No `maxComputationTimeMs` setting in the Monaco diff editor initialization

**Phase to address:**
Phase where diff viewer is implemented.

---

### Pitfall 10: Hybrid CLI/API Connection State Not Surfaced in UI

**What goes wrong:**
The smart hybrid model routes interactive chat through CC subscription (CLI subprocess) and autonomous tasks through Agent42's API. If the connection type is not clearly surfaced in the UI, users don't know which backend is handling their request. When CC subscription auth expires, the CLI fails or shows an auth prompt inside the terminal — invisible to the chat UI. The user sees no response and assumes the system hung.

**Why it happens:**
Auth state lives inside the CC subprocess. The subprocess writing "Please run `claude auth login`" to stdout is lost in the ANSI/JSONL stream unless the parser explicitly looks for it. The reconnect logic (designed for network drops) will retry indefinitely on an auth failure, which requires user action to resolve.

**How to avoid:**
- Display the active connection type prominently in the chat header ("CC Subscription" badge vs "API" badge)
- Parse CC output for auth-related strings: "Please authenticate", "auth login", "subscription required" — surface these as a formatted warning card in the UI, not as terminal output
- Add a backend health check for CC auth status: `claude auth status --text` returns parseable output; call this on CC startup and cache for 5 minutes
- When the CC process exits with a non-zero code, show a "Session ended — reconnect?" prompt rather than silently retrying

**Warning signs:**
- Users report "Claude stopped responding" when auth expired
- No connection type indicator anywhere in the chat UI
- The reconnect logic retries indefinitely without checking the process exit code

**Phase to address:**
Phase where hybrid connection switching is implemented. Auth state detection must be part of the CC output parser from the start.

---

### Pitfall 11: Tool Use Cards — Input JSON Arriving Out of Order

**What goes wrong:**
When rendering tool use cards (file reads, writes, shell commands), the tool name arrives in `content_block_start` but the input parameters arrive across multiple `input_json_delta` events as partial JSON strings. A renderer that draws the card on `content_block_start` will show "Running tool..." with no parameters, then suddenly populate. Intermediate states where parameters show `undefined` or `null` occur during the accumulation window.

**Why it happens:**
The streaming event model separates block start (tool name) from block content (tool input JSON). This is correct for the API, but visual rendering must handle the gap between them.

**How to avoid:**
Buffer tool use events. Only render the tool card when you have both the tool name AND the complete parsed input JSON (on `content_block_stop`). During accumulation, show a minimal "Calling tool..." placeholder that does not include parameters. This also prevents security issues from rendering partially-parsed JSON.

**Warning signs:**
- Tool cards briefly show empty braces or missing parameters during streaming
- JSON.parse errors in console during tool streaming
- Tool cards rendered on `content_block_start` (too early)

**Phase to address:**
Same phase as stream-json parsing (Pitfall 3). The accumulator must handle tool events alongside text events.

---

### Pitfall 12: Global Keydown Listeners Accumulating Across Page Revisits

**What goes wrong:**
The IDE page's `renderCode()` is called on every SPA navigation to the code page. Any `document.addEventListener('keydown', handler)` call inside `renderCode()` without a deregistration guard adds a new listener on every visit. After 5 page revisits, pressing a shortcut fires the handler 5 times. For Ctrl+\` (terminal toggle), this causes the panel to open and immediately close.

This pattern recurs for all chat keyboard shortcuts (Shift+Enter for newline, Escape to cancel streaming, etc.).

**Why it happens:**
SPA navigation pattern re-renders the page view but does not destroy the document. Event listeners on `document` survive navigation.

**How to avoid:**
Use the `window._<name>ListenerAttached` guard pattern established in Phase 19.1. For chat-specific shortcuts, centralize ALL keyboard handlers in one `initChatKeyHandlers()` function called once with a guard:

```javascript
if (!window._chatKeyHandlersAttached) {
  window._chatKeyHandlersAttached = true;
  document.addEventListener('keydown', chatKeyHandler);
}
```

**Warning signs:**
- Keyboard shortcuts trigger multiple times per keystroke
- Shift+Enter creates multiple newlines per press
- DevTools Event Listeners panel shows N identical handlers on `document`

**Phase to address:**
Phase 1 of chat UI build. Establish the guard pattern for all listeners before adding any shortcuts.

---

### Pitfall 13: JWT Accessible to Injected Scripts via localStorage

**What goes wrong:**
The Agent42 dashboard stores the JWT in `localStorage` (confirmed in app.js `state.token`). If an XSS vulnerability exists anywhere in the SPA (including via markdown rendering), an attacker can read the JWT with `localStorage.getItem('token')` and authenticate as the user. This is especially serious for Agent42 because the dashboard controls agent execution and server shell access via WebSocket terminal.

**Why it happens:**
localStorage is the path of least resistance for SPA token storage. The JWT is used to authenticate WebSocket connections to the terminal — token theft equals shell access.

**How to avoid:**
- Ensure DOMPurify is in place (Pitfall 2) before any user-controlled content reaches markup injection points
- Do NOT store CC session IDs or any additional credentials in localStorage — use sessionStorage (not accessible across tabs) for CC session IDs
- Implement a strict Content Security Policy that blocks inline scripts and `javascript:` protocol URLs
- The token storage architecture (localStorage vs HttpOnly cookie) is an existing decision in Agent42; the mitigation for this workstream is correct markdown sanitization

**Warning signs:**
- Any user-controlled content reaching markup injection points without DOMPurify
- No Content-Security-Policy header on the dashboard
- CC session IDs stored in localStorage rather than sessionStorage

**Phase to address:**
Security review phase, or as part of the markdown rendering phase when DOMPurify is introduced.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Render full message list HTML on each streaming token | Simple, stateless rendering | DOM thrash, stolen focus, lost text selection, O(n) work per token | Never for streaming; only for initial load |
| Markdown rendering without sanitization | One less dependency | XSS via prompt injection or tool output containing HTML | Never |
| Store CC session ID in memory only | Simple, no persistence code | Users lose context on refresh, no resume support | Only in Phase 1 prototype, must be fixed before ship |
| Parse ANSI with regex over raw bytes | Quick and simple | Breaks on split frames, misses non-SGR sequences, strips control characters CC uses for cursor navigation | Only if output is plain text with simple colors; not for CC interactive output |
| Rebuild entire chat on reconnect | Simplest reconnect handling | Flash of unstyled content, scroll position lost | In demos; never in production |
| Single WebSocket for both terminal and chat | Fewer connections | Protocol collision — terminal sends raw bytes, chat sends JSON events; parsing the wrong protocol produces garbage | Never — keep separate WebSocket connections for each session type |

---

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| CC CLI subprocess | Mixing `--output-format=stream-json` with interactive mode | `stream-json` only works with `-p` (print mode); use `--print --output-format=stream-json --include-partial-messages` for parsed chat; use interactive mode (no flags) for raw terminal tab |
| CC CLI auth | Treating auth failure as a network error and reconnecting forever | Parse exit codes: CC exits 1 on auth failure; stop reconnect loop and show "Auth required" card |
| Monaco diff editor | Creating a new `monaco.editor.createDiffEditor()` on every diff view without disposing the previous instance | Call `diffEditor.dispose()` before creating a new one; or reuse one instance by calling `setModel({ original, modified })` |
| marked.js | Calling `marked()` without setting `breaks: true` | CC output uses single `\n` for newlines, not the markdown double-newline paragraph break; set `breaks: true` or normalize newlines before parsing |
| DOMPurify | Loading DOMPurify from a CDN after the page loads | If the CDN request is blocked or slow, DOMPurify is undefined and unsafe rendering proceeds silently; bundle locally |
| Agent42 apiFetch() | Using raw `fetch()` for new CC-related API calls | Always use `apiFetch()` — it injects the auth token and handles 401 redirects automatically |
| WebSocket over HTTPS | Hardcoding `ws://` protocol | Must use `wss://` when the page is served over HTTPS; use `location.protocol === 'https:' ? 'wss:' : 'ws:'` |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Synchronous markdown parsing on every token | Frame drops, input lag during streaming | Defer full markdown parse to `message_stop`; show plain text during streaming | At approximately 20 tokens/second (typical CC output speed) |
| Creating new DOM elements for each streaming token | Reflow cascade, memory growth | Append text to existing element | At more than 5 tokens/second sustained for more than 30 seconds |
| Storing full message history in JS object without pruning | Memory leak on long sessions | Cap at 200 messages in memory; older messages fetched from session storage | After 2-3 hour CC sessions with multiple tool calls |
| Rendering all conversation history on resume | Page hangs when loading a long session | Paginate: load last 50 messages, add "Load earlier" button | Sessions with more than 100 exchanges |
| Monaco diff editor for every file change including trivial ones | CPU spike on every agent action | Only open diff editor on explicit user request; show a simple "N lines changed" summary by default | When CC runs an agent loop with 20+ file edits |
| Polling for CC session status | Unnecessary API calls, battery drain | Event-driven only: listen to WebSocket messages from CC subprocess | Immediately — polling is the wrong model for this use case |

---

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Rendering tool output (bash results, file contents) as markup | XSS via crafted file content — agent reads a file containing a script tag | Always escape tool output with textContent, never markup injection; wrap in pre elements |
| Diff viewer applying file content directly without sanitization | Agent writes a file containing XSS payload; diff viewer renders it as HTML | DOMPurify on both sides of the diff before Monaco receives it |
| Exposing `--dangerously-skip-permissions` as a UI toggle | One-click to disable all CC permission prompts | Never expose as a UI option; if needed, require it as a CLI flag at process start with documented risk |
| Storing CC auth tokens in browser storage | Token theft via XSS results in CC account compromise | CC auth lives in `~/.claude/` on the server, not in the browser; the browser only needs Agent42's JWT |
| CORS wildcard on CC session API endpoints | Cross-origin page reads session IDs | Agent42's existing CORS config must cover new CC endpoints; do not create unprotected routes |
| Rendering file paths from tool events without escaping | Path with HTML metacharacters breaks element structure | Always use the existing `esc()` helper on file paths before inserting into HTML contexts |

---

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No visual distinction between CC subscription and API responses | Users cannot tell which model is active; debugging auth issues is impossible | Show a persistent "CC" or "API" badge in the chat header; include model name in each message metadata |
| Auto-scroll fights with reading | Users cannot read long responses while Claude is still typing | Detect user scroll-up intent; pause auto-scroll; show "scroll to bottom" button |
| Tool use cards collapse by default with no summary | Users cannot see what the agent did without extra clicks | Show tool name and status always; collapse the full input/output but keep a one-line summary visible |
| No streaming cancellation | Claude runs a 10-minute agent loop; user cannot stop it | "Stop" button that closes the WebSocket and (for API path) sends a cancellation signal |
| Losing draft message on navigation | User types a prompt, navigates away accidentally, message lost | Persist draft to sessionStorage; restore on return to chat page |
| No timestamp on messages | Long sessions become unreadable; cannot correlate with file changes | Add relative timestamps (e.g., "2 minutes ago"); show absolute on hover |
| Code blocks without language indicator | Claude writes code in many languages; no syntax hint makes copy-pasting harder | Extract language from fenced code block marker and display it as a badge |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **ANSI parsing:** Handles split escape sequences across WebSocket frames — test with a script that flushes mid-sequence
- [ ] **Markdown rendering:** Sanitization library installed and called AFTER the markdown parser, not before — verify with a script tag in a message
- [ ] **Streaming rendering:** Uses append-only DOM updates, not full rebuild — verify with DevTools performance profiler during 60-second stream
- [ ] **Auto-scroll:** Pauses when user scrolls up — verify by scrolling up mid-stream and confirming position holds
- [ ] **WebSocket reconnect:** Old WebSocket handlers nulled before creating new connection — verify no duplicate messages appear on reconnect
- [ ] **CC session resume:** Session ID persisted to sessionStorage and `--resume` flag passed on re-connect — verify after hard page refresh
- [ ] **Tool use cards:** Built on `content_block_stop`, not `content_block_start` — verify with a tool call that has complex nested input JSON
- [ ] **Keyboard shortcuts:** Listener guard prevents accumulation — verify by navigating away and back 5 times, then pressing the shortcut
- [ ] **Monaco diff editor:** Disposes previous instance before creating new — verify no memory leak after opening 20 diffs in sequence
- [ ] **Hybrid connection:** CC auth expiry surfaced in UI — test by manually expiring auth and starting a new message

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| ANSI split sequences (Pitfall 1) | MEDIUM | Audit all places raw bytes are processed; introduce a stateful AnsiStreamBuffer wrapper class; update all consumers |
| Markdown XSS without sanitization (Pitfall 2) | HIGH — security incident | Rotate any exposed JWT tokens immediately; audit all markup injection usage in app.js; add DOMPurify; add CSP header |
| stream-json parser crashes (Pitfall 3) | LOW | Add try/catch plus default case to event handler; add unknown event logging; redeploy |
| DOM thrash (Pitfall 5) | MEDIUM | Refactor message rendering to append-only; identify all callsites that do full rebuilds |
| Ghost session handlers (Pitfall 6) | LOW | Add `session.ws.onmessage = null` before reassignment; add reconnect ID counter |
| CC session lost on navigate (Pitfall 7) | LOW | Add sessionStorage read/write calls; add `--resume` to process spawn command |
| Listener accumulation (Pitfall 12) | LOW | Add guard variable; existing listeners clear on page unload |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| ANSI split sequences | Phase: Stream parsing foundation | Send a test message that splits mid-ANSI-sequence; verify no garbage in output |
| Markdown without sanitization | Phase: Message rendering (first markup output) | Test with a script tag in a message; verify CSP blocks if sanitizer misses it |
| stream-json event brittleness | Phase: Stream parsing foundation | Replay a captured CC session with tool calls; verify all event types handled |
| Scroll-jump fighting | Phase: Chat bubble UI | Scroll up mid-stream; verify position holds for remainder of stream |
| DOM thrash | Phase: Chat bubble UI | Profile with DevTools during 60-second stream; verify less than 5% time in Recalculate Style |
| Ghost WebSocket handlers | Phase: WebSocket connection management | Force reconnect 3 times; verify no duplicate messages appear |
| CC session resume | Phase: CC integration (first subprocess spawn) | Refresh page mid-conversation; verify `--resume` restores context |
| Markdown code block flicker | Phase: Chat bubble UI | Stream a response with a large code block; verify no formatting flash |
| Monaco diff timeout | Phase: Diff viewer integration | Open diff for a 10,000-line file; verify timeout message shown within 2 seconds |
| Hybrid connection state | Phase: Hybrid connection switching | Expire CC auth; verify UI shows auth error card, not an infinite reconnect loop |
| Tool use card ordering | Phase: Stream parsing foundation | Send a tool call with complex nested input; verify card shows complete parameters |
| Listener accumulation | Phase: Chat bubble UI (any keyboard shortcut) | Navigate away and back 5 times; press shortcut; verify fires exactly once |
| JWT exposure via localStorage | Phase: Markdown rendering (when sanitization is introduced) | Audit all markup injection usage; add CSP; verify in security review |

---

## Sources

- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference) — HIGH confidence (official docs, verified stream-json flags)
- [Claude Code GitHub Issue #24596 — missing stream-json event type docs](https://github.com/anthropics/claude-code/issues/24596) — HIGH confidence (official repo, confirmed documentation gap)
- [Anthropic Agent SDK streaming docs — full event type reference](https://platform.claude.com/docs/en/agent-sdk/streaming-output) — HIGH confidence (official docs)
- [Showdown XSS in Markdown documentation](https://github.com/showdownjs/showdown/wiki/Markdown's-XSS-Vulnerability-(and-how-to-mitigate-it)) — HIGH confidence (library documentation, sanitize-after requirement)
- [CVE-2025-24981 Nuxt MDC XSS via javascript: bypass](https://github.com/nuxt-content/mdc/security/advisories/GHSA-cj6r-rrr9-fg82) — MEDIUM confidence (shows sanitization libraries can have bypasses)
- [Streaming LLM rendering pitfalls — markdown flicker, DOM performance](https://pockit.tools/blog/streaming-llm-responses-web-guide/) — MEDIUM confidence (community blog, patterns verified against known DOM behavior)
- [Scroll behavior for AI chat apps — intent detection pattern](https://jhakim.com/blog/handling-scroll-behavior-for-ai-chat-apps) — MEDIUM confidence (community blog)
- [WebSocket reconnection architecture guide — Ably](https://ably.com/topic/websocket-architecture-best-practices) — MEDIUM confidence (vendor doc, patterns are general)
- [Monaco diff editor API — IDiffEditorBaseOptions](https://microsoft.github.io/monaco-editor/typedoc/interfaces/editor.IDiffEditorBaseOptions.html) — HIGH confidence (official Monaco API docs, maxComputationTimeMs confirmed)
- [Phase 19.1 research — confirmed pitfalls from direct codebase inspection](../../../planning/workstreams/agent-llm-control/phases/19.1-ui-redesign/19.1-RESEARCH.md) — HIGH confidence (direct codebase read)
- [WebSocket reconnection logic guide — oneuptime](https://oneuptime.com/blog/post/2026-01-27-websocket-reconnection-logic/view) — MEDIUM confidence (community resource, patterns standard)

---
*Pitfalls research for: Custom Claude Code Chat UI — vanilla JS SPA integration*
*Researched: 2026-03-17*
