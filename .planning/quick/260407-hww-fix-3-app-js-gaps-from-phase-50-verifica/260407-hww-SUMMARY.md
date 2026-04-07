---
phase: quick
plan: 260407-hww
subsystem: dashboard-frontend
tags: [javascript, cleanup, harness-removal, bugfix]
dependency_graph:
  requires: [50-02]
  provides: [CLEAN-02]
  affects: [dashboard/frontend/dist/app.js]
tech_stack:
  added: []
  patterns: [dead-code-removal, static-category-substitution]
key_files:
  created: []
  modified:
    - dashboard/frontend/dist/app.js
    - .planning/workstreams/frood-dashboard/REQUIREMENTS.md
decisions:
  - "All remaining tools categorized as 'general' — code-only category no longer relevant after harness removal"
  - "system_health WS branch removed entirely (was only calling updateGsdIndicator) — dead branch, not just dead call"
metrics:
  duration: "~5 minutes"
  completed: "2026-04-07"
  tasks: 2
  files: 2
---

# Quick Task 260407-hww: Fix 3 app.js Gaps from Phase 50 Verification Summary

**One-liner:** Removed 6 harness-specific call sites and dead functions from app.js to eliminate all ReferenceErrors left by Phase 50-02, restoring dashboard startup and Tools page functionality.

## What Was Done

Phase 50-02 deleted harness function definitions but left behind 6 call sites and 3 dead functions. This caused the dashboard to crash on every startup (loadGsdWorkstreams), crash on the Tools page (_CODE_ONLY_TOOLS), and throw on 4 updateGsdIndicator call sites.

### Task 1: Remove blocker call sites and dead renderDetail block (app.js)

Targeted removals:

1. `loadGsdWorkstreams()` removed from `loadAll()` Promise.all array — function definition was deleted in 50-02
2. `_CODE_ONLY_TOOLS.has(t.name)` in `renderTools()` replaced with static `"general"` — constant deleted in 50-02, all remaining tools are intelligence-layer tools
3. All 4 `updateGsdIndicator()` call sites removed:
   - Line 160: from `loadAll().then()` callback
   - Line 306: standalone call after setup completion render
   - Line 474: sole statement in `system_health` WS branch — entire branch removed
   - Line 2237: standalone call in DOMContentLoaded handler
4. `renderDetail()` function (117 lines) deleted — unreachable harness renderer referencing 10+ deleted functions
5. `submitComment()` and `promptBlock()` deleted — only called from renderDetail HTML template

**Commit:** `c7d9ea7`

### Task 2: Mark CLEAN-02 complete in REQUIREMENTS.md

Checked the `CLEAN-02` checkbox from `[ ]` to `[x]` — requirement was satisfied by 50-02 plus this task's call-site cleanup.

**Commit:** `d67aa7f`

## Verification Results

1. `node -c dashboard/frontend/dist/app.js` — PASS (no syntax errors)
2. Grep for removed symbols (loadGsdWorkstreams, updateGsdIndicator, _CODE_ONLY_TOOLS, renderDetail, submitComment, promptBlock) — 0 matches
3. Kept symbols confirmed present: STATUS_FLAVOR (2), statusBadge (4), renderTools (6), renderApps (7), loadAll (5)
4. REQUIREMENTS.md shows `[x]` for CLEAN-02 — PASS

## Deviations from Plan

None — plan executed exactly as written. The `system_health` WS branch was removed entirely (not just the updateGsdIndicator call) as specified in the plan's action item 3.

## Known Stubs

None — this task only removed dead code, no new stubs introduced.

## Self-Check: PASSED

- `dashboard/frontend/dist/app.js` — modified, verified
- `.planning/workstreams/frood-dashboard/REQUIREMENTS.md` — modified, verified
- Commits c7d9ea7 and d67aa7f — confirmed in git log
