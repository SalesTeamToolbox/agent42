---
phase: 53
slug: frontend-identity-sidecar-auth
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-08
---

# Phase 53 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x (backend), manual grep (frontend) |
| **Config file** | tests/ directory (no pytest.ini — uses defaults) |
| **Quick run command** | `python -m pytest tests/ -x -q` |
| **Full suite command** | `python -m pytest tests/ -v` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python -m pytest tests/ -x -q`
- **After every plan wave:** Run `python -m pytest tests/ -v`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 53-01-01 | 01 | 1 | FE-01 | grep | `grep -c "frood_token" dashboard/frontend/dist/app.js` | ✅ | ⬜ pending |
| 53-01-02 | 01 | 1 | FE-02 | grep | `grep -c "frood_auth" dashboard/frontend/dist/app.js` | ✅ | ⬜ pending |
| 53-01-03 | 01 | 1 | FE-03 | grep | `grep -c "agent42" dashboard/frontend/dist/app.js` (expect 0 or migration comments only) | ✅ | ⬜ pending |
| 53-02-01 | 02 | 1 | AUTH-01 | unit | `python -m pytest tests/test_sidecar_token.py -v` | ❌ W0 | ⬜ pending |
| 53-02-02 | 02 | 1 | AUTH-03 | curl | `curl -s http://localhost:8001/sidecar/health` (manual) | ✅ | ⬜ pending |
| 53-03-01 | 03 | 2 | AUTH-02 | grep | `grep "apiKey" adapters/agent42-paperclip/src/types.ts` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_sidecar_token.py` — stubs for AUTH-01 (POST /sidecar/token password + API key paths)

*Note: No framework install needed — pytest already present.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| localStorage migration on page load | FE-01 | Requires browser with existing agent42_token | Open dashboard with agent42_token in localStorage, verify frood_token appears and agent42_token is deleted |
| Cross-tab BroadcastChannel sync | FE-02 | Requires multiple browser tabs | Open two tabs, login in one, verify other tab syncs via frood_auth channel |
| Adapter auto-provisioning | AUTH-02 | Requires Paperclip adapter running | Configure adapter with apiKey, verify it calls /sidecar/token and gets JWT |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
