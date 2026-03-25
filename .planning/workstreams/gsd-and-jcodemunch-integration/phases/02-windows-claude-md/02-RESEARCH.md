# Phase 2: Windows + CLAUDE.md - Research

**Researched:** 2026-03-24
**Domain:** Bash cross-platform compatibility (Windows Git Bash), Python venv activation, CRLF line endings, parameterized CLAUDE.md template generation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Windows Path and Venv Compatibility**
- **D-01:** Add platform detection at the top of `setup.sh` using `case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*` (pattern already exists in the `create-shortcut` subcommand). Set `VENV_ACTIVATE` and `PYTHON_CMD` variables that all subsequent steps use instead of hardcoded `.venv/bin/activate` and `python3`.
- **D-02:** In `setup_helpers.py`, use `sys.platform == "win32"` to select `.venv/Scripts/python.exe` vs `.venv/bin/python` for MCP config generation and health checks. Keep stdlib-only (no external deps), consistent with Phase 1 decision.
- **D-03:** Fix `python3` → `python` on Windows. Git Bash ships `python` not `python3`. Platform detection sets `PYTHON_CMD=python` on Windows, `PYTHON_CMD=python3` on Linux/macOS.

**CRLF Prevention**
- **D-04:** Add `.gitattributes` to the repo root enforcing LF line endings on `*.sh` and `*.py` files (`*.sh text eol=lf`, `*.py text eol=lf`). This prevents CRLF contamination at the git level — the root cause, not a runtime workaround.
- **D-05:** Do NOT add a runtime CRLF-stripping preamble to setup.sh. The `.gitattributes` approach is the correct fix. Runtime stripping doesn't protect Python shebang lines or hook scripts called from setup.sh.

**CLAUDE.md Template Generation**
- **D-06:** Generate a parameterized CLAUDE.md template, NOT a verbatim copy of Agent42's own CLAUDE.md. The template includes: hook protocol table, memory system description, architecture patterns overview, curated pitfall patterns, and testing standards — but adapted for a project *using* Agent42 as an MCP server, not for Agent42 development itself.
- **D-07:** Template is project-aware — inject detected values: project name (from directory name or git remote), jcodemunch repo identifier, active GSD workstream name (if any), venv path, and MCP server configuration status.
- **D-08:** Invocation is a `setup.sh` subcommand: `bash setup.sh generate-claude-md`. This follows the existing subcommand pattern (`sync-auth`, `create-shortcut`). It is NOT part of the default `bash setup.sh` flow to avoid overwriting existing CLAUDE.md files without consent.
- **D-09:** If a CLAUDE.md already exists, merge new sections rather than overwrite. Print a diff summary showing what was added. If no CLAUDE.md exists, generate from scratch.

### Claude's Discretion
- Exact content curation for the pitfalls section (which of the 124 pitfalls are relevant to general users vs Agent42-internal)
- Template section ordering and formatting
- How to detect project name (directory basename vs git remote parsing)
- Whether to include the full Common Pitfalls table or a curated top-20

### Deferred Ideas (OUT OF SCOPE)
- `setup.ps1` for native PowerShell users — could be a future enhancement but SETUP-06 only requires Git Bash support.
- Auto-update CLAUDE.md when new pitfalls accumulate (ENT-03 in v2 requirements) — out of scope, requires human approval gate.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SETUP-06 | User on Windows with Git Bash can run `bash setup.sh` without path errors or CRLF failures | Windows venv path (`Scripts/` not `bin/`), `python` not `python3`, CRLF in setup.sh confirmed — all addressed by D-01 through D-04 |
| SETUP-07 | User can run a setup command to generate a CLAUDE.md template with Agent42 conventions and pitfall patterns baked in | `generate-claude-md` subcommand in setup.sh + expanded `generate_claude_md_section()` in setup_helpers.py — addressed by D-06 through D-09 |
</phase_requirements>

---

## Summary

Phase 2 addresses two independent concerns that were explicitly excluded from Phase 1: making `setup.sh` work on Windows Git Bash, and generating a project-specific CLAUDE.md for new users.

