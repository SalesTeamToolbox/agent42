---
phase: 1
slug: backend-ws-bridge
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest with pytest-asyncio |
| **Config file** | `pyproject.toml` — `asyncio_mode = "auto"` |
| **Quick run command** | `python -m pytest tests/test_cc_bridge.py -x -q` |
| **Full suite command** | `python -m pytest tests/ -x -q` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python -m pytest tests/test_cc_bridge.py -x -q`
- **After every plan wave:** Run `python -m pytest tests/ -x -q`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 0 | BRIDGE-01 through BRIDGE-06 | unit stubs | `python -m pytest tests/test_cc_bridge.py -x -q` | ❌ W0 | ⬜ pending |
| 1-02-01 | 02 | 1 | BRIDGE-01 | unit (source inspection) | `pytest tests/test_cc_bridge.py::TestCCBridgeRouting::test_endpoint_defined -x` | ❌ W0 | ⬜ pending |
| 1-02-02 | 02 | 1 | BRIDGE-02 | unit (NDJSON parser) | `pytest tests/test_cc_bridge.py::TestNDJSONParser -x` | ❌ W0 | ⬜ pending |
| 1-02-03 | 02 | 1 | BRIDGE-03 | unit (file I/O) | `pytest tests/test_cc_bridge.py::TestSessionRegistry -x` | ❌ W0 | ⬜ pending |
| 1-02-04 | 02 | 1 | BRIDGE-04 | unit (source inspection) | `pytest tests/test_cc_bridge.py::TestMultiTurn -x` | ❌ W0 | ⬜ pending |
| 1-02-05 | 02 | 1 | BRIDGE-05 | unit (mock shutil.which) | `pytest tests/test_cc_bridge.py::TestFallback -x` | ❌ W0 | ⬜ pending |
| 1-02-06 | 02 | 1 | BRIDGE-06 | unit (mock subprocess) | `pytest tests/test_cc_bridge.py::TestAuthStatus -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_cc_bridge.py` — stubs for BRIDGE-01 through BRIDGE-06
- [ ] `tests/fixtures/cc_stream_sample.ndjson` — recorded live CC output for BRIDGE-02 parser tests (manual capture required for `--verbose` tool output verification — see Open Question 1 in RESEARCH.md)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `--verbose` tool output field names in NDJSON | BRIDGE-02 | Tool result field paths not verified from live session; SDK docs only cover tool input streaming | Run `claude -p "use the list_files tool" --output-format stream-json --verbose --include-partial-messages` and inspect raw NDJSON output for tool result content block structure |
| WebSocket client receives events end-to-end | BRIDGE-01 | Requires live CC CLI + browser WS client | Connect to `/ws/cc-chat?token=<jwt>`, send a message, verify browser console shows `text_delta`, `turn_complete` events |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
