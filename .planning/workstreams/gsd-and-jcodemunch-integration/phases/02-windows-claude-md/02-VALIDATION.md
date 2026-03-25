---
phase: 2
slug: windows-claude-md
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x + pytest-asyncio |
| **Config file** | `pyproject.toml` (asyncio_mode = "auto") |
| **Quick run command** | `python -m pytest tests/test_setup_helpers.py -x -q` |
| **Full suite command** | `python -m pytest tests/ -x -q` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python -m pytest tests/test_setup_helpers.py -x -q`
- **After every plan wave:** Run `python -m pytest tests/ -x -q`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | SETUP-06 | unit | `python -m pytest tests/test_setup_helpers.py -k "windows or venv_python" -x` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | SETUP-06 | integration | `bash setup.sh --quiet` (on Windows Git Bash) | N/A manual | ⬜ pending |
| 02-01-03 | 01 | 1 | SETUP-06 | unit | `python -m pytest tests/test_setup_helpers.py -k "gitattributes or crlf" -x` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 2 | SETUP-07 | unit | `python -m pytest tests/test_setup_helpers.py -k "generate_full_claude_md" -x` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | SETUP-07 | unit | `python -m pytest tests/test_setup_helpers.py -k "project_aware" -x` | ❌ W0 | ⬜ pending |
| 02-02-03 | 02 | 2 | SETUP-07 | integration | `bash setup.sh generate-claude-md --quiet` | N/A manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_setup_helpers.py` — add test classes for Windows venv detection, .gitattributes generation, CLAUDE.md template generation
- [ ] Existing `conftest.py` — sufficient, no new fixtures needed

*Existing test infrastructure covers framework requirements. Wave 0 adds test stubs only.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| setup.sh runs in Git Bash on Windows | SETUP-06 | Requires actual Git Bash environment | Run `bash setup.sh --quiet` in Git Bash, verify no errors |
| Generated CLAUDE.md readable in editor | SETUP-07 | Visual verification of formatting | Open generated file, check sections present |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
