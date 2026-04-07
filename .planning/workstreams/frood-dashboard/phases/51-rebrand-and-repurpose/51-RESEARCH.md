# Phase 51: Rebrand & Repurpose - Research

**Researched:** 2026-04-07
**Domain:** Hand-written SPA (app.js) + FastAPI server (server.py) — string replacement, UI restructuring, new Activity Feed page, intelligence metrics
**Confidence:** HIGH — all findings are from direct source inspection of the actual files being modified

## Summary

Phase 51 is primarily a surgical code-editing phase, not a library-research phase. The work falls into five distinct workstreams: (1) branding sweep replacing "Agent42" and "Sandboxed Apps" text throughout app.js and server.py, (2) SVG asset rename from agent42-* to frood-*, (3) Settings cleanup removing dead Channels tab and renaming Orchestrator to Routing, (4) Reports page repurposing replacing harness metrics with intelligence metrics, and (5) new Activity Feed sidebar page wired to a server-side in-memory ring buffer via WebSocket.

The codebase is a 2,114-line hand-written vanilla JS SPA — no build step, no bundler, no transpiler. All edits go directly to `dashboard/frontend/dist/app.js` and `dashboard/server.py`. The WebSocket infrastructure (`ws_manager.broadcast()`) is already in place and working. The intelligence data sources (`/api/memory/stats`, `/api/effectiveness/stats`, `/api/effectiveness/learn`) already exist. The pattern for a server-side in-memory ring buffer was used previously (`_activity_feed` list, removed in Phase 50) and must be re-implemented for intelligence events.

**Primary recommendation:** Work in discrete, independently testable groups: (a) branding + assets first since it is pure text substitution, (b) Settings cleanup second since it is structural removal, (c) Reports repurpose third since it rewires existing data, (d) Activity Feed last since it adds new server + frontend code.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Reports Repurposing**
- D-01: Repurpose Overview tab as intelligence dashboard — memory recall stats (hit rate, total recalls, avg latency), learning extraction count, effectiveness scores (top models, top tools), provider routing distribution (requests per tier), token spend summary. Data from `/api/reports` + `/api/effectiveness/*` endpoints.
- D-02: Delete "Tasks & Projects" tab entirely — no data sources remain.
- D-03: Keep "System Health" tab as-is.
- D-04: Rename "Overview" tab to "Intelligence" or keep as "Overview" — Claude's discretion on naming.

**Activity Feed**
- D-05: Activity Feed gets its own sidebar page (new "Activity" entry in sidebar nav), separate from Reports.
- D-06: Events to capture: memory recalls, learning extractions, routing decisions, effectiveness scores.
- D-07: Transport via WebSocket push using existing `ws_manager.broadcast()`. Event type: `"intelligence_event"` in WS message.
- D-08: Storage: in-memory ring buffer (last 200 events). No persistence — feed starts fresh on restart. Same pattern as old `_activity_feed` list.
- D-09: Server-side: new `_record_intelligence_event(event_type, data)` function in server.py. Called from memory recall, learning, routing, and effectiveness code paths. Also expose `/api/activity` GET endpoint to load recent events on page load.
- D-10: Frontend: new `renderActivity()` function in app.js. Shows events as a reverse-chronological feed with event type badges (Memory, Routing, Learning, Effectiveness), timestamps, and expandable detail.

**Branding Sweep**
- D-11: Replace all user-visible "Agent42" text with "Frood" in app.js — page titles, descriptions, help text, settings labels, setup wizard text, error messages. Approximately 20 occurrences.
- D-12: Replace "Agent42" in server.py user-visible strings — FastAPI title goes to "Frood Dashboard". Internal logger names stay as-is.
- D-13: Rename "Sandboxed Apps" to "Agent Apps" everywhere in UI.
- D-14: Rename SVG files: `agent42-logo-light.svg` to `frood-logo-light.svg`, `agent42-avatar.svg` to `frood-avatar.svg`, `agent42-favicon.svg` to `frood-favicon.svg`. Update all references in index.html and app.js.
- D-15: Defer internal renames — localStorage keys (`agent42_token`), BroadcastChannel (`agent42_auth`), `.agent42/` paths, Python logger names.

**Settings Cleanup**
- D-16: Remove "Channels" tab entirely.
- D-17: Rename "Orchestrator" tab to "Routing" — update label, tab ID, and section content.
- D-18: Remove MAX_CONCURRENT_AGENTS setting from Routing tab.
- D-19: Update Orchestrator description text.
- D-20: Remove `loadChannels()` call from `loadAll()` Promise.all.

