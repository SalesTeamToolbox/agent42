# Feature Research

**Domain:** VS Code-style AI chat interface embedded in web IDE (Agent42 dashboard)
**Researched:** 2026-03-17
**Confidence:** HIGH for table stakes (sourced from official Claude Code docs, Windsurf changelog, Cursor docs); MEDIUM for differentiators (sourced from community extensions and release notes); LOW for anti-features (sourced from community forum UX discussions)

---

## Context: What Already Exists

Phase 19.1 completed the VS Code-style IDE layout:
- xterm.js terminal in bottom panel showing raw CC CLI output
- Monaco editor with file tabs
- Activity bar, explorer panel, terminal panel tabs
- WebSocket relay to Claude CLI process (raw stdio)
- Dashboard is a vanilla JS SPA (app.js ~5082 lines, no build step)

This milestone adds a **structured chat UI** layered on top of the CC CLI connection — replacing the raw terminal view with a rich interface for users who want message bubbles, tool visualization, and session management without losing the xterm fallback.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features any VS Code-style AI chat UI must have. Missing these makes the interface feel like a prototype.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Message bubbles (user vs AI)** | Every chat interface since 2020. Users/AI visually distinct. | LOW | User: right-aligned, muted bg. AI: left-aligned, richer formatting. Single CSS pattern. |
| **Markdown rendering in AI messages** | CC produces markdown. Raw text is unreadable. | MEDIUM | Need a markdown renderer. Marked.js (MIT, 1.5KB min+gz) is standard for vanilla JS SPAs. Highlight.js adds code block syntax highlighting. |
| **Streaming token display** | Response appears progressively, not all at once. Waiting stalls feel broken. | MEDIUM | CC SDK yields `StreamEvent` with `content_block_delta/text_delta`. Append to active message div. Include blinking cursor animation (2px bar at 500ms). |
| **Tool use display (collapsed by default)** | CC uses 10-30 tool calls per task. Must show progress without drowning the chat. | MEDIUM | Show pill: "[Read file.py]" during execution. Collapsed chevron after. Expand to show tool name + input + output. State transitions: running → done → expandable. |
| **Input box with send button** | Users type and submit. Enter sends, Shift+Enter adds newline. | LOW | Auto-resize textarea (grows with content). Button disabled during streaming. Multiline standard. |
| **Streaming stop/interrupt button** | Long tasks need cancellation. Users will click away expecting a stop. | LOW | Replace Send with Stop during streaming. Send SIGINT or close WebSocket. Show "Interrupted" in chat. |
| **New conversation button** | Users start fresh tasks. Cannot share context across unrelated work. | LOW | Clear message list. Send `--resume` or open new CC session. No navigation needed. |
| **Basic session persistence (page reload)** | Users refresh the browser. Losing all history is unacceptable. | MEDIUM | Store sessions in `localStorage` or server-side. Reload restores message list. The raw CC session history (JSON) is server-side — can be replayed. |
| **Loading/thinking indicator** | While CC processes, show spinner or animated dots. Silence reads as broken. | LOW | Pulsing dots or skeleton row. Activate after send, deactivate on first token. |
| **Code block copy button** | Users copy code snippets constantly. Hover copy button is universal expectation. | LOW | Overlay button on `<pre>` blocks. Flash checkmark on click. No library needed. |
| **Error state display** | CC crashes, network drops, auth expires. Must communicate failure gracefully. | LOW | Red pill inline: "Session error — reconnect". Not a full-page takeover. |
| **Scrollable message history** | Long conversations need scroll. Auto-scroll to bottom on new content, but pin if user scrolled up. | LOW | Track if user is "near bottom" before each append. Only auto-scroll if they were already at bottom. |

### Differentiators (Competitive Advantage)

