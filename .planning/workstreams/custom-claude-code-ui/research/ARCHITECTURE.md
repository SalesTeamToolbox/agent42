# Architecture Research: Custom Claude Code Chat UI

**Domain:** Rich chat UI for Claude Code CLI integration in a vanilla JS + FastAPI web IDE
**Researched:** 2026-03-17
**Confidence:** HIGH (existing codebase fully read; CC CLI docs verified via official sources)

---

## The Central Question

Three architectural options exist for building a rich chat UI over Claude Code:

| Option | Mechanism | Verdict |
| ------ | --------- | ------- |
| A. Parse ANSI output | xterm renders ANSI; backend scrapes PTY stream | AVOID — brittle, unstructured, renders terminal not chat |
| B. Direct API backend | Backend calls Anthropic/Synthetic API directly | VIABLE — /api/ide/chat already exists |
| C. CLI stream-json bridge | Backend spawns `claude -p --output-format stream-json`, relays structured events over WS | RECOMMENDED — preserves CC auth, MCP tools, skills |

**Recommendation: Option C as primary, Option B as fallback/config path.**

`claude -p "prompt" --output-format stream-json --verbose --include-partial-messages` emits newline-delimited JSON events. The backend reads stdout, parses each event, and relays structured messages to the frontend over a WebSocket. This gives you CC's native tool permissions, MCP server integration, skills, session resume, and no separate API key configuration.

Option B (`/api/ide/chat`) already works and can remain as the fallback path for environments without CC installed.

---

## System Overview

```text
Browser (vanilla JS SPA)
  |
  |  WebSocket  /ws/cc-chat?token=&session=
  |
FastAPI (server.py)
  |  bridge layer
  +--- cc_chat_ws() endpoint
       |
       |  subprocess stdout (NDJSON)
       |
       claude -p "..." --output-format stream-json --verbose
                        --include-partial-messages
                        --resume <session_id>     (if resuming)
                        --allowedTools "..."      (configured tools)
       |
       [CC writes session to ~/.claude/projects/<cwd>/<uuid>.jsonl]
```

**Key insight:** The frontend never parses ANSI. It receives structured JSON events from the backend and renders them into a rich chat UI with typed message bubbles, streaming text, and tool use cards.

---

## Standard Architecture

### Component Diagram

```text
+-------------------------------------------------------------+
|                  Browser (Vanilla JS SPA)                   |
+----------------------------+--------------------------------+
|  ide-chat-panel (new)      |  xterm tab (existing)         |
|  - Message bubbles         |  - Raw CC terminal            |
|  - Streaming text cursor   |  - /ws/terminal?cmd=claude    |
|  - Tool use cards          |                               |
|  - Input composer          |                               |
+-------------+--------------+--------------------------------+
              |  /ws/cc-chat?token=&session=  (NEW WebSocket)
+-------------v----------------------------------------------+
|                     FastAPI  (server.py)                    |
|  cc_chat_ws()  -- new WS endpoint                          |
|  - Auth token validation                                    |
|  - Session ID management (create / resume)                  |
|  - Event relay: NDJSON stdout to WS JSON messages           |
|  - Inbound: user messages spawn new subprocess per turn     |
|  /api/cc/sessions  -- new REST endpoints                    |
|  - GET list sessions                                        |
|  - DELETE session                                           |
+------------------------------+-----------------------------+
                               |  subprocess (stdout pipe)
+------------------------------v-----------------------------+
|  claude -p --output-format stream-json --verbose           |
|           --include-partial-messages --resume <id>         |
|  [CC process -- owns MCP auth, skills, tools]              |
|  Session persisted: ~/.claude/projects/<cwd>/<uuid>.jsonl  |
+------------------------------------------------------------+
```

### Component Responsibilities

| Component | Responsibility | Location |
| --------- | -------------- | -------- |
| `cc_chat_ws()` | WS endpoint -- auth, spawn CC, relay events, handle resume | `dashboard/server.py` (new) |
| `_cc_chat_sessions` dict | Server-side session ID registry (user label to CC UUID) | In-memory + JSON file (new) |
| `/api/cc/sessions` | List and delete chat sessions | `dashboard/server.py` (new) |
| `renderCcChat()` | Frontend -- render chat panel DOM, attach WS | `dashboard/frontend/dist/app.js` (new) |
| `ccChatConnectWs()` | Frontend -- establish WS, handle events, update DOM | `dashboard/frontend/dist/app.js` (new) |
| `ccChatRenderMessage()` | Frontend -- render a single message bubble | `dashboard/frontend/dist/app.js` (new) |
| `_ccChatState` | Frontend -- session list, messages, streaming buffer | `dashboard/frontend/dist/app.js` (global) |