**Setup Wizard**
- D-21: Update setup wizard text to reflect Frood-as-service identity. Remove "A mostly harmless orchestrator" tagline (not present in current code — actual step 1 tagline is "The answer to life, the universe, and all your tasks."). New copy should emphasize intelligence layer.

**README**
- D-22: Update README.md to reflect Frood Dashboard as intelligence layer admin panel. Remove orchestrator/harness language.

### Claude's Discretion
- Exact wording for setup wizard steps
- Reports "Overview" vs "Intelligence" tab naming
- Activity Feed visual design (card style, badges, spacing)
- Whether to add Activity sidebar entry before or after Reports
- README structure and content depth

### Deferred Ideas (OUT OF SCOPE)
- Internal localStorage rename (`agent42_token` to `frood_token`)
- Internal `.agent42/` path rename
- Python package rename (`agent42` to `frood` in Python imports)
- Python logger name rename (`logging.getLogger("agent42.server")` etc.)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BRAND-01 | Rename "Sandboxed Apps" to "Agent Apps" throughout UI and API | Found in app.js lines 2052, 2071; page title map at line 2071; help text at line 1103 |
| BRAND-02 | Update sidebar navigation to show only kept features (add Activity) | Sidebar at app.js lines 2052-2057; renderers object at 2082-2088 |
| BRAND-03 | Ensure all remaining pages use Frood branding (no "Agent42" remnants) | 20+ occurrences found in app.js; server.py title at line 273 |
| BRAND-04 | Update setup wizard to reflect Frood-as-service identity | renderSetupWizard() at app.js lines 320-421 |
| RPT-01 | Repurpose Overview tab — replace harness metrics with intelligence layer metrics | _renderReportsOverview() at app.js lines 1248-1306; /api/memory/stats and /api/effectiveness/stats already exist |
| RPT-02 | Remove "Tasks & Projects" tab entirely | Tab defined at line 1212; _renderReportsTasks() at lines 1350-1441 |
| RPT-03 | Keep "System Health" tab as-is | _renderReportsHealth() at lines 1309-1348 — already good content |
| RPT-04 | Add memory/effectiveness data to Overview | Data available from /api/memory/stats and /api/effectiveness/stats endpoints |
| FEED-01 | Repurpose Activity Feed for memory/routing/effectiveness event log | New page — no existing Activity page exists post-Phase 50 |
| FEED-02 | Log memory recall hits, learning extractions, routing decisions, effectiveness scores | Recording hooks: /api/memory/search (line 850), /api/effectiveness/record (line 1240), /api/effectiveness/learn (line 1362) |
| FEED-03 | Expose as intelligence layer observability surface | /api/activity endpoint + WS push via ws_manager.broadcast() |
| SET-01 | Remove "Channels" tab | Tab at app.js line 1449; loadChannels() at lines 551-554; referenced in loadAll() line 2007 |
| SET-02 | Rename "Orchestrator" tab to "Routing" | Tab at app.js line 1451; panel at lines 1658-1682 |
| SET-03 | Remove MAX_CONCURRENT_AGENTS setting | In orchestrator panel at line 1662 |
| SET-04 | Remove loadChannels() from loadAll() | Promise.all at line 2007 |
| CLEAN-05 | Update README to reflect Frood Dashboard as intelligence layer admin panel | README.md has extensive harness/team/orchestrator content to clean |
</phase_requirements>

---

## Standard Stack

### Core (No New Dependencies)
| Component | Current State | Purpose in Phase 51 |
|-----------|---------------|---------------------|
| `dashboard/frontend/dist/app.js` | 2,114 lines, hand-written vanilla JS | All frontend changes — text, structure, new Activity page |
| `dashboard/server.py` | ~2,499 lines, FastAPI | New activity endpoint, intelligence event recording |
| `dashboard/websocket_manager.py` | 65 lines | Already has `broadcast()` — just add new event type |
| `dashboard/frontend/dist/index.html` | 42 lines | Update favicon reference only |
| `dashboard/frontend/dist/style.css` | Existing | May need Activity Feed card styles |
| `dashboard/frontend/dist/assets/` | 4 SVG files | Rename 3 files |
| `README.md` | ~1,000+ lines | Full rewrite of harness sections |

**Installation:** No new packages required. This phase is pure code editing.

