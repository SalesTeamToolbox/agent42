---
phase: 36
slug: paperclip-integration-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 36 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x (Python backend) / TypeScript tsc --noEmit (plugin frontend) |
| **Config file** | `tests/` directory (pytest) / `plugins/agent42-paperclip/tsconfig.json` (tsc) |
| **Quick run command** | `python -m pytest tests/ -x -q` |
| **Full suite command** | `python -m pytest tests/ -v && cd plugins/agent42-paperclip && npx tsc --noEmit` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python -m pytest tests/ -x -q`
- **After every plan wave:** Run `python -m pytest tests/ -v && cd plugins/agent42-paperclip && npx tsc --noEmit`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 36-01-01 | 01 | 1 | PAPERCLIP-01 | integration | `python -m pytest tests/test_sidecar_terminal.py -v` | ❌ W0 | ⬜ pending |
| 36-01-02 | 01 | 1 | PAPERCLIP-02 | integration | `python -m pytest tests/test_sidecar_apps.py -v` | ❌ W0 | ⬜ pending |
| 36-02-01 | 02 | 2 | PAPERCLIP-01 | type-check | `cd plugins/agent42-paperclip && npx tsc --noEmit` | ✅ | ⬜ pending |
| 36-02-02 | 02 | 2 | PAPERCLIP-02 | type-check | `cd plugins/agent42-paperclip && npx tsc --noEmit` | ✅ | ⬜ pending |
| 36-03-01 | 03 | 2 | PAPERCLIP-03 | integration | `python -m pytest tests/test_tools_skills.py -v` | ❌ W0 | ⬜ pending |
| 36-04-01 | 04 | 3 | PAPERCLIP-04 | integration | `python -m pytest tests/test_dashboard_retirement.py -v` | ❌ W0 | ⬜ pending |
| 36-04-02 | 04 | 3 | PAPERCLIP-05 | type-check | `cd plugins/agent42-paperclip && npx tsc --noEmit` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_sidecar_terminal.py` — stubs for PAPERCLIP-01 terminal endpoints
- [ ] `tests/test_sidecar_apps.py` — stubs for PAPERCLIP-02 app endpoints
- [ ] `tests/test_tools_skills.py` — stubs for PAPERCLIP-03 tool/skill registration
- [ ] `tests/test_dashboard_retirement.py` — stubs for PAPERCLIP-04 redundant component removal

*Existing pytest infrastructure covers framework needs — no new install required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Terminal renders in Paperclip UI | PAPERCLIP-01 | Requires browser rendering | Open Paperclip → Agent42 page → verify terminal component loads |
| Apps panel shows in workspace | PAPERCLIP-02 | Requires Paperclip runtime | Open Paperclip → Agent42 page → verify apps list renders |
| Settings panel in Paperclip admin | PAPERCLIP-05 | Requires Paperclip settings UI | Open Paperclip → Settings → verify Agent42 tab exists |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
