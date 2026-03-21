# Phase 02: GSD Auto-Activation - Research

**Researched:** 2026-03-20
**Domain:** Claude Code skills, context-loader hooks, CLAUDE.md conventions
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Multi-step detection uses keyword + structural heuristic, NOT an LLM call. Keywords: "build", "create", "implement", "refactor", "add feature", "set up", "migrate", "convert", "redesign", "scaffold", framework names ("flask app", "django", "react app"), and planning language ("plan", "roadmap", "milestone").
- **D-02:** Trivial task detection (skip GSD): prompts < 30 chars, questions starting with "what", "how", "why", "explain", "show me", slash commands, single-file edits explicitly named ("fix the typo in X"), and debugging/error messages.
- **D-03:** Ambiguous cases default to suggesting GSD with an opt-out — "This looks like a multi-step task. I'll use GSD to plan and execute. Say 'just do it' to skip."
- **D-04:** The always-on skill provides system-level instructions that Claude reads on every prompt. It does NOT produce visible output — it shapes Claude's behavior silently.
- **D-05:** When GSD activates, Claude's first response should naturally mention the approach: "I'll use GSD to break this down into phases..." — not a robotic "GSD AUTO-ACTIVATED" banner.
- **D-06:** The context-loader hook adds a brief stderr nudge when it detects a multi-step prompt: `[agent42] Tip: This looks like a multi-step task — /gsd:new-project or /gsd:quick available`. One line, not intrusive.
- **D-07:** Add a `## Development Methodology` section to CLAUDE.md that establishes GSD as the default process. Content: when to use GSD (multi-step), when to skip (trivial), key commands reference, and a note that Agent42's always-on skill handles auto-detection.
- **D-08:** The CLAUDE.md section is appended to the existing file — do not reorganize or rewrite existing content.
- **D-09:** The always-on skill (`gsd-auto-activate`) handles behavioral instructions — tells Claude HOW to think about task complexity and WHEN to suggest GSD. This is the primary mechanism.
- **D-10:** The context-loader hook enhancement is secondary — it adds a subtle stderr hint for multi-step prompts. The hook does NOT make decisions; it surfaces information.
- **D-11:** The always-on skill should reference GSD commands by name (`/gsd:new-project`, `/gsd:quick`, `/gsd:plan-phase`) so Claude knows what to suggest.
- **D-12:** After skipping GSD for a trivial task, if the task turns out to be complex mid-execution, Claude should suggest pivoting: "This is getting complex — want me to switch to GSD?"
- **D-13:** Never auto-activate GSD inside an already-running GSD workflow (check for `.planning/STATE.md` with active phase status).

### Claude's Discretion

- Exact keyword list and threshold tuning for multi-step detection
- How to phrase the mid-task pivot suggestion
- Whether to include a "GSD cheat sheet" in CLAUDE.md or keep it minimal
- Skill content structure and instruction ordering

### Deferred Ideas (OUT OF SCOPE)

- GSD auto-workstream creation (listed in REQUIREMENTS.md as out of scope for v1)
- Dashboard GSD roadmap progress display (Phase 4)
- Workstream switcher in dashboard sidebar (GSD-05, GSD-06 — v2 requirements)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GSD-01 | Always-on skill instructs Claude to use GSD methodology for multi-step coding/planning tasks | Skill `always: true` frontmatter confirmed working — `test_always_load` test verifies this pattern. New skill at `.claude/skills/gsd-auto-activate/SKILL.md`. |
| GSD-02 | CLAUDE.md section establishes GSD as the default process when Agent42 is installed | CLAUDE.md uses append-only pattern (D-08). Section under 30 lines, developer-skim friendly. Standard markdown append. |
| GSD-03 | Context-loader hook detects coding/planning task prompts and nudges toward GSD workflow | `context-loader.py` WORK_TYPE_KEYWORDS pattern is the exact extension point. Add `gsd` work type with multi-step keywords. Output to stderr, exit 0. |
| GSD-04 | Auto-activation is smart — skips GSD for trivial/single-step tasks (quick questions, simple edits) | Trivial skip logic belongs in the skill instructions (behavioral) and in the hook detection logic (structural heuristics per D-01/D-02). |
</phase_requirements>

---

## Summary

This phase creates three artifacts: a new always-on Claude Code skill, a CLAUDE.md section append, and an enhancement to the context-loader hook. All three are pure configuration/text changes — no new Python modules, no new tools, no schema changes.

The skill mechanism is well-understood and battle-tested in this codebase. The `always: true` frontmatter flag causes `SkillLoader.get_for_task_type()` to return the skill for any task type, meaning Claude receives its instructions on every prompt regardless of context. The test suite (`test_skill_loader.py::TestSkillLoader::test_always_load`) confirms this behavior.