### Supporting Data Sources (Already Exist)
| Endpoint | Returns | Used By |
|----------|---------|---------|
| `GET /api/memory/stats` | `{recall_count, learn_count, error_count, avg_latency_ms, period_start}` | Intelligence Overview tab |
| `GET /api/effectiveness/stats` | `{stats: [...]}` aggregated tool effectiveness | Intelligence Overview tab |
| `POST /api/effectiveness/record` | Records tool invocation | Hook point for intelligence events |
| `POST /api/effectiveness/learn` | Records learning extraction | Hook point for intelligence events |
| `POST /api/memory/search` | Performs memory recall | Hook point for intelligence events |
| `GET /api/reports` | Tools, skills, token usage, costs | Overview tab (keep token/cost sections) |

---

## Architecture Patterns

### Existing Render Function Pattern
The SPA follows a consistent pattern — all render functions are named `render{PageName}()` and write to `document.getElementById("page-content")`. New `renderActivity()` MUST follow this pattern exactly.

```javascript
// Pattern from renderTools() / renderSkills() / renderReports() / renderApps()
function renderActivity() {
  const el = document.getElementById("page-content");
  if (!el || state.page !== "activity") return;
  // Build HTML string and assign to el.innerHTML
  // (existing dashboard uses innerHTML throughout — internal admin panel with no user-supplied content)
}
```

### Sidebar + Renderers Registration Pattern
The sidebar nav and renderers object are co-located at lines ~2046-2090. Adding "Activity" requires two parallel changes:

1. A new anchor tag in the sidebar nav (after the Reports link, around line 2055)
2. A new key in the topbar title map at line 2071: `activity: "Activity"`
3. A new key in the renderers object at line ~2083: `activity: renderActivity`

### Settings Tabs Array Pattern
Settings tabs are a simple array at lines 1447-1454. Removing "channels" and renaming "orchestrator":

- Remove `{ id: "channels", label: "Channels" }` entirely
- Change `{ id: "orchestrator", label: "Orchestrator" }` to `{ id: "routing", label: "Routing" }`
- In the `panels` object (starts around line 1479), rename the `orchestrator:` key to `routing:` and update the h3 title and description text inside it
- Remove the `MAX_CONCURRENT_AGENTS` settingReadonly call from inside the routing/orchestrator panel

**CAUTION:** The tab ID change (`orchestrator` to `routing`) must also update the `panels` object key. These are separate locations in the file.

### Reports Tabs Array Pattern
The tabs array is at lines 1209-1213. Remove the tasks tab entry. Keep the id `"overview"` for the overview tab (avoids touching `state.reportsTab` default). Change only the label to "Intelligence" if that naming is chosen.

Remove the tab entry: `{ id: "tasks", label: "Tasks & Projects" }`

Remove the corresponding branch in the tab-switch block at line 1237: `else if (tab === "tasks") body = _renderReportsTasks(d);`

Delete the entire `_renderReportsTasks()` function (lines 1350-1441).

### Server-Side Activity Ring Buffer Pattern
Re-implement the pattern from the removed `_activity_feed` list. Place inside `create_app()` after `_memory_stats`, defined as a closure variable (not module-level, since `ws_manager` is a parameter to `create_app()`):

```python
# In-memory intelligence event ring buffer — inside create_app() closure
_intelligence_events: list[dict] = []
_INTELLIGENCE_MAX = 200

async def _record_intelligence_event(event_type: str, data: dict) -> None:
    """Append to ring buffer and broadcast via WebSocket."""
    import time as _ti
    event = {"type": event_type, "data": data, "ts": _ti.time()}
    _intelligence_events.append(event)
    if len(_intelligence_events) > _INTELLIGENCE_MAX:
        _intelligence_events.pop(0)
    if ws_manager:
        await ws_manager.broadcast("intelligence_event", event)
```

### WebSocket Message Handler Extension
The frontend `handleWSMessage()` at app.js line 471 currently only handles `app_status`. Add `intelligence_event` as a new branch:

- Prepend incoming event to `state.activityEvents` (initialize as `[]` in state at top of file)
- Trim to 200 events
- If `state.page === "activity"`, call `renderActivity()`

### Anti-Patterns to Avoid
- **Changing localStorage key names:** `agent42_token` and `agent42_auth` BroadcastChannel are explicitly deferred — do not touch them.
- **Changing Python logger names:** `agent42.server`, `agent42.websocket`, `memory.recall` — these are internal infrastructure, not user-visible.
- **Changing `.agent42/` path strings:** Directory paths are read from Settings dataclass and affect all stored data — deferred.
- **Touching the orchestrator tab ID without updating both locations:** The tab ID appears in both the tabs array AND the panels object. A rename requires updating both: tabs array entry, panels object key. Changing only one causes a blank settings panel.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Real-time feed push | Custom polling | `ws_manager.broadcast()` already in websocket_manager.py | Already wired to all connected clients |
| Intelligence data collection | New counters | `/api/memory/stats` + `/api/effectiveness/stats` | Stats counters maintained by existing endpoints |
| Activity state on page load | Complex hydration | `/api/activity` GET endpoint returning `_intelligence_events` list | Simple JSON array, same pattern as all other data endpoints |
| SVG asset serving | New route | FastAPI StaticFiles already mounts `/assets/` | Rename the files, update references — server picks them up automatically |

