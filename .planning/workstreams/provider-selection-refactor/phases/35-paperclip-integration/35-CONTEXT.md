# Phase 35: Paperclip Integration - Context

**Gathered:** 2026-04-06 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Update Paperclip integration to work with the simplified provider selection system. Ensure the Paperclip plugin correctly uses the tiered routing bridge, displays available provider models, allows agent-level model configuration, and shows provider connectivity status.

**Dependency constraint:** Phases 32 (Provider Selection Core) and 33 (Synthetic.new Integration) have NOT been executed. No phase directories, plans, or code exist for them. Only Phase 34 (System Simplification — L1/L2 dead config removal) is complete. The existing provider infrastructure is: `core/tiered_routing_bridge.py` (reward-tier routing), `core/agent_manager.py` (PROVIDER_MODELS registry), and `providers/zen_api.py` (Zen/OpenRouter integration).

**Achievable now (UI-01):** Ensure Paperclip plugin works with simplified provider system (no L1/L2 references, uses tiered_routing_bridge.py).

**Blocked until Phases 32+33 (UI-02, UI-03, UI-04):** Model discovery from Synthetic.new, Claude Code Subscription integration, and provider status reporting all require upstream infrastructure that doesn't exist yet.

</domain>

<decisions>
## Implementation Decisions

### Dependency Strategy
- **D-01:** Scope Phase 35 to what's achievable with current infrastructure. UI-01 is fully deliverable. UI-02, UI-03, UI-04 require stubs/interfaces that can be wired up when Phases 32+33 are complete.
- **D-02:** Create sidecar endpoint contracts (request/response types) for model discovery and provider status NOW, even if the implementation returns placeholder data. This lets Paperclip UI be built against stable interfaces.

### Provider Selection via Sidecar
- **D-03:** Paperclip plugin calls `TieredRoutingBridge.resolve()` via sidecar endpoints exclusively. No parallel provider logic in the plugin. The sidecar is the single source of truth for routing decisions.
- **D-04:** Agent role (engineer/researcher/writer/analyst) must be passed via adapter-run action to sidecar. `tiered_routing_bridge.py:34-42` maps roles to categories for model selection. Missing role falls back to "general" category (line 170).

### Model Discovery Endpoint
- **D-05:** New sidecar endpoint `GET /sidecar/models` returns available models grouped by provider. Response includes model ID, display name, provider, and capabilities (when available). Currently returns models from PROVIDER_MODELS registry; will return dynamic Synthetic.new models once Phase 33 is implemented.
- **D-06:** Model list is consumed by agent configuration UI for model selection dropdown.

### Provider Status Endpoint
- **D-07:** Enhance `GET /sidecar/health` response to include per-provider connectivity status (not just boolean "configured" flags). Each provider entry: `{name, configured, connected, model_count, last_check}`. Currently only Zen and hardcoded providers report; CC Subscription and Synthetic.new will report once Phases 32+33 land.

### Settings UI Enhancement
- **D-08:** Add SYNTHETIC_API_KEY to Paperclip SettingsPage "API Keys" tab alongside existing provider keys. The manifest.ts already documents this key. KEY_HELP entry needed in SettingsPage.tsx.

### Backward Compatibility
- **D-09:** Existing agents without role metadata fall back to "general" category. No migration needed — `tiered_routing_bridge.py` handles None/empty role with `.get(role or "", "general")`.
- **D-10:** Reward tier (gold/silver/bronze/provisional) comes from Agent42's RewardSystem. Paperclip adapter must NOT override tier. Cost estimation is deferred (current cost_estimate=0.0 is intentional per prior phase decisions).

### Claude's Discretion
- Exact response schema fields for /sidecar/models (beyond the required fields above)
- Loading/skeleton states for provider health widget
- Error handling when sidecar is unreachable from plugin

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Provider Routing (active system)
- `core/tiered_routing_bridge.py` — TieredRoutingBridge.resolve(), _ROLE_CATEGORY_MAP, _TIER_CATEGORY_UPGRADE, RoutingDecision dataclass
- `core/agent_manager.py` — PROVIDER_MODELS registry, resolve_model(), provider configuration

