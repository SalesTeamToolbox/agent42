# Phase 50: Strip Harness Features - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-07
**Phase:** 50-strip-harness-features
**Mode:** assumptions (--auto, with user discussion)
**Areas analyzed:** Feature classification, frontend approach, auth simplification, removal strategy

## User Discussion (pre-assumptions)

User and Claude discussed all dashboard features in the prior conversation turn. Key user decisions:

### Apps
- **User question:** "Are Apps something that agent harnesses like Paperclip offer?"
- **Claude analysis:** Apps is unique to Frood — sandboxed app building from natural language. No harness does this. Meatheadgear is the proof case.
- **User decision:** Keep. Rename to "Agent Apps" (Phase 51).

### Agent Profiles
- **User question:** "Would keeping the routing config add benefit to agents in Paperclip/other harnesses?"
- **Claude analysis:** PUT endpoint already returns 410 Gone. Routing overrides are dead. Profile CRUD is harness territory. TieredRoutingBridge handles routing internally.
- **User decision:** Remove.

### Activity Feed
- **User decision:** Repurpose to memory/routing event tracking (Phase 51). Remove current task-based version in Phase 50.

### Persona
- **User question:** "Is this needed?"
- **Claude analysis:** No chat = no persona. Dropping both makes a clean break — Frood is the towel, not the spaceship.
- **User decision:** Remove. "Seems like a clean break to show exactly what Frood is meant to be."

### Chat
- **User decision:** Remove. Frood is 100% a strap-on service, must have a harness to function.

## Assumptions Confirmed (--auto)

All assumptions were pre-confirmed by user discussion. No auto-resolution needed.

## Codebase Analysis

- server.py: 6,455 lines, ~1,600 lines to remove
- app.js: 8,924 lines, hand-written SPA (NOT compiled), ~3,000+ lines to remove
- auth.py: 218 lines, ~70 lines to simplify
- No frontend build system — surgical editing possible
- Chat and Memory are decoupled — safe independent removal
- Activity Feed is in-memory — safe to delete