---

## Message Data Model

### Backend-to-Frontend Message Types (WebSocket)

The backend consumes CC's NDJSON stdout and translates to these typed messages:

```text
All WS messages share this envelope:
  { "type": "<msg_type>", ...payload }

Session established (sent first on each WS connection):
  { "type": "session_init", "session_id": "uuid", "resumed": false }

Text streaming token:
  { "type": "text_delta", "text": "some text chunk" }

Turn complete (one full assistant response done):
  { "type": "turn_complete", "stop_reason": "end_turn" }

Tool use started (input not yet complete):
  { "type": "tool_start", "tool_id": "toolu_01...", "tool_name": "Bash" }

Tool input delta (streaming partial JSON):
  { "type": "tool_input_delta", "tool_id": "toolu_01...", "partial_json": "{\"cmd" }

Tool input complete (full input available):
  { "type": "tool_complete", "tool_id": "toolu_01...", "tool_name": "Bash",
    "input": {"command": "ls -la"} }

Agent done (final result message, process exits):
  { "type": "agent_done", "result": "summary text", "total_cost_usd": 0.012 }

Error:
  { "type": "error", "message": "CC not found / auth error / etc.", "fallback": "api" }

API retry notification:
  { "type": "api_retry", "attempt": 1, "max_retries": 3, "retry_delay_ms": 2000 }
```

### CC Stream-JSON Event Mapping

CC's `--output-format stream-json` emits NDJSON. Backend translation table:

| CC top-level type | CC sub-detail | Frontend type emitted |
| ----------------- | ------------- | --------------------- |
| `system` + `subtype: "init"` | has `session_id` | `session_init` |
| `stream_event` | inner `content_block_start`, block type `tool_use` | `tool_start` |
| `stream_event` | inner `content_block_delta`, delta type `text_delta` | `text_delta` |
| `stream_event` | inner `content_block_delta`, delta type `input_json_delta` | `tool_input_delta` |
| `stream_event` | inner `content_block_stop` (when prior block was tool_use) | `tool_complete` |
| `stream_event` | inner `message_stop` | `turn_complete` |
| `result` | has `result`, `total_cost_usd`, `session_id` | `agent_done` |
| `system` + `subtype: "api_retry"` | has `attempt`, `retry_delay_ms` | `api_retry` |

**Note on tool_result:** CC does not emit a separate `tool_result` stream event in `stream-json` mode. Tool outputs appear as context in subsequent turns. The chat UI represents executed tools as "ran X" cards showing input; the results appear in CC's prose response that follows.

### Frontend Message State Object

```javascript
// Stored in _ccChatState.messages array
{
  id: "msg-001",             // local ID for DOM keying
  role: "user" | "assistant",
  content: "",               // accumulated text (grows during streaming)
  streaming: true,           // false when turn_complete or agent_done received
  tool_calls: [              // populated from tool_start / tool_complete events
    {
      tool_id: "toolu_01...",
      tool_name: "Bash",
      input_partial: "",     // grows from tool_input_delta events
      input: null,           // set when tool_complete received
    }
  ],
  timestamp: 1742000000
}
```

### Session Persistence Model

CC handles its own session persistence at `~/.claude/projects/<cwd>/<session_uuid>.jsonl`. Agent42 stores only the mapping from user-visible label to CC session UUID:

```json
{
  "uuid-abc-123": {
    "id": "uuid-abc-123",
    "name": "My refactor chat",
    "created_at": 1742000000,
    "last_used_at": 1742001000,
    "cwd": "/path/to/workspace"
  }
}
```

The CC session file at `~/.claude/projects/.../*.jsonl` is authoritative. If it exists, the session is resumable. If the file is missing, start a fresh session gracefully rather than erroring.

---

## Architectural Patterns

### Pattern 1: NDJSON Bridge (CLI Stream-JSON to WebSocket)

**What:** Backend spawns `claude -p` with `--output-format stream-json`, reads stdout line-by-line, parses each NDJSON event, translates to frontend types, and sends over WebSocket.

**When to use:** Primary path when the `claude` binary is available and the user has a CC subscription or API key.

