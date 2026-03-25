# Phase 3: Memory Sync - Context

**Gathered:** 2026-03-24 (auto mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Memory entries carry stable identifiers so sync across nodes produces a lossless union of all entries, and MemoryTool isolates memories by project namespace when a project parameter is provided. Replaces the current mtime-wins strategy with entry-level union merge. Does NOT include real-time sync, Qdrant cluster replication, or multi-user memory namespaces.

</domain>

<decisions>
## Implementation Decisions

### Entry format
- **D-01:** Each MEMORY.md bullet gets an inline timestamp+short-UUID prefix: `- [2026-03-24T14:22:10Z a4f7b2c1] Content text`. The 8-char hex is the first 8 chars of a UUID4, sufficient for per-file uniqueness during merge.
- **D-02:** MEMORY.md gets a file-level YAML frontmatter block (`---` delimited) recording the file's own UUID and `last_modified` timestamp. NodeSyncTool uses this for fast coarse conflict detection before doing entry-level diff.
- **D-03:** The inline `[timestamp uuid]` pattern mirrors HISTORY.md's existing `[timestamp] event_type` convention — one consistent style across both memory files.

### Entry granularity
- **D-04:** Each `- ` bullet line is one entry with its own UUID. This is the atom that `append_to_section()` already writes and is the natural unit for union merge.
- **D-05:** Section headings (`## Section Name`) are structural grouping only — they do not get UUIDs. The merge algorithm operates on bullets within sections.

### Conflict resolution (same-entry edits)
- **D-06:** When two nodes have the same UUID but different content, newest wins by timestamp. The older version is appended as an inline history note under the entry: `> [prev: <node>, <timestamp>] <old text>`.
- **D-07:** This satisfies MEM-02 ("no entry from either node is silently lost") — the older version is demoted, not deleted. Users can clean up history notes at their discretion.
- **D-08:** When two nodes have entries that don't exist on the other side (different UUIDs), both are kept — standard union merge. This is the common case.

### Legacy entry migration
- **D-09:** Auto-migrate on first access — MemoryStore reads old-format bullets (no UUID), assigns UUIDs deterministically via UUID5 from content hash, writes back with the new format. Both nodes independently arrive at the same UUIDs for the same content.
- **D-10:** Migration is guarded by a sentinel file (`.agent42/memory/.migration_v1`) to prevent race conditions between cc-memory-sync hook and node_sync operating simultaneously.
- **D-11:** A `node_sync migrate --dry-run` escape hatch is available for operators who want to preview the transformation before it happens automatically.

### Project namespace routing
- **D-12:** MemoryTool routes to ProjectMemoryStore via a factory method stored in `ToolContext.extras["project_memory_factory"]`. The factory is a callable `(project_id: str) -> ProjectMemoryStore` that captures `base_dir`, `global_store`, `qdrant_store`, and `redis_backend` at registration time.
- **D-13:** MemoryTool adds `"project_memory_factory"` to its `requires` list. When `project != "global"`, `execute()` calls the factory and routes all operations through the returned ProjectMemoryStore.
- **D-14:** The factory maintains an internal `dict[str, ProjectMemoryStore]` cache keyed by `project_id` so repeated calls within a session don't reconstruct stores.
- **D-15:** When `project == "global"` (the default), existing behavior is unchanged — routes to the global MemoryStore as today. Full backward compatibility per MEM-03.

### Claude's Discretion
- Exact regex pattern for parsing/stripping `[timestamp uuid]` tags during embedding indexing
- Whether to use `uuid.uuid4().hex[:8]` or `uuid.uuid5(namespace, content).hex[:8]` for new entries (both work; uuid5 is deterministic, uuid4 is unique)
- Exact format of the history note for conflict resolution (indented blockquote vs comment)
- Order of migration steps during auto-migrate (parse sections first, then bullets, or single pass)
- How `EmbeddingStore.index_memory()` strips tags before embedding (regex vs split)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Memory sync (modify targets)
- `tools/node_sync.py` — Current sync tool with mtime-wins `_merge()` at line 218. Replace with entry-level union merge using UUID matching.
- `memory/store.py` — MemoryStore with `append_to_section()`, `update_memory()`, `read_memory()`. Must add UUID+timestamp injection on write and auto-migration on read.
- `tools/memory_tool.py` — MemoryTool with `project` parameter already defined but not routed. Wire to ProjectMemoryStore via factory.

### Project memory (integration point)
- `memory/project_memory.py` — ProjectMemoryStore already exists with per-project directories and global fallback. Factory wraps this.

### Embedding pipeline (update for tag stripping)
- `memory/embeddings.py` — EmbeddingStore with `index_memory()` that chunks MEMORY.md. Must strip `[timestamp uuid]` tags before embedding.

### CC memory sync (verify compatibility)
- `.claude/hooks/cc-memory-sync.py` — PostToolUse hook that detects CC memory file writes. Verify new format doesn't break detection.
- `.claude/hooks/cc-memory-sync-worker.py` — Background worker with `parse_frontmatter()` already stubbed. Verify compatibility with file-level frontmatter.

### Requirements
- `.planning/workstreams/gsd-and-jcodemunch-integration/REQUIREMENTS.md` — MEM-01, MEM-02, MEM-03 acceptance criteria.

### Prior phase context
- `.planning/workstreams/gsd-and-jcodemunch-integration/phases/01-setup-foundation/01-CONTEXT.md` — Phase 1 decisions on setup.sh, stdlib-only helpers, health checks.
- `.planning/workstreams/gsd-and-jcodemunch-integration/phases/02-windows-claude-md/02-CONTEXT.md` — Phase 2 decisions on Windows compatibility, CLAUDE.md generation.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NodeSyncTool._merge()` (node_sync.py:218): Current merge logic with rsync + mtime comparison. Refactor to entry-level merge using UUID matching instead of whole-file mtime.
- `MemoryStore.append_to_section()` (store.py:~119): Injects `- {content}` bullets. Add UUID+timestamp prefix here.
- `ProjectMemoryStore` (project_memory.py): Complete per-project memory wrapper with global fallback. Ready to wire into MemoryTool via factory.
- `cc-memory-sync-worker.parse_frontmatter()`: Already supports YAML frontmatter parsing — can handle new file-level frontmatter.
- `_make_point_id()` in embeddings.py: Deterministic point ID from `source:text` — pattern to follow for UUID generation.
- UUID5 namespace `a42a42a4-2a42-4a42-a42a-42a42a42a42a` in memory_tool.py: Existing namespace for deterministic UUIDs in the cc-memory-sync worker.

### Established Patterns
- Markdown files as source of truth, Qdrant vectors re-derived via `reindex_memory()` after any sync operation.
- `ToolContext.extras` dict for extensible tool injection — use for project_memory_factory.
- HISTORY.md uses `[timestamp]` headers — extend the same convention to MEMORY.md bullets.
- Fire-and-forget reindex: `_schedule_reindex()` pattern in MemoryStore.
- Async I/O everywhere — new sync merge logic must remain async-compatible.

### Integration Points
- `agent42.py _register_tools()`: Where MemoryTool gets `memory_store` injection. Add `project_memory_factory` to extras here.
- `ToolContext._instantiate()`: Pulls from `extras` dict for tool construction — already supports this pattern.
- `setup.sh`: No changes needed for Phase 3 — memory sync is runtime, not setup-time.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

- Real-time memory sync via WebSocket — out of scope per REQUIREMENTS.md (periodic sync sufficient for 2-node setup)
- Qdrant cluster replication — out of scope per REQUIREMENTS.md (flat files as source of truth)
- Multi-user memory namespaces (ENT-02) — v2 requirement, not this milestone
- MEMORY.md auto-update without human review — out of scope per REQUIREMENTS.md (approval gate mandatory)

</deferred>

---

*Phase: 03-memory-sync*
*Context gathered: 2026-03-24*
