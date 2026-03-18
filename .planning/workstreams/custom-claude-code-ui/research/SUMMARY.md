# Project Research Summary

**Project:** Custom Claude Code Chat UI
**Domain:** VS Code-style AI chat interface embedded in Agent42's vanilla JS web IDE
**Researched:** 2026-03-17
**Confidence:** HIGH

## Executive Summary

Building a structured chat UI over Claude Code requires one foundational architectural decision above all others: do not parse ANSI terminal output. Claude Code's `--output-format stream-json` flag produces stable, structured NDJSON events that carry tool use, streaming text, session IDs, and cost data as typed messages. The entire chat UI rests on a backend bridge (`cc_chat_ws`) that spawns `claude -p --output-format stream-json` per turn, translates the NDJSON stream into typed WebSocket messages, and relays them to the frontend. Multi-turn conversation is handled by re-spawning with `--resume <session_id>` — there is no persistent process between turns, and that is by design.

The recommended approach is entirely additive to the existing Agent42 codebase. No new Python packages are needed. Frontend additions are CDN-loaded UMD libraries loaded before Monaco's AMD loader. The six new CDN libraries (marked.js, marked-highlight, highlight.js, DOMPurify, ansi_up, diff2html) extend the existing vanilla JS SPA without requiring a build step. The key integration points are two new backend endpoints (`cc_chat_ws` WebSocket and `/api/cc/sessions` REST), a new frontend chat panel in `renderCode()`, and reuse of the existing `buildChatMsgHtml`, `appendChatMsgToDOM`, `esc()`, and `termConnectWs()` patterns.

The primary risks are security-first: markdown rendered from AI output MUST be sanitized with DOMPurify (after `marked.parse`, not before), and tool output (bash results, file contents) must always use `textContent` assignment rather than markup injection. Performance risks cluster around streaming: the DOM must use append-only updates during streaming — never rebuild the full message list per token — and markdown parsing must be deferred to `message_stop`, not applied per token. ANSI escape sequences that appear in CLI output embedded in CC responses must be handled via a stateful buffer, not a one-shot regex. These patterns must be established in Phase 1 and cannot be retrofitted.

## Key Findings

### Recommended Stack

The existing dashboard uses Monaco 0.52.2 (AMD loader), xterm.js (local bundle), and a 5000+ LOC vanilla JS SPA with no build step. All new libraries must be UMD or IIFE format, loaded via CDN script tags in `index.html` BEFORE the Monaco loader to avoid AMD conflicts. Diff2html is the one exception — it is lazy-loaded on first diff render, after Monaco has claimed the AMD namespace.

**Core technologies:**
- **marked.js 16.3.0** — markdown parsing — the UMD build is mandatory (v16 dropped CJS); pin the version, v17 may break again
- **marked-highlight 2.2.3** — wires highlight.js into marked — official extension, 3KB, pairs with `marked.use(markedHighlight(...))`
- **highlight.js 11.11.1** — syntax highlighting for code blocks — use `hljs.highlightElement(el)` never `hljs.highlightAll()` which re-processes Monaco output
- **DOMPurify 3.2.7** — XSS sanitization — mandatory, called AFTER `marked.parse()`, BEFORE markup is assigned to any element; never skip
- **ansi_up 6.0.6** — ANSI codes to HTML for CLI output in chat bubbles — constructor-based (`new AnsiUp()`), always wrap output in DOMPurify before use
- **diff2html 3.4.56** — diff viewer — lazy-loaded, uses hljs internally; only for passive display; Monaco diff editor is for interactive editing
- **sse-starlette 3.3.2** — backend SSE (alternative to WebSocket for streaming) — handles proper `text/event-stream` headers and disconnect detection

### Expected Features

See `FEATURES.md` for the full prioritization matrix.

