---
phase: 02-windows-claude-md
verified: 2026-03-24T00:00:00Z
status: passed
score: 8/8 must-haves verified
re_verification: false
gaps: []
human_verification:
  - test: "Run `bash setup.sh` in Windows Git Bash on a fresh Windows 11 machine"
    expected: "Setup completes without 'No such file or directory' errors for .venv/bin/activate, and without 'command not found: python3'"
    why_human: "Cannot execute bash setup.sh end-to-end in CI — requires an actual Windows Git Bash environment to confirm runtime behavior, not just static analysis"
  - test: "Run `bash setup.sh generate-claude-md` in a test project directory"
    expected: "CLAUDE.md is created containing project name, hook protocol table, agent42_memory instructions, and Common Pitfalls section"
    why_human: "End-to-end invocation requires a live Python environment and project directory; static analysis confirms all components are present but not that they compose correctly at runtime"
---

# Phase 2: Windows + CLAUDE.md Verification Report

**Phase Goal:** Users on Windows with Git Bash can run the same setup command without errors, and any user can generate a project CLAUDE.md pre-loaded with Agent42 conventions and pitfall patterns
**Verified:** 2026-03-24
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User on Windows runs `bash setup.sh` in Git Bash without path errors, CRLF failures, or Python venv activation errors | VERIFIED | `OS_TYPE` case block sets `VENV_ACTIVATE=".venv/Scripts/activate"` and `PYTHON_CMD="python"` for `MINGW*\|MSYS*\|CYGWIN*`; `source "$VENV_ACTIVATE"` and `$PYTHON_CMD -m venv .venv` used throughout; `.gitattributes` enforces `eol=lf` for `.sh` and `.py` files; `bash -n setup.sh` passes |
| 2 | User runs the CLAUDE.md generation command and receives a CLAUDE.md file containing Agent42 hook protocol, memory system description, and pitfall patterns | VERIFIED | `generate_full_claude_md()` produces content containing `## Agent42 Hook Protocol`, `agent42_memory` tool usage, `## Agent42 Memory`, and 20-row `## Common Pitfalls` table; `generate-claude-md` subcommand dispatches through `$PYTHON_CMD scripts/setup_helpers.py generate-claude-md "$PROJECT_DIR"` |
| 3 | Generated CLAUDE.md is project-aware (references correct project name, repo identifier, and active workstream) | VERIFIED | `_detect_project_context()` extracts project name from directory basename or git remote (HTTPS and SSH); sets `jcodemunch_repo = "local/{project_name}"`; scans `.planning/workstreams/*/STATE.md` for `status: active` for workstream; template uses `{project_name}`, `{jcodemunch_repo}`, and `{active_workstream_line}` placeholders |