The Windows problem is confirmed concrete: `setup.sh` currently hardcodes `source .venv/bin/activate` and `python3`, but on Windows the venv lives at `.venv/Scripts/` (no `bin/` directory) and Git Bash ships `python`, not `python3`. Additionally, `setup.sh` itself was found to have CRLF line endings on this Windows machine (confirmed via `file` command), and `setup_helpers.py` also has partial CRLF contamination. The `.gitattributes` fix prevents recurrence at the git level — this is the right root-cause fix (D-04), not a runtime workaround.

The CLAUDE.md generation concern is a template expansion: the current `generate_claude_md_section()` only writes a minimal memory-section. D-06 through D-09 require expanding it into a full project conventions document injected with project-specific values (name, jcodemunch repo ID, workstream) and offering a merge path when CLAUDE.md already exists.

**Primary recommendation:** Implement Windows fixes (D-01 through D-04) as setup.sh + setup_helpers.py changes; implement `generate-claude-md` subcommand as a new `generate_full_claude_md()` function in setup_helpers.py and the corresponding subcommand dispatch in setup.sh.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python stdlib (`sys`, `os`, `pathlib`) | 3.11+ | Platform detection, path construction, file I/O | stdlib-only constraint (D-02, Phase 1 decision [01-02]) |
| bash built-ins (`uname`, `case`) | Git Bash 2.x | Platform detection in shell | Already used in `create-shortcut` subcommand — zero new deps |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `subprocess` (stdlib) | 3.11+ | Run `git remote get-url origin` for project name detection | Only used when detecting project name from git remote |
| `difflib` (stdlib) | 3.11+ | Generating diff summary for CLAUDE.md merge (D-09) | Only needed if planner chooses to show a diff in the merge path |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.gitattributes` for CRLF (D-04) | Runtime `sed -i 's/\r//'` preamble in setup.sh | `.gitattributes` fixes root cause + protects all scripts; runtime strip only protects the file that runs it. D-05 explicitly forbids runtime workaround. |
| `sys.platform == "win32"` (D-02) | `os.name == "nt"` | Both are equivalent on Windows; `sys.platform` is more explicit and already the community standard for platform branching |
| Directory basename for project name | Git remote URL parsing | Basename is simpler and always available; git remote may not exist (fresh clone or no remote). Use basename as primary, git remote as enhancement when available. |

**Installation:** No new dependencies required. All changes use stdlib only.

---

## Architecture Patterns

### Recommended Project Structure
```
setup.sh               # Modified: platform detection block at top, $PYTHON_CMD/$VENV_ACTIVATE vars, generate-claude-md subcommand
scripts/
└── setup_helpers.py   # Modified: platform-aware venv_python(), generate_full_claude_md()
.gitattributes         # New file: *.sh eol=lf, *.py eol=lf
```

### Pattern 1: Platform Detection Block in setup.sh (top-level)
**What:** Extract the existing `MINGW*|MSYS*|CYGWIN*` detection from `create-shortcut` into a top-level block that sets `VENV_ACTIVATE` and `PYTHON_CMD`.
**When to use:** Must execute before venv activation (currently line ~274).
**Example:**
```bash
# ── Platform detection ────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
    MINGW*|MSYS*|CYGWIN*)
        VENV_ACTIVATE=".venv/Scripts/activate"
        PYTHON_CMD="python"
        ;;
    *)
        VENV_ACTIVATE=".venv/bin/activate"
        PYTHON_CMD="python3"
        ;;
esac
```
Then replace all hardcoded uses:
- `source .venv/bin/activate` → `source "$VENV_ACTIVATE"`
- `python3 scripts/...` → `$PYTHON_CMD scripts/...`

### Pattern 2: Platform-Aware venv_python() in setup_helpers.py
**What:** Replace the two hardcoded `os.path.join(project_dir, ".venv", "bin", "python")` occurrences (lines 216 and 391) with a helper function.
**When to use:** Called in `generate_mcp_config()` and `check_health()`.
**Example:**
```python
import sys

def _venv_python(project_dir: str) -> str:
    """Return the correct venv python path for the current platform."""
    if sys.platform == "win32":
        return os.path.join(project_dir, ".venv", "Scripts", "python.exe")
    return os.path.join(project_dir, ".venv", "bin", "python")