Features that elevate the interface beyond a basic chat box. These are present in VS Code CC extension, Cursor, and Windsurf — but are not assumed by users.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Permission request UI (approve/reject inline)** | CC frequently asks for permission before write/exec actions. Inline approve/reject avoids context switch to terminal. | MEDIUM | CC outputs a permission prompt (detectable via SDK `PermissionRequest` events or pattern-matching terminal output). Render as inline card with Approve/Reject buttons. This is the single most impactful differentiator. |
| **Plan mode display** | CC "plan mode" shows proposed work before execution. Markdown plan rendered as structured card with "Proceed" button. | MEDIUM | Claude Code CC extension auto-opens plan as markdown doc. In chat UI: render plan message with different visual treatment (outlined card, Proceed/Cancel buttons). Depends on permission mode selector (below). |
| **Permission mode selector** | Toggle between Normal / Plan / Auto-Accept. VS Code CC extension exposes this at the bottom of the prompt box. | LOW | Three-state toggle or dropdown. Stateful per session. Maps to `--permission-mode` CLI flag or SDK `ClaudeAgentOptions`. |
| **Session history list** | Browse and resume past CC sessions (conversation history). Claude CC extension shows Today/Yesterday/Last 7 days groupings. | MEDIUM | CC CLI stores session JSON at `~/.claude/projects/`. Read via `/api` endpoint. Render as searchable list panel. Click to resume with `--resume [session-id]`. |
| **Context window / token usage bar** | Visual indicator of how much of the 200K context window is used. CC auto-compacts at ~155K tokens. Alerts at 75%, 90% | LOW-MEDIUM | Parse `ResultMessage` or `/context` command output for token counts. Progress bar in status area under input. This is a highly requested feature (active GitHub issues #10593, #28962 on claude-code repo). |
| **@-mention file references** | Type `@` to fuzzy-search and insert file references into the prompt. Files are injected as context for CC. | HIGH | Requires file autocomplete popup, fuzzy matching against workspace file tree, and injecting file paths into the CC prompt. Fuzzy matching: Fuse.js (lightweight, MIT). Popup is custom dropdown. Significant scope. |
| **Thinking block (collapsible)** | Extended thinking produces verbose reasoning text. Show as collapsible "Thinking..." block, auto-open during stream, auto-close when done. | MEDIUM | Detect `thinking_delta` stream event type. Render as visually distinct (italic, indented, muted color) collapsible section. Nuxt UI's `ChatReasoning` component is the reference pattern. |
| **Conversation fork / rewind** | Hover any message to reveal Fork or Rewind. Fork branches from a point; Rewind reverts code changes. Shipped in CC v2.1.19. | HIGH | Requires server-side session checkpoint storage and git-level undo. CC SDK may expose this; otherwise requires custom implementation. High complexity relative to value for v1. |
| **Inline diff display for file edits** | When CC proposes a file edit, show the diff inline in the chat (not a new terminal tab). Side-by-side or unified with colored lines. | HIGH | Requires diff rendering library (diff2html, jsdiff). Must intercept CC file write events before they apply, or use post-write diff. Monaco's diff editor can embed inline. High complexity — and Monaco is already loaded. |
| **Multi-session tabs** | Multiple CC conversations open simultaneously in tabs (similar to terminal tabs). VS Code CC extension supports this via "Open in New Tab". | MEDIUM | Extend existing `_termSessions` tab pattern. Each chat tab = independent CC session. Tab state persists between switches. UI already has tab pattern from Phase 19.1. |
| **Local vs remote session indicator** | Color-coded dot: blue = local CC, green = remote CC. Phase 19.1 already established this pattern for terminal tabs. | LOW | Extend Phase 19.1 tab coloring to chat UI tabs. Consistent with existing visual language. |
| **Cost tracking per session** | Show estimated API cost per session. CC tracks this internally; the CC extension displays per-session cost. | LOW-MEDIUM | Parse `ResultMessage.usage` for token counts. Compute cost from known model pricing. Display as subtle "~$0.04" label in session header. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Full diff editor replacing terminal** | Looks polished, developers love diff views | Implementing a custom diff viewer over CC's terminal output requires intercepting file writes, which means wrapping the CC subprocess — high complexity, brittle, breaks on CC updates | Show raw terminal as fallback via existing xterm.js tab; add inline diff only for explicit edit events |
| **Real-time everything (token-level streaming to DOM)** | Feels fast and responsive | Adding a DOM node per token is O(n) layout thrashing. 500-token response = 500 DOM mutations. Visible lag at high speeds. | Batch updates: append text chunks every 50ms using `requestAnimationFrame`, not per-token |
| **Chat history in localStorage only** | Simple to implement | localStorage is capped at 5-10MB, easily filled by long CC sessions. Silently corrupts. | Use server-side session storage (CC already writes session JSON to disk). localStorage for index only. |
| **Full markdown parsing in streaming** | Complete output looks polished | Parsing markdown on every token is expensive. Partial markdown (mid-code-block) produces broken HTML. | Stream as plain text with `<pre>` wrapping; parse markdown only on `message_stop` event (complete message). |
| **Persistent @-mention autocomplete for all files** | Power users love it | File tree crawl on every `@` keypress is expensive for large repos. Requires file watcher. Out of scope for v1. | Include @-mentions as v2 feature. For v1, users can reference files via the Monaco explorer and paste paths manually. |
| **WebRTC or SSE instead of WebSocket** | Seems more "modern" | Agent42's entire real-time infrastructure is WebSocket. Mixing transport protocols doubles complexity with no user benefit. | Stick with WebSocket. The existing `/ws/terminal` endpoint is the integration point. |
| **Voice input** | Windsurf added it; seems differentiating | Browser microphone permissions, OS-level speech recognition, server-side ASR = 3 new integration points. No evidence users of agent platforms want this. | Text-only input for v1. Windsurf's voice implementation is shallow (transcription only, not semantic). |

---

## Feature Dependencies

```
[Message bubbles]
    └──requires──> [Markdown rendering]
                       └──requires──> [Streaming batching] (not per-token DOM updates)

[Tool use display]
    └──requires──> [Stream event parsing] (content_block_start → running → content_block_stop → expandable)

[Permission request UI]
    └──requires──> [Stream event parsing]
    └──requires──> [Permission mode selector] (to know if approval is expected)

[Plan mode display]
    └──requires──> [Permission mode selector]
    └──requires──> [Markdown rendering]

[Session history list]
    └──requires──> [Server API endpoint] (/api/chat/sessions reading ~/.claude/projects/)

[Context window bar]
    └──requires──> [ResultMessage parsing] (token counts from CC SDK)

[Multi-session tabs]
    └──requires──> [Phase 19.1 tab infrastructure] (already built)
    └──enhances──> [Session history list]

[Conversation fork/rewind]
    └──requires──> [Session persistence] (server-side checkpoints)
    └──requires──> [Multi-session tabs] (fork creates new tab)

[Inline diff display]
    └──requires──> [Stream event parsing] (detect file write events)
    └──conflicts──> [Raw xterm terminal] (competing views for same CC output)

[@-mention file references]
    └──requires──> [File tree API] (workspace listing)
    └──requires──> [Autocomplete popup] (custom component)
```

### Dependency Notes

- **Tool use display requires stream event parsing:** Tool visualization only works if the chat UI is connected to the CC SDK/API layer, not just the raw terminal output. The existing xterm.js connection writes raw bytes — tool events require the structured SDK event stream.
- **Inline diff conflicts with raw xterm terminal:** Both features claim the same CC output stream. Either the chat UI OR the terminal shows a given CC session, not both simultaneously. Design decision: chat UI is the primary view; xterm is fallback/power-user mode.
- **Session history list requires a new API endpoint:** CC session JSON files are stored at `~/.claude/projects/[project-hash]/` on the server. A new `/api/chat/sessions` endpoint is needed. This is backend work prerequisite to the session list feature.
- **@-mention is independently large:** Estimating 3-5 days of work alone. It is a differentiator, not table stakes, and should be Phase 2+.

---

## MVP Definition

### Launch With (v1) — Core Chat Experience

Minimum to make the chat tab feel like a real CC interface, not a prototype.

- [ ] **Message bubbles** — user messages (right, muted) and AI messages (left, formatted). Essential visual language.
- [ ] **Markdown rendering** — applied on `message_stop`, not per-token. Marked.js + Highlight.js.
- [ ] **Streaming with batched DOM updates** — tokens appear progressively; `requestAnimationFrame` batching at 50ms.
- [ ] **Streaming cursor animation** — 2px blinking bar to signal "still generating."
- [ ] **Tool use display (collapsed pills)** — "[Read app.js] done" pills. Expandable to see input/output. No tool UX = CC looks broken.
- [ ] **Stop/interrupt button** — replaces Send during streaming. Essential for long-running tasks.
- [ ] **Loading indicator** — dots or spinner before first token arrives.
- [ ] **New conversation button** — clear session and start fresh.
- [ ] **Auto-scroll with scroll-pin logic** — auto-scroll to bottom unless user has scrolled up.
- [ ] **Code block copy button** — hover reveals copy. Flash checkmark.
- [ ] **Error state display** — red pill on session failure.
- [ ] **Permission request UI (approve/reject)** — the most-used interactive CC element. Without this, users are forced to use the raw xterm tab for every CC permission prompt.
- [ ] **Permission mode selector (Normal/Plan/Auto)** — foundational to how CC behaves. Exposes existing CC capability.
- [ ] **Multi-session chat tabs** — extend Phase 19.1 tab infrastructure. Users need to switch between CC tasks.

### Add After Validation (v1.x)

- [ ] **Session history list** — requires new API endpoint. High value, moderate backend work. Add once core chat is stable.
- [ ] **Context window / token usage bar** — highly requested, low UI complexity. Add once `ResultMessage` parsing is wired in.
- [ ] **Thinking block (collapsible)** — valuable for extended thinking tasks. Add when CC extended thinking is being used.
- [ ] **Plan mode display** — structured plan card with Proceed/Cancel. Add alongside permission mode improvements.
- [ ] **Cost tracking per session** — computed from `ResultMessage.usage`. Subtle label, low effort once usage data is available.
- [ ] **Local vs remote session indicator** — extend Phase 19.1 color dots to chat tabs. Low effort, high consistency.

### Future Consideration (v2+)

- [ ] **@-mention file references** — high value, high complexity (fuzzy search popup, file watcher). Needs dedicated phase.
- [ ] **Conversation fork / rewind** — requires server-side checkpoint storage. Complex; defer until checkpointing is a declared feature.
- [ ] **Inline diff display** — Monaco diff editor embedded in chat. Requires intercepting CC file write events. High complexity.
- [ ] **Remote session resume (cloud)** — resuming CC sessions from claude.ai. Requires Anthropic auth integration beyond current scope.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Message bubbles | HIGH | LOW | P1 |
| Markdown rendering | HIGH | LOW | P1 |
| Streaming token display | HIGH | MEDIUM | P1 |
| Tool use display (pills) | HIGH | MEDIUM | P1 |
| Stop button | HIGH | LOW | P1 |
| Permission request UI | HIGH | MEDIUM | P1 |
| Permission mode selector | HIGH | LOW | P1 |
| Multi-session chat tabs | HIGH | MEDIUM | P1 |
| Loading indicator | MEDIUM | LOW | P1 |
| Code block copy | MEDIUM | LOW | P1 |
| Auto-scroll with pin | MEDIUM | LOW | P1 |
| Error state display | MEDIUM | LOW | P1 |
| New conversation | MEDIUM | LOW | P1 |
| Session history list | HIGH | MEDIUM | P2 |
| Context window bar | HIGH | LOW-MEDIUM | P2 |
| Thinking block | MEDIUM | MEDIUM | P2 |
| Plan mode display | MEDIUM | MEDIUM | P2 |
| Cost tracking | LOW | LOW | P2 |
| Local/remote indicator | LOW | LOW | P2 |
| @-mention file references | HIGH | HIGH | P3 |
| Conversation fork/rewind | MEDIUM | HIGH | P3 |
| Inline diff display | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

Study reference: VS Code Claude Code extension (official, Anthropic), Windsurf Cascade, Cursor Composer, claude-code-chat (community extension by andrepimenta).

| Feature | VS Code CC Extension | Windsurf Cascade | Cursor Composer | Our Approach |
|---------|---------------------|-----------------|-----------------|--------------|
| Message display | Graphical chat panel, markdown rendered | Cascade panel, markdown, code blocks | Chat panel, markdown | Markdown on complete message; stream as text |
| Tool use display | Shown inline; collapses after | Todo list + tool progress inline | Shown in chat with expandable detail | Collapsed pills → expandable on click |
| Streaming | Yes, per-token | Yes | Yes | Yes, 50ms batch via requestAnimationFrame |
| Thinking blocks | Collapsible "Thinking" section | Not confirmed | Not confirmed | Collapsible auto-opens during stream |
| Diff display | VS Code native diff viewer (opens in editor) | Built-in diff preview in Cascade | Diff at end of conversation via "Review changes" | v2+ only; use Monaco diff editor |
| Permission UI | Inline approve/reject in panel | Confirmation prompts in Cascade | Plan then approve | Inline card with Approve/Reject buttons |
| Permission modes | Normal / Plan / Auto-Accept selector | Autonomous by default | Plan mode prominent | Three-state mode selector in input area |
| Session history | Dropdown: Today/Yesterday/Last 7 days, searchable | Multiple Cascades via dropdown | Chat history panel | Sidebar list grouped by time, searchable |
| @-mentions | Full file/folder fuzzy autocomplete | @-context aware | @-codebase, @-docs | v2+ only |
| Checkpoints/rewind | Hover message → Fork / Rewind / Fork+Rewind | Checkpoint snapshots | Diff view at end | v2+ only |
| Context indicator | Context bar below input | Context window bar in header | Not confirmed | Token usage bar below input (v1.x) |
| Multi-session | Multiple tabs or windows | Side-by-side panes | Multiple chat windows | Chat tabs extending Phase 19.1 tab bar |
| Cost tracking | Not directly shown | Flow credits display | Token usage shown | Subtle per-session cost label (v1.x) |

---

## Architecture Integration Notes

These are specific to Agent42's existing codebase and constrain implementation choices:

### Existing Integration Points

- **CC connection:** Currently xterm.js raw WebSocket to `/ws/terminal?cmd=claude&node=local`. The chat UI needs a **structured event stream**, not raw bytes. Options:
  1. Parse CC JSON output from the existing WebSocket (CC CLI outputs structured JSON on stdout with `--output-format json`). Medium effort.
  2. Connect via the Claude Agent SDK on the backend, expose a new `/ws/chat` endpoint that proxies SDK events as JSON. Cleaner, recommended.
- **Tab infrastructure:** Phase 19.1 built `_termSessions` with tab switching, color dots, reconnect. Chat sessions can reuse the same tab bar with a different renderer per tab (xterm vs chat UI).
- **Message rendering:** Must use `esc()` helper for all dynamic content (existing XSS protection pattern).
- **DOM pattern:** Vanilla JS with innerHTML. React/Vue are out of scope. Marked.js is safe to add as a global script tag.

### New Backend Requirements

The chat UI requires at minimum one new backend capability not currently in Agent42:

- **`/ws/chat` endpoint** (or `/api/chat/stream` via SSE): proxies Claude Agent SDK events as structured JSON instead of raw terminal bytes. This is the foundational requirement for all chat UI features. Without it, only raw xterm is possible.
- **`/api/chat/sessions`** (for session history, v1.x): reads CC session files from `~/.claude/projects/` and returns list with timestamps and first-message previews.

### Vanilla JS Constraints

No build step. All libraries must be:
- Available as a single CDN script tag or bundled local file
- Compatible with global namespace usage (no ES module imports)
- Small enough to not noticeably affect page load

Recommended additions:
- `marked.min.js` (~1.5KB gzip) — markdown rendering. MIT license. CDN: `https://cdn.jsdelivr.net/npm/marked/marked.min.js`
- `highlight.min.js` (~35KB gzip, core only) — code block syntax highlighting. BSD license. CDN: `https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/highlight.min.js`
- No additional libraries required for streaming, tool pills, permission UI, or session tabs.

---

## Sources

**HIGH confidence (official documentation):**
- [Claude Code VS Code extension docs](https://code.claude.com/docs/en/vs-code) — permission modes, checkpoints, @-mentions, session management, UI features
- [Claude Agent SDK streaming output](https://platform.claude.com/docs/en/agent-sdk/streaming-output) — stream event types, message flow, tool call streaming patterns
- [Windsurf Cascade docs](https://docs.windsurf.com/windsurf/cascade/cascade) — Cascade UI patterns, checkpoint system, model selector
- [Windsurf Wave 8 changelog](https://windsurf.com/blog/windsurf-wave-8-ux-features-and-plugins) — code block/diff improvements, terminal command editing

**MEDIUM confidence (community extensions + verified against official feature lists):**
- [claude-code-chat by andrepimenta](https://github.com/andrepimenta/claude-code-chat) — community VS Code extension; message bubbles, inline diff, cost/token tracking UI patterns
- [claude-code-webui by sugyan](https://github.com/sugyan/claude-code-webui) — web UI for CC CLI; session management, permission dialogs, streaming patterns
- [Shape of AI — Stream of Thought](https://www.shapeof.ai/patterns/stream-of-thought) — thinking block / progressive disclosure UX pattern
- Cursor Composer patterns — sourced from [Cursor overview](https://cursor.com/features) and [comparison articles](https://www.qodo.ai/blog/windsurf-vs-cursor/)

**LOW confidence (community forum / feature requests):**
- [Claude Code GitHub issue #10593](https://github.com/anthropics/claude-code/issues/10593) — real-time token usage indicator (requested, not yet shipped)
- [Claude Code GitHub issue #28962](https://github.com/anthropics/claude-code/issues/28962) — context window bar with threshold alerts (requested, not yet shipped)
- [Cursor forum discussion on UI regression](https://forum.cursor.com/t/please-bring-back-the-old-ui/146375) — evidence of Cursor's 2.0 agent-centric redesign and user reactions

---

*Feature research for: VS Code-style AI chat interface embedded in Agent42 dashboard*
*Researched: 2026-03-17*
