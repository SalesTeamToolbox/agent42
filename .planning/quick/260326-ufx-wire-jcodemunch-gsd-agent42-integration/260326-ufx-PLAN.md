# Quick Task 260326-ufx: Wire jcodemunch + GSD + Agent42 integration

## Task

Register `context-loader.py` hook in `settings.json` so jcodemunch context guidance is emitted on every UserPromptSubmit event. This was the missing link — the hook existed but was never registered.

## Tasks

### Task 1: Register context-loader.py in settings.json
- **files**: `.claude/settings.json`
- **action**: Add context-loader.py to UserPromptSubmit hooks array
- **verify**: JSON valid, hook appears in UserPromptSubmit section
- **done**: Hook registered with 15s timeout

### Task 2: Verify hook fires with jcodemunch guidance
- **files**: `.claude/hooks/context-loader.py`
- **action**: Test with tools, security, memory, and dashboard prompts
- **verify**: Each work type emits `[context-loader] jcodemunch guidance` with MCP tool recommendations
- **done**: All work types emit correct guidance
