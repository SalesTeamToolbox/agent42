# Phase 21: Effectiveness Tracking and Learning Extraction - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Every completed task produces structured effectiveness records (SQLite) and a durable learning entry (HISTORY.md + Qdrant), with zero latency added to the tool execution path. Covers async tool tracking, EffectivenessStore, and post-task learning pipeline. No proactive injection or recommendations (those are Phases 22-23).

</domain>

<decisions>
## Implementation Decisions

### Tracking granularity
- Minimal schema per tool invocation: tool_name, task_type, task_id, success (bool), duration_ms, timestamp
- Track ALL tools — both built-in (ToolRegistry) and MCP tools (from external servers)
- Success determined by `ToolResult.success` field; for MCP tools, non-error responses count as success
- Instrumentation point: ToolRegistry wrapper — single hook wraps all tool execution, times it, and fires off the record
- Fire-and-forget via `asyncio.create_task()` — tool call returns before any SQLite write is awaited

### Learning extraction
- LLM-based extraction using `instructor` library + Pydantic schema
- LLM called via Agent42's provider router (uses existing tiered routing: Synthetic API, Gemini Flash, etc.)
- New Stop hook (separate from existing learning-engine.py and memory-learn.py — all three are complementary)
- Skip extraction for trivial sessions (<2 tool calls or <1 file modification)
- Extracted learning written to HISTORY.md in `[task_type][task_id][outcome]` format
- Extracted learning also indexed in Qdrant with task_id and task_type payload fields

### SQLite store design
- File location: `.agent42/effectiveness.db` (alongside existing Qdrant storage, already gitignored)
- Module: `memory/effectiveness.py` (EffectivenessStore class)
- No retention/cleanup policy — keep all records (even 100K rows is <10MB)
- Async writes via `asyncio.create_task()` — same pattern as `store.py` recall recording
- New dependency: `aiosqlite`
- Graceful degradation: if SQLite DB is missing or unwritable, tool execution continues normally (EFFT-05)

### Quarantine mechanics
- Observations counted by same-outcome tasks: a learning gets +1 when a later task of the same type produces a similar outcome
- Requires 3 independent task confirmations before quarantine lifts (LEARN-04)
- Quarantine state stored in Qdrant payload: `observation_count` and `confidence` fields on the learning entry
- Quarantined learnings have confidence capped at 0.6 — filtered out by downstream consumers that require higher confidence
- Once observation_count >= threshold: confidence unlocks to 1.0, normal lifecycle scoring takes over (decay, recall boosts)
- Config-driven: `LEARNING_MIN_EVIDENCE=3` and `LEARNING_QUARANTINE_CONFIDENCE=0.6` in .env (tunable without code changes)

### Claude's Discretion
- Exact instructor Pydantic schema for learning extraction
- EffectivenessStore table DDL beyond the agreed columns
- ToolRegistry wrapper implementation details (decorator vs middleware pattern)
- How to detect "similar outcome" for observation counting
- Stop hook implementation structure (standalone module vs integrated into existing hook)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Task lifecycle (Phase 20 foundation)
- `core/task_context.py` — `begin_task()`, `end_task()`, `get_task_context()` — task_id and task_type propagation via contextvars
- `core/task_types.py` — `TaskType` enum (coding, debugging, research, content, strategy, app_create, marketing, general)

### Memory layer
- `memory/store.py` — `MemoryStore`: `log_event_semantic()` for HISTORY.md writes, `build_context_semantic()` for task-type-filtered search, fire-and-forget pattern in `_record_recalls()`
- `memory/embeddings.py` — `EmbeddingStore`: `add_entry()` with metadata dict, `index_history_entry()` for Qdrant indexing
- `memory/qdrant_store.py` — `QdrantStore`: `upsert_vectors()` with payload merge, `search_with_lifecycle()` with task_type_filter

### Existing hooks (complementary, not replaced)
- `.claude/hooks/learning-engine.py` — Stop hook: file co-occurrences, task type frequency, skill candidates → `learned-patterns.json`
- `.claude/hooks/memory-learn.py` — Stop hook: session knowledge extraction → memory system

### Tool execution
- `tools/base.py` — `Tool` base class, `ToolResult` with `success` field
- Agent42's ToolRegistry — where the tracking wrapper will be added

### Provider routing
- Agent42's existing provider router — for instructor LLM calls (Synthetic API, Gemini Flash, etc.)

### Requirements
- `.planning/workstreams/per-project-task-memories/REQUIREMENTS.md` — EFFT-01 through EFFT-05, LEARN-01 through LEARN-05

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `asyncio.create_task()` fire-and-forget: used in `store.py` `_record_recalls()`, `heartbeat.py`, `agent_runtime.py` — proven pattern for non-blocking background writes
- `MemoryStore.log_event_semantic()`: writes to HISTORY.md and indexes in Qdrant — can be extended or called by the new extraction pipeline
- `get_task_context()`: returns `(task_id, task_type_string)` — ready for Phase 21 consumers to tag records
- Provider router: existing tiered routing for LLM calls — instructor can plug into this

### Established Patterns
- All I/O is async — `aiosqlite` fits naturally
- Graceful degradation: Redis, Qdrant already handle unavailability with fallbacks — SQLite store follows same pattern
- Qdrant payload merge: `**payload` in `upsert_vectors()` — adding observation_count/confidence fields is transparent
- Stop hooks: JSON on stdin, stderr for feedback, exit code 0 — new hook follows existing protocol

### Integration Points
- ToolRegistry: where tracking wrapper wraps all tool calls (timing + success recording)
- Stop event: where learning extraction triggers (after task completion)
- `end_task()`: clean boundary for flushing accumulated tool records to EffectivenessStore
- Qdrant payloads: where quarantine fields (observation_count, confidence) are stored alongside existing task_id/task_type

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 21-effectiveness-tracking-and-learning-extraction*
*Context gathered: 2026-03-17*
