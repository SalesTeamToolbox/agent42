# Phase 01: Cross-CLI Setup Core - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning
**Source:** PRD Express Path (`C:\Users\rickw\.claude\plans\with-our-claude-code-wobbly-goblet.md`)

<domain>
## Phase Boundary

This phase delivers a complete v1 cross-CLI setup feature for Frood:

1. A user-level manifest at `~/.frood/cli.yaml` (new directory — Frood has no user-level state today)
2. A new MCP tool `frood_skill` on Frood's existing MCP server that exposes the Claude Code warehouse (skills, commands, agents) + Frood's built-in personas/skills as an on-demand inventory + load API
3. A `frood cli-setup` CLI subcommand with sub-actions `detect`, `claude-code`, `opencode`, `all`, `unwire`
4. A matching dashboard panel with toggles per detected CLI
5. Tests covering merge idempotency, wire/unwire byte-identical round-trip, and manifest default-fill

OpenCode has no skill/command/agent concept — its extension model is declarative (`opencode.json` + `.opencode/` plugins + MCP). The `frood_skill` MCP tool is the cross-CLI parity bridge: Claude Code users keep `/use` + warehouse; OpenCode users invoke `frood_skill list` / `load` to get the same inventory on-demand.

</domain>

<decisions>
## Implementation Decisions

### User-level config surface
- Introduce `~/.frood/` directory — greenfield (all existing Frood state is project-local `.frood/`)
- Manifest path: `~/.frood/cli.yaml`
- Minimal manifest shape:
  ```yaml
  clis:
    claude-code: { enabled: true }
    opencode: { enabled: true, projects: auto }  # or explicit list of paths
  warehouse:
    include_claude_warehouse: true
    include_frood_builtins: true
  ```
- Absent manifest file → `frood cli-setup` creates with defaults
- Partial manifest → missing keys filled with defaults (no crash)

