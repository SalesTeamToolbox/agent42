# Phase 4: Context Engine - Context

**Gathered:** 2026-03-25 (auto mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

A single `agent42_context` MCP tool call returns a unified response merging jcodemunch code symbols, the active GSD workstream phase plan, and effectiveness-ranked tools/skills — all within a single token budget. Graceful degradation when any source is unavailable. Does NOT replace the existing `context` tool (ContextAssemblerTool) — wraps it.

</domain>

<decisions>
## Implementation Decisions

### Architecture approach
- **D-01:** Create a new `UnifiedContextTool` in `tools/unified_context.py` that wraps the existing `ContextAssemblerTool` rather than modifying it in-place
- **D-02:** `ContextAssemblerTool` (`context` MCP tool) continues to work unchanged — backward compatible
- **D-03:** `UnifiedContextTool` delegates to ContextAssemblerTool for memory + docs + git + skills, then adds jcodemunch + GSD + effectiveness on top

### jcodemunch integration
- **D-04:** Call jcodemunch via MCP client async protocol (`mcp` library's `ClientSession`) — proper MCP-to-MCP communication
- **D-05:** Graceful degradation: when jcodemunch server is unavailable (not running, connection refused), omit code symbols from response and return remaining sources without error
- **D-06:** Use `search_symbols` and `search_text` jcodemunch tools as primary code search actions, with `get_file_outline` for structural context

### GSD workstream state
- **D-07:** Read active workstream by scanning `.planning/workstreams/*/STATE.md` files for the one with `status != Complete`
- **D-08:** When a GSD workstream is active, include current phase goal and open plan items in the response only when query topic keyword-matches the phase name or plan task descriptions
- **D-09:** Parse STATE.md YAML frontmatter for `stopped_at`, `status`, phase/plan progress; read active phase PLAN.md for open task list

### Effectiveness ranking
- **D-10:** Use existing `EffectivenessStore.get_recommendations(task_type)` to rank tools/skills by success rate for the inferred task type
- **D-11:** Infer task type from query keywords using the same keyword-to-task-type mapping that `context-loader.py` hook uses (coding, debugging, research, etc.)
- **D-12:** Tools/skills with effectiveness history appear ranked above those without history for the detected task type

### Token budget allocation
- **D-13:** Rebalance token budget across 6 sources: memory 30%, code symbols 25%, GSD state 15%, git history 10%, skills 10%, effectiveness 10%
- **D-14:** When a source returns nothing (e.g., jcodemunch unavailable), redistribute its budget proportionally to remaining sources

### MCP tool registration
- **D-15:** Register as new `agent42_context` MCP tool name in `mcp_server.py`
- **D-16:** Keep existing `context` tool (ContextAssemblerTool) registered separately — no breaking change
- **D-17:** `agent42_context` parameters: `topic` (required), `scope`, `depth`, `max_tokens`, `task_type` (optional override for effectiveness ranking)

### Claude's Discretion
- MCP client connection management (persistent vs per-call, timeout values)
- Deduplication algorithm between jcodemunch results and memory results
- Exact keyword extraction and matching logic for GSD state relevance
- Output formatting and section ordering within the response

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture research
- `.planning/workstreams/gsd-and-jcodemunch-integration/research/ARCHITECTURE.md` — Unified context engine design, component boundaries, token budget allocation, build order recommendation
- `.planning/workstreams/gsd-and-jcodemunch-integration/research/FEATURES.md` — Feature dependency graph, jcodemunch integration path, effectiveness-aware injection design

### Existing context tool
- `tools/context_assembler.py` — Current ContextAssemblerTool implementation with 4 sources (memory, docs, git, skills). Budget allocation constants, deduplication via SHA256 hashing, keyword extraction logic
- `mcp_server.py` lines 254-266 — Registration of ContextAssemblerTool as `context` MCP tool with memory_store and workspace injection

### Effectiveness system
- `memory/effectiveness.py` — `EffectivenessStore.get_recommendations(task_type)` returns top tools ranked by success_rate. `get_aggregated_stats()` returns per-tool metrics

### jcodemunch integration
- `scripts/jcodemunch_index.py` — Existing jcodemunch subprocess integration pattern (MCP client via stdio)
- `.claude/hooks/context-loader.py` — Task type detection keywords and jcodemunch guidance patterns

### Requirements
- `.planning/workstreams/gsd-and-jcodemunch-integration/REQUIREMENTS.md` — CTX-01, CTX-02, CTX-03 requirement definitions
- `.planning/workstreams/gsd-and-jcodemunch-integration/ROADMAP.md` — Phase 4 success criteria (4 criteria)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ContextAssemblerTool` (`tools/context_assembler.py`): Full memory + docs + git + skills pipeline with dedup, token budgeting, keyword extraction — delegate to this for existing sources
- `EffectivenessStore.get_recommendations()` (`memory/effectiveness.py`): Ready-made tool/skill ranking by success rate per task type
- `_extract_keywords()` and `_truncate_to_budget()` in `context_assembler.py`: Reusable utility functions for keyword extraction and token truncation
- `context-loader.py` hook: Contains task type detection logic (keyword → task_type mapping) that can be extracted

### Established Patterns
- **Tool registration**: `requires = [...]` class variable for ToolContext injection, same pattern as ContextAssemblerTool
- **Graceful degradation**: All tools handle missing dependencies with try/except and `None` checks — jcodemunch must follow same pattern
- **SHA256 dedup**: ContextAssemblerTool uses `hashlib.sha256(text[:200])` for content deduplication across sources
- **Token budgeting**: Fraction-based allocation with `_truncate_to_budget()` per source

### Integration Points
- `mcp_server.py` `_register_tools()`: Add new UnifiedContextTool registration alongside existing ContextAssemblerTool
- `tools/registry.py`: ToolContext provides `memory_store`, `skill_loader`, `workspace` — may need `effectiveness_store` added
- `.planning/workstreams/*/STATE.md`: YAML frontmatter + markdown body, parseable with simple yaml/regex

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 04-context-engine*
*Context gathered: 2026-03-25*
