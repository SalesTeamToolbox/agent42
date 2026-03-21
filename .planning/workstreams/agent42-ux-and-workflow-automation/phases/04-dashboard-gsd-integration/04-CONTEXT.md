# Phase 4: Dashboard GSD Integration - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

The Agent42 dashboard sidebar footer shows the active GSD workstream name and current phase number in real-time, updated via the existing WebSocket heartbeat. No roadmap progress view, no workstream switcher, no GSD-specific navigation (those are v2 requirements GSD-05/GSD-06).

</domain>

<decisions>
## Implementation Decisions

### Placement
- **D-01:** Display in the sidebar footer — above the WS dot/Connected label. Visible on every page without navigation. Analogous to VS Code's git branch indicator in the status bar.
- **D-02:** The GSD block sits between the `<nav class="sidebar-nav">` and the existing `<div class="sidebar-footer">` content, OR is inserted at the top of `sidebar-footer`.

### Content format
- **D-03:** Show: workstream short name (truncated) + "Phase N" on two lines. E.g.:
  ```
  ▶ agent42-ux
    Phase 4
  ```
- **D-04:** Truncate workstream name to fit sidebar width — strip the longest common prefix pattern (e.g., "agent42-" prefix) or truncate at ~16 chars with ellipsis.
- **D-05:** No phase name shown — just the number. Keeps it compact.

### Empty state
- **D-06:** When no active workstream exists (`.planning/active-workstream` absent or empty), the GSD block is hidden entirely — no placeholder text, no reserved space.

### Server-side state reading
- **D-07:** The `HeartbeatService.get_health()` in `core/heartbeat.py` reads `.planning/active-workstream` (relative to project root / cwd) on every heartbeat tick. File read is sync (tiny file, negligible I/O). No file watcher, no separate polling.
- **D-08:** If workstream name is found, also read `.planning/workstreams/{name}/STATE.md` to extract current phase number. Parse the "Current Position" or equivalent field.
- **D-09:** Add two nullable fields to `SystemHealth` and `to_dict()`: `gsd_workstream: str | None = None` and `gsd_phase: str | None = None`. Null when no active workstream.
- **D-10:** Frontend receives these via the existing `system_health` WebSocket event — no new event type needed.

### Frontend update
- **D-11:** The sidebar render function in `app.js` reads `state.status.gsd_workstream` and `state.status.gsd_phase`. If both are non-null, inject the GSD block HTML into the sidebar footer. If null, omit.
- **D-12:** State is already updated on every `system_health` WS message (line 506-508 in app.js) — no extra subscription needed.

### Claude's Discretion
- Exact CSS styling of the GSD sidebar block (color, font-size, icon choice — match existing sidebar-footer style)
- Exact regex/parsing logic for STATE.md phase extraction
- Whether to use `▶` or a GSD-specific icon prefix
- Error handling if STATE.md is missing or malformed (silently omit, don't crash heartbeat)

</decisions>

<specifics>
## Specific Ideas

- Should feel like the VS Code git branch indicator — ambient, always there, never intrusive.
- When workstream name is long like "agent42-ux-and-workflow-automation", strip redundant prefix to show something readable like "ux-automation" or "agent42-ux".

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Heartbeat pipeline
- `core/heartbeat.py` — `SystemHealth` dataclass (fields ~line 54), `to_dict()` method, `get_health()` where new file reads go
- `agent42.py` lines 1219-1221 — `_on_heartbeat()` broadcasts health to WebSocket

### Frontend sidebar
- `dashboard/frontend/dist/app.js` lines 6910-6980 — full sidebar HTML including `sidebar-footer` block (WS dot, Connected label, Logout, DON'T PANIC watermark)
- `dashboard/frontend/dist/app.js` lines 506-508 — `system_health` WS message handler that updates `state.status`

### GSD state files
- `.planning/active-workstream` — contains current workstream slug (e.g., `agent42-ux-and-workflow-automation`), or absent if no active workstream
- `.planning/workstreams/{name}/STATE.md` — contains current phase number in "Current Position" or similar field

### Requirements
- `.planning/workstreams/agent42-ux-and-workflow-automation/REQUIREMENTS.md` — DASH-01, DASH-02

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `state.status` object in app.js — already holds all SystemHealth fields from WS heartbeat; `gsd_workstream`/`gsd_phase` just need to be added server-side and read client-side
- `sidebar-footer` div — already styled and positioned; GSD block slots in naturally above WS dot

### Established Patterns
- Frontend is pure HTML/JS/CSS — no build step. Edits go directly to `dashboard/frontend/dist/app.js`
- All SystemHealth fields flow through the same pipeline: `get_health()` → `to_dict()` → `broadcast("system_health", ...)` → `state.status` → `renderApp()`
- File I/O in `get_health()` is already synchronous (CPU load, memory reads) — adding two small file reads is consistent

### Integration Points
- `core/heartbeat.py` — add 2 fields to `SystemHealth`, read files in `get_health()`
- `dashboard/frontend/dist/app.js` — add GSD block in sidebar render (lines ~6940-6960), read from `state.status`
- No new routes, no new WS events, no new dependencies

</code_context>

<deferred>
## Deferred Ideas

- GSD roadmap progress view in dashboard (GSD-05 — v2 requirement)
- Workstream switcher in sidebar (GSD-06 — v2 requirement)
- Clicking the GSD indicator to navigate to a GSD status page

</deferred>

---

*Phase: 04-dashboard-gsd-integration*
*Context gathered: 2026-03-21 via discuss-phase*
