# Phase 3: Memory Sync - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 03-memory-sync
**Mode:** auto (advisor research + auto-resolve)
**Areas discussed:** Entry format, Entry granularity, Conflict resolution, Legacy migration, Project namespace routing

---

## Entry Format

| Option | Description | Selected |
|--------|-------------|----------|
| File-level frontmatter only | YAML block at top with file UUID and updated_at | |
| Per-entry HTML comment tags | `<!-- uuid: ... -->` inline after each bullet | |
| Inline timestamp+short-UUID prefix | `- [ISO-timestamp 8chars] Content` on each bullet | ✓ |
| YAML frontmatter + per-entry comments | Both file-level and entry-level metadata | |

**User's choice:** [auto] Inline timestamp+short-UUID prefix (recommended default)
**Notes:** Consistent with HISTORY.md's existing `[timestamp]` pattern. Plus file-level YAML frontmatter for coarse conflict detection. 8-char hex prefix sufficient for per-file uniqueness.

---

## Entry Granularity

| Option | Description | Selected |
|--------|-------------|----------|
| Section-level | Each `## heading` = one entry with UUID | |
| Bullet-level | Each `- ` line = one entry with UUID | ✓ |
| Block-level | Blank-line-separated paragraphs = entries | |

**User's choice:** [auto] Bullet-level (recommended default)
**Notes:** Matches `append_to_section()` write atom. Two nodes adding different bullets to the same section merge cleanly via UUID union. Section-level insufficient because same-section concurrent edits lose one node's entries.

---

## Conflict Resolution

| Option | Description | Selected |
|--------|-------------|----------|
| Last-write-wins by timestamp | Newer timestamp overwrites older | |
| Keep both versions (conflict markers) | Duplicate entry with [CONFLICT] markers | |
| Newest wins + history note | Winner stays, loser demoted to inline history | ✓ |
| Field-level merge | Sub-entry structured diff | |

**User's choice:** [auto] Newest wins + append old as history note (recommended default)
**Notes:** Satisfies MEM-02 without cluttering MEMORY.md with permanent conflict markers. Older version recoverable via blockquote history note. Clean for 2-node manual sync workflow.

---

## Legacy Migration

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-migrate on first access | MemoryStore reads old format, auto-assigns UUIDs, writes back | ✓ |
| Explicit migration command | User runs `node_sync migrate` one-time | |
| Lazy migration | New entries get UUIDs; old entries get UUIDs when edited | |

**User's choice:** [auto] Auto-migrate on first access with sentinel guard (recommended default)
**Notes:** UUID5 deterministic from content — both nodes arrive at same UUIDs independently. Sentinel file prevents race conditions. Explicit `migrate --dry-run` kept as escape hatch.

---

## Project Namespace Routing

| Option | Description | Selected |
|--------|-------------|----------|
| MemoryTool creates stores on-demand | Lazy construction cached by project_id inside tool | |
| ToolContext factory method | Factory in `ToolContext.extras`, called with project_id | ✓ |
| Pre-register projects at startup | Static registry populated at boot | |

**User's choice:** [auto] ToolContext factory method (recommended default)
**Notes:** Clean boundary — MemoryTool asks for a store, factory knows how to construct one. Uses existing `ToolContext.extras` extensibility. Cache inside factory for repeated calls.

---

## Claude's Discretion

- Exact regex for tag parsing/stripping
- UUID4 vs UUID5 for new entries
- History note format details
- Migration parse order
- Embedding tag stripping approach

## Deferred Ideas

- Real-time WebSocket sync — future capability
- Qdrant cluster replication — out of scope
- Multi-user memory namespaces — v2 requirement (ENT-02)
