---
phase: 01-setup-foundation
verified: 2026-03-18T20:30:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
human_verification:
  - test: "Run bash setup.sh on a fresh Linux/VPS clone of agent42"
    expected: ".mcp.json created with agent42 entry, .claude/settings.json patched with all hooks, jcodemunch index completes, health report prints with pass/fail per service"
    why_human: "Full end-to-end path requires Linux OS, uvx/jcodemunch installed, and live MCP subprocess — cannot simulate on Windows dev machine"
  - test: "Re-run bash setup.sh on an already-configured system"
    expected: "No existing .mcp.json entries or settings.json hook entries are overwritten or duplicated"
    why_human: "Idempotency tested at unit level; integration path (actual setup.sh running on Linux with real config files) requires live environment"
---

# Phase 1: Setup Foundation Verification Report

**Phase Goal:** Users can run a single command on Linux/VPS and have a fully configured Agent42 + Claude Code environment with working MCP, hooks, and jcodemunch index
**Verified:** 2026-03-18T20:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User runs `bash setup.sh` and `.mcp.json` exists with Agent42 MCP server entry pointing to correct Python path | VERIFIED | `generate_mcp_config()` functional test: produces .mcp.json with agent42 entry, correct AGENT42_WORKSPACE, REDIS_URL, QDRANT_URL; setup.sh calls `python3 scripts/setup_helpers.py mcp-config "$PROJECT_DIR"` |
| 2 | User runs `bash setup.sh` and `.claude/settings.json` contains all Agent42 hooks registered under correct event keys | VERIFIED | `register_hooks()` functional test: reads frontmatter, merges into settings.json with correct event/matcher/timeout; setup.sh calls `python3 scripts/setup_helpers.py register-hooks "$PROJECT_DIR"` |
| 3 | User runs `bash setup.sh` and project repo is indexed in jcodemunch | VERIFIED | `scripts/jcodemunch_index.py` exists with `index_project()` sending initialize + notifications/initialized + tools/call index_folder; setup.sh calls `python3 scripts/jcodemunch_index.py "$PROJECT_DIR" --timeout=120`; failure treated as warning not hard error |
| 4 | User re-runs `bash setup.sh` and no existing configuration is overwritten or corrupted | VERIFIED | Idempotency functional test passed: `register_hooks()` produces identical JSON on second run; `generate_mcp_config()` skips existing entries unless agent42 command path is stale; unit tests `TestIdempotency` pass |
| 5 | User sees post-setup health report listing MCP server reachable, jcodemunch responding, and Qdrant accessible (pass/fail per service) | VERIFIED | `check_health()` probes 5 services (MCP Server, jcodemunch, Qdrant, Redis, Claude Code CLI); `print_health_report()` outputs [checkmark]/[x] per service with Fix hints; setup.sh calls `python3 scripts/setup_helpers.py health "$PROJECT_DIR"` in non-quiet mode |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.claude/hooks/security-gate.py` | Hook frontmatter for auto-discovery | VERIFIED | `# hook_event: PreToolUse`, `# hook_matcher: Write\|Edit\|Bash`, `# hook_timeout: 10` present after shebang |
| `.claude/hooks/jcodemunch-reindex.py` | Multi-event hook frontmatter | VERIFIED | Two `# hook_event:` lines: PostToolUse + Stop |
| All 12 hook files | Correct frontmatter | VERIFIED | Python verification script: PASS — all 12 hooks have correct frontmatter; total 13 hook_event lines (1 extra for jcodemunch-reindex dual registration) |
| `tests/test_setup.py` | Test scaffolding with all 10 classes | VERIFIED | 10 test classes present; 28 passing, 2 integration skips; imports from scripts.setup_helpers and scripts.jcodemunch_index |
| `scripts/setup_helpers.py` | Python helpers for MCP config, hook registration, health probes | VERIFIED | All 5 functions importable: `generate_mcp_config`, `read_hook_metadata`, `register_hooks`, `check_health`, `print_health_report`; stdlib-only; CLI subcommands: mcp-config, register-hooks, health |
| `scripts/jcodemunch_index.py` | MCP JSON-RPC client for jcodemunch indexing | VERIFIED | `index_project()` and `ensure_uvx()` importable; sends initialize + notifications/initialized + tools/call index_folder via Popen stdio; threading timeout |
| `setup.sh` | Extended with 4 new sections | VERIFIED | Contains PROJECT_DIR, SSH_ALIAS prompt, mcp-config, register-hooks, jcodemunch indexing (soft fail), health report; `bash -n setup.sh` exits 0 |
| `mcp_server.py` | --health flag | VERIFIED | `"--health" in sys.argv` guard present; imports Settings.from_env(); exits 0/1; does not start transport |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `setup.sh` | `scripts/setup_helpers.py` | `python3 scripts/setup_helpers.py mcp-config` | WIRED | Line present in setup.sh: `python3 scripts/setup_helpers.py mcp-config "$PROJECT_DIR"` |
| `setup.sh` | `scripts/setup_helpers.py` | `python3 scripts/setup_helpers.py register-hooks` | WIRED | Line present: `python3 scripts/setup_helpers.py register-hooks "$PROJECT_DIR"` |
| `setup.sh` | `scripts/jcodemunch_index.py` | `python3 scripts/jcodemunch_index.py` | WIRED | Line present: `if ! python3 scripts/jcodemunch_index.py "$PROJECT_DIR" --timeout=120; then` |
| `setup.sh` | `scripts/setup_helpers.py` | `python3 scripts/setup_helpers.py health` | WIRED | Line present: `python3 scripts/setup_helpers.py health "$PROJECT_DIR"` |
| `scripts/setup_helpers.py` | `.mcp.json` | `generate_mcp_config writes JSON` | WIRED | `json.dump(config, f, indent=2)` on line 174; AGENT42_WORKSPACE/REDIS_URL/QDRANT_URL env vars present |
| `scripts/setup_helpers.py` | `.claude/settings.json` | `register_hooks writes JSON` | WIRED | `json.dump(config, f, indent=2)` on line 284; hook command uses absolute project_dir path |
| `scripts/setup_helpers.py` | `.claude/hooks/*.py` | `read_hook_metadata parses frontmatter` | WIRED | `# hook_event:` pattern parsing verified against actual hook files; security-gate.py, jcodemunch-reindex.py, context-loader.py all parse correctly |
| `mcp_server.py` | Health check | `--health flag` | WIRED | `if "--health" in sys.argv:` → `Settings.from_env()` → `sys.exit(0)` or `sys.exit(1)` |
| `tests/test_setup.py` | `scripts/setup_helpers.py` | `from scripts.setup_helpers import` | WIRED | Import verified; 27 references to helper functions across test file |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SETUP-01 | 01-01, 01-02, 01-03 | `.mcp.json` generated with Agent42 MCP server entry | SATISFIED | `generate_mcp_config()` produces .mcp.json; functional test passes; setup.sh wired |
| SETUP-02 | 01-01, 01-02, 01-03 | `.claude/settings.json` patched with all Agent42 hooks | SATISFIED | `register_hooks()` reads frontmatter, merges hooks; idempotent; setup.sh wired |
| SETUP-03 | 01-01, 01-03 | Project repo indexed by jcodemunch automatically | SATISFIED | `jcodemunch_index.py` sends MCP JSON-RPC; soft failure in setup.sh; `TestJcodemunchIndex` passes |
| SETUP-04 | 01-01, 01-02, 01-03 | Re-run without overwriting existing config (idempotent) | SATISFIED | Functional idempotency test passes; `TestIdempotency` class: both tests pass; stale-path detection for agent42 entry |
| SETUP-05 | 01-01, 01-02, 01-03 | Post-setup health report for MCP server, jcodemunch, Qdrant | SATISFIED | `check_health()` probes 5 services; `print_health_report()` outputs colored pass/fail; `TestHealthReport` passes |

