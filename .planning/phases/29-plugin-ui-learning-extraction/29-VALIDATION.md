---
phase: 29
slug: plugin-ui-learning-extraction
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-30
---

# Phase 29 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | vitest 3.x (TypeScript plugin) + pytest 7.x (Python sidecar) |
| **Config file** | `plugins/agent42-paperclip/vitest.config.ts` + `pytest.ini` |
| **Quick run command** | `cd plugins/agent42-paperclip && npx vitest run --reporter=verbose` |
| **Full suite command** | `cd plugins/agent42-paperclip && npx vitest run && cd ../.. && python -m pytest tests/ -x -q` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd plugins/agent42-paperclip && npx vitest run --reporter=verbose`
- **After every plan wave:** Run full suite (vitest + pytest)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 29-01-01 | 01 | 1 | UI-01 | unit | `npx vitest run --reporter=verbose` | ❌ W0 | ⬜ pending |
| 29-01-02 | 01 | 1 | UI-02 | unit | `npx vitest run --reporter=verbose` | ❌ W0 | ⬜ pending |
| 29-01-03 | 01 | 1 | UI-03 | unit | `npx vitest run --reporter=verbose` | ❌ W0 | ⬜ pending |
| 29-01-04 | 01 | 1 | UI-04 | unit | `npx vitest run --reporter=verbose` | ❌ W0 | ⬜ pending |
| 29-02-01 | 02 | 1 | UI-01 | unit | `python -m pytest tests/test_sidecar_ui_endpoints.py -x -q` | ❌ W0 | ⬜ pending |
| 29-02-02 | 02 | 1 | UI-03 | unit | `python -m pytest tests/test_memory_run_trace.py -x -q` | ❌ W0 | ⬜ pending |
| 29-03-01 | 03 | 2 | LEARN-01 | unit+integration | `python -m pytest tests/test_learning_extraction.py -x -q` | ❌ W0 | ⬜ pending |
| 29-03-02 | 03 | 2 | LEARN-02 | integration | `python -m pytest tests/test_learning_extraction.py -x -q` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `plugins/agent42-paperclip/tests/ui/` — test stubs for UI component rendering
- [ ] `tests/test_sidecar_ui_endpoints.py` — stubs for new sidecar GET endpoints
- [ ] `tests/test_memory_run_trace.py` — stubs for run_id tracing in memory pipeline
- [ ] `tests/test_learning_extraction.py` — stubs for transcript capture + batch extraction
- [ ] `esbuild` + `react` + `@types/react` installed as devDependencies

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| detailTab renders on Paperclip agent page | UI-01 | Requires running Paperclip host | Open agent detail page, verify "Effectiveness" tab appears |
| dashboardWidget renders on Paperclip dashboard | UI-02 | Requires running Paperclip host | Open dashboard, verify "Provider Health" widget appears |
| Memory browser shows injected/extracted data | UI-03 | Requires run with memory pipeline | Execute an agent run, open run detail, verify Memory tab |
| Learning extraction feedback loop | LEARN-02 | End-to-end across sidecar + Qdrant | Run agent, wait 1h, recall memories for same agent type |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