**Trade-offs:** Preserves all CC features (MCP tools, skills, permissions). Process lifecycle managed by FastAPI. Complexity lives in the translation layer. All CC authentication is inherited -- no second API key needed in Agent42.

Endpoint structure mirrors the existing `terminal_ws` pattern in `server.py`:

1. Accept WS + auth token validation using existing `_get_user_from_token`
2. Determine if new session or resume from `?session=` query param
3. Build subprocess command array: `[claude_bin, "-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages", "--allowedTools", allowed_tools]` with optional `["--resume", session_id]`
4. Receive first JSON message from frontend containing `{"prompt": "..."}`, extract prompt string
5. Spawn subprocess with prompt as final positional arg, `stdout=PIPE`, cwd=workspace
6. Async read stdout line-by-line, parse NDJSON, call `_translate_cc_event()`, send over WS
7. On process exit (or result event), send `agent_done` or `error` message and close

### Pattern 2: Multi-Turn via Re-Spawn with Resume

**What:** `claude -p` is single-shot -- it takes one prompt and exits. Multi-turn chat requires spawning a new process with `--resume <session_id>` for each user message. The session UUID is extracted from the first run's `system/init` event.

**When to use:** Every follow-up message after the first.

**Trade-offs:** Process startup cost per turn (~200-400ms on most machines). This is acceptable for chat UX. CC session files accumulate context so Claude has full conversation history on every turn.

Session ID lifecycle:

- Turn 1: spawn without `--resume`, extract `session_id` from `system/init` event, store in `_cc_chat_sessions`
- Turn 2+: spawn with `--resume <session_id>`, CC reads `~/.claude/projects/<cwd>/<session_id>.jsonl` and responds with full prior context

Frontend sends `?session=abc-123` on WS connect for follow-up turns. Backend sees this and adds `--resume abc-123` to the CC command.

### Pattern 3: Frontend Streaming Renderer

**What:** Accumulate `text_delta` events into a streaming buffer, updating a single message DOM node incrementally. Show a CSS-animated blinking cursor during streaming. Remove cursor on `turn_complete` or `agent_done`.

**When to use:** Displaying CC responses token-by-token, same pattern as the VS Code CC extension.

Key implementation detail: maintain `_ccChatState.streamingMsgId` as a pointer to the DOM element currently receiving deltas. Update `innerHTML` of that element directly -- do not re-render the entire message list on every token. The existing `appendChatMsgToDOM()` pattern already does incremental DOM updates; extend it for the streaming case.

### Pattern 4: Tool Use Cards

**What:** Tool calls render as collapsible cards, visually distinct from prose text. Show tool name and a CSS spinner while CC is using the tool. Expand to show input on completion.

**When to use:** Any time a `tool_start` event arrives.

Card anatomy:

- Header: tool icon + tool name + status indicator (CSS spinner while running / check mark when complete)
- Input section: collapsed by default; shows tool parameters as one-liner (e.g., `Read auth.py` or `Bash: ls -la`)
- Output: not shown in the card -- appears in CC's prose response text that follows

Tool cards must be visually distinct from prose to make the agentic behavior legible to the user.

### Pattern 5: Diff Rendering

**What:** When CC modifies files, its response text often contains a diff. The existing `renderMarkdown()` function already handles triple-backtick code blocks. Add CSS to colorize `+`/`-` lines within diff blocks.

**When to use:** When CC's response includes a code block with language identifier `diff`.

Implementation: add `.cc-diff del` (red background) and `.cc-diff ins` (green background) CSS rules. Detect diff code blocks and apply the `.cc-diff` class. Zero new JS libraries needed. Full Monaco diff view is out of scope for phase 1.

### Pattern 6: Fallback to Direct API

**What:** If `claude` binary is absent or CC auth fails, fall back to the existing `/api/ide/chat` endpoint (Anthropic API direct).

**When to use:** Dev environments without CC installed, or users who prefer direct API access.

Implementation: `cc_chat_ws` tries `shutil.which("claude")` first. If None, it sends `{"type":"error","message":"Claude Code not installed","fallback":"api"}`. Frontend detects `fallback:"api"` and uses `apiFetch("/api/ide/chat", ...)` with a spinner (non-streaming). The existing `/api/ide/chat` endpoint already handles message history and tool calls.

---

## Data Flow

### First Message (New Session)

