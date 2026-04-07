# Phase 50: Strip Harness Features - Context

**Gathered:** 2026-04-07 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove all harness features from the Frood dashboard, leaving only intelligence layer admin/observability features. The dashboard becomes an admin panel for configuring and monitoring Frood's unique capabilities (memory, tools, skills, effectiveness, provider health, Agent Apps, LLM proxy), not an end-user interface.

**Frood is the towel, not the spaceship.** It requires a harness (Claude Code, OpenCode, Paperclip, etc.) to function.

</domain>

<decisions>
## Implementation Decisions

### What to REMOVE (Harness Features)

- **D-01:** Remove Mission Control — Kanban board, tasks, projects (server.py tasks/projects routes, frontend renderMissionControl)
- **D-02:** Remove Workspace/IDE — Monaco editor, terminal, file browser, IDE chat (server.py /api/ide/*, /ws/terminal, frontend renderCode)
- **D-03:** Remove Agents page — Agent lifecycle CRUD, start/stop/delete (server.py /api/agents/*, frontend renderAgents)
- **D-04:** Remove Teams page — Multi-agent team monitoring (frontend renderTeams, no server routes)
- **D-05:** Remove Approvals — Human-in-the-loop task review (server.py /api/approvals, frontend renderApprovals)
- **D-06:** Remove GitHub Integration — Repo cloning, OAuth, account management (server.py /api/github/*, /api/repos/*)
- **D-07:** Remove Chat — Chat sessions, message streaming, CC chat bridge (server.py /api/chat/*, /ws/cc-chat, /api/cc/*, frontend renderChat)
- **D-08:** Remove Device Gateway — Multi-device management, device API keys (server.py /api/devices/*, auth.py device key validation)
- **D-09:** Remove GSD Workstreams UI — Phase tracking in dashboard (server.py /api/gsd/*)
- **D-10:** Remove Status page — Platform capacity dashboard (server.py /api/status, frontend renderStatus)
- **D-11:** Remove Agent Profiles — Profile CRUD and routing overrides (server.py /api/profiles/*, /api/agent-routing/* — PUT already returns 410 Gone)
- **D-12:** Remove Persona — Custom chat system prompt (server.py /api/persona — no chat = no persona)
- **D-13:** Remove Rewards API — Depends on Agents page (server.py /api/rewards/*)
- **D-14:** Remove Projects — Project management, project memory (server.py /api/projects/*, gated by project_manager)

### What to KEEP (Intelligence Layer)

- **D-15:** Keep Auth — JWT login/logout, password management, setup wizard (server.py /api/login, /api/logout, /api/setup/*)
- **D-16:** Keep Memory — Semantic recall, learning extraction, stats (server.py /api/memory/*)
- **D-17:** Keep Tools — Tool registry enable/disable (server.py /api/tools/*)
- **D-18:** Keep Skills — Skill loader management (server.py /api/skills/*)
- **D-19:** Keep Reports — Token usage, model performance, cost tracking (server.py /api/reports)
- **D-20:** Keep Effectiveness — Model/tool outcome tracking, learnings (server.py /api/effectiveness/*, /api/learnings/*)
- **D-21:** Keep Provider Status — LLM provider health, model catalog (server.py /api/providers/*)
- **D-22:** Keep LLM Chat Proxy — OpenAI/Anthropic-compatible proxy (server.py /llm/*)
- **D-23:** Keep Settings — Key vault, env config, storage backends (server.py /api/settings/*)
- **D-24:** Keep Agent Apps — Sandboxed app building/lifecycle (server.py /api/apps/* — this is unique to Frood, NOT a harness feature). Rename to "Agent Apps" happens in Phase 51.
- **D-25:** Keep Health — Service health check (server.py /health, /api/health)
- **D-26:** Keep WebSocket infrastructure — Keep broadcast mechanism, remove harness event handlers

### Frontend Approach

- **D-27:** `dashboard/frontend/dist/app.js` is hand-written (8,924 lines, no build system, no source directory). It CAN be surgically edited — remove render functions, sidebar links, and page router entries for stripped features.
- **D-28:** Remove harness page render functions: `renderMissionControl`, `renderStatus`, `renderApprovals`, `renderCode`, `renderAgents`, `renderTeams`, `renderChat`
- **D-29:** Update sidebar navigation (lines ~8786-8796) to only show kept pages
- **D-30:** Update page renderers object (lines ~8829-8843) to remove harness entries

### Auth Simplification

- **D-31:** Remove device API key validation from auth.py (`_validate_api_key()`, `_device_store` references). Keep JWT auth only.
- **D-32:** Simplify `get_auth_context()` to skip API key validation path.

### Removal Strategy

- **D-33:** Work bottom-to-top in server.py to avoid line number drift during removal. Remove routes in reverse order of their line positions.
- **D-34:** Remove associated imports, helpers, and model classes that become orphaned after route removal.
- **D-35:** Activity Feed (`_record_activity()`, in-memory `_activity_feed` list) — remove entirely in this phase. Repurposing as intelligence event log happens in Phase 51.

### Claude's Discretion
- Exact order of route group removal within the bottom-to-top strategy
- Whether to leave stub 410 endpoints or remove routes entirely (preference: remove entirely)
- How to handle `@standalone_guard` decorator — can be removed from kept routes since all harness routes are gone

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Dashboard Server
- `dashboard/server.py` — Main FastAPI server, 6455 lines. All route groups for both removed and kept features.
- `dashboard/auth.py` — JWT + API key auth, 218 lines. Device key logic to strip.
- `dashboard/websocket_manager.py` — WebSocket broadcast, 101 lines. Keep infrastructure.

### Dashboard Frontend
- `dashboard/frontend/dist/app.js` — Hand-written SPA, 8924 lines. Sidebar nav at ~8786, renderers at ~8829.
- `dashboard/frontend/dist/index.html` — Page shell.

### Sidecar (DO NOT TOUCH)
- `dashboard/sidecar.py` — Paperclip integration surface, 903 lines. Separate concern — not part of this phase.

### Requirements
- `.planning/workstreams/frood-dashboard/REQUIREMENTS.md` — STRIP-01 through STRIP-12, CLEAN-01 through CLEAN-04

</canonical_refs>

<code_context>
## Existing Code Insights

### server.py Route Ranges (approximate, for bottom-to-top removal)
| Feature | Line Range | Routes |
|---------|-----------|--------|
| Apps (KEEP) | 6194-6340 | 8 routes |
| GitHub + Repos (REMOVE) | 5914-6193 | 10 routes |
| Projects (REMOVE) | 5727-5890 | gated by project_manager |
| WebSocket (KEEP infra) | 5661-5752 | /ws |
| Settings (KEEP) | 5312-5651 | /api/settings/* |
| Tools + Skills (KEEP) | 5249-5310 | /api/tools/*, /api/skills/* |
| Provider Status (KEEP) | 5140-5248 | /api/providers/* |
| Devices (REMOVE) | 5067-5139 | /api/devices/* |
| Approvals (REMOVE) | 5049-5066 | /api/approvals |
| Rewards (REMOVE) | 4944-5048 | /api/rewards/* |
| Agents (REMOVE) | 4732-4943 | /api/agents/* |
| Effectiveness (KEEP) | 4112-4731 | /api/effectiveness/*, /api/learnings/* |
| Chat + IDE Chat (REMOVE) | 3282-4112 | /api/chat/*, /api/ide/chat* |
| Memory (KEEP) | 3168-3269 | /api/memory/* |
| LLM Proxy (KEEP) | 3641-3912 | /llm/* |
| CC Sessions (REMOVE) | 3082-3119 | /api/cc/* |
| CC Chat WebSocket (REMOVE) | 2065-3082 | /ws/cc-chat |
| Terminal WebSocket (REMOVE) | 1776-2064 | /ws/terminal |
| GSD Workstreams (REMOVE) | 1612-1708 | /api/gsd/* |
| IDE routes (REMOVE) | 1429-1710 | /api/ide/* |
| Workspaces (REMOVE) | 1376-1428 | /api/workspaces/* |
| Reports (KEEP) | 1140-1365 | /api/reports |
| Activity Feed (REMOVE) | 1075-1095 | /api/activity |
| Profiles + Routing + Persona (REMOVE) | 858-1073 | /api/profiles/*, /api/agent-routing/*, /api/persona |
| Auth (KEEP) | 749-857 | /api/login, /api/logout |
| Status (REMOVE) | 608-642 | /api/status |
| Health + Setup (KEEP) | 580-750 | /health, /api/setup/* |

### Cross-Cutting Dependencies (verified safe)
- Chat does NOT log to Memory — safe to remove independently
- Effectiveness works without Agents page — no hard dependency
- Activity Feed is in-memory only — safe to delete
- Apps (Agent Apps) has no dependency on removed features
- `@standalone_guard` routes are already gated — removing entirely is cleaner

### Estimated Removal
- ~1,600 lines from server.py (route handlers + associated code)
- ~3,000+ lines from app.js (harness render functions)
- ~70 lines from auth.py (device key logic)

</code_context>

<specifics>
## Specific Ideas

- Bottom-to-top removal in server.py avoids line number drift
- Agent Apps stays — Meatheadgear is the proof case, no harness offers this
- Frontend is hand-written SPA, not compiled — can surgically edit
- Full test suite must pass after every major removal step

</specifics>

<deferred>
## Deferred Ideas

- **Agent Apps rename** — "Apps" → "Agent Apps" in UI/API is Phase 51 (BRAND-01)
- **Activity Feed repurpose** — Intelligence event log (memory/routing/effectiveness) is Phase 51 (FEED-01 through FEED-03)
- **Frood branding polish** — Remaining "Agent42" text cleanup is Phase 51 (BRAND-03)
- **Internal package rename** — `agent42` → `frood` in Python is out of scope entirely

</deferred>

---

*Phase: 50-strip-harness-features*
*Context gathered: 2026-04-07*
