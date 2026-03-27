# Quick Task 260326-ufx: Wire jcodemunch + GSD + Agent42 integration — Summary

## What was done

**Problem:** `context-loader.py` hook existed in `.claude/hooks/` with full jcodemunch guidance logic but was **never registered** in `.claude/settings.json`. This meant:
- No jcodemunch tool call recommendations were emitted on user prompts
- No work-type detection was running (tools, security, memory, etc.)
- No GSD nudges for multi-step tasks
- No memory storage reminders for knowledge-producing work

**Fix:** Added `context-loader.py` to the `UserPromptSubmit` hooks array in `settings.json` with a 15-second timeout.

## What now works

On every user prompt, `context-loader.py` now:
1. **Detects work type** from prompt keywords (tools, security, providers, config, dashboard, memory, skills, testing, async, deployment, structure, gsd)
2. **Loads relevant lessons** from `.claude/lessons.md` sections matching the work type
3. **Loads reference docs** from `.claude/reference/` (pitfalls-archive, conventions, terminology, etc.)
4. **Emits jcodemunch guidance** — specific MCP tool calls to run before starting work (e.g., `search_symbols`, `get_file_outline`)
5. **GSD nudge** for multi-step prompts when no active workstream
6. **Memory reminder** for knowledge-producing tasks (debug, fix, deploy, etc.)

## Integration chain

```
User prompt → UserPromptSubmit hook
  → conversation-accumulator.py (captures prompt)
  → memory-recall.py (recalls relevant memories)
  → proactive-inject.py (injects learned patterns)
  → context-loader.py (NEW — detects work type, emits jcodemunch guidance)
  → Claude receives all context + jcodemunch tool recommendations
  → Claude uses jcodemunch MCP tools before reading files
  → PostToolUse hooks track token savings + detect drift
  → Stop hooks re-index if structure changed
```

## Files changed

- `.claude/settings.json` — Added context-loader.py to UserPromptSubmit hooks

## Verified

- Hook fires correctly for tools, security, dashboard, memory work types
- jcodemunch guidance emits with correct MCP tool names and parameters
- Memory reminder triggers on knowledge-producing prompts
- settings.json remains valid JSON