```text
User types message, presses Enter
  --> ccChatSend()
  --> WebSocket connect: /ws/cc-chat?token=X  (no session param)
  --> Frontend sends JSON: {"prompt": "fix the login bug"}

Backend: verifies token, spawns CC subprocess
  Command: claude -p "fix the login bug"
           --output-format stream-json --verbose --include-partial-messages
           --allowedTools "Read,Bash,Grep,Glob,Edit,Write"
           (cwd = workspace root)

CC stdout NDJSON lines, backend translates, sends WS JSON:

  CC: {"type":"system","subtype":"init","session_id":"abc-123"}
  WS: {"type":"session_init","session_id":"abc-123"}
  FE: _ccChatState.sessionId = "abc-123"; store in backend _cc_chat_sessions

  CC: {"type":"stream_event","event":{"type":"content_block_start",
       "content_block":{"type":"tool_use","id":"toolu_01","name":"Read"}}}
  WS: {"type":"tool_start","tool_id":"toolu_01","tool_name":"Read"}
  FE: append tool card with spinner

  CC: {"type":"stream_event","event":{"type":"content_block_delta",
       "delta":{"type":"text_delta","text":"I found the issue"}}}
  WS: {"type":"text_delta","text":"I found the issue"}
  FE: append to streaming bubble

  CC: {"type":"result","result":"Done.","total_cost_usd":0.005,"session_id":"abc-123"}
  WS: {"type":"agent_done","result":"Done.","total_cost_usd":0.005}
  FE: finalize message, show cost, re-enable input
```

### Follow-Up Message (Same Session)

```text
User types follow-up, _ccChatState.sessionId = "abc-123"
  --> WebSocket connect: /ws/cc-chat?token=X&session=abc-123
  --> Frontend sends JSON: {"prompt": "also fix the password reset"}

Backend spawns CC subprocess:
  Command: claude -p "also fix the password reset"
           --output-format stream-json --verbose --include-partial-messages
           --resume abc-123
  CC reads ~/.claude/projects/<cwd>/abc-123.jsonl for full prior context
  Same event flow as first message
```

### State Management

```javascript
_ccChatState = {
  sessionId: null,           // set from session_init event
  sessions: [],              // list from /api/cc/sessions (sidebar)
  messages: [],              // rendered message objects
  streamingMsgId: null,      // DOM element ID currently receiving deltas
  sending: false,            // disables input during generation
  ws: null                   // current WebSocket (null between turns)
}
```

---

## Integration Points

### New Components

| Component | Type | Depends On |
| --------- | ---- | ---------- |
| `cc_chat_ws()` | New WS endpoint in server.py | `claude` binary via `shutil.which`, existing token auth |
| `_translate_cc_event()` | New function in server.py | CC stream-json event schema |
| `/api/cc/sessions` GET + DELETE | New REST endpoints | `_cc_chat_sessions` dict |
| `_cc_chat_sessions` | Server-side state (in-memory + JSON) | `.agent42/cc-sessions.json` |
| `renderCcChat()` | New function in app.js | Existing `renderCode()` layout DOM |
| `ccChatConnectWs()` | New function in app.js | Existing `termConnectWs()` pattern |
| `ccChatHandleEvent()` | New event dispatcher in app.js | None |
| `ccChatRenderMessage()` | New function in app.js | Existing `renderMarkdown()`, `esc()` |
| `ccChatRenderToolCard()` | New function in app.js | None |

### Modified Components

| Component | Change | Risk |
| --------- | ------ | ---- |
| `renderCode()` in app.js | Add chat panel container to IDE layout HTML | LOW -- additive; no touch to terminal or Monaco code |
| `ide-layout` DOM | Add `#ide-chat-panel` div | LOW -- additive only |
| `server.py` `create_app()` | Register new WS and REST endpoints | LOW -- additive |

### Existing Assets to Reuse

| Asset | How to Reuse |
| ----- | ------------ |
| `esc()` | XSS protection for all interpolated chat content |
| `renderMarkdown()` | Render CC prose responses (markdown with code blocks) |
| `apiFetch()` / `api()` | Load session list from `/api/cc/sessions` |
| `toast()` | Show connection errors to user |
| `get_current_user()` | Auth dependency for new endpoints |
| `shutil.which("claude")` | Already used in `terminal_ws` -- same pattern |
| `buildChatMsgHtml()` | Existing bubble HTML -- extend for CC mode |
| `appendChatMsgToDOM()` | Incremental DOM append without full re-render |
| Existing CSS vars | `--bg-secondary`, `--accent-blue`, etc. for consistent styling |

