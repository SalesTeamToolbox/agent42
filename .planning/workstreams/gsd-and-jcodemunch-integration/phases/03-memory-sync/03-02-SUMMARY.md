---
phase: 03-memory-sync
plan: "02"
subsystem: memory-sync
tags: [memory, node-sync, uuid, merge, conflict-resolution]
dependency_graph:
  requires: [03-01]
  provides: [entry-level-union-merge, _parse_memory_entries, _resolve_entry_conflict, _rebuild_memory, migrate-action]
  affects: [tools/node_sync.py, tests/test_memory_sync.py]
tech_stack:
  added: []
  patterns: [uuid-keyed-entry-merge, newest-wins-conflict-resolution, ssh-cat-fetch, section-order-preservation]
key_files:
  created: []
  modified:
    - tools/node_sync.py
    - tests/test_memory_sync.py
decisions:
  - "_merge() now uses SSH cat to fetch remote MEMORY.md content for in-memory entry-level diff, not stat/mtime"
  - "_resolve_entry_conflict() uses string comparison on ISO timestamps (lexicographic >= is correct for Z-suffix UTC)"
  - "History note appended inline to winner content with '> [prev: TS] TEXT' format"
  - "_rebuild_memory() appends section-less entries at the very end after all sections"
  - "_migrate_action() does NOT create sentinel on dry-run — only real migration creates it"
metrics:
  duration: 20 min
  completed: "2026-03-24"
  tasks_completed: 1
  files_changed: 2
---

# Phase 03 Plan 02: Entry-Level Union Merge in NodeSyncTool Summary

**One-liner:** Entry-level UUID-keyed union merge replacing mtime-wins strategy — lossless bidirectional sync with newest-wins conflict resolution and history notes.

## What Was Built

Replaced the file-level mtime-wins `_merge()` in `NodeSyncTool` with an entry-level union merge strategy. The new implementation fetches remote MEMORY.md via `ssh cat`, parses both files into dicts keyed by 8-hex UUID, performs a lossless union, resolves same-UUID conflicts by keeping the newest-timestamp version and appending the older content as an inline history note. Local section ordering is preserved in the rebuilt output; remote-only sections are appended at the end. A `migrate` action was added that converts old-format bullets to UUID format, with `--dry-run` support that previews changes without touching files or creating the sentinel.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Add failing test classes | 72686d8 | tests/test_memory_sync.py |
| 1 (GREEN) | Implement entry-level union merge | cddea78 | tools/node_sync.py |

## Decisions Made

- `_merge()` uses SSH `cat` to fetch remote content (not `stat`/mtime). This enables byte-for-byte comparison needed for UUID diff without a separate file transfer step.
- `_resolve_entry_conflict()` compares ISO 8601 timestamps as strings — lexicographic `>=` is correct for UTC timestamps in `YYYY-MM-DDTHH:MM:SSZ` format.
- Conflict history note format: `\n  > [prev: TS] OLD_TEXT` appended to winner's content, keeping it inline in the same bullet for searchability.
- `_rebuild_memory()` places section-less entries at the end after all named sections to keep structured content above unsectioned bullets.
- `_migrate_action()` dry-run returns immediately without writing files or creating the sentinel, ensuring idempotency.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing `from datetime import UTC, datetime` import**
- **Found during:** GREEN phase test run (`test_migrate_dry_run`)
- **Issue:** `datetime.now(UTC)` in `_migrate_action` raised `NameError: name 'datetime' is not defined` — the linter's post-write reformatting did not add the import automatically.
- **Fix:** Added `from datetime import UTC, datetime` to the import block in `tools/node_sync.py`.
- **Files modified:** `tools/node_sync.py`
- **Commit:** cddea78 (fixed inline before GREEN commit)

### Out-of-Scope Observations

- Pre-existing: `tests/test_app_git.py::TestAppManagerGit::test_persistence_with_git_fields` fails with `ValueError: path not in subpath` on Windows (tmpdir not under project root). Unrelated to this plan. Logged to deferred-items.

## Known Stubs

None — all merge logic is fully implemented and tested.

## Verification Results

```
tests/test_memory_sync.py::TestEntryParsing::test_parse_uuid_bullets PASSED
tests/test_memory_sync.py::TestEntryParsing::test_parse_with_sections PASSED
tests/test_memory_sync.py::TestEntryParsing::test_parse_ignores_non_uuid_lines PASSED
tests/test_memory_sync.py::TestEntryParsing::test_parse_normalizes_crlf PASSED
tests/test_memory_sync.py::TestUnionMerge::test_merge_disjoint_entries PASSED
tests/test_memory_sync.py::TestUnionMerge::test_merge_identical_entries PASSED
tests/test_memory_sync.py::TestUnionMerge::test_merge_missing_remote PASSED
tests/test_memory_sync.py::TestConflictResolution::test_conflict_newest_wins PASSED
tests/test_memory_sync.py::TestConflictResolution::test_conflict_preserves_history PASSED
tests/test_memory_sync.py::TestSectionOrderPreservation::test_local_section_order_preserved PASSED
tests/test_memory_sync.py::TestMigrateAction::test_migrate_dry_run PASSED
34 passed in 9.28s
```

## Self-Check: PASSED

- FOUND: tools/node_sync.py
- FOUND: tests/test_memory_sync.py
- FOUND: commit 72686d8 (RED phase)
- FOUND: commit cddea78 (GREEN phase)