The context-loader hook already has a fully established pattern for adding new work types — it's a dict entry in `WORK_TYPE_KEYWORDS` plus optional entries in `REFERENCE_FILES` and `JCODEMUNCH_GUIDANCE`. The new `gsd` work type follows exactly this pattern, outputting a one-line stderr nudge when multi-step keywords are detected.

**Primary recommendation:** Build in three discrete tasks: (1) create skill, (2) append CLAUDE.md section, (3) extend context-loader hook. Each task is self-contained and independently testable.

---

## Standard Stack

### Core

| Component | Version/Location | Purpose | Why Standard |
|-----------|-----------------|---------|--------------|
| Claude Code skill (SKILL.md) | YAML frontmatter + markdown | Behavioral instructions injected into Claude's context | Existing pattern in `.claude/skills/`; `always: true` is the always-on mechanism |
| context-loader.py | `.claude/hooks/context-loader.py` | Keyword-based work type detection + stderr hints | Already registered in `settings.json` for UserPromptSubmit |
| CLAUDE.md | Project root `CLAUDE.md` | Persistent developer-facing documentation | Established project convention |

### Supporting

| Component | Location | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `tests/test_skill_loader.py` | `tests/` | Validates skill loading behavior | Extend with test for `gsd-auto-activate` always-load behavior |
| `.claude/settings.json` | Project root | Hook registration | No changes needed — context-loader is already registered |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Always-on skill | LLM call to classify task type | LLM call adds latency and cost on every prompt. Decision D-01 explicitly rejects LLM classification. |
| Keyword heuristic in hook | Regex-based pattern matching | Regex is harder to read/maintain; keyword list in dict is already the project standard. |

---

## Architecture Patterns

### Files Being Created / Modified

```
.claude/
├── skills/
│   └── gsd-auto-activate/       # NEW — always-on skill directory
│       └── SKILL.md             # NEW — YAML frontmatter + behavioral instructions
├── hooks/
│   └── context-loader.py        # MODIFY — add "gsd" work type to WORK_TYPE_KEYWORDS
CLAUDE.md                        # MODIFY — append ## Development Methodology section
tests/
└── test_context_loader.py       # NEW or MODIFY — test for gsd work type detection
```

No new Python modules. No new test fixture files needed beyond what conftest.py provides.

### Pattern 1: Always-On Skill via `always: true`

**What:** A skill with `always: true` in its YAML frontmatter is returned by `SkillLoader.get_for_task_type()` for any task type, including unknown ones. This means Claude receives the skill's instructions on every prompt.

**When to use:** For behavioral guidance that should apply universally, regardless of what specific task Claude is working on.

**Verified in:** `tests/test_skill_loader.py::TestSkillLoader::test_always_load` (line 74–84):
```python
# Source: tests/test_skill_loader.py
def test_always_load(self, tmp_path):
    _write_skill(
        tmp_path,
        "always-skill",
        "---\nname: always-skill\nalways: true\n---\n\nAlways loaded.",
    )
    loader = SkillLoader([tmp_path])
    loader.load_all()
    result = loader.get_for_task_type("anything")
    assert len(result) == 1
    assert result[0].name == "always-skill"
```

**New skill frontmatter pattern:**
```yaml
---
name: gsd-auto-activate
description: Instructs Claude to use GSD methodology for multi-step tasks
always: true
---
```
Note: `task_types` is omitted when `always: true` — the skill loads for all task types.

### Pattern 2: Adding a Work Type to context-loader.py

**What:** Add a new entry to `WORK_TYPE_KEYWORDS` dict with `keywords`, `files`, and `section` keys. Optionally add to `REFERENCE_FILES` and `JCODEMUNCH_GUIDANCE`.

**When to use:** When a new category of work needs detection-and-hint behavior.

**Verified in:** `context-loader.py` lines 22–194. Existing `memory` work type is a close analog (line 153–166):
```python
# Source: .claude/hooks/context-loader.py
"memory": {
    "keywords": [
        "memory", "session", "embedding", "qdrant", "redis",
        "semantic", "vector", "consolidat",
    ],
    "files": ["memory/"],
    "section": "Memory Patterns",
},
```

**New gsd work type entry:**
```python
"gsd": {
    "keywords": [
        "build", "create", "implement", "refactor", "add feature",
        "set up", "migrate", "convert", "redesign", "scaffold",
        "flask app", "django", "react app", "vue app", "fastapi",
        "plan", "roadmap", "milestone", "phases", "workstream",
    ],
    "files": [],      # no file-path-based detection for GSD
    "section": None,  # no lessons.md section to load
},
```

