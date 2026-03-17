---
workstream: per-project-task-memories
created: 2026-03-17
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-17)

**Core value:** Agent42 must always be able to run agents reliably, with tiered provider routing ensuring no single provider outage stops the platform.
**Current focus:** v1.4 Per-Project/Task Memories — Phase 20: Task Metadata Foundation

## Current Position

Phase: 20 of 23 (Task Metadata Foundation)
Plan: 1 of 1 in current phase (plan 01 complete)
Status: Phase 20 complete — ready for Phase 21
Last activity: 2026-03-17 — Plan 20-01 executed: TaskType enum + task lifecycle protocol + payload injection

Progress: [##░░░░░░░░] 25%

## Performance Metrics

**Velocity:**
- Total plans completed: 1
- Average duration: 5 min
- Total execution time: ~0.1 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 20. Task Metadata Foundation | 1 | 5 min | 5 min |
| 21. Tracking and Learning | 0 | — | — |
| 22. Proactive Injection | 0 | — | — |
| 23. Recommendations Engine | 0 | — | — |

## Accumulated Context

### Decisions

- Payload-first order: TMETA schema must exist before any tracking/extraction/retrieval is built
- RETR-01/02 grouped with Phase 20: type-aware retrieval is a search layer change that belongs with schema work, not injection work
- Tracking and extraction together in Phase 21: both depend on ToolTracker and share test infrastructure
- Injection (Phase 22) before recommendations (Phase 23): injection delivers value on every task; recommendations need accumulated data
- get_task_context() returns string value of enum (not the enum member) — Qdrant payloads must be JSON-serializable strings
- Task fields conditionally injected (only when non-None) — outside task context, payload has no task_id/task_type keys at all
- Payload indexes scoped to MEMORY and HISTORY only — CONVERSATIONS and KNOWLEDGE not needed for task filtering
- Lazy import of get_task_context inside methods to prevent circular imports (memory -> core direction only)

### Key Architecture Constraints (from research)

- aiosqlite + instructor are the only new dependencies; everything else extends existing patterns
- Fire-and-forget tracking is non-negotiable — synchronous SQLite writes add 300-1500ms on a 100-call task
- Quarantine (LEARN-04) and score gate (RETR-04 >= 0.80) must be in from day one, not added later
- LEARNING_MIN_EVIDENCE and LEARNING_QUARANTINE_HOURS must be config-driven for tuning without code changes

### Research Flags for Upcoming Phases

- Phase 21: instructor extraction prompt schema needs careful design (noisy learnings hard to reverse)
- Phase 22: task-type detection at hook time without LLM call — verify IntentClassifier keyword path is reusable

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-03-17
Stopped at: Completed 20-task-metadata-foundation/20-01-PLAN.md
Resume file: .planning/workstreams/per-project-task-memories/phases/20-task-metadata-foundation/20-01-SUMMARY.md