```

### Pattern 3: generate-claude-md Subcommand in setup.sh
**What:** Add `generate-claude-md` to the subcommand dispatch (alongside `sync-auth`, `create-shortcut`).
**When to use:** User explicitly calls `bash setup.sh generate-claude-md`.
**Example:**
```bash
if [ "$1" = "generate-claude-md" ]; then
    $PYTHON_CMD scripts/setup_helpers.py generate-claude-md "$PROJECT_DIR"
    exit 0
fi
```
Note: Platform detection must happen BEFORE this block to ensure `$PYTHON_CMD` is set. Either move detection to very top (before all subcommand blocks), or duplicate the minimal detection before the subcommand block.

### Pattern 4: generate_full_claude_md() in setup_helpers.py
**What:** New function that builds a parameterized CLAUDE.md template, detects project context, and merges using existing marker pattern (`<!-- BEGIN AGENT42 MEMORY -->` / `<!-- END AGENT42 MEMORY -->`).
**When to use:** Called by the `generate-claude-md` CLI subcommand.
**Key implementation points:**
- Reuse the existing `_CLAUDE_MD_BEGIN` / `_CLAUDE_MD_END` markers for the merge boundary
- Project name: `os.path.basename(project_dir)` as primary; try `git remote get-url origin` as enhancement (strip `.git` suffix, take final path component)
- jcodemunch repo ID: `local/{project_name}` is the format jcodemunch uses (confirmed from CLAUDE.md: `local/agent42`)
- Active GSD workstream: scan `.planning/workstreams/` for directories; read `STATE.md` `status:` field; report "active" workstreams. Graceful fallback if `.planning/` doesn't exist.
- Merge: reuse the existing before/after marker logic from `generate_claude_md_section()`

### Pattern 5: .gitattributes Content
**What:** New file at repo root enforcing LF line endings.
**Why:** `setup.sh` was confirmed to have CRLF line endings on this Windows machine. `setup_helpers.py` also shows partial CRLF contamination. `.gitattributes` fixes this at git-checkout time.
```
# Enforce LF line endings for shell and Python files
*.sh    text eol=lf
*.py    text eol=lf
*.bash  text eol=lf
```
Optionally add `* text=auto` as the first line to normalize all text files by default, with the above overrides for critical types.

### Pattern 6: generate-claude-md CLI Dispatch in setup_helpers.py
**What:** Add `generate-claude-md` to the `__main__` CLI dispatch block alongside existing subcommands.
**Example:**
```python
elif cmd == "generate-claude-md":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} generate-claude-md <project_dir>")
        sys.exit(1)
    project_dir = sys.argv[2]
    generate_full_claude_md(project_dir)