**Note on REQUIREMENTS.md:** The traceability table in REQUIREMENTS.md still shows SETUP-01 through SETUP-05 as `[ ]` (unchecked) and the status column says "setup.sh integration pending (01-03)" — this is stale documentation. The implementation is complete but REQUIREMENTS.md was not updated to reflect completion. This is a documentation gap, not an implementation gap.

**Orphaned requirements for Phase 2 (correctly excluded):** SETUP-06, SETUP-07 are mapped to Phase 2 in REQUIREMENTS.md and are correctly not claimed by Phase 1 plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scripts/setup_helpers.py` | 515 | Unicode characters `✓` and `✗` in `print_health_report()` using raw `print()` without encoding guard | Info | On Windows with default cp1252 console encoding, `print_health_report()` raises `UnicodeEncodeError`. Does not affect target platform (Linux/VPS). No impact on Phase 1 goal which targets Linux only. |
| `tests/test_auth_flow.py` | 156 | Pre-existing test failure (`test_protected_endpoint_requires_auth` expects 401, gets 404) | Info | Pre-existing from v2.0 MCP pivot (before this phase). Documented in all 3 plan summaries. Not caused by Phase 1 changes. Does not affect `test_setup.py` (28/28 pass). |

### Human Verification Required

#### 1. End-to-End Setup on Linux/VPS

**Test:** Clone agent42 repo on a fresh Linux server, `source .venv/bin/activate`, then `bash setup.sh`
**Expected:** `.mcp.json` created with agent42 entry pointing to venv Python path; `.claude/settings.json` updated with all 12 hooks under correct event keys; jcodemunch indexing attempts (passes if uvx present, warns if absent); health report printed showing per-service pass/fail
**Why human:** Requires Linux OS environment, actual Python venv, real uvx/jcodemunch installation, and live subprocess spawning — cannot simulate fully on Windows dev machine

#### 2. Idempotency Integration Test

**Test:** Run `bash setup.sh` twice in a row on a configured Linux system
**Expected:** Second run produces no changes — existing .mcp.json and settings.json entries unchanged, no duplicate hook registrations
**Why human:** Unit tests verify the Python helper idempotency; integration path through setup.sh on real Linux files with real settings requires live environment

### Gaps Summary

No gaps found. All 5 success criteria from ROADMAP are satisfied by verified, substantive, wired implementations.

The two items flagged for human verification are integration-level end-to-end tests that are appropriately outside automated verification scope. The Unicode issue in `print_health_report` is a Windows-only display quirk that does not affect the target platform (Linux/VPS).

**Minor documentation debt:** REQUIREMENTS.md traceability table was not updated after Plan 03 completion — SETUP-01 through SETUP-05 still show `[ ]` and stale "pending" status. Recommend updating as housekeeping before Phase 2.

---

_Verified: 2026-03-18T20:30:00Z_
_Verifier: Claude (gsd-verifier)_
