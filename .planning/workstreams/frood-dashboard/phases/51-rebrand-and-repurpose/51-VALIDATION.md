---
phase: 51
slug: rebrand-and-repurpose
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-07
---

# Phase 51 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest |
| **Config file** | none (default discovery) |
| **Quick run command** | `python -m pytest tests/test_rebrand_phase51.py -x -q` |
| **Full suite command** | `python -m pytest tests/ -v` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python -m pytest tests/test_rebrand_phase51.py -x -q`
- **After every plan wave:** Run `python -m pytest tests/ -x -q`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 51-01-01 | 01 | 1 | W0 bootstrap | W0 create | `python -m pytest tests/test_rebrand_phase51.py -x -q` | W0 task | ⬜ pending |
| 51-01-02 | 01 | 1 | BRAND-01, BRAND-03, SET-01..04 | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py -x -q` | ✅ (51-01-01) | ⬜ pending |
| 51-02-01 | 02 | 2 | RPT-01, RPT-02, RPT-03 | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_reports_tabs -x` | ✅ (51-01-01) | ⬜ pending |
| 51-02-02 | 02 | 2 | RPT-04 | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_intelligence_overview -x` | ✅ (51-01-01) | ⬜ pending |
| 51-03-01 | 03 | 3 | FEED-01, FEED-02, FEED-03 | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_activity_endpoint -x` | ✅ (51-01-01) | ⬜ pending |
| 51-03-02 | 03 | 3 | BRAND-02 | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_sidebar_nav -x` | ✅ (51-01-01) | ⬜ pending |
| 51-04-01 | 04 | 4 | BRAND-04 | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_setup_wizard_copy -x` | ✅ (51-01-01) | ⬜ pending |
| 51-04-02 | 04 | 4 | CLEAN-05 | unit (grep) | `python -m pytest tests/test_rebrand_phase51.py::test_readme_updated -x` | ✅ (51-01-01) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_rebrand_phase51.py` — stubs for all BRAND/RPT/FEED/SET/CLEAN requirements
  - Pattern: same as `tests/test_settings_ui.py` — read app.js and server.py at module level, assert string presence/absence
  - No network calls needed — all assertions are string grep against file content

*Existing infrastructure covers test framework. Only new test file needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SVG files render correctly after rename | BRAND-03 | Visual verification | Open dashboard, check logo/avatar/favicon display |
| Activity Feed real-time updates | FEED-02 | WebSocket behavior | Trigger a memory recall, verify event appears in feed |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