```

### Anti-Patterns to Avoid
- **Hardcoding `bin/` path in setup_helpers.py:** Lines 216 and 391 currently do this. Both must use `_venv_python()`.
- **Leaving `python3` in setup.sh:** Every `python3 scripts/...` call must become `$PYTHON_CMD scripts/...` after platform detection.
- **Placing platform detection after venv activation:** Detection must precede `source "$VENV_ACTIVATE"`, which itself must precede all pip and python calls.
- **Runtime CRLF stripping:** D-05 explicitly forbids this. Use `.gitattributes` only.
- **Overwriting existing CLAUDE.md without consent:** D-09 requires merge path. The existing marker logic in `generate_claude_md_section()` handles this correctly — reuse it.
- **Placing generate-claude-md before platform detection:** Subcommand dispatch blocks currently appear before `QUIET=false` (line 223). Platform detection and `PYTHON_CMD` must be set before any subcommand uses `$PYTHON_CMD`. Move platform detection to the very top, immediately after the logging function definitions.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CRLF normalization | Runtime `sed` strip in bash | `.gitattributes` with `eol=lf` | One declaration fixes all checked-out files; protects Python scripts and hook files too |
| Platform venv path | `if/else` scattered throughout setup_helpers.py | `_venv_python(project_dir)` helper function | Centralizes the logic — two callers (`generate_mcp_config`, `check_health`) both need it |
| Git remote URL parsing | Custom regex parser | Simple `split('/')[-1].removesuffix('.git')` | Git remote URL formats are simple; the edge case (no remote) is handled by fallback to basename |
| CLAUDE.md merge | Custom marker parser | Reuse `_CLAUDE_MD_BEGIN`/`_CLAUDE_MD_END` logic from `generate_claude_md_section()` | Already tested (6 tests in TestClaudeMdGeneration), already handles all edge cases |

**Key insight:** Both problems in this phase have existing infrastructure to build on. Windows compatibility reuses the platform detection already in `create-shortcut`. CLAUDE.md generation reuses the marker-based merge already in `generate_claude_md_section()`. The work is extension, not greenfield.

---

## Common Pitfalls

### Pitfall 1: Subcommand Blocks Fire Before Platform Detection
**What goes wrong:** The subcommand blocks (`sync-auth`, `create-shortcut`, and new `generate-claude-md`) are at the top of setup.sh. If platform detection and `$PYTHON_CMD` are defined after them, `generate-claude-md` calls `python3` on Windows and fails.
**Why it happens:** Current ordering: subcommand blocks → `QUIET=false` → Python version check. New platform detection must inject before all subcommand blocks, or `generate-claude-md` gets a different inline copy of detection.
**How to avoid:** Move platform detection immediately after the color/logging function definitions (lines 15-22) and before the first `if [ "$1" = ...` block.
**Warning signs:** `generate-claude-md` works on Linux but fails on Windows with `python3: command not found`.

### Pitfall 2: `source .venv/Scripts/activate` Works in Git Bash But Python3 Still Fails
**What goes wrong:** After activating `.venv/Scripts/activate`, the venv's `Scripts/` is on PATH, making `python.exe` available. But if any script subsequently calls `python3` (hardcoded), it will find the Microsoft Store stub at `C:\Users\...\WindowsApps\python3.EXE`, NOT the venv's Python.
**Why it happens:** `python3` on Windows (when not in a venv) resolves to the Microsoft Store stub, which works but may be a different version and won't have the project's installed packages.
**How to avoid:** Replace ALL `python3` calls in setup.sh with `$PYTHON_CMD` after platform detection.
**Warning signs:** Imports fail for packages installed in the venv (e.g., `fastapi`, `aiofiles`) when running via `python3` directly.

### Pitfall 3: `.venv/Scripts/activate` Has CRLF Even After `.gitattributes` Fix
**What goes wrong:** `.gitattributes` with `*.sh eol=lf` and `*.py eol=lf` does NOT normalize `.venv/` files — `.venv` is in `.gitignore` and not tracked by git.
**Why it happens:** `.gitattributes` only applies to tracked files. The venv's `activate` script is generated by Python's `venv` module and is LF on all platforms.
**How to avoid:** This is not actually a problem — `venv` always generates LF `activate` on all platforms including Windows. Verified: `.venv/Scripts/activate` on this Windows machine starts with correct LF bash shebang. No action needed.
**Warning signs:** None — this is a non-issue.

### Pitfall 4: Existing CLAUDE.md Tests Break When Template Expands
**What goes wrong:** `TestClaudeMdGeneration` checks for specific strings from the current minimal `CLAUDE_MD_TEMPLATE` (e.g., `action="search"`, `action="store"`, `action="log"`). If `generate_full_claude_md()` replaces or supplements `generate_claude_md_section()`, tests that expect the old content may fail.
**Why it happens:** The new full template includes different content than the minimal memory section.
**How to avoid:** Keep `generate_claude_md_section()` and `CLAUDE_MD_TEMPLATE` unchanged. `generate_full_claude_md()` is a NEW function that produces a richer output — it can reuse the same marker logic but write different content between the markers. Tests for the old function remain valid. New tests cover the new function.
**Warning signs:** `TestClaudeMdGeneration::test_template_contains_search_instruction` fails — indicates the new function accidentally replaced the old one.

### Pitfall 5: Project Name Detection Diverges Between Platforms
**What goes wrong:** `git remote get-url origin` returns different URL formats (SSH `git@github.com:org/repo.git` vs HTTPS `https://github.com/org/repo.git`). Parsing logic must handle both.
**Why it happens:** Users use different git auth methods.
**How to avoid:** Parse both formats with: `url.split('/')[-1].removesuffix('.git')` works for HTTPS; for SSH, `url.split(':')[-1].split('/')[-1].removesuffix('.git')`. Or use the safer fallback: always use `os.path.basename(project_dir)` — it's available without subprocess and always correct.
**Warning signs:** Project name shows as `repo.git` (suffix not stripped) or `org/repo` (extra path component).

### Pitfall 6: `.gitattributes` Does Not Retroactively Fix Already-Checked-Out Files
**What goes wrong:** Adding `.gitattributes` prevents future CRLF contamination but does not fix existing files in the working tree. After commit, users on Windows who already have CRLF versions will not get them fixed until they re-clone or run `git checkout` / `git add --renormalize`.
**Why it happens:** `.gitattributes` applies at checkout/staging time, not retroactively.
**How to avoid:** Document in setup output that users should run `git add --renormalize .` after the first run on existing checkouts. The setup.sh `generate-claude-md` flow doesn't need to handle this — it's a one-time note.
**Warning signs:** `git status` shows `*.sh` files as modified after adding `.gitattributes`.

---

## Code Examples

### Platform Detection Block (setup.sh)
```bash
# Source: D-01 from 02-CONTEXT.md + create-shortcut pattern at setup.sh lines 65-67
# ── Platform detection ──────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
    MINGW*|MSYS*|CYGWIN*)
        VENV_ACTIVATE=".venv/Scripts/activate"
        PYTHON_CMD="python"
        ;;
    *)
        VENV_ACTIVATE=".venv/bin/activate"
        PYTHON_CMD="python3"
        ;;
esac
```

### Platform-Aware Venv Python Helper (setup_helpers.py)
```python
# Source: D-02 from 02-CONTEXT.md; replaces lines 216 and 391 in setup_helpers.py
def _venv_python(project_dir: str) -> str:
    """Return the correct venv python executable path for the current platform."""
    if sys.platform == "win32":
        return os.path.join(project_dir, ".venv", "Scripts", "python.exe")
    return os.path.join(project_dir, ".venv", "bin", "python")
```

### Project Context Detection (setup_helpers.py)
```python
# Source: D-07 from 02-CONTEXT.md
def _detect_project_context(project_dir: str) -> dict:
    """Detect project name, jcodemunch repo ID, and active GSD workstream."""
    # Project name: try git remote first, fall back to directory basename
    project_name = os.path.basename(os.path.abspath(project_dir))
    try:
        result = subprocess.run(
            ["git", "-C", project_dir, "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            url = result.stdout.strip()
            # Handle both HTTPS and SSH URL formats
            repo_part = url.split(":")[-1] if ":" in url else url.split("/")[-1]
            name = repo_part.split("/")[-1].removesuffix(".git")
            if name:
                project_name = name
    except Exception:
        pass

    # jcodemunch repo identifier: "local/{project_name}"
    jcodemunch_repo = f"local/{project_name}"

    # Active GSD workstream: scan .planning/workstreams/
    active_workstream = None
    workstreams_dir = os.path.join(project_dir, ".planning", "workstreams")
    if os.path.isdir(workstreams_dir):
        for ws_name in sorted(os.listdir(workstreams_dir)):
            state_path = os.path.join(workstreams_dir, ws_name, "STATE.md")
            if os.path.isfile(state_path):
                with open(state_path, encoding="utf-8") as f:
                    state_content = f.read()
                if "status: active" in state_content or "status: in-progress" in state_content:
                    active_workstream = ws_name
                    break

    return {
        "project_name": project_name,
        "jcodemunch_repo": jcodemunch_repo,
        "active_workstream": active_workstream,
        "venv_python": _venv_python(project_dir),
    }
```

### .gitattributes Content
```gitattributes
# Source: D-04 from 02-CONTEXT.md
# Normalize line endings: enforce LF for shell and Python files
* text=auto
*.sh    text eol=lf
*.py    text eol=lf
*.bash  text eol=lf
```

### CLAUDE.md Merge with Diff Summary (setup_helpers.py)
```python
# Source: D-09 from 02-CONTEXT.md; reuses existing marker logic
# When CLAUDE.md exists, identify new sections and print what changed.
# Use difflib.unified_diff for the summary, then write the merged file.
import difflib

original_lines = original.splitlines(keepends=True)
new_lines = new_content.splitlines(keepends=True)
diff = list(difflib.unified_diff(original_lines, new_lines, n=0,
                                  fromfile="CLAUDE.md (before)",
                                  tofile="CLAUDE.md (after)"))
if diff:
    added = sum(1 for l in diff if l.startswith("+") and not l.startswith("+++"))
    print(f"  CLAUDE.md updated: +{added} lines added")
else:
    print("  CLAUDE.md already up to date — no changes")
```

---

## Confirmed Facts from Codebase Inspection

| Finding | Source | Confidence |
|---------|--------|------------|
| `setup.sh` line 275: `source .venv/bin/activate` — hardcoded, breaks Windows | Direct read of setup.sh | HIGH |
| `setup.sh` lines 313, 316, 321, 326, 331: `python3 scripts/...` — all must become `$PYTHON_CMD` | Direct read of setup.sh | HIGH |
| `setup_helpers.py` line 216: `os.path.join(project_dir, ".venv", "bin", "python")` in `generate_mcp_config()` | Direct read | HIGH |
| `setup_helpers.py` line 391: `os.path.join(project_dir, ".venv", "bin", "python")` in `check_health()` | Direct read | HIGH |
| Windows venv has `.venv/Scripts/python.exe` (not `.venv/bin/python`) — verified on this machine | `python -c "os.path.isfile()"` probe | HIGH |
| `.venv/Scripts/activate` exists and is a valid bash script (LF endings) — Git Bash can source it | Direct `ls` and `head` inspection | HIGH |
| `python3` on Windows resolves to Microsoft Store stub, NOT the venv python — version matches but not activated | `shutil.which('python3')` probe | HIGH |
| `python` on Windows resolves to venv's `python.exe` when venv is active | `shutil.which('python')` probe | HIGH |
| `setup.sh` itself has CRLF line endings on this machine — confirms the problem is real | `file` command output | HIGH |
| `setup_helpers.py` has partial CRLF contamination (4 CRLF in first 200 bytes) | Binary read probe | HIGH |
| `.gitattributes` does not currently exist in the repo | `ls` check → "NOT FOUND" | HIGH |
| `git config core.autocrlf` = `true` for this repo — git is converting LF→CRLF on checkout | `git config` output | HIGH |
| jcodemunch repo ID format: `local/{project_name}` — confirmed from CLAUDE.md (`local/agent42`) | CLAUDE.md content | HIGH |
| Agent42's CLAUDE.md is 661 lines / 42,810 chars — not appropriate to copy verbatim into a template | `wc` count | HIGH |
| `.claude/reference/pitfalls-archive.md` is 87 lines — pitfalls 1-80, manageable to curate from | `wc` count | HIGH |
| `TestClaudeMdGeneration` (6 tests) covers the current `generate_claude_md_section()` behavior | test_setup.py read | HIGH |
| `pyproject.toml` sets `asyncio_mode = "auto"` — all async tests auto-detected | pyproject.toml read | HIGH |

---

## Pitfall Curation Guidance (Claude's Discretion)

The template should include pitfalls that are:
1. **Universally relevant** to any project using Agent42 as an MCP server
2. **Not Agent42-internal** (i.e., not specific to developing Agent42 itself)

**Recommended curated set (top ~20 general-purpose pitfalls):**

| Category | Pitfall #s to Include | Rationale |
|----------|-----------------------|-----------|
| Async I/O | 81 (chat session isolation), 103 (memory loading paths) | General async agent patterns |
| Deployment | 94 (missing module files), 95 (bcrypt hash), 119 (unstaged changes block deploy) | Any deploy-workflow |
| Security | 104-108 (GitHub tokens, git auth, sandbox, zip-slip, HMAC) | All users face these |
| Memory | 109-113 (Qdrant availability, embedding fallback, memory tool) | Memory system users |
| Testing | 117-118 (stale imports, removed endpoints) | General test hygiene |
| Windows-specific | New: D-01 through D-05 patterns | This phase |

**Skip:** Pitfalls 81-100 that are Agent42-internal-UI-specific (dashboard route changes, specific API endpoints, service names) unless they reflect a general pattern.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest + pytest-asyncio |
| Config file | `pyproject.toml` (`[tool.pytest.ini_options]`) |
| Quick run command | `python -m pytest tests/test_setup.py -x -q` |
| Full suite command | `python -m pytest tests/ -x -q` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETUP-06 | `generate_mcp_config()` generates correct Windows venv path | unit | `python -m pytest tests/test_setup.py::TestMcpConfigGeneration -x -q` | Wave 0: add test to existing file |
| SETUP-06 | `check_health()` uses Windows venv path on win32 | unit | `python -m pytest tests/test_setup.py::TestHealthReport -x -q` | Wave 0: add test to existing file |
| SETUP-06 | `.gitattributes` exists with correct eol=lf entries | unit (file presence) | `python -m pytest tests/test_setup.py::TestWindowsCompat -x -q` | Wave 0: new test class |
| SETUP-07 | `generate_full_claude_md()` creates CLAUDE.md with hook protocol | unit | `python -m pytest tests/test_setup.py::TestClaudeMdFull -x -q` | Wave 0: new test class |
| SETUP-07 | `generate_full_claude_md()` injects correct project name | unit | `python -m pytest tests/test_setup.py::TestClaudeMdFull -x -q` | Wave 0: new test class |
| SETUP-07 | `generate_full_claude_md()` merges into existing CLAUDE.md | unit | `python -m pytest tests/test_setup.py::TestClaudeMdFull -x -q` | Wave 0: new test class |
| SETUP-07 | `generate_full_claude_md()` is idempotent | unit | `python -m pytest tests/test_setup.py::TestClaudeMdFull -x -q` | Wave 0: new test class |

### Sampling Rate
- **Per task commit:** `python -m pytest tests/test_setup.py -x -q`
- **Per wave merge:** `python -m pytest tests/ -x -q`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_setup.py` — Add `TestWindowsCompat` class (SETUP-06: venv path, `.gitattributes` presence)
- [ ] `tests/test_setup.py` — Add `TestClaudeMdFull` class (SETUP-07: full template generation, project context injection, merge)
- [ ] No framework changes needed — existing pytest config covers all new tests

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python (stdlib) | setup_helpers.py changes | ✓ | 3.14.3 | — |
| Git | Project name detection | ✓ | Git Bash 2.x | Fallback to `os.path.basename()` |
| `.venv/Scripts/python.exe` | Windows MCP config + health | ✓ | Confirmed present | Error if missing (user must run venv first) |
| `.venv/Scripts/activate` | Windows venv activation in setup.sh | ✓ | Present, LF endings | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** Git (for project name) — basename fallback always works.

---

## Sources

### Primary (HIGH confidence)
- Direct read of `setup.sh` — confirmed hardcoded paths at lines 275, 313, 316, 321, 326, 331
- Direct read of `scripts/setup_helpers.py` — confirmed hardcoded venv paths at lines 216, 391
- Direct filesystem probe — confirmed `.venv/Scripts/python.exe` exists, `.venv/bin/python` does not
- Direct filesystem probe — confirmed `.venv/Scripts/activate` exists with LF endings
- `git config` output — confirmed `core.autocrlf=true` causing CRLF in checkout
- `file setup.sh` output — confirmed CRLF line terminators in setup.sh
- Binary read of `setup_helpers.py` — confirmed partial CRLF contamination
- `02-CONTEXT.md` — locked decisions D-01 through D-09
- `tests/test_setup.py` — confirmed existing test classes and what they cover

### Secondary (MEDIUM confidence)
- `shutil.which('python')` / `shutil.which('python3')` probes on Windows — confirmed `python` maps to venv, `python3` maps to Store stub
- CLAUDE.md content — confirmed jcodemunch repo ID format `local/agent42`

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Windows compat fixes: HIGH — all confirmed by direct filesystem probes on this Windows machine
- CRLF root cause: HIGH — `git config core.autocrlf=true` + confirmed CRLF in setup.sh
- Template generation: HIGH — existing code structure well understood, approach is extension not rewrite
- Test coverage gaps: HIGH — test file exists, existing tests clearly cover old function, new tests obviously needed

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (stable domain — bash/Python platform detection, git attributes)
