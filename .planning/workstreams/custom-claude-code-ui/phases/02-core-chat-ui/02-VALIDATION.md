---
phase: 2
slug: core-chat-ui
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest (backend) + manual browser (frontend) |
| **Config file** | pyproject.toml |
| **Quick run command** | `python -m pytest tests/ -x -q -k "cc_chat"` |
| **Full suite command** | `python -m pytest tests/ -x -q` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python -m pytest tests/ -x -q -k "cc_chat"`
- **After every plan wave:** Run `python -m pytest tests/ -x -q`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 1 | CHAT-01 | unit | `python -m pytest tests/ -x -q -k "cc_chat"` | ❌ W0 | ⬜ pending |
| 2-01-02 | 01 | 1 | CHAT-02/03 | manual | browser visual | N/A | ⬜ pending |
| 2-01-03 | 01 | 1 | CHAT-04/05 | manual | browser visual | N/A | ⬜ pending |
| 2-02-01 | 02 | 2 | INPUT-01..04 | manual | browser interaction | N/A | ⬜ pending |
| 2-02-02 | 02 | 2 | CHAT-06/07 | unit | `python -m pytest tests/ -x -q -k "cc_chat"` | ❌ W0 | ⬜ pending |
| 2-02-03 | 02 | 2 | CHAT-08/09 | manual | browser interaction | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_cc_chat_ws.py` — stubs for stop/streaming backend logic
- [ ] Existing `tests/conftest.py` — shared fixtures (exists)

*Existing test infrastructure covers most phase requirements; Wave 0 adds backend WS tests only.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Streaming bubble with blinking cursor | CHAT-01 | DOM animation | Open chat tab, send message, observe token-by-token rendering |
| Markdown rendering (headers, code) | CHAT-02 | Visual DOM | Send markdown-heavy message, verify rendered output |
| Auto-scroll pinning | CHAT-04 | Scroll behavior | Send long response, scroll up mid-stream, verify scroll-to-bottom button appears |
| Shift+Enter newline | INPUT-02 | Keyboard event | Press Shift+Enter in input, verify newline inserted |
| Slash command dropdown | INPUT-04 | DOM popup | Type `/` in input, verify autocomplete appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