---

## File-by-File Change Map

### `dashboard/frontend/dist/app.js` (2,114 lines)

**Branding changes (D-11, D-12, D-13, D-14):**

| Location | Change |
|----------|--------|
| Line 1 (comment) | "Agent42 Dashboard" to "Frood Dashboard" |
| Line 71 | `agent42-avatar.svg` to `frood-avatar.svg` |
| Line 335 | `agent42-logo-light.svg` to `frood-logo-light.svg` |
| Line 624 | "Restart Agent42" to "Restart Frood" |
| Line 870 | "Internal (Agent42 system tool)" to "Internal (Frood system tool)" |
| Line 1103 | "What do sandboxed apps get from Agent42?" to "What do Agent Apps get from Frood?" |
| Line 1280 | "Model routing is handled by Agent42's tiered routing." to Frood equivalent |
| Line 1320 | "Agent42 operates as an MCP server..." to "Frood operates as..." |
| Line 1486 | "Agent42 routes tasks..." to "Frood routes LLM requests..." |
| Lines 1660, 1672, 1726, 1729, 1735, 1739-1743, 1775 | "Agent42" to "Frood" in storage/memory descriptions |
| Lines 2023, 2050 | `agent42-logo-light.svg` to `frood-logo-light.svg` |
| Line 2052 | "Sandboxed Apps" to "Agent Apps" |

**Settings cleanup (D-16, D-17, D-18, D-19, D-20):**

| Location | Change |
|----------|--------|
| Lines 1447-1454 | Remove "channels" tab entry; rename "orchestrator" to "routing" |
| Lines 1589-1612 | Delete channels panel function body |
| Lines 1658-1682 | Rename panel key to "routing"; update h3 to "Routing"; update description; remove MAX_CONCURRENT_AGENTS line |
| Line 2007 | Remove `loadChannels()` from Promise.all |

**Reports repurpose (D-02, D-04, RPT-01, RPT-04):**

| Location | Change |
|----------|--------|
| Lines 1209-1213 | Remove "tasks" tab entry; rename overview label to "Intelligence" |
| Line 1237 | Remove `else if (tab === "tasks")` branch |
| Lines 1248-1306 | Rewrite `_renderReportsOverview()` with intelligence metrics |
| Lines 1350-1441 | Delete `_renderReportsTasks()` function entirely |

**Activity Feed additions (D-05, D-07, D-09, D-10):**

| Location | Change |
|----------|--------|
| State object (line ~10) | Add `activityEvents: []` |
| Line 471-479 (`handleWSMessage`) | Add `intelligence_event` branch |
| After `loadReports()` | Add `loadActivity()` function |
| Line 2007 (`loadAll`) | Add `loadActivity()` to Promise.all |
| After `renderSettings()` | Add `renderActivity()` function |
| Line ~2055 (sidebar nav) | Add Activity nav link |
| Line ~2071 (title map) | Add `activity: "Activity"` |
| Line ~2088 (renderers) | Add `activity: renderActivity` |

**Setup wizard (D-21):**

| Location | Change |
|----------|--------|
| Lines 333-338 (step 1) | Update subtitle and description |
| Lines 411-418 (step 4) | Update "Loading Mission Control..." text |

**Total "Agent42" occurrences confirmed by grep:** 20 in app.js plus favicon reference in index.html.

### `dashboard/server.py` (~2,499 lines)

| Location | Change |
|----------|--------|
| Line 273 | `title="Agent42 Dashboard"` to `title="Frood Dashboard"` |
| Line 309 | "Agent42 dashboard UI is disabled" to "Frood dashboard UI is disabled" |
| After `_memory_stats` dict | Add `_intelligence_events` list and `_record_intelligence_event()` function |
| Line ~923 (after recall_count++) | Await `_record_intelligence_event("memory_recall", {...})` |
| Line ~1257 (after effectiveness.record) | Await `_record_intelligence_event("effectiveness", {...})` |
| Line ~1410 (after memory_store.log_event_semantic) | Await `_record_intelligence_event("learning", {...})` |
| Near `/api/memory/stats` | Add new `GET /api/activity` endpoint |