### Internal Boundaries

| Boundary | Communication | Notes |
| -------- | ------------- | ----- |
| Frontend `ccChatConnectWs()` to backend `cc_chat_ws()` | WebSocket (JSON) | One WS per turn; reconnects per follow-up message |
| Backend `cc_chat_ws()` to CC subprocess | asyncio PIPE stdout | stdin receives only the initial prompt string |
| Backend session store to REST API | In-process dict | No DB needed; serialize to `.agent42/cc-sessions.json` |
| Chat panel to Monaco editor | None | Independent containers in `ide-layout` |
| Chat panel to xterm tabs | None | Both in IDE layout as independent sections |

---

## Recommended Build Order

Build phases in this order so each unblocks the next:

### Phase 1: Backend WS Bridge

Can test with curl/websocat before any frontend exists. Unblocks all frontend work.

1. `cc_chat_ws()` endpoint -- single-turn, no resume yet
2. `_translate_cc_event()` covering the 8 event types in the mapping table above
3. Session ID extraction from `system/init`; persist to `_cc_chat_sessions`
4. `/api/cc/sessions` GET (list) and DELETE endpoints
5. Tests: source inspection for translation logic; mock subprocess for WS endpoint

### Phase 2: Frontend Chat Panel

Renders messages. No session persistence UI yet.

1. `_ccChatState` global definition
2. `renderCcChat()` -- adds panel container alongside terminal wrapper in `renderCode()`
3. `ccChatConnectWs()` + `ccChatHandleEvent()` event dispatch
4. `ccChatRenderMessage()` -- user and assistant bubbles reusing `buildChatMsgHtml` pattern
5. `ccChatRenderToolCard()` -- tool use cards with CSS spinner
6. Input composer: textarea + send button + Enter key handler

### Phase 3: Session Persistence + Multi-Turn

1. Backend: re-spawn with `--resume <id>` on follow-up messages
2. Backend: persist `_cc_chat_sessions` to `.agent42/cc-sessions.json` on each write
3. Frontend: session list sidebar (reuse existing session list CSS)
4. Frontend: `createCcSession()` / `switchCcSession()` / `deleteCcSession()`

### Phase 4: Polish

1. Diff colorization in CC response code blocks
2. Copy-to-clipboard on code blocks
3. Cost display from `agent_done.total_cost_usd`
4. API retry progress from `api_retry` events
5. Fallback path to `/api/ide/chat` when CC binary absent

---

## Anti-Patterns

### Anti-Pattern 1: Parse ANSI from PTY

**What people do:** Read the raw PTY stream from the existing `terminal_ws`, scrape ANSI escape codes, reconstruct structured messages.

**Why it's wrong:** ANSI codes change with CC version updates. Interactive CC writes cursor movement, color, and TUI chrome indistinguishable from response text. PTY streams are designed for human terminals, not machine parsing.

**Do this instead:** Use `claude -p --output-format stream-json`. This is an explicit, stable, documented contract.

### Anti-Pattern 2: Keep Interactive CC Process for Multi-Turn

**What people do:** Start `claude` in interactive mode, keep process running, pipe follow-up messages to stdin.

**Why it's wrong:** Interactive CC uses a TUI with escape sequences. There is no documented protocol for injecting messages into a running interactive session's stdin without corruption.

**Do this instead:** Spawn a new `-p` process per turn with `--resume <session_id>`. CC restores full context from the session file on disk.

### Anti-Pattern 3: Store Full CC Session Content Server-Side

**What people do:** Copy `~/.claude/projects/<cwd>/<session_id>.jsonl` into Agent42's database.

**Why it's wrong:** CC session files grow large (100KB+). CC already owns and persists them. Duplicating creates sync issues and wasted storage.

**Do this instead:** Store only `{session_id, name, cwd, timestamps}` in Agent42. CC owns session content.

### Anti-Pattern 4: Persistent WebSocket Per Session

**What people do:** Keep a WebSocket open for the entire lifetime of a chat session across multiple messages.

**Why it's wrong:** `claude -p` exits after each response. A persistent WS has no live process behind it between turns.

**Do this instead:** One WS per turn. Frontend opens new WS per message (with `?session=<id>`), receives the complete response, then closes. Same pattern as SSH terminal sessions in `terminal_ws`.

### Anti-Pattern 5: Disable All Tool Permissions