### Sidecar API
- `dashboard/sidecar.py` — Current sidecar endpoints (GET /sidecar/health, POST /sidecar/run)
- `dashboard/sidecar_models.py` — HealthResponse, AdapterRunRequest/Response models

### Paperclip Plugin
- `plugins/agent42-paperclip/src/manifest.ts` — Tool definitions, route_task, adapter-run
- `plugins/agent42-paperclip/src/worker.ts` — Adapter execution, sidecar communication
- `plugins/agent42-paperclip/src/ui/` — Dashboard widgets (ProviderHealthWidget, RoutingDecisionsWidget, SettingsPage)
- `plugins/agent42-paperclip/src/client.ts` — Sidecar API client (health(), getAgentSpend())

### Provider Implementations
- `providers/zen_api.py` — Zen/OpenRouter API client pattern (model refresh, caching, auth)

### Requirements
- `.planning/workstreams/provider-selection-refactor/REQUIREMENTS.md` — UI-01 through UI-04

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TieredRoutingBridge.resolve()` — Returns RoutingDecision with provider, model, tier, task_category, cost_estimate. Full routing decision in one call.
- `PROVIDER_MODELS` dict in `agent_manager.py` — Central model registry already organized by provider and category. Can be serialized for the /sidecar/models endpoint.
- `ProviderHealthWidget` in Paperclip plugin — Already registers UI data handler for provider health. Needs enhancement, not rebuild.
- `SettingsPage` API Keys tab — Already shows OPENROUTER_API_KEY, OPENAI_API_KEY, etc. Adding SYNTHETIC_API_KEY follows established pattern.
- `zen_api.py` model refresh pattern — `start_zen_model_refresh_task()` with background asyncio task, 24h refresh, PROVIDER_MODELS update. Reusable for Synthetic.new when Phase 33 lands.

### Established Patterns
- Sidecar endpoints use FastAPI with Pydantic models in `sidecar_models.py`
- Plugin UI uses `ctx.data.register()` for data handlers, `usePluginData()` hook for consumption
- Plugin tools defined in `manifest.ts`, executed in `worker.ts`
- Provider API clients follow: class with async methods, bearer token auth, OpenAI-compatible endpoints

### Integration Points
- `worker.ts adapter-run` → `POST /sidecar/run` → `SidecarOrchestrator` → `TieredRoutingBridge.resolve()`
- `ProviderHealthWidget` → `client.health()` → `GET /sidecar/health` → provider status aggregation
- `SettingsPage` → `client.updateSettings()` → `POST /sidecar/settings` → `.env` / key store

</code_context>

<specifics>
## Specific Ideas

- Dashboard consolidation decision (2026-03-30): All UI lives in Paperclip via native plugin slots. Agent42 standalone dashboard is being retired. Rich plugin panels for memory browser, effectiveness, routing, provider health.
- Paperclip integration decision (2026-03-28): Agent42 is intelligence layer, Paperclip is company infrastructure. Agent42 adapter for Paperclip operates in sidecar mode.
- Out of scope (from REQUIREMENTS.md): No iframe embeds, no direct PostgreSQL access, no per-company plugin instances, no duplicate conversation storage.

</specifics>

<deferred>
## Deferred Ideas

- **Phase 32 execution** — Provider Selection Core (CC Subscription as primary, Synthetic.new as fallback). Must be done before UI-02/03/04 can show real data.
- **Phase 33 execution** — Synthetic.new Integration (dynamic model discovery, 24h refresh, health check). Must be done before UI-02/03 can list real models.
- **Cost estimation wiring** — RoutingDecision.cost_estimate is intentionally 0.0 until AgentRuntime wires real token counts (deferred from earlier phases).
- **Real-time provider status updates** — Plugin currently polls via data handlers. WebSocket push for live health status is a future enhancement.

</deferred>

---

*Phase: 35-paperclip-integration*
*Context gathered: 2026-04-06*