**Stderr nudge pattern** (one-liner, follows `_emit_memory_nudge` precedent):
```python
# Output: one line to stderr, ignorable
print(
    "[agent42] Tip: This looks like a multi-step task — "
    "/gsd:new-project or /gsd:quick available",
    file=sys.stderr,
)
```

The nudge is emitted only when work type "gsd" is detected AND no other indicator of an already-active GSD session exists (check for `.planning/STATE.md`).

### Pattern 3: CLAUDE.md Section Append

**What:** Append a new `## Development Methodology` section to the end of CLAUDE.md (before the `## Common Pitfalls` table is NOT required — append after existing content).

**Constraint (D-08):** Append only — do not reorganize or rewrite existing sections.

**Constraint (D-07):** Section under 30 lines. Covers: when to use GSD, when to skip, key commands.

**Structure:**
```markdown
## Development Methodology

Agent42 uses **GSD (Get Shit Done)** as the default methodology for multi-step work.
The always-on `gsd-auto-activate` skill handles detection automatically.

### When to Use GSD

Use GSD for any task involving multiple files, phases, or coordinated steps:
- New features, tools, skills, or providers
- Refactors touching 3+ files
- Architecture changes or migrations
- Any task where you'd naturally say "first I need to... then..."

### When to Skip GSD

Skip GSD for trivial tasks (Claude handles these directly):
- Quick questions ("what does X do?")
- Single-file typo/style fixes
- Configuration lookups
- Debugging a specific known error

### Key GSD Commands

| Command | When to Use |
|---------|-------------|
| `/gsd:new-project` | Initialize a new multi-phase workstream |
| `/gsd:quick` | Ad-hoc task with GSD tracking but no full phase plan |
| `/gsd:plan-phase` | Plan a specific phase when already in a workstream |
| `/gsd:execute-phase` | Execute a planned phase |
| `/gsd:next` | Advance to the next task in the current plan |
```

### Anti-Patterns to Avoid

- **Visible "activated" banners:** The skill must shape behavior silently. Claude's first response should naturally incorporate GSD thinking, not announce it. Per D-04 and D-05.
- **Firing the hint inside active GSD sessions:** The hook should check for `.planning/STATE.md` before emitting the GSD nudge. Firing inside an active session creates noise. Per D-13.
- **LLM classification:** No LLM calls for detection. Keyword heuristics only. Per D-01.
- **Modifying `settings.json`:** The context-loader is already registered for `UserPromptSubmit`. Adding a new hook registration is unnecessary.
- **Putting `section:` in the gsd work type:** There is no `## GSD Patterns` section in `lessons.md`. Set `section: None` to avoid loading non-existent content.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Always-on behavior | Custom hook that injects text into every prompt | Skill with `always: true` | SkillLoader already handles this; tested, integrated with agent context assembly |
| Keyword detection | New Python module | Add entry to WORK_TYPE_KEYWORDS dict | Pattern is already established; one dict entry is the entire implementation |
| GSD session detection | Parse active STATE.md from scratch | Check file existence + `status` field in existing state file | Simple `os.path.exists()` + line scan; no new parsing code needed |

---

## Common Pitfalls

### Pitfall 1: Setting `task_types` When `always: true`

**What goes wrong:** Skill with both `always: true` and `task_types: [...]` — the `always` flag makes task_types irrelevant. Not harmful but confusing.

**How to avoid:** When `always: true`, omit `task_types` entirely. The `test_always_load` test confirms always-skills load regardless of task type.

### Pitfall 2: Hook Fires Inside Active GSD Session

**What goes wrong:** User is mid-execution of a GSD plan; they ask a sub-task question. Hook detects keywords ("implement", "refactor") and fires the "try /gsd:new-project" nudge. This is noise and potentially confusing.

**How to avoid:** In the hook's GSD nudge logic, check for `.planning/` directory with an active `STATE.md`. If found with a status indicating active work (not "unknown" or "completed"), suppress the nudge.

**Detection:**
```python
import os

def _is_gsd_active(project_dir):
    """Return True if a GSD workstream is currently active."""
    state_path = os.path.join(project_dir, ".planning", "active-workstream")
    if os.path.exists(state_path):
        try:
            with open(state_path) as f:
                content = f.read().strip()
            return bool(content)  # non-empty = active workstream
        except OSError:
            pass
    return False
```

### Pitfall 3: Skill Instructions Too Prescriptive

**What goes wrong:** Skill says "you MUST use GSD for everything" — Claude starts pulling out full phase plans for a 3-line bug fix.

