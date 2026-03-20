---
phase: 2
slug: gsd-auto-activation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x with asyncio_mode = "auto" |
| **Config file** | `pyproject.toml` |
| **Quick run command** | `python -m pytest tests/test_skill_loader.py tests/test_context_loader.py -x -q` |
| **Full suite command** | `python -m pytest tests/ -v` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python -m pytest tests/test_skill_loader.py tests/test_context_loader.py -x -q`
- **After every plan wave:** Run `python -m pytest tests/ -v`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | GSD-01 | unit | `python -m pytest tests/test_skill_loader.py -x -q -k "gsd"` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 1 | GSD-02 | smoke | `grep "## Development Methodology" CLAUDE.md` | ✅ | ⬜ pending |
| 02-03-01 | 03 | 1 | GSD-03 | unit | `python -m pytest tests/test_context_loader.py -x -q -k "gsd"` | ❌ W0 | ⬜ pending |
| 02-03-02 | 03 | 1 | GSD-04 | unit | `python -m pytest tests/test_context_loader.py -x -q -k "trivial or active_workstream"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_context_loader.py` — new file covering GSD work type detection, nudge emission, trivial skip logic, active-workstream suppression
- [ ] Extend `tests/test_skill_loader.py` with `test_gsd_auto_activate_skill_always_loads` (requires skill file from Wave 1)

*Existing infrastructure (pytest, conftest.py fixtures) covers all framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Claude naturally mentions GSD in response | GSD-01 | Behavioral — depends on LLM generation | Submit "build a Flask app" in Claude Code and observe first response mentions GSD |
| GSD nudge appears in VS Code chat stream | GSD-03 | Requires real Claude Code + VS Code | Submit multi-step prompt, check stderr output in chat |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