### MCP bridge tool
- Single new tool `frood_skill` registered in [mcp_server.py:_build_registry](c:/Users/rickw/projects/frood/mcp_server.py#L87)
- `frood_skill(action="list")` → inventory dict: `{skills: [...], commands: [...], agents: [...], personas: [...], frood_skills: [...]}`
- `frood_skill(action="load", name="<name>")` → `{name, source, body}` where body is the full markdown
- Sources indexed (gated by manifest flags):
  - `~/.claude/skills-warehouse/*/SKILL.md`
  - `~/.claude/commands-warehouse/**/*.md`
  - `~/.claude/agents-warehouse/*.md`
  - Frood built-in personas (reuse whatever backs `frood_persona`)
  - Frood built-in skills via `SkillLoader` ([mcp_server.py:374](c:/Users/rickw/projects/frood/mcp_server.py#L374))
- Missing warehouse paths degrade to empty slice; never crash

### CLI subcommand
- Register `cli-setup` argparse subparser in [frood.py](c:/Users/rickw/projects/frood/frood.py) ~line 411 alongside `backup`/`restore`/`clone`
- Handler `CliSetupCommandHandler` in [commands.py](c:/Users/rickw/projects/frood/commands.py) extending `CommandHandler` ABC (lines 12-17)
- Sub-actions (all idempotent):
  - `frood cli-setup detect` — JSON report of installed CLIs + wiring state
  - `frood cli-setup claude-code` — merge `frood` MCP entry into `~/.claude/settings.json` `mcpServers`
  - `frood cli-setup opencode [<path>]` — detect or accept explicit path; merge `frood` into `opencode.json` `mcp` object; append one-line note to `AGENTS.md` (create if absent)
  - `frood cli-setup all` — wire every enabled CLI in manifest
  - `frood cli-setup unwire <cli>` — reverse operation; round-trip must be byte-identical to pre-wire state

### Claude Code specifics
- Target file: `~/.claude/settings.json`
- Merge into `mcpServers` key only; preserve all other keys byte-for-byte
- Do NOT touch `/use` command, skills, commands, agents, or warehouse — user's existing flow stays intact

### OpenCode specifics
- Target: each detected `opencode.json` at project root (OpenCode has no user-global config)
- Project detection: scan configured paths in manifest (or auto-discover by walking user's projects dir)
- Merge: add `frood` into `mcp` object; preserve `provider`, `instructions`, `server`, other MCP entries
- Also write/update a single line in `AGENTS.md`: note pointing to `frood_skill list` / `load` as warehouse entry point

### Safety
- Before first modification of any CLI config file, write a timestamped backup beside the target (e.g., `opencode.json.bak-20260417T120000`)
- `unwire` returns the file to its pre-wire state exactly (byte-identical)
- Setup NEVER removes/disables user's existing MCP servers, plugins, providers, instructions

### Dashboard
- Mirror existing toggle pattern at [dashboard/server.py:2502](c:/Users/rickw/projects/frood/dashboard/server.py#L2502) (`@app.patch("/api/tools/{name}")`)
- Toggle state persistence: `.frood/cli-setup-state.json` (mirrors [dashboard/server.py:322-334](c:/Users/rickw/projects/frood/dashboard/server.py#L322-L334) pattern)
- Endpoints:
  - `GET /api/cli-setup/detect` — admin-guarded; same `_admin: AuthContext = Depends(require_admin)` pattern
  - `POST /api/cli-setup/wire` with `{cli: str, enabled: bool}` — calls same core functions as CLI subcommand
- Frontend: single panel in [dashboard/frontend/dist/app.js](c:/Users/rickw/projects/frood/dashboard/frontend/dist/app.js); shows detected CLIs with per-CLI toggles, a "What this does" blurb, and a link to docs

### What to reuse, not reinvent
- `SkillLoader` at [mcp_server.py:374](c:/Users/rickw/projects/frood/mcp_server.py#L374) — don't duplicate skill discovery
- `KeyStore.inject_into_environ()` pattern in [core/key_store.py](c:/Users/rickw/projects/frood/core/key_store.py) — precedent for user-scoped file reads with graceful absence
- `Settings.reload_from_env()` at [core/config.py:768](c:/Users/rickw/projects/frood/core/config.py#L768) — hot-reload pattern
- Toggle state pattern in [dashboard/server.py:322-334](c:/Users/rickw/projects/frood/dashboard/server.py#L322-L334)
- `CommandHandler` ABC at [commands.py:12-17](c:/Users/rickw/projects/frood/commands.py#L12)

### Claude's Discretion
- Exact Python class names within `core/cli_setup.py` (suggested: `ClaudeCodeSetup`, `OpenCodeSetup`, shared `CliAdapter` base)
- Whether to use TOML, YAML, or JSON for `~/.frood/cli.yaml` — YAML was suggested in the PRD; if PyYAML isn't already a dep, JSON is acceptable fallback
- Exact backup file naming scheme (timestamped is required; format is flexible)
- Whether the OpenCode auto-detect scans a user-configured project list or walks a known dir — use whatever is simplest and documented
- Whether `AGENTS.md` note is a marker-delimited block (for clean unwire) or simple append — use marker-delimited block to preserve unwire reversibility
- The exact JSON schema of `frood_skill` `list` response beyond the fields listed in decisions

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Approved plan (source of truth for all decisions)
- `C:\Users\rickw\.claude\plans\with-our-claude-code-wobbly-goblet.md` — user-approved implementation plan

### Frood integration points
- `c:\Users\rickw\projects\frood\frood.py` — CLI entry; argparse subparsers registered ~line 368-463
- `c:\Users\rickw\projects\frood\commands.py` — `CommandHandler` ABC + existing handlers; ~line 12-17
- `c:\Users\rickw\projects\frood\mcp_server.py` — MCP tool registry at `_build_registry`, line 87; `SkillLoader` at line 374
- `c:\Users\rickw\projects\frood\core\config.py` — `Settings.from_env()` line ~808; `reload_from_env()` line 768
- `c:\Users\rickw\projects\frood\core\key_store.py` — precedent for user-scoped encrypted file handling
- `c:\Users\rickw\projects\frood\dashboard\server.py` — toggle pattern lines 2502, 2538, 2566; state persistence lines 322-334
- `c:\Users\rickw\projects\frood\dashboard\frontend\dist\app.js` — frontend (vanilla JS, no React)

### CLI-specific target files
- `C:\Users\rickw\.claude\settings.json` — Claude Code user settings (MCP wiring target)
- `c:\Users\rickw\projects\frood\opencode.json` — example OpenCode project config
- `c:\Users\rickw\projects\frood\.opencode\opencode.json` — project-local OpenCode overrides
- `c:\Users\rickw\projects\frood\AGENTS.md` — OpenCode instruction file (target for notification line)

### Warehouse sources (read-only)
- `C:\Users\rickw\.claude\skills-warehouse\*\SKILL.md` — warehoused skills
- `C:\Users\rickw\.claude\commands-warehouse\**\*.md` — warehoused commands
- `C:\Users\rickw\.claude\agents-warehouse\*.md` — warehoused agents
- `C:\Users\rickw\.claude\commands\use.md` — reference: how `/use` routes (do not modify)

### Project conventions
- `c:\Users\rickw\projects\frood\CLAUDE.md` — project rules; note the "all I/O async", "sandbox always on", "graceful degradation" rules
- `c:\Users\rickw\projects\frood\.planning\workstreams\cross-cli-setup\REQUIREMENTS.md` — requirement IDs (CLI-01…CLI-03, MCP-01…MCP-05, CMD-01…CMD-09, DASH-01…DASH-04, SAFE-01…SAFE-03, TEST-01…TEST-04)

</canonical_refs>

<specifics>
## Specific Ideas

- The user runs Claude Code CLI and OpenCode CLI today; expects to add more CLIs later but v1 ships with just these two
- The user explicitly said "simple" regarding the dashboard — no per-skill toggles; manifest is source of truth for inclusion
- Tools in Claude Code are already deferred natively (via `ToolSearch`); this work does NOT try to replicate tool-level lazy-loading — it targets skills/commands/agents which are always loaded
- `/use` in Claude Code is a personal command at `~/.claude/commands/use.md`; it routes at invocation time by reading the warehouse file and executing it. The `frood_skill` MCP tool gives OpenCode an equivalent mechanism.
- User accepted GSD workflow routing — the approved plan is the PRD for this phase

</specifics>

<deferred>
## Deferred Ideas

- Cursor, Aider, Continue — architecture must not paint us into a corner, but no v1 implementation
- Per-skill toggles in dashboard (manifest only for v1)
- Auto-detect-and-prompt on Frood launch (explicit trigger only — CLI command + dashboard)
- Rewriting or altering the user's existing `/use` command (Claude Code already works; leave untouched)

</deferred>

---

*Phase: 01-cross-cli-setup-core*
*Context gathered: 2026-04-17 via PRD Express Path*