**How to avoid:** Skill instructions should be written in advisory tone ("for multi-step work, reach for GSD...") not imperative tone ("ALWAYS use GSD"). The D-02 trivial-skip criteria are the escape valve — make sure they're clearly expressed in the skill.

### Pitfall 4: GSD Keyword List Too Broad

**What goes wrong:** "create" matches "create a variable", triggering the GSD nudge for a trivial inline edit suggestion.

**How to avoid:** The hook's trivial-skip criteria (D-02 — prompt < 30 chars, starts with "what/how/why/explain") run BEFORE the multi-step detection. Ensure the trivial check short-circuits first. The `_emit_memory_nudge` function in context-loader.py already demonstrates this pattern (line 476–478):
```python
if not prompt or len(prompt.strip()) < 20:
    return
if prompt.strip().startswith("/"):
    return
```

Apply the same guard before the GSD nudge.

### Pitfall 5: REFERENCE_FILES Entry for `gsd` Work Type Loads Missing Files

**What goes wrong:** Adding `"gsd": ["gsd-patterns.md"]` to REFERENCE_FILES when that file doesn't exist. `load_reference_files()` silently skips missing files (line 394: `if os.path.exists(path):`), so this is harmless — but wastes dict maintenance.

**How to avoid:** Either create the reference file or omit the `REFERENCE_FILES` entry for `gsd`. Given this phase is creating the infrastructure, start with no reference file and add one later if patterns accumulate.

---

## Code Examples

### Complete SKILL.md for gsd-auto-activate

```markdown
---
name: gsd-auto-activate
description: Instructs Claude to use GSD methodology for multi-step tasks
always: true
---

# GSD Auto-Activation

When working in this project, use the GSD (Get Shit Done) structured workflow
for any multi-step task. This is the default methodology — not an optional enhancement.

## Activate GSD When You See

- Multiple files need to be created or modified
- The task has a clear sequence of steps ("first..., then..., finally...")
- Keywords like: build, create, implement, refactor, add feature, set up,
  migrate, convert, redesign, scaffold, plan, roadmap
- Framework scaffolding: Flask app, Django app, React app, FastAPI service
- The work would naturally break into phases

**Use `/gsd:new-project`** to start a full workstream, or **`/gsd:quick`** for
a single self-contained task that still benefits from structured tracking.

## Skip GSD For

- Prompts under ~30 characters
- Questions beginning with "what", "how", "why", "explain", "show me"
- Single-file fixes where the target file is explicitly named ("fix the typo in X")
- Slash commands (/, /help, /gsd:...)
- Debugging a specific error message

## Mid-Task Pivot

If a task that started simple reveals unexpected complexity, suggest:
> "This is getting more involved — want me to switch to GSD for better tracking?"

## Already In GSD

If `.planning/active-workstream` exists and is non-empty, a GSD workstream is
already active. Do not suggest starting a new one. Continue within the current
workflow.

## Natural Language

When GSD activates, mention it naturally in your first response:
"I'll use GSD to break this into phases..." — not a banner or announcement.
```

### Context-Loader gsd Work Type Entry

```python
# Add to WORK_TYPE_KEYWORDS in .claude/hooks/context-loader.py
"gsd": {
    "keywords": [
        "build",
        "create",
        "implement",
        "refactor",
        "add feature",
        "set up",
        "migrate",
        "convert",
        "redesign",
        "scaffold",
        "flask app",
        "django",
        "react app",
        "vue app",
        "fastapi app",
        "plan",
        "roadmap",
        "milestone",
        "phases",
        "workstream",
    ],
    "files": [],
    "section": None,
},
```

### GSD Nudge Emission in context-loader.py

The nudge should be implemented as a new function `_emit_gsd_nudge(prompt, project_dir)`,
called from `main()` after work type detection, following the pattern of `_emit_memory_nudge()`:

```python
def _emit_gsd_nudge(prompt, project_dir):
    """Suggest GSD for multi-step prompts when not already in a GSD session."""
    if not prompt or len(prompt.strip()) < 30:
        return
    stripped = prompt.strip()
    if stripped.startswith("/"):
        return
    # Skip trivial question patterns
    trivial_starts = ("what ", "how ", "why ", "explain ", "show me ", "what's ")
    if any(stripped.lower().startswith(t) for t in trivial_starts):
        return
    # Skip if GSD session already active
    active_ws = os.path.join(project_dir, ".planning", "active-workstream")
    if os.path.exists(active_ws):
        try:
            with open(active_ws) as f:
                if f.read().strip():
                    return  # Active workstream — no nudge
        except OSError:
            pass
    # Only nudge if gsd work type was detected
    # (caller passes detected flag)
    print(
        "[agent42] Tip: This looks like a multi-step task — "
        "/gsd:new-project or /gsd:quick available",
        file=sys.stderr,
    )
```

