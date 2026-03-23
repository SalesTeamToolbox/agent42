# Phase 4: Dashboard - Context

**Gathered:** 2026-03-23 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Operators can see every agent's tier and performance metrics at a glance, toggle the rewards system on/off without a restart, override any agent's tier via UI, and watch tier changes propagate in real time via WebSocket — with all API endpoints protected by authentication. No new enforcement logic, no new scoring, no hysteresis.

</domain>

<decisions>
## Implementation Decisions

### REST API Endpoints
- **D-01:** All rewards endpoints added inline in `create_app()` using `@app.get/post/patch` with per-endpoint `Depends()` decorators — no `APIRouter` (none exists in codebase). Read endpoints use `Depends(get_current_user)`, mutations use `Depends(require_admin)`.
- **D-02:** Rewards API block gated behind `if agent_manager:` check, with `reward_system` parameter added to `create_app()` — follows existing optional capability injection pattern (`if project_manager:`, `if channel_manager:`).
- **D-03:** Endpoints:
  - `GET /api/rewards` — system status (enabled, config, tier counts)
  - `POST /api/rewards/toggle` — enable/disable via RewardsConfig.save() (ADMN-02)
  - `GET /api/agents/{id}/performance` — score, tier, task count, success rate
  - `PATCH /api/agents/{id}/reward-tier` — set tier_override via AgentManager.update()
  - `POST /api/admin/rewards/recalculate-all` — trigger immediate recalculation
- **D-04:** All endpoints return 401 for unauthenticated requests (TEST-04 verifies this for every endpoint).

### WebSocket Events
- **D-05:** `tier_update` WebSocket event broadcast from two sources: (1) the override endpoint in server.py when admin sets override, (2) `TierRecalcLoop` after each recalculation cycle.
- **D-06:** `TierRecalcLoop` receives `ws_manager` as constructor argument and calls `ws_manager.broadcast("tier_update", data)` after updating tiers — matches `HeartbeatService` pattern for `system_health` events.
- **D-07:** Frontend `handleWSMessage` in `app.js` gets a new `tier_update` case that refreshes agent card badges without full page reload.

### Frontend UI
- **D-08:** `effective_tier` field added to `AgentConfig.to_dict()` — exposed via existing `GET /api/agents` response. No separate per-agent tier fetch (prevents N+1).
- **D-09:** Tier badge on agent cards — modify `_renderAgentCards()` in `app.js` to show Bronze/Silver/Gold/Provisional badge using the existing `badge-tier` CSS class pattern.
- **D-10:** Performance metrics panel per agent — score, tier, task count, success rate displayed when clicking an agent card. Data from `GET /api/agents/{id}/performance`.
- **D-11:** Rewards toggle in settings page — switch with confirmation dialog. Calls `POST /api/rewards/toggle`.
- **D-12:** Admin tier override UI — dropdown on agent detail view, calls `PATCH /api/agents/{id}/reward-tier`. Optional expiry date field.

### Claude's Discretion
- Exact CSS styling for tier badges (colors, positioning)
- Performance metrics panel layout and chart style
- Confirmation dialog copy for toggle
- Whether override expiry is a date picker or text input
- Error toast styling for failed operations

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Dashboard server
- `dashboard/server.py` — create_app(), existing endpoint patterns, auth dependencies (get_current_user, require_admin), WebSocket manager usage, agent_manager injection
- `dashboard/websocket_manager.py` — broadcast() method, event type handling

### Frontend
- `dashboard/static/js/app.js` — _renderAgentCards(), handleWSMessage(), state management, badge-tier CSS class

### Phase 1-3 output
- `core/rewards_config.py` — RewardsConfig.load()/save() for toggle
- `core/agent_manager.py` — AgentConfig.effective_tier(), get_effective_limits(), update()
- `core/reward_system.py` — RewardSystem.score(), TierRecalcLoop

### Auth patterns
- `dashboard/server.py` line ~4033 — `require_admin` pattern for mutations
- `dashboard/server.py` line ~3823 — `get_current_user` pattern for reads

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `create_app()` optional capability injection — `if agent_manager:`, `if project_manager:` blocks
- `ws_manager.broadcast(event_type, data)` — existing WebSocket broadcast infrastructure
- `_renderAgentCards()` — existing agent card rendering with badge support
- `handleWSMessage` switch — existing event type dispatch for real-time updates
- `AgentConfig.to_dict()` via `asdict()` — automatic field serialization

### Established Patterns
- Per-endpoint `Depends()` decorators for auth (no APIRouter)
- `if capability_obj:` gating for optional feature endpoints
- `ws_manager.broadcast("type", data)` from both endpoints and background services
- Frontend state management via `state.agents` array
- `badge-tier` CSS class for status badges on agent cards

### Integration Points
- `dashboard/server.py` create_app() — add `reward_system` param, add rewards endpoint block
- `core/reward_system.py` TierRecalcLoop — add `ws_manager` constructor param for broadcast
- `core/agent_manager.py` AgentConfig.to_dict() — expose effective_tier in serialization
- `dashboard/static/js/app.js` — _renderAgentCards() badges, handleWSMessage tier_update case

</code_context>

<specifics>
## Specific Ideas

No specific requirements — follows established dashboard patterns throughout.

</specifics>

<deferred>
## Deferred Ideas

- Override expiry auto-enforcement (background job that clears expired overrides) — v2
- Tier change audit log display — v2
- Score trend charts (need 4+ weeks of data) — v2
- Fleet-level tier analytics dashboard — v2
- Hysteresis controls in settings — v2

### Reviewed Todos (not folded)
None — no matching todos found.

</deferred>

---

*Phase: 04-dashboard*
*Context gathered: 2026-03-23*
