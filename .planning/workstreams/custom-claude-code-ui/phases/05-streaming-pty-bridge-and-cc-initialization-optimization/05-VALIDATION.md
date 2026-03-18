---
phase: 05
slug: streaming-pty-bridge-and-cc-initialization-optimization
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-18
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x with pytest-asyncio |
| **Config file** | `pyproject.toml` `[tool.pytest.ini_options]` |
| **Quick run command** | `python -m pytest tests/test_cc_pty.py -x -q` |
| **Full suite command** | `python -m pytest tests/ -x -q` |
| **Estimated runtime** | ~2 seconds (source inspection + unit tests) |

---

## Sampling Rate

- **After every task commit:** Run `python -m pytest tests/test_cc_pty.py -x -q`
- **After every plan wave:** Run `python -m pytest tests/ -x -q`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | PTY-01..05 | fixture | `python -c "import json; ..."` | W0 | pending |
| 05-01-02 | 01 | 1 | PTY-01..05 | scaffold | `python -m pytest tests/test_cc_pty.py --co -q` | W0 | pending |
| 05-02-01 | 02 | 2 | PTY-02 | unit | `python -m pytest tests/test_cc_pty.py::TestInitProgress -x -q` | W0 dep | pending |
| 05-02-02 | 02 | 2 | PTY-01,04,05 | source inspect | `python -m pytest tests/test_cc_pty.py::TestPTYSubprocess tests/test_cc_pty.py::TestKeepalive tests/test_cc_pty.py::TestGracefulDegradation -x -q` | W0 dep | pending |
| 05-03-01 | 03 | 3 | PTY-03 | source inspect | `python -m pytest tests/test_cc_pty.py::TestPreWarmPool -x -q` | W0 dep | pending |
| 05-03-02 | 03 | 3 | PTY-03 | integration | `python -m pytest tests/test_cc_pty.py -x -v` | W0 dep | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_cc_pty.py` — 13 tests across 5 classes (TestPTYSubprocess, TestInitProgress, TestPreWarmPool, TestKeepalive, TestGracefulDegradation)
- [ ] `tests/fixtures/cc_init_event.ndjson` — sample CC init event with mcp_servers array for unit tests

*Existing `tests/test_cc_bridge.py` covers PTY-04 fallback path; no changes needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real-time token streaming in browser | PTY-01 | Requires live CC subprocess + PTY | Open CC chat, send message, verify tokens appear incrementally |
| Init progress messages visible | PTY-02 | Requires live CC startup with MCP servers | Open CC chat, observe italicized status messages during ~50s init |
| Pre-warm eliminates cold start | PTY-03 | Requires timing comparison | Open CC chat with ?warm=true, send message, verify response in <5s |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 2s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