**Must have (table stakes) — v1:**
- Message bubbles with user/AI distinction — foundational visual language
- Markdown rendering with syntax highlighting — applied on `message_stop` only
- Streaming token display with 50ms batched DOM updates via `requestAnimationFrame`
- Streaming cursor animation — 2px blinking bar, removed on `turn_complete`
- Tool use display as collapsed pills — `[Read app.js] done`, expandable; no tool UX makes CC look broken
- Stop/interrupt button — replaces Send during streaming; sends SIGINT or closes WebSocket
- Permission request UI (approve/reject inline) — the single most impactful differentiator; without it users must switch to raw xterm for every CC permission prompt
- Permission mode selector (Normal/Plan/Auto-Accept) — three-state toggle per session
- Multi-session chat tabs — extends Phase 19.1 tab infrastructure
- Loading indicator, code block copy button, auto-scroll with scroll-pin, error state display, new conversation button

**Should have — v1.x post-validation:**
- Session history list — requires `/api/cc/sessions` endpoint reading `~/.claude/projects/`
- Context window / token usage bar — highly requested; parse `ResultMessage` for counts
- Thinking block (collapsible) — detect `thinking_delta` stream events
- Plan mode display — structured card with Proceed/Cancel
- Cost tracking per session — from `agent_done.total_cost_usd`
- Local/remote session indicator — extend Phase 19.1 color dots

**Defer (v2+):**
- @-mention file references — 3-5 days alone; needs file watcher and fuzzy search popup
- Conversation fork/rewind — requires server-side checkpoint storage
- Inline diff display (intercepting CC file write events) — high complexity, conflicts with raw terminal view

### Architecture Approach

The system has three layers: the browser chat panel (vanilla JS, new `_ccChatState` global, new `renderCcChat()` / `ccChatConnectWs()` / `ccChatHandleEvent()` / `ccChatRenderMessage()` / `ccChatRenderToolCard()` functions), the FastAPI bridge (`cc_chat_ws` WebSocket endpoint + `_translate_cc_event()` function + `/api/cc/sessions` REST + `_cc_chat_sessions` dict persisted to `.agent42/cc-sessions.json`), and the CC subprocess (`claude -p --output-format stream-json --verbose --include-partial-messages --resume <id>` spawned per turn). The frontend never parses ANSI. The backend never stores CC session content — only the metadata mapping (session_id, name, cwd, timestamps).

