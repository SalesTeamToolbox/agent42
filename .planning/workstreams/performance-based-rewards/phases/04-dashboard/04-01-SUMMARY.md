---
phase: 04-dashboard
plan: 01
subsystem: rewards-api
tags: [rewards, dashboard, api, websocket, auth, tdd]
dependency_graph:
  requires:
    - core/reward_system.py (TierRecalcLoop, RewardSystem)
    - core/agent_manager.py (AgentConfig, AgentManager)
    - core/rewards_config.py (RewardsConfig.load/save)
    - dashboard/server.py (create_app, auth patterns)
    - dashboard/websocket_manager.py (broadcast)
  provides:
    - GET /api/rewards — system status with enabled flag, config, tier counts
    - POST /api/rewards/toggle — runtime enable/disable without restart
    - GET /api/agents/{id}/performance — score, tier, task_count, success_rate
    - PATCH /api/agents/{id}/reward-tier — admin tier override
    - POST /api/admin/rewards/recalculate-all — immediate recalculation trigger
    - effective_tier field in all AgentConfig.to_dict() responses
    - TierRecalcLoop WebSocket tier_update broadcast
  affects:
    - GET /api/agents (now includes effective_tier field in every agent dict)
    - TierRecalcLoop._run_recalculation (now broadcasts after loop completes)
tech_stack:
  added: []
  patterns:
    - "Optional capability injection via if agent_manager and reward_system: block"
    - "Per-endpoint Depends() decorators for auth (no APIRouter)"
    - "Single broadcast after loop (not per-agent) for WebSocket tier_update events"
    - "ws_manager=None graceful degradation in TierRecalcLoop"
key_files:
  created:
    - tests/test_rewards_api.py
  modified:
    - core/agent_manager.py
    - core/reward_system.py
    - dashboard/server.py
    - agent42.py
decisions:
  - "Rewards endpoints gated on both agent_manager AND reward_system being truthy — follows existing if project_manager: pattern"
  - "broadcast called once after loop with all changed agents — prevents N WebSocket messages for N tier changes"
  - "ws_manager=None in TierRecalcLoop is graceful degradation — no broadcast, no crash"
  - "_effectiveness_store local variable alias added near _agent_manager for consistent access pattern"
metrics:
  duration: 18
  completed_date: "2026-03-23"
  tasks_completed: 2
  files_changed: 5
---

# Phase 04 Plan 01: Dashboard Rewards API Summary

**One-liner:** JWT-authenticated REST API for rewards management with WebSocket tier_update broadcasts wired from TierRecalcLoop into the FastAPI dashboard.

## What Was Built

Five new authenticated REST endpoints added to `dashboard/server.py` inside `create_app()`, gated on `if agent_manager and reward_system:` (follows existing optional capability injection pattern). All five return 401 for unauthenticated requests.

Endpoints:
- `GET /api/rewards` — system status (enabled flag, config thresholds, per-tier agent counts)
- `POST /api/rewards/toggle` — runtime enable/disable via RewardsConfig.save() (admin only)
- `GET /api/agents/{id}/performance` — per-agent score, tier, task_count, success_rate
- `PATCH /api/agents/{id}/reward-tier` — set tier_override, broadcasts tier_update immediately (admin only)
- `POST /api/admin/rewards/recalculate-all` — triggers immediate recalculation as asyncio.create_task (admin only, returns 202)

Supporting changes:
- `AgentConfig.to_dict()` now includes `effective_tier` field — surfaces via existing `GET /api/agents` with no N+1 queries
- `TierRecalcLoop.__init__()` accepts `ws_manager=None` — collects changed agents during recalc loop, broadcasts single `tier_update` event after the loop completes
- `agent42.py` passes `reward_system=self.reward_system` to `create_app()` and `ws_manager=self.ws_manager` to `TierRecalcLoop`
- `_effectiveness_store` local variable alias added in the agent manager block for clean access from endpoint closures

## Test Coverage

20 tests in `tests/test_rewards_api.py`:
- `TestRewardsAuth` (5 tests) — 401 for all 5 endpoints without auth
- `TestRewardsEndpoints` (9 tests) — happy-path with JWT, 404 for unknown agent, 422 for invalid tier, endpoints absent when dependencies missing
- `TestTierUpdateBroadcast` (3 tests) — broadcast called once on tier change, not called when no change, not called when ws_manager=None
- `TestEffectiveTierInAgentDict` (2 tests) — to_dict() has effective_tier, override takes precedence

All 1698 tests pass, no regressions.

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| 213336e | test | Add failing tests for rewards API endpoints (TDD RED) |
| b239929 | feat | Wire reward_system into dashboard API and expose effective_tier |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all data flows from real objects (AgentConfig, EffectivenessStore, RewardsConfig). The `_effectiveness_store` may be None in test/headless usage, in which case task_count and success_rate return 0.0 (documented graceful degradation, not a stub).

## Self-Check: PASSED

Files created/modified:
- tests/test_rewards_api.py: EXISTS
- core/agent_manager.py: EXISTS (effective_tier in to_dict)
- core/reward_system.py: EXISTS (ws_manager param + broadcast)
- dashboard/server.py: EXISTS (reward_system param + 5 endpoints)
- agent42.py: EXISTS (reward_system kwarg + ws_manager to TierRecalcLoop)

Commits verified:
- 213336e: EXISTS (test RED)
- b239929: EXISTS (feat implementation)
