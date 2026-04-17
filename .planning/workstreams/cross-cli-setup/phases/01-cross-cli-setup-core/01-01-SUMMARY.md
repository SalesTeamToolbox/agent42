---
phase: 01-cross-cli-setup-core
plan: 01
subsystem: cross-cli-setup
tags: [manifest, bootstrap, user-config, cli-setup]
requires: []
provides:
  - user_frood_dir()
  - load_manifest()
  - save_manifest()
  - DEFAULT_MANIFEST
affects:
  - "Downstream plans 01-02..01-06 consume this manifest"
tech-stack:
  added: []
  patterns:
    - "Stdlib + optional PyYAML (graceful import guard)"
    - "Sync bootstrap I/O (precedent: core/key_store.py, core/portability.py)"
    - "Deep-merge override pattern for user overrides over locked defaults"
key-files:
  created:
    - core/user_frood_dir.py
    - tests/test_user_frood_dir.py
  modified: []
decisions:
  - "PyYAML picked as primary serializer (already installed: PyYAML 6.0.3); JSON is a clean fallback — both parse through the same YAML loader."
  - "user_frood_dir() never raises: mkdir errors log a warning and fall through so bootstrap cannot crash the process."
  - "Malformed manifest is left on disk intentionally — overwriting a user's typo would be hostile; they fix it, we re-parse next run."
metrics:
  duration_minutes: 4
  completed_date: "2026-04-17"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
requirements_satisfied:
  - CLI-01
  - CLI-02
  - CLI-03
---

# Phase 01 Plan 01: User manifest + `~/.frood/` bootstrap Summary

**One-liner:** Added `core/user_frood_dir.py` exposing `DEFAULT_MANIFEST`, `user_frood_dir()`, `load_manifest()`, `save_manifest()` — a sync, stdlib + optional-PyYAML bootstrap that self-heals missing/partial/malformed `~/.frood/cli.yaml` so every downstream plan can trust a populated manifest dict.

## What Was Built

### `core/user_frood_dir.py` (new, 209 lines)

Public contract (the only exports downstream plans should use):

| Name | Signature | Behaviour |
| --- | --- | --- |
| `DEFAULT_MANIFEST` | `dict` | Locked shape per 01-CONTEXT.md D-01..D-03. Clis = claude-code + opencode (projects="auto"); warehouse = both flags True. |
| `user_frood_dir` | `(create: bool = False) -> Path` | Returns `Path.home() / ".frood"`. With `create=True`, calls `mkdir(parents=True, exist_ok=True)`; mkdir errors log a warning, never raise. |
| `load_manifest` | `() -> dict` | Missing file → writes defaults, returns a deep copy. Present + valid → deep-merges user values over a fresh default dict. Present + malformed → logs a `WARNING` on `frood.user_frood_dir` and returns a deep copy of defaults. |
| `save_manifest` | `(manifest: dict) -> None` | Serializes via PyYAML if available (human-friendly), else JSON. Writes UTF-8 with trailing newline. Parent dir is auto-created. I/O errors log a warning, never raise. |

Private helpers (not part of the contract):
- `_parse(raw, path)` — tries PyYAML first (handles YAML + JSON input), JSON fallback when PyYAML is absent; returns `None` on any failure.
- `_deep_merge(base, override)` — recursive dict merge; non-dict values replaced wholesale; `base` is mutated and returned.

### `tests/test_user_frood_dir.py` (new, 143 lines)

Seven tests covering all `<behavior>` bullets from Task 1 of the plan:

1. `test_user_frood_dir_returns_home_dot_frood` — path resolution is CWD-independent
2. `test_user_frood_dir_creates_dir_on_demand` — `create=True` bootstraps + is idempotent
3. `test_load_manifest_absent_returns_defaults_and_creates_file` — first-run defaults persist; returned dict is a deep copy (mutating it doesn't leak into `DEFAULT_MANIFEST`)
4. `test_load_manifest_partial_fills_defaults` — user override wins, missing keys backfill
5. `test_save_then_load_roundtrip` — lossless round-trip for a full dict including list values
6. `test_malformed_file_falls_back_to_defaults` — garbage input → defaults + warning, no crash
7. `test_warehouse_flags_accessible` — both warehouse toggles default to `True`

All tests redirect `Path.home` via `monkeypatch.setattr` (classmethod form) so they pass on Windows where `HOME` is not the canonical env var.

## Decisions Made

### Serializer: PyYAML preferred, JSON fallback

PyYAML 6.0.3 is already installed in the venv, so the module imports it at load time. If it were ever absent, the module degrades to JSON (which is a valid YAML subset, so `load_manifest()` still works either way). Per CONTEXT.md Claude's Discretion: "YAML preferred if PyYAML available, else JSON fallback is acceptable."

### Sync I/O is acceptable here

CLAUDE.md mandates async for tool I/O. This module runs at bootstrap (before the async loop is alive), matches the precedent of `core/key_store.py` and `core/portability.py`, and must stay free of circular-dep risk with `core.config`. Sync pathlib is the right call — explicitly called out in the plan's context block as the accepted pattern for bootstrap code.

### Malformed file → fall back, do NOT overwrite

If the user has a typo in their manifest, silently overwriting their file would destroy the edit they were trying to save. The module logs a warning, returns `DEFAULT_MANIFEST`, and leaves the malformed file untouched. This is the principle-of-least-surprise path.

### `load_manifest()` returns a deep copy

Callers may mutate the returned dict freely. Test 3 guards this — mutating `result["clis"]["claude-code"]["enabled"]` does not leak into the module constant.

## Deviations from Plan

None — plan executed exactly as written. Both tasks landed without triggering any of the deviation rules.

## Verification Results

| Command | Result |
| --- | --- |
| `python -m pytest tests/test_user_frood_dir.py -v` | 7 passed in 0.17s |
| `python -c "from core.user_frood_dir import load_manifest, save_manifest, DEFAULT_MANIFEST, user_frood_dir; print(user_frood_dir(), DEFAULT_MANIFEST)"` | Prints `C:\Users\rickw\.frood` + the defaults dict, no errors |
| `ruff check core/user_frood_dir.py tests/test_user_frood_dir.py` | All checks passed |

## Success Criteria — All Met

- CLI-01 — `user_frood_dir()` introduces the user-level `~/.frood/` surface (test 1, 2)
- CLI-02 — `DEFAULT_MANIFEST` encodes the locked shape (test 7, smoke command)
- CLI-03 — absent file auto-creates, partial file merges without crashing (tests 3, 4, 6)
- Downstream plans can `from core.user_frood_dir import load_manifest` and trust the contract (smoke command confirms import chain)

## Commits

| Task | Type | Hash | Message |
| --- | --- | --- | --- |
| 1 | test | `f1dbc45` | `test(01-01): add failing tests for user_frood_dir + cli.yaml manifest` |
| 2 | feat | `2038d32` | `feat(01-01): implement user_frood_dir + cli.yaml manifest` |

## Known Stubs

None — this plan delivers a complete, tested bootstrap module. No placeholder data, no "coming soon" strings, no unwired imports.

## Self-Check: PASSED

- `core/user_frood_dir.py` — FOUND
- `tests/test_user_frood_dir.py` — FOUND
- Commit `f1dbc45` — FOUND in git log
- Commit `2038d32` — FOUND in git log
- All 7 tests passing; lint clean; smoke command prints defaults