**Internal logger names at lines 47, 12, 321 — do NOT change.** Only user-visible strings change.

### `dashboard/frontend/dist/index.html` (42 lines)

| Line | Change |
|------|--------|
| Line 16 | `agent42-favicon.svg` to `frood-favicon.svg` |

### `dashboard/frontend/dist/assets/` (files)

| Old Name | New Name |
|----------|----------|
| `agent42-logo-light.svg` | `frood-logo-light.svg` |
| `agent42-avatar.svg` | `frood-avatar.svg` |
| `agent42-favicon.svg` | `frood-favicon.svg` |

Note: `agent42-logo.svg` (no `-light` suffix) exists in assets. README.md references it. Rename to `frood-logo.svg` and update the README reference as part of CLEAN-05.

### `README.md`

Extensive rewrite required. Current README describes: Teams, Mission Control, Agent Profiles, Chat, multi-node orchestration. Post-rewrite: Frood as intelligence layer, MCP tools, memory system, provider routing, Agent Apps, Settings/Reports admin panel. Remove references to: "Mission Control", "Agent Teams", "Agents page", "orchestrator", "harness", "Workspace/IDE".

---

## Common Pitfalls

### Pitfall 1: Orchestrator Tab ID Disconnect
**What goes wrong:** Renaming the tab entry `{ id: "orchestrator", label: "Orchestrator" }` to `{ id: "routing", label: "Routing" }` without updating the `panels` object key from `orchestrator:` to `routing:`.
**Why it happens:** The tabs array and panels object are co-located but separately keyed — tab `id` must match panels key exactly.
**How to avoid:** When renaming the tab, find-and-replace `orchestrator:` (with trailing colon) in the panels section AND find any `state.settingsTab === "orchestrator"` guards.
**Warning signs:** Settings page shows blank content when clicking Routing tab.

### Pitfall 2: `_record_intelligence_event` Is Async but Called from Sync Context
**What goes wrong:** If `_record_intelligence_event` is called without `await`, it returns a coroutine that is never executed, and events never appear in the feed.
**Why it happens:** The existing memory stats tracking is synchronous. The new event recording adds async work.
**How to avoid:** All call sites (`memory_search`, `record_effectiveness`, `record_learning`) are already `async def` functions, so `await _record_intelligence_event(...)` works directly. Do not use `asyncio.create_task()` unless the call site is synchronous (it is not).
**Warning signs:** Events never appear in the feed; Python may emit a coroutine warning.

### Pitfall 3: `_record_intelligence_event` Must Be Defined Inside `create_app()` Scope
**What goes wrong:** If defined as a module-level function, it cannot access `ws_manager` (a parameter to `create_app()`) or `_intelligence_events` (a local closure variable).
**Why it happens:** The existing `create_app()` pattern wraps everything in a closure — `ws_manager`, `_memory_stats`, and all route handlers are inside the closure.
**How to avoid:** Define both `_intelligence_events` and `_record_intelligence_event` INSIDE `create_app()`, same as `_build_reports()` and `_memory_stats`. This matches the established pattern.

### Pitfall 4: `test_settings_ui.py` Checks Paperclip TSX, Not app.js
**What goes wrong:** The test file checks both standalone app.js AND Paperclip's SettingsPage.tsx. The "orchestrator" tab is in Paperclip TSX — the app.js rename to "routing" does NOT affect Paperclip. If tests for Paperclip TSX are modified to expect "routing", they will fail because Paperclip has not changed.
**Why it happens:** The test file covers two different codebases.
**How to avoid:** In `tests/test_settings_ui.py`, the `TestPaperclipSettingsPage` class checks `_SETTINGS_TSX` — do NOT change those assertions. Only app.js assertions in `TestStandaloneMemoryTab` (if any reference orchestrator) need updating.
**Warning signs:** `test_six_tabs_defined` or `test_tab_labels` failure in Paperclip test class.

### Pitfall 5: Activity Page Not in `loadAll()` Breaks Cold Load
**What goes wrong:** If `loadActivity()` is defined but not added to the `loadAll()` Promise.all, the Activity page shows empty on first load (before any WS events arrive).
**Why it happens:** All data pages require an initial load call in `loadAll()`.
**How to avoid:** Add `loadActivity()` to the `loadAll()` Promise.all alongside other loaders. Initialize `state.activityEvents = []` in the state object at the top of app.js.

