# Phase 35: Paperclip Integration - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-06
**Phase:** 35-paperclip-integration
**Mode:** assumptions (--auto)
**Areas analyzed:** Dependency Strategy, Provider Selection via Sidecar, Model Discovery, Provider Status, Settings UI, Backward Compatibility

## Assumptions Presented

### Dependency Strategy
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phases 32+33 have NOT been executed — no directories, plans, or code exist | Confident | `find .planning/workstreams/provider-selection-refactor/phases` shows only 34-system-simplification |
| Scope to UI-01 now; stub interfaces for UI-02/03/04 | Likely | No Synthetic.new client, no CC Subscription code, no model discovery endpoints |

### Provider Selection via Sidecar
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| TieredRoutingBridge is the single routing authority | Confident | core/tiered_routing_bridge.py resolve() method, SidecarOrchestrator injection |
| Agent role must be passed via adapter-run | Confident | tiered_routing_bridge.py:34-42 _ROLE_CATEGORY_MAP, manifest.ts route_task tool |

### Model Discovery
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New GET /sidecar/models endpoint needed | Likely | No model listing endpoint exists; PROVIDER_MODELS is internal-only |
| Alternative: Embed in health response | Likely | Would avoid new endpoint but couples concerns |

### Provider Status
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Enhance health response with per-provider status | Likely | Current HealthResponse has generic providers dict |
| Alternative: Separate /provider/status endpoint | Likely | Cleaner separation but more endpoints to maintain |

### Settings UI
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add SYNTHETIC_API_KEY to SettingsPage | Confident | manifest.ts documents the key; SettingsPage pattern for other keys |

### Backward Compatibility
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Missing role falls back to "general" | Confident | tiered_routing_bridge.py:170 .get(role or "", "general") |
| Reward tier comes from Agent42 only | Confident | tiered_routing_bridge.py:156-167 RewardSystem scoring |

## Corrections Made

No corrections — all assumptions auto-confirmed (--auto mode).

## Auto-Resolved

- Dependency Strategy: auto-selected "scope to achievable now, stub interfaces for blocked requirements"
- Model Discovery: auto-selected "new dedicated endpoint" over "embed in health response" (cleaner separation)
- Provider Status: auto-selected "enhance existing health endpoint" over "separate endpoint" (avoid endpoint sprawl)

## External Research Flagged

1. Synthetic.new API specification (endpoint URLs, auth, model list response format)
2. Claude Code Subscription API (no code exists; needed for Phase 32)
3. Paperclip Plugin SDK limitations (real-time updates, adapter config schema)
4. Existing OpenAI-compatible client patterns for Synthetic.new wrapping
