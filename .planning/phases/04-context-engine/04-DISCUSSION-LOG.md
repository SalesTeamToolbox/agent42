# Phase 4: Context Engine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-25
**Phase:** 04-context-engine
**Mode:** auto
**Areas discussed:** Architecture approach, jcodemunch integration, GSD state sourcing, Effectiveness ranking, Token budget allocation, MCP tool naming

---

## Architecture Approach

| Option | Description | Selected |
|--------|-------------|----------|
| New UnifiedContextTool wrapping existing | Create `tools/unified_context.py` that delegates to ContextAssemblerTool and adds new sources | ✓ |
| Extend ContextAssemblerTool in-place | Modify existing tool to add jcodemunch + GSD sources directly | |
| Replace ContextAssemblerTool entirely | Remove old tool, build new one from scratch | |

**User's choice:** [auto] New UnifiedContextTool wrapping existing (recommended default — preserves backward compatibility, per ARCHITECTURE.md research)
**Notes:** Research ARCHITECTURE.md explicitly recommends: "Does NOT replace ContextAssemblerTool. UnifiedContextTool wraps it."

---

## jcodemunch Integration

| Option | Description | Selected |
|--------|-------------|----------|
| MCP client async call | Use `mcp` library's ClientSession to talk to jcodemunch MCP server | ✓ |
| Direct SQLite DB access | Read jcodemunch's index database directly | |
| Subprocess CLI call | Shell out to jcodemunch binary | |

**User's choice:** [auto] MCP client async call with graceful degradation (recommended default — proper protocol, decoupled from internal schema)
**Notes:** Graceful degradation mandatory per success criterion 4. jcodemunch_index.py has existing subprocess pattern as reference.

---

## GSD State Sourcing

| Option | Description | Selected |
|--------|-------------|----------|
| Active workstream STATE.md + phase PLAN.md | Scan for active workstream, keyword-match query against phase goals/tasks | ✓ |
| All workstreams summarized | Include summary of all workstreams regardless of query topic | |
| GSD state only when explicit flag passed | Require `include_gsd=true` parameter | |

**User's choice:** [auto] Active workstream STATE.md + current phase PLAN.md, keyword-match query (recommended default — relevant context without noise)
**Notes:** Only surfaces GSD context when query topic actually matches current work. Avoids injecting irrelevant planning data.

---

## Effectiveness Ranking

| Option | Description | Selected |
|--------|-------------|----------|
| EffectivenessStore.get_recommendations() | Use existing API with task_type inferred from query keywords | ✓ |
| Static ranking from config | Pre-configured tool priority list per task type | |
| No ranking, alphabetical | List all tools without effectiveness weighting | |

**User's choice:** [auto] Use EffectivenessStore.get_recommendations() with inferred task_type (recommended default — existing API, proven data)
**Notes:** Task type inference reuses logic from context-loader.py hook.

---

## Token Budget Allocation

| Option | Description | Selected |
|--------|-------------|----------|
| Rebalanced 6-source split | memory 30%, code 25%, GSD 15%, git 10%, skills 10%, effectiveness 10% | ✓ |
| Keep current 4-source + add fixed | Keep existing fractions, add jcodemunch/GSD as fixed-size extras | |
| Dynamic budget based on source availability | Allocate proportionally based on which sources return data | |

**User's choice:** [auto] Rebalanced 6-source split (recommended default — explicit allocation, predictable output)
**Notes:** Budget redistribution when a source is unavailable (D-14) provides dynamic fallback within the fixed allocation model.

---

## MCP Tool Naming

| Option | Description | Selected |
|--------|-------------|----------|
| New `agent42_context` alongside existing `context` | Two separate MCP tools, different capabilities | ✓ |
| Replace `context` with `agent42_context` | Single tool, breaking change for existing users | |
| Rename existing to `agent42_context` | Alias the old tool under new name | |

**User's choice:** [auto] Register as new `agent42_context` MCP tool; keep existing `context` unchanged (recommended default — per requirements CTX-01, no breaking change)
**Notes:** Requirements specify `agent42_context` as the tool name. Existing `context` tool continues for backward compatibility.

---

## Claude's Discretion

- MCP client connection management (persistent vs per-call, timeout values)
- Deduplication algorithm between jcodemunch results and memory results
- Keyword extraction and matching logic for GSD state relevance
- Output formatting and section ordering

## Deferred Ideas

None — auto mode stayed within phase scope.