**Major components:**
1. `cc_chat_ws()` endpoint in `server.py` — auth, subprocess spawn, NDJSON-to-WS relay, session ID extraction; mirrors existing `terminal_ws` pattern
2. `_translate_cc_event()` in `server.py` — state machine translating 8 CC NDJSON event types to 8 typed frontend messages; must handle unknown events gracefully (log, don't throw)
3. `renderCcChat()` + `ccChatConnectWs()` in `app.js` — chat panel DOM, WS connection management (one WS per turn, null old handlers before replacing), streaming renderer
4. `ccChatRenderMessage()` + `ccChatRenderToolCard()` in `app.js` — append-only message rendering, tool card buffered on `content_block_stop` not `content_block_start`
5. `/api/cc/sessions` REST — session list for sidebar; GET + DELETE; reads `_cc_chat_sessions` dict

### Critical Pitfalls

1. **Markdown rendered without sanitization** — AI output or prompt-injected content with script tags executes in the browser. Apply `DOMPurify.sanitize(marked.parse(text))` on every AI message. Tool output (bash results, file contents) must use `textContent` assignment, not markup injection. Load DOMPurify locally if possible; CDN failure with fallback to unsanitized rendering is a security bug.

2. **DOM thrash during streaming** — rebuilding the entire message list on every token destroys and recreates the full DOM at 10-50Hz. Text selections are lost, input focus is stolen, scroll position resets. Use append-only: create the message element once on `message_start`, store a reference in `_ccChatState`, append tokens to `.querySelector('.content')`, do a full re-render only on `message_stop`.

3. **stream-json parser crashes on unknown events** — CC adds event types without major version bumps. Parse with an explicit default case that logs unknowns rather than throwing. Accumulate tool input JSON in a per-block buffer keyed by `content_block.index`; parse JSON only on `content_block_stop` — never on intermediate `input_json_delta` events.

4. **Ghost WebSocket handlers on reconnect** — replacing `session.ws = new WebSocket(...)` leaves the old object's event handlers firing. Always null the old handlers before replacement (`session.ws.onmessage = null`, `session.ws.onerror = null`, `session.ws.onclose = null`). Use a `session.reconnectId` counter to guard handlers.

5. **Scroll-jump fighting** — auto-scroll on every token fights the user who scrolled up to re-read. Track scroll intent: if `scrollHeight - scrollTop - clientHeight > 80px`, set `userScrolledUp = true`; only auto-scroll when `false`. Show a floating "scroll to bottom" button when streaming and the user has scrolled up. Use `requestAnimationFrame` for the actual scroll call.

## Implications for Roadmap

Based on research, the dependency chain is strict: the backend bridge must exist before any frontend rendering is possible, streaming rendering correctness (sanitization, append-only DOM, scroll-pin) must be established before any polish features are added, and session persistence must be part of the initial CC integration — not a retrofit. Four phases follow naturally.

### Phase 1: Backend WS Bridge + Stream Parser

**Rationale:** All frontend work is blocked until a backend exists that emits structured typed events. The NDJSON-to-WebSocket translation layer is the foundation everything else builds on. This phase can be tested with `websocat` or curl before any frontend changes exist.

**Delivers:** `cc_chat_ws()` endpoint, `_translate_cc_event()` state machine handling all 8 CC event types with unknown-event fallback, session ID extraction, `_cc_chat_sessions` dict with JSON persistence, `/api/cc/sessions` GET and DELETE endpoints, and the CC binary fallback path (`shutil.which("claude")` returning None sends an `error` message with `fallback:"api"`).

**Addresses:** Multi-turn (re-spawn with `--resume`), tool permission pass-through (`--allowedTools`), cost data (`agent_done.total_cost_usd`), auth failure detection (exit code 1 pattern).

**Avoids:** Pitfall 3 (stream-json brittleness), Pitfall 10 (auth failure not surfaced — parse CC stdout for auth strings).

### Phase 2: Core Chat UI — Streaming Rendering

**Rationale:** With the backend emitting structured events, the frontend chat panel can be built. This phase establishes the non-negotiable correctness properties: sanitization on all AI output, append-only DOM updates, scroll-pin, and WebSocket handler lifecycle. These cannot be retrofitted after the panel is shipped — they must be the initial design.

**Delivers:** `_ccChatState` global, `renderCcChat()` panel in IDE layout (additive — no touch to terminal or Monaco), `ccChatConnectWs()` + `ccChatHandleEvent()`, message bubbles for user and assistant, streaming text with `requestAnimationFrame` 50ms batching, blinking cursor, stop button, loading indicator, error state display, code block copy button, auto-scroll with scroll-pin. Markdown stack (marked.js + marked-highlight + highlight.js + DOMPurify) loaded in `index.html` before Monaco AMD loader.

**Uses:** marked.js, marked-highlight, highlight.js, DOMPurify CDN stack from STACK.md. All loaded before Monaco loader script tag.

**Avoids:** Pitfall 2 (XSS — DOMPurify mandatory), Pitfall 4 (scroll-jump — scroll intent tracking), Pitfall 5 (DOM thrash — append-only from day one), Pitfall 6 (ghost WS handlers — null-handler pattern), Pitfall 8 (markdown flicker — defer to `message_stop`), Pitfall 12 (listener accumulation — `_chatKeyHandlersAttached` guard).

### Phase 3: Tool Use Cards + Session Persistence

**Rationale:** Tool use visualization and session persistence are the two features that separate a real Claude Code UI from a plain chat box. They depend on Phase 2's streaming infrastructure but do not block each other and can be built in parallel within a phase.

**Delivers:** `ccChatRenderToolCard()` — tool cards built on `content_block_stop` showing tool name, status spinner, one-line input summary; `ccChatSwitchSession()` / `ccChatDeleteSession()` — session list sidebar; session ID persisted to `sessionStorage` (not localStorage); `--resume` flag wired into backend spawn for follow-up messages; multi-session chat tabs extending Phase 19.1 tab infrastructure; permission request UI (approve/reject inline cards); permission mode selector (Normal/Plan/Auto).

**Avoids:** Pitfall 7 (CC session resume broken after page navigation — sessionStorage persistence and `--resume` from first spawn), Pitfall 11 (tool card input JSON arriving out of order — buffer until `content_block_stop`).

### Phase 4: Polish + v1.x Features

**Rationale:** Once the core chat experience is stable and validated, add the features that require additional data parsing or backend work. These are individually low-risk additions.

**Delivers:** Diff colorization in CC response code blocks (CSS for `+`/`-` lines, zero new libraries), ansi_up for CLI output snippets in chat bubbles, cost display from `agent_done.total_cost_usd`, api_retry progress from `api_retry` events, session history list (requires `/api/cc/sessions` reading `~/.claude/projects/`), local/remote session indicator (extend Phase 19.1 color dots). Optionally: context window token usage bar, thinking block collapsible, plan mode display.

**Uses:** ansi_up 6.0.6 (CDN), diff2html 3.4.56 (lazy-loaded on first diff render). See STACK.md for lazy-load pattern — inject CSS and JS into document.head on first use, safe because Monaco has already claimed AMD by this point.

**Avoids:** Pitfall 9 (Monaco diff editor timeout — set `maxComputationTimeMs: 2000`, `maxFileSize: 10`).

### Phase Ordering Rationale

- Backend before frontend: `cc_chat_ws` is a strict prerequisite; there is nothing to render without structured events.
- Correctness before features: sanitization, append-only DOM, scroll-pin, and handler lifecycle are architectural properties cheapest to establish on the first day of chat UI code.
- Tool cards and session persistence are grouped because they share the same dependency (working streaming renderer) and have similar complexity.
- Polish and v1.x features are isolated to Phase 4 because they each require one new data source (cost from `agent_done`, session list from filesystem, token counts from `ResultMessage`) but no core rendering changes.
- @-mention, fork/rewind, and inline diff intercept (v2+) are correctly deferred: each is 3-5+ days of scope that would delay the core experience without proportional user value at launch.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Backend WS Bridge):** The exact NDJSON event schema for `--include-partial-messages` and `--verbose` combined flags should be verified against a live CC session capture before implementation. The docs cover the happy path; the verbose flag adds additional event types not fully documented.
- **Phase 3 (Permission Request UI):** The CC SDK `PermissionRequest` event type and its exact payload structure needs verification against the current CC version. Pattern-matching stdout text is the fallback — needs a real CC session that triggers permission prompts to confirm.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Core Chat UI):** DOM manipulation, WebSocket connection management, and markdown rendering are well-documented patterns. The existing `termConnectWs()` and `buildChatMsgHtml()` in app.js are direct models.
- **Phase 4 (Polish):** CDN lazy-loading pattern, CSS diff colorization, and cost label display are all straightforward additive changes with no novel integration challenges.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | CDN URLs verified on cdnjs/jsDelivr; versions pinned; AMD conflict workaround confirmed from existing codebase inspection |
| Features | HIGH for table stakes, MEDIUM for differentiators | Table stakes sourced from official Claude Code VS Code extension docs; differentiators from community extensions and release notes |
| Architecture | HIGH | CC CLI `--output-format stream-json` confirmed in official docs; `terminal_ws` pattern directly read from `server.py` lines 1437-1713; `buildChatMsgHtml` and `appendChatMsgToDOM` confirmed in `app.js` lines 2795-2979 |
| Pitfalls | HIGH | Primary pitfalls from direct codebase inspection + official CC CLI docs; secondary pitfalls from MEDIUM-confidence community sources |

