# Phase 51: Rebrand & Repurpose - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the discussion.

**Date:** 2026-04-07
**Phase:** 51-rebrand-and-repurpose
**Mode:** discuss
**Areas discussed:** Reports repurposing, Activity Feed design, Branding sweep, Settings cleanup

## Gray Areas Presented

All 4 areas selected by user.

## Discussion

### Reports Repurposing
| Question | Options | Selected |
|----------|---------|----------|
| What should Overview tab show? | Intelligence dashboard / Provider-focused / Minimal tokens+costs | Intelligence dashboard |
| What happens to Tasks & Projects tab? | Delete entirely / Replace with Effectiveness tab | Delete entirely |
| Should Activity get own Reports tab or separate? | Separate sidebar page / New tab in Reports | Separate sidebar page |

### Activity Feed Design
| Question | Options | Selected |
|----------|---------|----------|
| What events to capture? | Memory+routing+effectiveness / Memory only / Everything including proxy | Memory + routing + effectiveness |
| How should events reach frontend? | WebSocket push / Polling API | WebSocket push |
| How should events be stored? | In-memory ring buffer / SQLite / Redis stream | In-memory ring buffer |

### Branding Sweep
| Question | Options | Selected |
|----------|---------|----------|
| How deep should rename go? | UI text + API title only / Full sweep / Minimal | User: "use best judgment, push internals to future phase" |
| What about logo SVG files? | Keep filenames / Rename to frood-* | Rename SVG files to frood-* |
| Setup wizard text? | Frood intelligence identity / Towel-themed humor / You decide | You decide |

### Settings Cleanup
| Question | Options | Selected |
|----------|---------|----------|
| What should Orchestrator tab become? | Rename to Routing / Merge into API Keys / Rename to LLM Proxy | Rename to Routing |
| Any other Settings changes? | No other changes / Clean Security tab / Rename remaining tabs | No other changes |

## Corrections Made

No corrections — all decisions captured from fresh discussion.
