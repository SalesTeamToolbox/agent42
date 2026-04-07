# Phase 51: Rebrand & Repurpose - Context

**Gathered:** 2026-04-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Polish the Frood Dashboard identity — rename "Sandboxed Apps" to "Agent Apps", replace all user-visible "Agent42" text with "Frood", repurpose the Reports page for intelligence layer metrics, add an Activity Feed sidebar page for real-time observability, and clean up Settings (remove dead tabs, rename Orchestrator to Routing).

**Frood is the towel, not the spaceship.** The dashboard is an admin/observability panel for the intelligence layer.

</domain>

<decisions>
## Implementation Decisions

### Reports Repurposing
- **D-01:** Repurpose Overview tab as an intelligence dashboard — memory recall stats (hit rate, total recalls, avg latency), learning extraction count, effectiveness scores (top models, top tools), provider routing distribution (requests per tier), token spend summary. Data comes from existing `/api/reports` + `/api/effectiveness/*` endpoints.
- **D-02:** Delete "Tasks & Projects" tab entirely — no data sources remain.
- **D-03:** Keep "System Health" tab as-is — MCP transport, tools enabled, skills loaded, token tracking, tool usage table. This is already intelligence-layer content.
- **D-04:** Rename "Overview" tab to "Intelligence" or keep as "Overview" — Claude's discretion on naming.

### Activity Feed
- **D-05:** Activity Feed gets its own sidebar page (new "Activity" entry in sidebar nav), separate from Reports.
- **D-06:** Events to capture: memory recalls (query, hit count, latency), learning extractions (what was learned, confidence), routing decisions (model chosen, tier, reason), effectiveness scores (tool/model outcomes). These are the 3 pillars of intelligence observability.
- **D-07:** Transport via WebSocket push using existing `ws_manager.broadcast()`. Frontend auto-updates. Event type: `"intelligence_event"` in WS message.
- **D-08:** Storage: in-memory ring buffer (last 200 events). No persistence — feed starts fresh on restart. Same pattern as the old `_activity_feed` list that was removed in Phase 50.
- **D-09:** Server-side: new `_record_intelligence_event(event_type, data)` function in server.py. Called from memory recall, learning, routing, and effectiveness code paths. Also expose `/api/activity` GET endpoint to load recent events on page load.
- **D-10:** Frontend: new `renderActivity()` function in app.js. Shows events as a reverse-chronological feed with event type badges (Memory, Routing, Learning, Effectiveness), timestamps, and expandable detail.

### Branding Sweep
- **D-11:** Replace all user-visible "Agent42" text with "Frood" in app.js — page titles, descriptions, help text, settings labels, setup wizard text, error messages. ~20 occurrences.
- **D-12:** Replace "Agent42" in server.py user-visible strings — FastAPI title ("Agent42 Dashboard" → "Frood Dashboard"), log messages visible to users, error messages. Internal logger names (`agent42.server`) stay as-is this phase.
- **D-13:** Rename "Sandboxed Apps" to "Agent Apps" everywhere — sidebar link, page heading, page title map, API route comments, help text expandable section ("What do sandboxed apps get from Agent42?" → "What do Agent Apps get from Frood?").
- **D-14:** Rename SVG files: `agent42-logo-light.svg` → `frood-logo-light.svg`, `agent42-avatar.svg` → `frood-avatar.svg`, `agent42-favicon.svg` → `frood-favicon.svg`. Update all references in index.html and app.js.
- **D-15:** Defer internal renames to a future phase — localStorage keys (`agent42_token`), BroadcastChannel name (`agent42_auth`), `.agent42/` directory paths, Python logger names. These are not user-visible and have high blast radius.

### Settings Cleanup
- **D-16:** Remove "Channels" tab entirely — backend route gone (404), frontend `loadChannels()` and channel state/rendering are dead code.
- **D-17:** Rename "Orchestrator" tab to "Routing" — update label, tab ID, and section content.
- **D-18:** Remove MAX_CONCURRENT_AGENTS setting from the Routing tab — harness concept, no agents to throttle.
- **D-19:** Update "Orchestrator" description text ("Controls how Agent42 processes tasks" → "Controls how Frood routes LLM requests") to match the new identity.
- **D-20:** Remove `loadChannels()` call from `loadAll()` Promise.all — eliminates the 404 console error.