Call site in `main()`:
```python
# After work_types detection, before lessons/references loading
if "gsd" in work_types:
    _emit_gsd_nudge(prompt, project_dir)
    work_types.discard("gsd")  # Don't load lessons/references for gsd (none exist)
```

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pytest with asyncio_mode = "auto" |
| Config file | `pyproject.toml` |
| Quick run command | `python -m pytest tests/ -x -q` |
| Full suite command | `python -m pytest tests/ -v` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GSD-01 | `gsd-auto-activate` skill loads with `always: true` for any task type | unit | `python -m pytest tests/test_skill_loader.py -x -q -k "gsd"` | Wave 0 — extend existing test file |
| GSD-02 | CLAUDE.md contains `## Development Methodology` section | smoke | `python -m pytest tests/test_gsd_autoactivation.py::test_claude_md_has_methodology_section -x` | Wave 0 — new file |
| GSD-03 | context-loader detects multi-step keywords and emits GSD hint to stderr | unit | `python -m pytest tests/test_context_loader.py -x -q -k "gsd"` | Wave 0 — new file or extend |
| GSD-04 | Trivial prompts do not trigger GSD nudge; active workstream suppresses nudge | unit | `python -m pytest tests/test_context_loader.py -x -q -k "trivial or active_workstream"` | Wave 0 — new file or extend |

### Sampling Rate

- **Per task commit:** `python -m pytest tests/test_skill_loader.py tests/test_context_loader.py -x -q`
- **Per wave merge:** `python -m pytest tests/ -x -q`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/test_context_loader.py` — new file covering GSD work type detection, nudge emission, trivial skip logic, active-workstream suppression
- [ ] `tests/test_gsd_autoactivation.py` — optional smoke test for CLAUDE.md section existence (low value — consider skipping in favor of manual verification)
- Extending `tests/test_skill_loader.py` with a `test_gsd_auto_activate_skill_always_loads` test requires the skill file to exist first (Wave 1 task)

---

## Open Questions

1. **Active workstream detection path**
   - What we know: `.planning/active-workstream` exists when a workstream is active (confirmed in STATE.md and file listing)
   - What's unclear: Is the file always non-empty when active, or could it be empty? Does it persist between sessions?
   - Recommendation: Read the file and check for non-empty content. Treat empty file same as missing file.

2. **GSD nudge: emit only once per session or on every multi-step prompt?**
   - What we know: `_emit_memory_nudge` fires on every matching prompt. That's acceptable for a brief reminder.
   - What's unclear: Whether repeated nudges across a session are annoying.
   - Recommendation: Keep it simple — fire on every qualifying prompt, same as memory nudge. Users can ignore it.

3. **CLAUDE.md section placement**
   - What we know: D-08 says append, not reorganize. Current file ends with `## Common Pitfalls` table.
   - What's unclear: Should the new section go before or after Common Pitfalls?
   - Recommendation: Insert before `## Common Pitfalls` — methodology guidance belongs with architecture/workflow sections, not after the pitfalls table. This is still an append in spirit (no rewriting), just careful placement.

---

## Sources

### Primary (HIGH confidence)

- `.claude/hooks/context-loader.py` — Full implementation read; WORK_TYPE_KEYWORDS pattern, `_emit_memory_nudge` precedent, `main()` flow verified
- `tests/test_skill_loader.py` — `test_always_load` test confirmed at lines 74–84; always-on mechanism verified
- `.claude/skills/add-tool/SKILL.md` — Skill YAML frontmatter format verified (name, description, always, task_types)
- `.claude/skills/deploy/SKILL.md` — Confirms skills can omit task_types when using always/disable-model-invocation flags
- `.claude/settings.json` — Hook registration verified; context-loader registered for UserPromptSubmit; no settings.json changes needed

### Secondary (MEDIUM confidence)

- `.planning/workstreams/agent42-ux-and-workflow-automation/phases/02-gsd-auto-activation/02-CONTEXT.md` — Decisions D-01 through D-13 read and incorporated
- `CLAUDE.md` — Current structure confirmed; append pattern understood

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components are existing, tested, verified by reading source
- Architecture patterns: HIGH — patterns copied directly from working implementations
- Pitfalls: HIGH — pitfalls derived from reading actual code behavior (not guesses)

**Research date:** 2026-03-20
**Valid until:** 2026-06-20 (stable; these are static config files and well-established patterns)
