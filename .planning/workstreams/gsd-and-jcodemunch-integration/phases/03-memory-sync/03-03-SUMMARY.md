---
phase: 03-memory-sync
plan: "03"
subsystem: memory-sync
tags: [memory, project-routing, factory, MEM-03]
dependency_graph:
  requires: [03-01]
  provides: [project-namespace-routing]
  affects: [tools/memory_tool.py, mcp_server.py, tests/test_memory_sync.py]
tech_stack:
  added: []
  patterns: [factory-callable, dict-cache, graceful-fallback]
key_files:
  created: []
  modified:
    - tools/memory_tool.py
    - mcp_server.py
    - tests/test_memory_sync.py
decisions:
  - "_get_store() centralized routing: single method used by store/recall/search for consistent project dispatch"
  - "log action stays global-only intentionally: event log is cross-project by design"
  - "semantic search stays on self._store for Qdrant project-filter: Qdrant already has project filter support via project= param"
  - "factory fallback to memory_store (not error) on creation failure: graceful degradation preserved"
metrics:
  duration: "~20 min"
  completed: "2026-03-25"
  tasks: 1
  files: 3
---

# Phase 03 Plan 03: Project Namespace Factory Wiring Summary

MemoryTool now routes store/recall/search operations to a per-project ProjectMemoryStore via a factory callable, with dict caching and graceful fallback to global store when factory is missing.

## Objective

Wire MemoryTool's `project` parameter to ProjectMemoryStore via a factory callable registered at MCP server startup. ProjectMemoryStore already existed — this plan connects it to MemoryTool.

## What Was Built

### tools/memory_tool.py

- `requires` list expanded: `["memory_store", "project_memory_factory"]`
- `__init__` accepts `project_memory_factory=None` kwarg, stored as `self._project_factory`
- New `_get_store(project)` method: routes to `self._project_factory(project)` when project is non-global and factory is available; logs a WARNING and falls back to `self._store` when factory is None and project is non-global
- `_handle_store()`: uses `_get_store(project)` for `append_to_section()` and dedup check; semantic indexing (log_event_semantic, reindex_memory) stays on `self._store` (global event log)
- `_handle_recall(project)`: now accepts and routes via `_get_store(project)`
- `_handle_search()`: keyword fallback and history search use `_get_store(project)`; semantic search stays on `self._store` (Qdrant already filters via `project=` param)
- `log` action deliberately unchanged: event log is global-only by design

### mcp_server.py

- `_project_store_cache: dict = {}` — module-level dict cache keyed by project_id
- `_project_memory_factory(project_id)` closure: creates ProjectMemoryStore instances with workspace/.agent42 as base_dir, global_store, qdrant_store, and redis_backend; caches by project_id; returns global memory_store as fallback on creation failure
- MemoryTool registration updated to pass `project_memory_factory=_project_memory_factory if memory_store else None`

### tests/test_memory_sync.py

Added 4 new test classes (9 test methods total):

- `TestProjectRouting` (3 tests): store/recall/search route to ProjectMemoryStore when project='myproject'
- `TestBackwardCompat` (3 tests): project='global', default project, factory=None+global all use global store
- `TestFactoryFallback` (1 test): factory=None + non-global project falls back to global and logs WARNING
- `TestFactoryCache` (2 tests): same project_id returns same instance (id() equality); different IDs different instances

## Test Results

```
tests/test_memory_sync.py + tests/test_memory_tool.py: 58 passed
All new project routing tests: 9 passed
No regressions introduced
Pre-existing failures (unrelated): test_app_git.py, test_app_manager.py, test_app_modes.py, test_task_context.py
```

## Deviations from Plan

None — plan executed exactly as written.

The plan specified keeping `log_event_semantic` on `self._store` and `reindex_memory` on `self._store` for the global event log, which was followed. Semantic search also stays on `self._store` as specified since Qdrant supports `project=` filter parameter.

## Known Stubs

None. All project routing is fully wired and tested.

## Self-Check

- [x] `tools/memory_tool.py` modified with `_get_store`, factory kwarg, and routing in store/recall/search
- [x] `mcp_server.py` modified with `_project_memory_factory` closure and cache
- [x] `tests/test_memory_sync.py` contains TestProjectRouting, TestBackwardCompat, TestFactoryFallback, TestFactoryCache
- [x] commit `8953871` exists

## Self-Check: PASSED