### Setup Wizard
- **D-21:** Update setup wizard text to reflect Frood-as-service identity. Remove "A mostly harmless orchestrator" tagline. New copy should emphasize intelligence layer (memory, tools, routing).

### README
- **D-22:** Update README.md to reflect Frood Dashboard as intelligence layer admin panel. Remove any orchestrator/harness language.

### Claude's Discretion
- Exact wording for setup wizard steps
- Reports "Overview" vs "Intelligence" tab naming
- Activity Feed visual design (card style, badges, spacing)
- Whether to add Activity sidebar entry before or after Reports
- README structure and content depth

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Dashboard Server
- `dashboard/server.py` — Main FastAPI server, ~2,499 lines post-strip. Reports endpoint, settings routes, memory routes, effectiveness routes.
- `dashboard/auth.py` — JWT auth, 175 lines. No changes expected this phase.
- `dashboard/websocket_manager.py` — WebSocket broadcast for Activity Feed push.

### Dashboard Frontend
- `dashboard/frontend/dist/app.js` — Hand-written SPA, 2,114 lines post-strip. Sidebar at ~2052, renderers at ~2083, reports at ~1194-1430, settings at ~1443-1800.
- `dashboard/frontend/dist/index.html` — Page shell, script/CSS references, SVG paths.
- `dashboard/frontend/dist/style.css` — CSS styles for any new Activity Feed components.

### Assets
- `dashboard/frontend/dist/assets/agent42-logo-light.svg` — Logo to rename to frood-*
- `dashboard/frontend/dist/assets/agent42-avatar.svg` — Avatar to rename
- `dashboard/frontend/dist/assets/agent42-favicon.svg` — Favicon to rename

### Requirements
- `.planning/workstreams/frood-dashboard/REQUIREMENTS.md` — BRAND-01..04, RPT-01..04, FEED-01..03, SET-01..04, CLEAN-05

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ws_manager.broadcast()` — WebSocket broadcast for Activity Feed push events. Already in place.
- `/api/reports` endpoint — Returns aggregated stats including token_usage, costs, tools, skills. Can be extended for intelligence metrics.
- `/api/effectiveness/*` endpoints — Model/tool outcome tracking, learnings. Data source for intelligence dashboard.
- `/api/memory/*` endpoints — Memory recall stats. Data source for intelligence dashboard.
- In-memory list pattern (was `_activity_feed`) — exact pattern to reuse for new intelligence event buffer.

### Established Patterns
- Hand-written SPA with render functions per page (`renderApps`, `renderTools`, `renderSkills`, `renderReports`, `renderSettings`). New `renderActivity` follows same pattern.
- Settings tabs implemented as a `tabs[]` array with `id` and `label`, rendered by `renderSettingsPanel()`.
- Reports tabs: `{ id: "overview", label: "Overview" }` array with `_renderReportsOverview()`, `_renderReportsHealth()` sub-functions.
- Page routing via `renderers` object at ~line 2083 and sidebar `data-page` attributes.

### Integration Points
- Add "Activity" to sidebar nav (line ~2052) and renderers object (line ~2083)
- Add `renderActivity()` function alongside existing render functions
- Add intelligence event recording to memory recall, learning extraction, routing decision, and effectiveness code paths in server.py
- Extend `/api/reports` response to include intelligence metrics or create new endpoint

</code_context>

<specifics>
## Specific Ideas

- Activity Feed as a real-time observability surface — watch memory recalls, routing decisions, and effectiveness scores as they happen
- SVG files renamed to frood-* (user explicitly requested this)
- Internal renames (localStorage, .agent42 paths) deferred per user guidance — "use best judgment, push to future phase for internals as needed"
- Setup wizard copy is Claude's discretion but should emphasize intelligence layer identity

</specifics>

<deferred>
## Deferred Ideas

- **Internal localStorage rename** — `agent42_token` → `frood_token`, `agent42_auth` BroadcastChannel. High blast radius, breaks existing sessions. Future phase.
- **Internal .agent42/ path rename** — `.agent42/qdrant/`, `.agent42/MEMORY.md`, `.agent42/cc-sync-status.json`. Affects all components. Separate effort per out-of-scope rule.
- **Python package rename** — `agent42` → `frood` in all Python imports/modules. Explicitly out of scope (REQUIREMENTS.md).
- **Python logger name rename** — `logging.getLogger("agent42.server")` etc. Not user-visible, defer.

</deferred>

---

*Phase: 51-rebrand-and-repurpose*
*Context gathered: 2026-04-07*