### Pitfall 6: SVG File Rename Misses `agent42-logo.svg` (Non-light)
**What goes wrong:** `README.md` references `dashboard/frontend/dist/assets/agent42-logo.svg` (no `-light` suffix). D-14 lists three specific files for renaming; this fourth file is not explicitly listed.
**Why it happens:** The context decision list is not exhaustive for the non-light logo.
**How to avoid:** Check all references with `grep -r "agent42-logo.svg"` before final commit. Rename to `frood-logo.svg` and update README as part of CLEAN-05.
**Warning signs:** Broken image in README.md after update.

### Pitfall 7: Reports Overview Needs Two API Calls, Not One
**What goes wrong:** The new intelligence overview needs data from `/api/memory/stats` and `/api/effectiveness/stats` in addition to `/api/reports`, but `loadReports()` currently only calls `/api/reports`. If the new data is not loaded, the intelligence cards show zeros or dashes.
**Why it happens:** The existing `loadReports()` only fetches one endpoint and stores it in `state.reportsData`.
**How to avoid:** Either extend `loadReports()` to also fetch memory stats and effectiveness stats and merge into `state.reportsData`, or load them into separate state keys (`state.memoryStats`, `state.effectivenessStats`) in `loadAll()`. The merged approach is simpler and keeps the renderer self-contained.

### Pitfall 8: Setup Wizard Step 4 Text References "Mission Control"
**What goes wrong:** Step 4 of the setup wizard (completion screen) currently says "Loading Mission Control...". This is harness language that must change.
**Why it happens:** The setup wizard was written for the harness product.
**How to avoid:** Update the step 4 completion text at line ~416 to reference the intelligence layer admin panel, not Mission Control.

---

## Code Examples

Verified patterns from direct inspection of the codebase.

### Server-Side Activity Ring Buffer (Inside `create_app()`)

```python
# Source: Direct inspection of server.py create_app() closure pattern
# Place after _memory_stats dict, inside create_app():

_intelligence_events: list[dict] = []
_INTELLIGENCE_MAX = 200

async def _record_intelligence_event(event_type: str, data: dict) -> None:
    """Append intelligence event to ring buffer and broadcast via WebSocket."""
    import time as _ti
    event = {"type": event_type, "data": data, "ts": _ti.time()}
    _intelligence_events.append(event)
    if len(_intelligence_events) > _INTELLIGENCE_MAX:
        _intelligence_events.pop(0)
    if ws_manager:
        await ws_manager.broadcast("intelligence_event", event)
```

### /api/activity Endpoint

```python
# Source: Pattern from /api/memory/stats at server.py line 938
@app.get("/api/activity")
async def get_activity(_: AuthContext = Depends(require_admin)):
    """Return recent intelligence events (last 200, newest first)."""
    return {"events": list(reversed(_intelligence_events))}
```

### `_record_intelligence_event` Call Site — Memory Search

```python
# Source: server.py memory_search() at line 923
# After: _memory_stats["recall_count"] += 1
await _record_intelligence_event("memory_recall", {
    "query_keywords": keyword_count,
    "results": len(results),
    "method": search_method,
    "latency_ms": round(_elapsed, 1),
})
```

### `_record_intelligence_event` Call Site — Learning Extraction

```python
# Source: server.py record_learning() at line 1362
# After: await memory_store.log_event_semantic(...)
await _record_intelligence_event("learning", {
    "task_type": task_type,
    "outcome": outcome,
    "summary": summary[:100],
})
```

### `_record_intelligence_event` Call Site — Effectiveness Record

```python
# Source: server.py record_effectiveness() at line 1240
# After: await effectiveness_store.record(...)
await _record_intelligence_event("effectiveness", {
    "tool_name": data.get("tool_name", "unknown"),
    "success": bool(data.get("success", True)),
    "duration_ms": float(data.get("duration_ms", 0)),
})
```

### WebSocket Message Handler Extension

```javascript
// Source: handleWSMessage() at app.js line 471
// Add after the app_status branch:
} else if (msg.type === "intelligence_event") {
  state.activityEvents = [msg.data, ...(state.activityEvents || [])].slice(0, 200);
  if (state.page === "activity") renderActivity();
}
```

### loadActivity() Function

```javascript
// Source: Pattern from loadReports() at app.js line 1986
async function loadActivity() {
  try {
    const data = await api("/activity");
    state.activityEvents = (data && data.events) || [];
  } catch { state.activityEvents = []; }
}
```

### Settings Tab Rename (Before/After)

```javascript
// BEFORE (lines 1447-1454):
const tabs = [
  { id: "providers", label: "API Keys" },
  { id: "channels", label: "Channels" },      // remove
  { id: "security", label: "Security" },
  { id: "orchestrator", label: "Orchestrator" }, // rename
  { id: "storage", label: "Storage & Paths" },
  { id: "memory", label: "Memory & Learning" },
];

// AFTER:
const tabs = [
  { id: "providers", label: "API Keys" },
  { id: "security", label: "Security" },
  { id: "routing", label: "Routing" },
  { id: "storage", label: "Storage & Paths" },
  { id: "memory", label: "Memory & Learning" },
];
```

