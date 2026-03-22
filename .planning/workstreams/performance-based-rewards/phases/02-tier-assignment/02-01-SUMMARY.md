---
phase: 02-tier-assignment
plan: "01"
subsystem: rewards
tags: [tdd, tier-assignment, agent-config, pure-computation]
dependency_graph:
  requires: [core/reward_system.py, core/rewards_config.py, core/config.py, core/agent_manager.py]
  provides: [TierDeterminator.determine(), AgentConfig.effective_tier(), AgentConfig tier fields]
  affects: [Phase 3 enforcement, Phase 4 dashboard]
tech_stack:
  added: []
  patterns: [deferred import to avoid circular, pure computation class, dataclass field extension]
key_files:
  created: [tests/test_tier_assignment.py]
  modified: [core/reward_system.py, core/agent_manager.py]
decisions:
  - "TierDeterminator added at end of core/reward_system.py alongside Phase 1 classes (D-04)"
  - "RewardsConfig imported at module level in reward_system.py; settings imported deferred inside determine() to avoid circular"
  - "effective_tier() uses None sentinel check (is not None) per D-03 — empty string '' is NOT a no-override signal"
metrics:
  duration: "8 min"
  completed_date: "2026-03-22"
  tasks: 2
  files: 3
---

# Phase 02 Plan 01: TierDeterminator and AgentConfig Tier Fields Summary

**One-liner:** TierDeterminator maps (score, obs_count) to provisional/bronze/silver/gold using RewardsConfig thresholds; AgentConfig extended with four tier fields and effective_tier() None-sentinel override logic.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | RED — Write failing tests | cde60e3 | tests/test_tier_assignment.py |
| 2 | GREEN — Implement TierDeterminator and AgentConfig tier fields | f5740db | core/reward_system.py, core/agent_manager.py |

## What Was Built

### TierDeterminator (core/reward_system.py)

Pure computation class with a single `determine(score, observation_count) -> str` method:
- Returns `"provisional"` when `observation_count < settings.rewards_min_observations` (default 10)
- Returns `"gold"` when `score >= cfg.gold_threshold` (0.85)
- Returns `"silver"` when `score >= cfg.silver_threshold` (0.65)
- Returns `"bronze"` otherwise

Thresholds are read from `RewardsConfig.load()` (mtime-cached, cheap). `settings` is imported inside the method body to avoid circular import at module load time.

### AgentConfig tier fields (core/agent_manager.py)

Four new fields added to the `AgentConfig` dataclass:
- `reward_tier: str = ""` — Computed tier string
- `tier_override: str | None = None` — Admin override, None sentinel means "use computed"
- `performance_score: float = 0.0` — Last computed composite score
- `tier_computed_at: str = ""` — ISO timestamp of last computation

Fields round-trip through `to_dict()`/`from_dict()` automatically (via `asdict()`). Old agents loaded without these fields use the defaults (no migration needed).

### AgentConfig.effective_tier() method

Returns `tier_override` when it is not `None`, otherwise returns `reward_tier`. This is the single read point for Phase 3 enforcement and Phase 4 dashboard display.

## Test Results

- 17 tests in `tests/test_tier_assignment.py` — all pass
- 75 total tests across reward/effectiveness suites — no regressions
- RED phase confirmed `ImportError: cannot import name 'TierDeterminator'`
- GREEN phase: all 17 pass in 0.06s

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Deferred `settings` import inside `determine()` | Avoids circular import: reward_system.py imports from config.py, and config.py could transitively import from reward_system.py |
| Module-level `RewardsConfig` import | RewardsConfig has no circular dependency risk; mtime-cached so cheap |
| None sentinel for tier_override | Matches `AgentRoutingStore` idiom; empty string is a valid but distinct state |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all tier fields are active data storage slots, not placeholders. Phase 3 (resource enforcement) and Phase 4 (dashboard) will read these fields.

## Self-Check: PASSED

- [x] `tests/test_tier_assignment.py` exists
- [x] `core/reward_system.py` contains `class TierDeterminator`
- [x] `core/agent_manager.py` contains `reward_tier`, `tier_override`, `effective_tier`
- [x] Commits cde60e3 and f5740db present in git log
- [x] 17 tests pass, 0 regressions