**Overall confidence:** HIGH

### Gaps to Address

- **CC verbose flag extra events:** The combined `--verbose --include-partial-messages` flag set may emit additional NDJSON event types not covered in the standard Agent SDK docs. Capture a real CC session log in Phase 1 development and replay it to surface any unexpected event types before the parser is locked.
- **Permission request event payload:** The exact structure of CC's permission request in `stream-json` mode is not fully documented at time of research. The community `claude-code-webui` project provides MEDIUM-confidence evidence that it is detectable via `stream_event` with a specific subtype — this needs verification with a live CC session before Phase 3 implementation.
- **Remote CC session resume:** The architecture for resuming CC sessions on a remote host (SSH relay) is conceptually clear but untested. Flagged LOW confidence in ARCHITECTURE.md. Defer remote session resume to after local session resume is validated.
- **CC process startup latency:** Estimated 200-400ms per turn based on typical values; not benchmarked in the Agent42 environment. If latency is higher on the Contabo VPS, a "Connecting..." indicator before the first `session_init` event may need to be added in Phase 2.

## Sources

### Primary (HIGH confidence)
- `code.claude.com/docs/en/headless` — `claude -p --output-format stream-json --verbose --include-partial-messages --resume` confirmed; single-shot nature of `-p` mode confirmed
- `code.claude.com/docs/en/cli-reference` — `--resume`, `--session-id`, `--allowedTools`, `--max-budget-usd` flags confirmed; session stored at `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`
- `platform.claude.com/docs/en/agent-sdk/streaming-output` — full event type reference with code examples; `text_delta`, `input_json_delta`, `content_block_stop` patterns confirmed
- `platform.claude.com/docs/en/agent-sdk/sessions` — session resume by ID confirmed
- `cdnjs.com/libraries/marked` — version 16.3.0 verified
- `cdnjs.com/libraries/highlight.js` — version 11.11.1 verified
- `cdnjs.com/libraries/dompurify` — version 3.2.7 verified
- `jsdelivr.com/package/npm/diff2html` — version 3.4.56 verified January 2026
- `jsdelivr.com/package/npm/ansi_up` — version 6.0.6 verified May 2025
- `dashboard/server.py` lines 1437-1713 (direct read) — `terminal_ws` confirmed as model for `cc_chat_ws`
- `dashboard/server.py` lines 1810-1957 (direct read) — `/api/ide/chat` confirmed as fallback path
- `dashboard/frontend/dist/app.js` lines 2795-2979 (direct read) — `buildChatMsgHtml`, `appendChatMsgToDOM`, `sendSessionMessage` confirmed reusable
- `dashboard/frontend/dist/app.js` lines 3198-3713 (direct read) — `renderCode()`, `ideOpenClaude()`, `termConnectWs()` confirmed
- `microsoft.github.io/monaco-editor/typedoc` — `maxComputationTimeMs` in `IDiffEditorBaseOptions` confirmed
- `code.claude.com/docs/en/vs-code` — permission modes, checkpoints, @-mentions, session management confirmed
- Claude Code GitHub Issue #24596 (official repo) — documentation gap for stream-json event types confirmed

### Secondary (MEDIUM confidence)
- `github.com/sugyan/claude-code-webui` — subprocess-based CC web UI confirmed viable; permission event pattern
- `github.com/andrepimenta/claude-code-chat` — message bubbles, inline diff, cost/token tracking UI patterns
- `windsurf.com/docs` and Wave 8 changelog — Cascade UI patterns, checkpoint system
- `pockit.tools/blog/streaming-llm-responses-web-guide` — streaming markdown flicker and DOM performance patterns
- `jhakim.com/blog/handling-scroll-behavior-for-ai-chat-apps` — scroll intent detection pattern
- `ably.com/topic/websocket-architecture-best-practices` — WebSocket reconnection handler lifecycle

### Tertiary (LOW confidence)
- Claude Code GitHub issues #10593, #28962 — context window bar (requested feature, not yet shipped; needs validation against current CC release)
- CVE-2025-24981 (Nuxt MDC) — shows sanitization libraries can have bypasses; defense-in-depth argument for DOMPurify + CSP

---
*Research completed: 2026-03-17*
*Ready for roadmap: yes*