**What people do:** Pass `--allowedTools ""` to avoid permission prompts, accidentally stripping CC of all tools.

**Why it's wrong:** Without tools, CC responds with text only -- no file reading, bash, or MCP. This eliminates most of the value of CC integration.

**Do this instead:** Default `--allowedTools "Read,Bash,Grep,Glob,Edit,Write"`. Expose as `CC_CHAT_ALLOWED_TOOLS` env var.

---

## Scaling Considerations

This is a single-user local tool. Practical limits only:

| Concern | Approach |
| ------- | -------- |
| CC process startup per turn (~200-400ms) | Acceptable; no mitigation needed |
| CC session file size growth | Add `max_age_days` cleanup to `/api/cc/sessions` |
| WebSocket connections | One per active turn; FastAPI handles trivially |
| Token cost accumulation | Show `total_cost_usd` in UI; support `--max-budget-usd` CC flag |
| Concurrent chat tabs | Each WS spawns independent CC process; isolated by session_id |

---

## Recommended Project Structure Changes

```text
dashboard/
  server.py               -- +cc_chat_ws(), +/api/cc/sessions, +_cc_chat_sessions dict
  frontend/dist/
    app.js                -- +_ccChatState, +renderCcChat(), +ccChatConnectWs(),
                             +ccChatHandleEvent(), +ccChatRenderMessage(),
                             +ccChatRenderToolCard()
    style.css             -- +.cc-chat-panel, .cc-msg-*, .cc-tool-card, .cc-diff

.agent42/
  cc-sessions.json        -- persisted session metadata (id, name, cwd, timestamps)
```

No new Python packages (uses existing `asyncio`, `json`, `shutil`). No new JS libraries. No new directories beyond `.agent42/`.

---

## Sources

- [Run Claude Code programmatically (official)](https://code.claude.com/docs/en/headless) -- HIGH confidence. Confirms `claude -p --output-format stream-json --verbose --include-partial-messages` as the structured streaming API. Confirms single-shot nature of `-p` mode.
- [Claude Code CLI reference (official)](https://code.claude.com/docs/en/cli-reference) -- HIGH confidence. `--resume`, `--session-id`, `--allowedTools`, `--include-partial-messages`, `--max-budget-usd` flags all confirmed.
- [Claude Agent SDK -- Stream responses (official)](https://platform.claude.com/docs/en/agent-sdk/streaming-output) -- HIGH confidence. Event types documented with code examples.
- [Claude Agent SDK -- Sessions (official)](https://platform.claude.com/docs/en/agent-sdk/sessions) -- HIGH confidence. Session stored under `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`. Resume by ID confirmed.
- Existing codebase `dashboard/server.py` lines 1437-1713 (direct read) -- HIGH confidence. `terminal_ws` is the direct model for `cc_chat_ws`.
- Existing codebase `dashboard/server.py` lines 1810-1957 (direct read) -- HIGH confidence. `/api/ide/chat` confirmed as fallback path.
- Existing codebase `dashboard/frontend/dist/app.js` lines 2795-2979 (direct read) -- HIGH confidence. `buildChatMsgHtml`, `appendChatMsgToDOM`, `sendSessionMessage` confirmed as reusable.
- Existing codebase `dashboard/frontend/dist/app.js` lines 3198-3713 (direct read) -- HIGH confidence. `renderCode()`, `ideOpenClaude()`, `termConnectWs()` confirmed.
- [`claude-code-webui` (GitHub)](https://github.com/sugyan/claude-code-webui) -- MEDIUM confidence. Confirms subprocess-based CC web UI is viable.

---

## Confidence Assessment

| Area | Confidence | Reason |
| ---- | ---------- | ------ |
| CC stream-json event schema | HIGH | Official Agent SDK docs; events are stable and versioned |
| Multi-turn via `--resume` | HIGH | Official CLI docs confirm `--resume <id>` with session at `~/.claude/projects/` |
| Tool permission handling | HIGH | `--allowedTools` documented and confirmed |
| Frontend message model | HIGH | Derived from existing chat infrastructure in app.js (direct read) |
| Session persistence (server-side dict + JSON file) | MEDIUM | Straightforward but untested in this specific codebase |
| CC process startup latency | MEDIUM | Estimated; not benchmarked in this environment |
| Remote chat (SSH relay) | LOW | Concept clear; requires CC on remote host; untested |

---

*Architecture research for: Custom Claude Code Chat UI*
*Researched: 2026-03-17*