---

## Runtime State Inventory

This phase involves string renaming (UI labels only — no storage keys or internal IDs change).

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | No stored keys change — `agent42_token`, `.agent42/` paths, Qdrant collection names are all deferred (D-15) | None |
| Live service config | No service config changes | None |
| OS-registered state | None — verified by scope of changes | None |
| Secrets/env vars | No env var names change | None |
| Build artifacts | 3 SVG files to rename in filesystem; tests/test_settings_ui.py checks Paperclip TSX (not affected by app.js rename) | File rename only |

All internal identifiers (localStorage, BroadcastChannel, Python loggers, directory paths) are explicitly deferred per D-15. The only renaming is of user-visible UI strings and SVG filenames.

---

## Validation Architecture

nyquist_validation is enabled (config.json `workflow.nyquist_validation: true`).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest |
| Config file | none (default discovery) |
| Quick run command | `python -m pytest tests/ -x -q` |
| Full suite command | `python -m pytest tests/ -v` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BRAND-01 | "Agent Apps" in app.js, "Sandboxed Apps" absent | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_agent_apps_renamed -x` | ❌ Wave 0 |
| BRAND-02 | Sidebar has Activity link; no Channels link in app.js | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_sidebar_nav -x` | ❌ Wave 0 |
| BRAND-03 | No user-visible "Agent42" text in app.js (excluding internal/deferred strings) | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_no_agent42_visible -x` | ❌ Wave 0 |
| BRAND-04 | Setup wizard step 1 text updated; "Mission Control" absent | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_setup_wizard_copy -x` | ❌ Wave 0 |
| RPT-01 | "Tasks & Projects" NOT in app.js reports tabs | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_reports_tabs -x` | ❌ Wave 0 |
| RPT-02 | `_renderReportsTasks` NOT in app.js | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_tasks_tab_removed -x` | ❌ Wave 0 |
| RPT-03 | System Health tab still present in reports tabs | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_health_tab_present -x` | ❌ Wave 0 |
| RPT-04 | `memory_recall` and `effectiveness` data referenced in reports overview | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_intelligence_overview -x` | ❌ Wave 0 |
| FEED-01 | `renderActivity` function exists in app.js | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_activity_renderer -x` | ❌ Wave 0 |
| FEED-02 | intelligence_event type badges in app.js | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_intelligence_event_types -x` | ❌ Wave 0 |
| FEED-03 | `/api/activity` endpoint string in server.py | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_activity_endpoint -x` | ❌ Wave 0 |
| SET-01 | "channels" tab entry NOT in settings tabs array | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_channels_tab_removed -x` | ❌ Wave 0 |
| SET-02 | "routing" tab present; "Orchestrator" label absent from tabs | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_routing_tab -x` | ❌ Wave 0 |
| SET-03 | "MAX_CONCURRENT_AGENTS" absent from routing panel | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_max_concurrent_removed -x` | ❌ Wave 0 |
| SET-04 | `loadChannels` absent from `loadAll()` body | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_load_channels_removed -x` | ❌ Wave 0 |
| CLEAN-05 | "Mission Control" and "Agent Teams" absent from README.md | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_readme_updated -x` | ❌ Wave 0 |

**Existing tests that MUST still pass:**
- `tests/test_settings_ui.py::TestStandaloneMemoryTab` — tests memory tab, not affected
- `tests/test_settings_ui.py::TestPaperclipSettingsPage` — tests Paperclip TSX, not app.js, not affected by tab renames in app.js
- `tests/test_channels.py` — tests channel Python classes (not the settings tab UI), not affected
- Full suite: `python -m pytest tests/ -x -q`