**Score:** 3/3 success criteria verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `setup.sh` | Platform detection block with `VENV_ACTIVATE` and `PYTHON_CMD` | VERIFIED | Lines 25-36: `OS_TYPE="$(uname -s)"` case block sets both variables; `MINGW*\|MSYS*\|CYGWIN*` handled |
| `setup.sh` | `generate-claude-md` subcommand dispatch | VERIFIED | Lines 237-243: `if [ "$1" = "generate-claude-md" ]` block present, uses `$PYTHON_CMD` |
| `setup.sh` | All local `python3` calls replaced with `$PYTHON_CMD` | VERIFIED | Only 1 `python3` occurrence in file: string assignment `PYTHON_CMD="python3"` at line 34 — all executable calls use `$PYTHON_CMD` |
| `setup.sh` | `source "$VENV_ACTIVATE"` instead of hardcoded path | VERIFIED | Line 297: `source "$VENV_ACTIVATE"` |
| `scripts/setup_helpers.py` | `_venv_python()` helper returning platform-correct path | VERIFIED | Lines 23-27: `def _venv_python(project_dir: str) -> str:` with `sys.platform == "win32"` check returning `Scripts/python.exe` or `bin/python` |
| `scripts/setup_helpers.py` | `generate_mcp_config()` and `check_health()` use `_venv_python()` | VERIFIED | `check_health()` line 671: `venv_python = _venv_python(project_dir)`; `generate_mcp_config()` confirmed via SUMMARY (hardcoded path removed) |
| `scripts/setup_helpers.py` | `_detect_project_context()` helper | VERIFIED | Lines 129-184: function defined, extracts project name, jcodemunch_repo, active_workstream, and venv_python |
| `scripts/setup_helpers.py` | `generate_full_claude_md()` function | VERIFIED | Lines 333-397: function defined; creates or merges CLAUDE.md using `_CLAUDE_MD_BEGIN`/`_CLAUDE_MD_END` markers; prints diff summary |
| `scripts/setup_helpers.py` | `_FULL_CLAUDE_MD_TEMPLATE` constant | VERIFIED | Lines 191-330: template contains all required sections (Quick Reference, Codebase Navigation, Agent42 Hook Protocol, Agent42 Memory, Testing Standards, Common Pitfalls, Project) |
| `scripts/setup_helpers.py` | `generate-claude-md` CLI dispatch | VERIFIED | Lines 923-928: `elif cmd == "generate-claude-md":` block calls `generate_full_claude_md(project_dir)`; usage string updated to include `generate-claude-md` |
| `.gitattributes` | LF line ending enforcement for `.sh` and `.py` files | VERIFIED | File exists at repo root; contains `* text=auto`, `*.sh text eol=lf`, `*.py text eol=lf`, `*.bash text eol=lf` |
| `tests/test_setup.py` | `TestWindowsCompat` class with 5 tests | VERIFIED | Class present at line 760; 5 test methods confirmed: `test_venv_python_returns_scripts_on_win32`, `test_venv_python_returns_bin_on_linux`, `test_mcp_config_uses_venv_python_win32`, `test_mcp_config_uses_venv_python_linux`, `test_health_check_uses_platform_venv_path` |
| `tests/test_setup.py` | `TestProjectContext` class with 6 tests | VERIFIED | Class present at line 852; 6 test methods confirmed |
| `tests/test_setup.py` | `TestClaudeMdFull` class with 14 tests | VERIFIED | Class present at line 919; 14 test methods confirmed |

---

### Key Link Verification

#### Plan 01 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `setup.sh` | `scripts/setup_helpers.py` | `$PYTHON_CMD scripts/setup_helpers.py` | WIRED | Lines 335-361: all 5 helper invocations (mcp-config, register-hooks, claude-md, jcodemunch_index.py, health) use `$PYTHON_CMD` prefix |
| `scripts/setup_helpers.py:generate_mcp_config` | `_venv_python()` | function call | WIRED | `check_health()` line 671 confirmed; `generate_mcp_config()` confirmed per SUMMARY (both callers updated) |
| `scripts/setup_helpers.py:check_health` | `_venv_python()` | function call | WIRED | Line 671: `venv_python = _venv_python(project_dir)` |

#### Plan 02 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `setup.sh` | `scripts/setup_helpers.py:generate_full_claude_md` | `$PYTHON_CMD scripts/setup_helpers.py generate-claude-md` | WIRED | Lines 237-243 in setup.sh dispatch to CLI; lines 923-928 in setup_helpers.py dispatch to `generate_full_claude_md()` |
| `scripts/setup_helpers.py:generate_full_claude_md` | `_detect_project_context()` | function call | WIRED | Line 345: `ctx = _detect_project_context(project_dir)` |
| `scripts/setup_helpers.py:generate_full_claude_md` | `_CLAUDE_MD_BEGIN/_CLAUDE_MD_END` markers | marker-based merge | WIRED | Lines 368-374: marker detection and replacement logic present |

---

### Data-Flow Trace (Level 4)

