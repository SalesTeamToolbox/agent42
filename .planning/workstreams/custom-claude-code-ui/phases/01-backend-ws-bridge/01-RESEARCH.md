# Phase 1: Backend WS Bridge - Research

**Researched:** 2026-03-17
**Domain:** Python asyncio subprocess management, FastAPI WebSocket, CC CLI stream-json NDJSON parsing
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**CC CLI invocation:**
- Command: `claude -p --output-format stream-json --verbose --include-partial-messages`
- `--verbose`: includes tool input/output inline in stream events, required for Phase 3 tool cards
- `--include-partial-messages`: enables incremental streaming of tool content (not just on completion)
- No `--allowedTools` restriction - CC operates with its full native + MCP tool set
- No `--system` prompt injection - UI handles display formatting on the frontend

**Process lifecycle:**
- Spawn a new `claude` subprocess per user turn (re-spawn model, not keep-alive)
- First turn: spawn without `--resume`, parse `session_id` from CC's result event, store server-side
- Subsequent turns: spawn with `--resume <cc_session_id>` for conversation continuity
- On WebSocket disconnect mid-generation: kill subprocess immediately (SIGTERM), no grace period
- No orphan process risk - each turn's subprocess is tracked and killed on WS disconnect

**Server-side session storage:**
- Storage: file-based JSON in `.agent42/cc-sessions/`
- One JSON file per Agent42 session
- Fields: `cc_session_id`, `ws_session_id`, `created_at`, `last_active_at`, `title` (first ~80 chars of user's first message)
- No full transcript - CC already owns conversation history
- Survives server restarts (unlike in-memory dict)
- No Redis dependency for this feature

**WebSocket message schema (normalized envelope):**
- Consistent envelope: `{"type": "<event>", "data": {...}}`
- Full event type set:
  - `text_delta` - streaming assistant text chunk: `{text: string}`
  - `tool_start` - tool invocation begins: `{id, name, input}`
  - `tool_delta` - incremental tool output: `{id, partial}`
  - `tool_complete` - tool invocation done: `{id, name, output, is_error}`
  - `turn_complete` - turn finished: `{session_id, cost_usd, input_tokens, output_tokens}`
  - `error` - backend or CC error: `{message, code}`
  - `status` - informational: `{message}`
- `turn_complete` includes full usage stats for Phase 3 token display (SESS-06)

**Fallback behavior:**
- BRIDGE-05: when `claude` CLI unavailable, route to existing `/api/ide/chat` logic
- Frontend notified via `status` event before fallback kicks in

### Claude's Discretion

- JWT auth approach for `/ws/cc-chat` (follow `/ws/terminal` pattern)
- File format and cleanup policy for `.agent42/cc-sessions/`
- Exact asyncio subprocess management (follow `asyncio.create_subprocess_exec` pattern from `/ws/terminal`)
- BRIDGE-06 subscription detection implementation details (`claude auth status` parsing)

### Deferred Ideas (OUT OF SCOPE)

- Session transcript storage (full message history) - Phase 3
- Cross-node CC sessions via SSH relay - ADV-03
- Token usage cost tracking across sessions - ADV-02
- Configurable --allowedTools per session - Phase 3 or later
- System prompt injection / project-specific CC context - out of scope Phase 1
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BRIDGE-01 | Server exposes `/ws/cc-chat` WebSocket endpoint that spawns `claude -p --output-format stream-json` and relays structured NDJSON events to frontend | FastAPI `@app.websocket`, `asyncio.create_subprocess_exec` with PIPE stdout - same pattern as `/ws/terminal` |
| BRIDGE-02 | Backend translates CC stream-json events (system, stream_event, result) into normalized message format (text_delta, tool_start, tool_complete, turn_complete, etc.) | CC stream-json event schema documented below - `stream_event` wraps raw Anthropic API events, `result` contains session_id and usage |
| BRIDGE-03 | Session registry tracks active CC processes by session ID, allowing multi-session management | File-based JSON in `.agent42/cc-sessions/` - one JSON file per session, directory pattern follows `.agent42/qdrant/` |
| BRIDGE-04 | Multi-turn conversations work via `--resume <session_id>` - process re-spawned per turn with session continuity | CC `--resume` flag verified: accepts session ID from prior turn's `result` event. First turn omits flag, subsequent turns pass `--resume <cc_session_id>` |
| BRIDGE-05 | Fallback path uses existing `/api/ide/chat` (Anthropic API via httpx) when `claude` CLI not available | `/api/ide/chat` handler exists in `server.py` line 1962. Fallback uses `shutil.which("claude")` detection - same pattern as `/ws/terminal` line 1467 |
| BRIDGE-06 | Server detects CC subscription status via `claude auth status` and reports availability to frontend | `claude auth status` exits 0 if logged in, exits 1 if not. JSON output by default; `--text` for human-readable. Can run async via `asyncio.create_subprocess_exec` |
</phase_requirements>

---

## Summary

Phase 1 builds a Python asyncio WebSocket bridge that translates CC CLI subprocess output into typed WebSocket messages. The implementation is heavily constrained by existing patterns already present in `dashboard/server.py` - specifically the `/ws/terminal` endpoint (lines 1423-1650) which already demonstrates asyncio subprocess spawning, JWT auth via query param, and disconnect cleanup. The CC bridge follows this same skeleton, replacing PTY I/O with NDJSON line parsing.

The CC CLI outputs NDJSON when invoked with `--output-format stream-json --verbose --include-partial-messages`. Each line is a JSON object. Event types are: `system` (session init + retry info), `stream_event` (wraps raw Anthropic API streaming events - text deltas, tool use, tool input chunks), and `result` (final turn summary with `session_id`, `cost_usd`, `usage`). The bridge's core job is parsing these three raw CC event types and mapping them to the six normalized envelope types the frontend contract requires.

Session persistence is straightforward: a small JSON file per session in `.agent42/cc-sessions/` (following the `.agent42/qdrant/` data-dir pattern already established). No Redis, no database. The `--resume <session_id>` flag provides multi-turn continuity by re-spawning CC with the prior turn's session ID from the `result` event.

**Primary recommendation:** Implement `/ws/cc-chat` directly after the terminal WebSocket block in `server.py` (~line 1650+), reusing `_get_user_from_token` and the `asyncio.create_subprocess_exec` + PIPE stdout pattern verbatim. The NDJSON parser is a simple line-by-line `readline()` loop with a `json.loads()` call per line.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `asyncio` | stdlib | Subprocess management, concurrent read + receive | Already used throughout agent42; all I/O is async |
| `fastapi.WebSocket` | installed | WebSocket endpoint hosting | Already installed, all endpoints use FastAPI |
| `asyncio.create_subprocess_exec` | stdlib | Spawn CC CLI subprocess with PIPE stdout | Same pattern as remote SSH in `/ws/terminal` |
| `json` | stdlib | NDJSON line parsing | Standard; CC output is line-delimited JSON |
| `shutil.which` | stdlib | Detect `claude` binary availability | Already used in `/ws/terminal` line 1467 |
| `aiofiles` | installed | Async file I/O for session JSON files | Project standard - NEVER use blocking `open()` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `python-jose` | installed | JWT decode for WS auth token | Same `_get_user_from_token()` already in server.py |
| `pathlib.Path` | stdlib | Session directory and file path handling | Project convention - `workspace` is a Path throughout |
| `datetime` | stdlib | `created_at` / `last_active_at` timestamps in session JSON | ISO format strings |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| File-based session JSON | In-memory dict | In-memory doesn't survive restarts - ruled out by locked decision |
| Per-turn subprocess spawn | Keep-alive process | Keep-alive adds orphan-process risk + stdin pipe complexity; locked decision is per-turn |
| `asyncio.create_subprocess_exec` | `subprocess.Popen` in executor | Blocking Popen violates async-I/O rule; asyncio is the correct approach |

**Installation:** No new dependencies required - all libraries are already installed.

---

## Architecture Patterns

### Recommended Project Structure

```
dashboard/
  server.py              # /ws/cc-chat and /api/cc/sessions/* added inline (~line 1650+)
.agent42/
  cc-sessions/           # Created on first use; one JSON file per ws_session_id
    {ws_session_id}.json
```

No new files required. The entire Phase 1 implementation lives in `dashboard/server.py`, consistent with all other IDE endpoints.

### Pattern 1: CC Subprocess Spawn (per-turn)

**What:** For each user message, spawn a fresh CC process with PIPE stdout. Read stdout line by line (NDJSON). Kill on WS disconnect.

**When to use:** Every user turn. First turn omits `--resume`. Subsequent turns pass `--resume <cc_session_id>`.

```python
# Source: /ws/terminal pattern + CC CLI docs (code.claude.com/docs/en/headless)
import asyncio, shutil, json

claude_bin = shutil.which("claude")
if not claude_bin:
    # BRIDGE-05 fallback path
    ...

# First turn (no session yet)
args = [claude_bin, "-p", user_message,
        "--output-format", "stream-json",
        "--verbose", "--include-partial-messages"]

# Subsequent turns
if cc_session_id:
    args += ["--resume", cc_session_id]

proc = await asyncio.create_subprocess_exec(
    *args,
    stdout=asyncio.subprocess.PIPE,
    stderr=asyncio.subprocess.PIPE,
    cwd=str(workspace),
)
```

### Pattern 2: NDJSON Line Reader with Event Mapping

**What:** Read CC stdout line by line. Each line is a JSON object. Map CC event types to normalized envelope types and send over WS.

**CC stream-json event types (verified against official CC docs):**

| CC `type` field | Sub-fields | Maps to normalized type |
|-----------------|-----------|-------------------------|
| `system` (subtype `init`) | `session_id`, `cwd`, `tools[]` | Internal - capture session_id opportunistically |
| `system` (subtype `api_retry`) | `attempt`, `max_retries`, `retry_delay_ms`, `error` | `status` envelope with retry info |
| `stream_event` | `event` (raw Anthropic API event) | See inner event routing below |
| `result` | `session_id`, `cost_usd`, `usage.input_tokens`, `usage.output_tokens` | `turn_complete` envelope |

**Inner `stream_event.event` routing (raw Anthropic API events, verified via Agent SDK docs):**

| `stream_event.event.type` | Sub-fields | Maps to normalized type |
|---------------------------|-----------|-------------------------|
| `content_block_start` (type=`text`) | - | No output (text accumulation begins) |
| `content_block_start` (type=`tool_use`) | `content_block.id`, `content_block.name` | `tool_start`: `{id, name, input: {}}` |
| `content_block_delta` (delta.type=`text_delta`) | `delta.text` | `text_delta`: `{text}` |
| `content_block_delta` (delta.type=`input_json_delta`) | `delta.partial_json` | `tool_delta`: `{id, partial}` |
| `content_block_stop` (after tool_use block) | - | `tool_complete`: `{id, name, output, is_error}` - output from `--verbose` inlined content |
| `message_start` / `message_delta` / `message_stop` | - | Internal bookkeeping; no WS emit |

**Note on `--verbose` tool output:** With `--verbose`, tool results appear in the stream as additional content blocks after the tool call. The exact field name for tool result text requires the STATE.md research flag: **verify against a live session before finalizing the `tool_complete` parser.**

```python
# Source: Agent SDK streaming docs (platform.claude.com/docs/en/agent-sdk/streaming-output)
async def _read_and_relay(proc, websocket, session_state):
    tool_id_map = {}   # index -> {id, name} for completing tool events
    current_tool_index = None

    async for raw_line in proc.stdout:
        line = raw_line.decode("utf-8", errors="replace").strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        etype = event.get("type")

        if etype == "stream_event":
            raw = event.get("event", {})
            raw_type = raw.get("type")
            cb = raw.get("content_block", {})
            delta = raw.get("delta", {})
            index = raw.get("index")

            if raw_type == "content_block_start" and cb.get("type") == "tool_use":
                tool_id_map[index] = {"id": cb["id"], "name": cb["name"]}
                current_tool_index = index
                await websocket.send_json({
                    "type": "tool_start",
                    "data": {"id": cb["id"], "name": cb["name"], "input": {}}
                })

            elif raw_type == "content_block_delta":
                if delta.get("type") == "text_delta":
                    await websocket.send_json({
                        "type": "text_delta",
                        "data": {"text": delta.get("text", "")}
                    })
                elif delta.get("type") == "input_json_delta":
                    tool_info = tool_id_map.get(index, {})
                    await websocket.send_json({
                        "type": "tool_delta",
                        "data": {"id": tool_info.get("id"), "partial": delta.get("partial_json", "")}
                    })

        elif etype == "result":
            session_state["cc_session_id"] = event.get("session_id")
            usage = event.get("usage", {})
            await websocket.send_json({
                "type": "turn_complete",
                "data": {
                    "session_id": event.get("session_id"),
                    "cost_usd": event.get("cost_usd"),
                    "input_tokens": usage.get("input_tokens", 0),
                    "output_tokens": usage.get("output_tokens", 0),
                }
            })
```

### Pattern 3: Session File I/O

**What:** One JSON file per Agent42 ws_session_id. Read on connection to get prior `cc_session_id`. Write/update after each turn.

```python
# Source: project convention (aiofiles for async I/O, pathlib for paths)
import aiofiles

CC_SESSIONS_DIR = workspace_root / ".agent42" / "cc-sessions"
CC_SESSIONS_DIR.mkdir(parents=True, exist_ok=True)

async def _load_session(ws_session_id: str) -> dict:
    path = CC_SESSIONS_DIR / f"{ws_session_id}.json"
    if not path.exists():
        return {}
    async with aiofiles.open(path, "r") as f:
        return json.loads(await f.read())

async def _save_session(ws_session_id: str, data: dict):
    path = CC_SESSIONS_DIR / f"{ws_session_id}.json"
    async with aiofiles.open(path, "w") as f:
        await f.write(json.dumps(data, indent=2))
```

### Pattern 4: JWT Auth (follow /ws/terminal)

**What:** Accept WS, read `token` query param, validate JWT, reject with close code 4001 if invalid.

```python
# Source: dashboard/server.py lines 1449-1457 (direct code read)
await websocket.accept()
token = websocket.query_params.get("token", "")
if not token:
    await websocket.close(code=4001, reason="Missing token")
    return
try:
    _get_user_from_token(token)
except Exception:
    await websocket.close(code=4001, reason="Invalid token")
    return
```

### Pattern 5: BRIDGE-06 Subscription Detection

**What:** Run `claude auth status` async, capture exit code. Exit code 0 = logged in, exit code 1 = not logged in. Cache result 60 seconds to avoid Node.js startup overhead per connection.

```python
# Source: CC CLI reference (code.claude.com/docs/en/cli-reference)
# "claude auth status - exits with code 0 if logged in, 1 if not"
_cc_auth_cache: dict = {"result": None, "expires": 0.0}

async def _check_cc_subscription() -> tuple[bool, str]:
    import time
    now = time.monotonic()
    if _cc_auth_cache["expires"] > now and _cc_auth_cache["result"] is not None:
        return _cc_auth_cache["result"]

    claude_bin = shutil.which("claude")
    if not claude_bin:
        result = (False, "claude CLI not installed")
    else:
        try:
            proc = await asyncio.create_subprocess_exec(
                claude_bin, "auth", "status",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await asyncio.wait_for(proc.wait(), timeout=10.0)
            result = (proc.returncode == 0, "CC subscription active" if proc.returncode == 0 else "CC not authenticated")
        except asyncio.TimeoutError:
            result = (False, "claude auth status timed out")
        except Exception as e:
            result = (False, f"auth check failed: {e}")

    _cc_auth_cache["result"] = result
    _cc_auth_cache["expires"] = now + 60.0
    return result
```

### Pattern 6: Disconnect Cleanup

**What:** Cancel the stdout read task and SIGTERM the subprocess when WS closes. Exactly as in `/ws/terminal` lines 1519-1522.

```python
# Source: dashboard/server.py lines 1519-1522 (direct code read)
finally:
    read_task.cancel()
    if proc.returncode is None:
        proc.terminate()
```

### Anti-Patterns to Avoid

- **Blocking file I/O in subprocess read loop:** Never use `open()` inside the NDJSON loop - use `aiofiles` for session writes, deferred to after turn completion.
- **Keep-alive process between turns:** Per-turn spawn is locked. Don't attempt keep-alive - adds stdin pipe management with no benefit.
- **String interpolation in subprocess args:** Use a list `[claude_bin, "-p", user_message, ...]` - never build a shell command string. No `shell=True`.
- **Parsing CC stderr for events:** CC writes errors to stderr; stdout is the NDJSON stream. Read stdout with PIPE; log stderr separately.
- **Fixed-size read() for NDJSON:** Use `readline()` (reads until newline) not `read(4096)` - chunks can split JSON lines.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JWT validation | Custom token decoder | `_get_user_from_token()` already in `server.py` | Already handles HS256, error cases |
| Async subprocess | `threading.Thread` + `subprocess.Popen` | `asyncio.create_subprocess_exec` | Project rule: no blocking I/O in async context |
| File-based session store | Custom DB or Redis | `aiofiles` + `json` to `.agent42/cc-sessions/` | Locked decision; no Redis dep |
| WS connection lifecycle | Custom manager | FastAPI `WebSocket` accept/close | Sufficient for single-session-per-WS pattern |

**Key insight:** The complexity of this phase is in the NDJSON parser mapping, not in the infrastructure. The infrastructure (subprocess, auth, disconnect) is already proven - copy it. Invest time in correctly mapping CC event types to normalized types, especially `tool_complete` with `--verbose` output.

---

## Common Pitfalls

### Pitfall 1: Session ID Extraction Timing
**What goes wrong:** `cc_session_id` is only available in the `result` event at end-of-turn. Attempting to store from `system/init` may use a different field.
**Why it happens:** CC emits a `system/init` event first with `session_id`, but the canonical ID for `--resume` is confirmed in the `result` event.
**How to avoid:** Store `session_id` from the `result` event (authoritative). Optionally capture from `system/init` as early-store.
**Warning signs:** `--resume` fails with "session not found" despite successful turn.

### Pitfall 2: NDJSON Parser Breaks on Partial Lines
**What goes wrong:** `proc.stdout.read(4096)` may split a JSON line mid-way, causing `json.JSONDecodeError`.
**Why it happens:** TCP buffering can split lines at arbitrary byte boundaries.
**How to avoid:** Use `proc.stdout.readline()` in a `async for line in proc.stdout` loop - reads until newline. Do NOT use fixed-size `read()` for NDJSON.
**Warning signs:** Intermittent `json.JSONDecodeError` on long tool output lines.

### Pitfall 3: tool_complete Content Requires --verbose
**What goes wrong:** Without `--verbose`, tool results don't appear in the NDJSON stream - only tool inputs stream. `tool_complete` events have no output data.
**Why it happens:** By default CC does not include tool result content in stream output.
**How to avoid:** `--verbose` is locked into the CLI command. Verify the exact field name for tool result content blocks in a live session (STATE.md research flag). Gate on field presence before emitting `output`.
**Warning signs:** `tool_complete` emits but `output` field is always empty or missing.

### Pitfall 4: Orphan Process on WS Disconnect During Generation
**What goes wrong:** WS disconnects while CC subprocess is running. Process continues consuming API credits.
**Why it happens:** `websocket.receive_text()` raises on disconnect; if not caught in `finally`, cleanup code doesn't run.
**How to avoid:** Wrap the read/receive loop in `try/finally` that always calls `proc.terminate()`. This is the established pattern in `/ws/terminal` lines 1519-1522.
**Warning signs:** Multiple `claude` processes visible in process list after client disconnects.

### Pitfall 5: `claude auth status` Slow on Cold Start
**What goes wrong:** Calling `claude auth status` on every `/ws/cc-chat` connection adds 200-500ms latency due to Node.js startup.
**How to avoid:** Cache the result at module level with a 60-second TTL (Pattern 5 above).
**Warning signs:** `/ws/cc-chat` connection handshake consistently slow.

### Pitfall 6: Fallback Path Emits Wrong Message Schema
**What goes wrong:** BRIDGE-05 fallback to `/api/ide/chat` returns a single complete response (not streamed). Frontend receives no incremental events.
**Why it happens:** `/api/ide/chat` is a REST endpoint returning a single JSON response. The WS bridge must adapt it to emit normalized events.
**How to avoid:** In fallback mode, emit: `status` event (informing user), call the chat logic, emit one `text_delta` with full response text, then `turn_complete` with zero token counts. Frontend sees consistent event sequence regardless of path.
**Warning signs:** Frontend renders nothing in fallback mode.

### Pitfall 7: Windows Path Separator in Session Files
**What goes wrong:** `.agent42/cc-sessions/` directory created with backslashes on Windows causes path comparison failures.
**How to avoid:** Always use `pathlib.Path` objects, never string concatenation. Use `.resolve()` for canonical paths.
**Warning signs:** Session file not found despite file existing on disk.

---

## Code Examples

### GET /api/cc/sessions and DELETE /api/cc/sessions/{id}
```python
# Source: server.py IDE API pattern (lines 1285-1365)
@app.get("/api/cc/sessions")
async def cc_sessions(_user: str = Depends(get_current_user)):
    sessions = []
    cc_dir = workspace / ".agent42" / "cc-sessions"
    if cc_dir.exists():
        for f in sorted(cc_dir.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True):
            async with aiofiles.open(f, "r") as fh:
                data = json.loads(await fh.read())
            sessions.append(data)
    return {"sessions": sessions}

@app.delete("/api/cc/sessions/{session_id}")
async def cc_delete_session(session_id: str, _user: str = Depends(get_current_user)):
    path = workspace / ".agent42" / "cc-sessions" / f"{session_id}.json"
    if path.exists():
        path.unlink()
    return {"status": "ok"}
```

### claude auth status - exit code approach
```python
# Source: CC CLI reference - "exits with code 0 if logged in, 1 if not"
# Gate on exit code only; do not parse JSON fields (schema may change)
proc = await asyncio.create_subprocess_exec(
    claude_bin, "auth", "status",
    stdout=asyncio.subprocess.PIPE,
    stderr=asyncio.subprocess.PIPE,
)
await asyncio.wait_for(proc.wait(), timeout=10.0)
available = (proc.returncode == 0)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CC "headless mode" | CC "Agent SDK / print mode" (`-p` flag) | ~2025 | Same `-p` flag, docs renamed - no code change needed |
| `--output-format json` (batch) | `--output-format stream-json --verbose --include-partial-messages` | Current | stream-json gives real-time events; `--verbose` required for tool output in stream |
| `--continue` (most recent) | `--resume <session_id>` (specific) | Current | `--resume` is correct for programmatic multi-turn; `--continue` is interactive-only |

**Deprecated/outdated:**
- `--headless` flag: replaced by `-p` / `--print`; all docs now use "Agent SDK / CLI mode"
- `subprocess.Popen` with blocking reads: use `asyncio.create_subprocess_exec` in async code

---

## Open Questions

1. **Exact NDJSON field path for tool output with `--verbose`**
   - What we know: `--verbose` injects tool results into the stream. Tool inputs stream via `input_json_delta`. SDK docs cover tool input streaming fully.
   - What's unclear: Do tool results appear as a `tool_result` content block type? What field carries the output text?
   - Recommendation: Verify against a live CC session before finalizing `tool_complete` parser. In Wave 0, add a fixture with a recorded live NDJSON session. This is the highest-risk unknown in Phase 1.

2. **`system/init` event - does it carry `session_id`?**
   - What we know: CC docs document `system/api_retry` subtype fields. The `result` event carries `session_id`.
   - What's unclear: Whether `system/init` also carries `session_id` for early session registration.
   - Recommendation: Parse `result` event for `session_id` (authoritative). Treat `system/init` session_id as opportunistic bonus if present.

3. **`claude auth status` JSON schema field names**
   - What we know: Exits 0 if logged in, 1 if not. JSON output by default.
   - What's unclear: Exact JSON field names (`authenticated`, `email`, `subscription_type`?).
   - Recommendation: Gate BRIDGE-06 on exit code (0/1) - do not parse JSON fields. Exit code is stable; JSON schema may change across CC versions.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pytest with pytest-asyncio |
| Config file | `pyproject.toml` - `asyncio_mode = "auto"` |
| Quick run command | `python -m pytest tests/test_cc_bridge.py -x -q` |
| Full suite command | `python -m pytest tests/ -x -q` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BRIDGE-01 | `/ws/cc-chat` endpoint defined in server.py; spawns `claude -p` subprocess args | unit (source inspection) | `pytest tests/test_cc_bridge.py::TestCCBridgeRouting::test_endpoint_defined -x` | No - Wave 0 |
| BRIDGE-02 | NDJSON `stream_event` lines map to `text_delta`/`tool_start`/`tool_complete`/`turn_complete` | unit (parser logic) | `pytest tests/test_cc_bridge.py::TestNDJSONParser -x` | No - Wave 0 |
| BRIDGE-03 | Session files written to `.agent42/cc-sessions/`; `GET /api/cc/sessions` returns list | unit (file I/O + source) | `pytest tests/test_cc_bridge.py::TestSessionRegistry -x` | No - Wave 0 |
| BRIDGE-04 | `--resume <session_id>` appears in subprocess args for turns 2+ | unit (source inspection) | `pytest tests/test_cc_bridge.py::TestMultiTurn -x` | No - Wave 0 |
| BRIDGE-05 | When `claude` binary absent, WS sends `status` event then falls back | unit (mock shutil.which) | `pytest tests/test_cc_bridge.py::TestFallback -x` | No - Wave 0 |
| BRIDGE-06 | `claude auth status` exit code 0 returns available=true; exit 1 returns false | unit (mock subprocess) | `pytest tests/test_cc_bridge.py::TestAuthStatus -x` | No - Wave 0 |

**Testing strategy note:** Given the pattern established by `tests/test_websocket_terminal.py`, BRIDGE-01 and BRIDGE-04 use source inspection (`inspect.getsource()`) without spawning a subprocess. BRIDGE-02 is a pure-function parser test against recorded NDJSON fixtures. BRIDGE-05 and BRIDGE-06 mock `shutil.which` and `asyncio.create_subprocess_exec`.

### Sampling Rate
- **Per task commit:** `python -m pytest tests/test_cc_bridge.py -x -q`
- **Per wave merge:** `python -m pytest tests/ -x -q`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_cc_bridge.py` - covers BRIDGE-01 through BRIDGE-06
- [ ] `tests/fixtures/cc_stream_sample.ndjson` - recorded live CC output for BRIDGE-02 parser tests (manual capture needed; see Open Question 1 for `--verbose` tool output)

---

## Sources

### Primary (HIGH confidence)
- `/llmstxt/code_claude_llms_txt` (Context7) - stream-json format, `--output-format`, `--verbose`, `--include-partial-messages` flags
- `/websites/code_claude` (Context7) - streaming event types, `--resume` flag, session_id in result event
- `/anthropics/claude-code` (Context7) - CLI flags and stream-json output
- `https://code.claude.com/docs/en/headless` (WebFetch 2026-03-17) - `--resume` syntax, session_id in result event, `claude auth status` exit codes
- `https://code.claude.com/docs/en/cli-reference` (WebFetch 2026-03-17) - all CLI flags verified; auth status exits 0/1
- `https://platform.claude.com/docs/en/agent-sdk/streaming-output` (WebFetch 2026-03-17) - full StreamEvent schema; `content_block_delta` text_delta/input_json_delta; `content_block_start` tool_use with id and name
- `dashboard/server.py` lines 1423-1650 (direct code read) - `/ws/terminal` asyncio subprocess pattern
- `dashboard/server.py` lines 1962-2110 (direct code read) - `/api/ide/chat` fallback handler
- `dashboard/websocket_manager.py` (direct code read) - WS lifecycle pattern

### Secondary (MEDIUM confidence)
- `dashboard/server.py` line 1467 - `shutil.which("claude")` detection pattern confirmed present
- `tests/test_websocket_terminal.py` - source-inspection test pattern confirmed workable for BRIDGE-01/BRIDGE-04

### Tertiary (LOW confidence)
- Tool output field names with `--verbose` flag - not independently verified from a live session; flagged as Open Question 1

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all libraries already installed and in use; no new dependencies
- Architecture: HIGH - implementation pattern is a direct extension of proven `/ws/terminal` code
- CC NDJSON event schema (text, tool input): HIGH - verified via Context7 + official docs WebFetch
- CC NDJSON event schema (tool output with `--verbose`): LOW - SDK docs cover tool input streaming; tool result field path not verified from live session
- Session file I/O: HIGH - follows `.agent42/` data directory convention already in use
- Auth check (exit code): HIGH - verified in CLI reference WebFetch
- Pitfalls: HIGH - derived from direct code reading or verified docs

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (CC CLI changes fast - re-verify `--verbose` tool output schema if CC version bumps)