### Sampling Rate
- **Per task commit:** `python -m pytest tests/test_rebrand_phase51.py -x -q`
- **Per wave merge:** `python -m pytest tests/ -x -q`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_rebrand_phase51.py` — covers all BRAND/RPT/FEED/SET/CLEAN requirements above
  - Pattern: same as `tests/test_settings_ui.py` — read app.js and server.py at module level, assert string presence/absence
  - No network calls needed — all assertions are string grep against file content

---

## Environment Availability

Step 2.6 findings:

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3.11+ | pytest + server | ✓ | 3.11+ (project requirement) | — |
| pytest | Test suite | ✓ | Installed (existing tests run) | — |
| No new packages needed | All phase work | N/A | N/A | — |

No missing dependencies. This phase requires only file edits and renames.

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `_activity_feed` list (removed Phase 50) | New `_intelligence_events` ring buffer | Same pattern — re-implement inside `create_app()` |
| "Sandboxed Apps" label | "Agent Apps" — matches the intelligence layer identity | Pure text change |
| `GET /api/channels` (404 after Phase 50) | Remove from `loadAll()` — eliminates console error | Cleanup |
| harness metrics in Reports Overview | Intelligence metrics (memory, effectiveness, routing) | Data sources already exist in API |

---

## Open Questions

1. **Routing decisions as intelligence events**
   - What we know: D-06 lists "routing decisions (model chosen, tier, reason)" as events to capture. The LLM proxy route in server.py at ~line 955 is the routing entry point.
   - What's unclear: The exact location of provider selection logic. The comment at line 1646 says "Use Agent42's own provider routing" — the actual routing call may be in `core/` modules rather than inside a server.py function that is easy to hook.
   - Recommendation: During implementation, search for `_select_provider`, `get_provider`, or the routing function in server.py. If routing is in `core/`, pass `_record_intelligence_event` as a callback or record the event at the LLM proxy response return site (where model and provider are known). Do NOT block the response — use `asyncio.create_task()` if calling from a context where latency matters.

2. **`state.settingsTab` default value**
   - What we know: The state object at line 10 shows `settingsTab` is initialized (not visible in grep output for line 10).
   - What's unclear: Whether it defaults to `"orchestrator"` explicitly.
   - Recommendation: Grep `settingsTab` in app.js before editing. If it defaults to `"orchestrator"`, change to `"routing"`. If it defaults to something else (likely `"providers"`), no action needed.

3. **`agent42-logo.svg` (non-light) rename**
   - What we know: The file exists in `dashboard/frontend/dist/assets/`. README.md references it directly. Not referenced in index.html or app.js.
   - What's unclear: Whether `manifest.json` also references it.
   - Recommendation: Run `grep -r "agent42-logo.svg" .` before finalizing. Rename to `frood-logo.svg` as part of CLEAN-05 README update.

---

## Project Constraints (from CLAUDE.md)

- **All I/O is async** — `_record_intelligence_event` must be `async def`, called with `await`.
- **Frozen config** — Do not add new Settings fields. Intelligence event recording uses no env config.
- **Graceful degradation** — `_record_intelligence_event` must handle `ws_manager is None` silently (already in pattern: `if ws_manager:`).
- **Sandbox always on** — Not relevant to this phase (no file system operations added).
- **New pitfalls** — Add any discovered non-obvious issues to `.claude/reference/pitfalls-archive.md`.
- **No blocking I/O** — `_record_intelligence_event` uses `ws_manager.broadcast()` which is already async.
- **Test requirement** — New test file `tests/test_rebrand_phase51.py` required per CLAUDE.md: "New modules need tests/test_*.py."

---

## Sources

### Primary (HIGH confidence)
- Direct inspection of `dashboard/frontend/dist/app.js` (2,114 lines) — all line numbers verified by grep and Read
- Direct inspection of `dashboard/server.py` (2,499 lines) — all endpoint locations verified
- Direct inspection of `dashboard/websocket_manager.py` — broadcast API confirmed at line 51
- Direct inspection of `dashboard/frontend/dist/index.html` — favicon reference confirmed at line 16
- Direct inspection of `tests/test_settings_ui.py` — existing test assertions confirmed
- Direct inspection of `.planning/workstreams/frood-dashboard/phases/51-rebrand-and-repurpose/51-CONTEXT.md`
- Direct inspection of `.planning/workstreams/frood-dashboard/REQUIREMENTS.md`

### Secondary (MEDIUM confidence)
- None required — all findings are from first-party source inspection

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Branding sweep: HIGH — all occurrences located by grep, line numbers verified
- Settings cleanup: HIGH — tab arrays and panel keys directly inspected
- Reports repurpose: HIGH — existing data endpoints confirmed available; data structures known
- Activity Feed (frontend): HIGH — WS handler pattern and render function pattern documented from existing code
- Activity Feed (server, ring buffer): HIGH — exact same pattern as removed `_activity_feed` list
- Activity Feed (routing event hook): MEDIUM — routing hook location inside `create_app()` requires implementation-time investigation
- README rewrite: MEDIUM — scope is clear but content is Claude's discretion

**Research date:** 2026-04-07
**Valid until:** 2026-05-07 (stable codebase, no external dependencies)