Not applicable — no data-rendering components. All artifacts are file generators and shell scripts. The template `_FULL_CLAUDE_MD_TEMPLATE` is a string constant (not dynamic data from a store), and `_detect_project_context()` derives values from the filesystem and git, not a cached or empty data source.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `setup.sh` has valid bash syntax | `bash -n setup.sh` | OK (exit 0) | PASS |
| `.gitattributes` exists and enforces LF | `test -f .gitattributes && grep -q "eol=lf" .gitattributes` | Both true | PASS |
| Only 1 `python3` occurrence in setup.sh (string assignment only) | `grep -c "python3" setup.sh` | 1 (line 34: `PYTHON_CMD="python3"`) | PASS |
| All 3 new test classes pass | `python -m pytest tests/test_setup.py -k "TestWindowsCompat or TestProjectContext or TestClaudeMdFull" -q` | 25 passed, 37 deselected | PASS |
| All test_setup.py tests pass (no regressions) | `python -m pytest tests/test_setup.py -x -q` | 60 passed, 2 skipped | PASS |
| All 5 phase commits exist in git | `git log --oneline 12197d2 1b59e9d 713296a 9d5b40b 5759293` | All 5 hashes confirmed | PASS |
| CLI dispatch includes `generate-claude-md` in usage string | `grep "generate-claude-md" scripts/setup_helpers.py` | Found in elif block + usage string | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SETUP-06 | 02-01-PLAN.md | User on Windows with Git Bash can run `bash setup.sh` without path errors or CRLF failures | SATISFIED | Platform detection block in setup.sh (lines 25-36); `.gitattributes` with `eol=lf`; `_venv_python()` helper; 5 TestWindowsCompat tests pass |
| SETUP-07 | 02-02-PLAN.md | User can run a setup command to generate a CLAUDE.md template with Agent42 conventions and pitfall patterns baked in | SATISFIED | `generate-claude-md` subcommand in setup.sh; `generate_full_claude_md()` function; `_detect_project_context()` for project-awareness; `_FULL_CLAUDE_MD_TEMPLATE` with all required sections; 20 new tests pass |

**Orphaned requirements check:** REQUIREMENTS.md maps SETUP-06 and SETUP-07 to Phase 2. Both are claimed in plan frontmatter. No orphaned requirements.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | No anti-patterns detected | — | — |

Checked `scripts/setup_helpers.py` and `setup.sh` for: TODO/FIXME/placeholder comments, `return null`/`return []`/`return {}`, hardcoded empty data, stub patterns. None found. The `_FULL_CLAUDE_MD_TEMPLATE` is fully populated with 20 pitfall rows and all required sections. The `_detect_project_context()` function contains real logic (git subprocess, filesystem scan). No placeholder values remain.

---

### Human Verification Required

#### 1. Windows Git Bash End-to-End

**Test:** On a Windows machine with Git Bash, clone the repo and run `bash setup.sh` in Git Bash
**Expected:** Setup completes without errors: no `No such file or directory: .venv/bin/activate`, no `command not found: python3`, CRLF errors do not appear
**Why human:** Static analysis confirms the platform detection code is correct and `.gitattributes` is present, but the actual runtime behavior on Windows (including whether Git Bash correctly resolves `uname -s` to `MINGW64_NT-*` and whether Windows Python is at `python` or `py`) requires a live Windows environment

#### 2. CLAUDE.md Generation End-to-End

**Test:** In a fresh project directory with a git remote, run `bash setup.sh generate-claude-md`
**Expected:** CLAUDE.md is created containing the project name (from git remote), `## Agent42 Hook Protocol`, `## Agent42 Memory` with `agent42_memory` tool instructions, `## Codebase Navigation (jcodemunch)` with the correct `local/{project_name}` repo identifier, and `## Common Pitfalls` table
**Why human:** The template generation depends on `git remote get-url origin` returning a real URL and string extraction being correct — automated tests mock this. A live invocation in a real git repo confirms the full data-flow chain.

---

### Gaps Summary

No gaps. All phase 02 goals are achieved:

- SETUP-06 (Windows Git Bash): Platform detection block is in place, `.gitattributes` enforces LF endings, `_venv_python()` helper produces correct paths for both platforms, all `python3` executable calls replaced with `$PYTHON_CMD`, `source "$VENV_ACTIVATE"` replaces hardcoded path. 5 TestWindowsCompat tests pass.

- SETUP-07 (CLAUDE.md generation): `generate_full_claude_md()` and `_detect_project_context()` are implemented, `_FULL_CLAUDE_MD_TEMPLATE` is fully populated (not a stub), `generate-claude-md` subcommand is wired in `setup.sh` using `$PYTHON_CMD`. 20 new tests (TestProjectContext + TestClaudeMdFull) pass. Merge idempotency is verified by the test suite.

Two human verification items are flagged (Windows runtime and live CLAUDE.md generation) but both represent environmental testing that automated static analysis cannot substitute for.

---

_Verified: 2026-03-24_
_Verifier: Claude (gsd-verifier)_
