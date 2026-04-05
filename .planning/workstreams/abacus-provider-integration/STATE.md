# State: Abacus Provider & Paperclip Autonomy

## Current Phase

Phase 41: Abacus AI Provider Integration — Plan 01 complete, Plan 02 next

## Progress

[████░░░░░░] 40% — 1/2 plans complete in Phase 41

## Decisions

- Abacus AI RouteLLM chosen as provider (OpenAI-compatible, single API key, free-tier models)
- Claude Code subscription preserved for interactive/human use only
- Paperclip autonomous agent execution moves to Abacus API via Agent42 adapter
- Used httpx instead of aiohttp for AbacusApiClient (httpx is project standard per CLAUDE.md)
- Abacus placed at position 4 in provider chain: preferredProvider > claudecode > synthetic > abacus > anthropic

## Completed

- [x] Plan 41-01: Config, key store, provider module, routing, runtime, tests (2026-04-05)
  - providers/abacus_api.py created (AbacusApiClient with httpx)
  - PROVIDER_MODELS["abacus"] with 10 categories (free-tier + premium)
  - Tiered routing: abacus selected when ABACUS_API_KEY set
  - agent_runtime._build_env handles provider="abacus"
  - 27 tests all passing

## Blockers

- Need Abacus AI API key from https://abacus.ai/app/route-llm-apis
