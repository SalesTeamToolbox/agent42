# Phase 02: Tier Assignment - Research

**Researched:** 2026-03-22
**Domain:** Python async background task / dataclass extension / tier state machine
**Confidence:** HIGH

## Summary

Phase 2 builds directly on the Phase 1 foundation (ScoreCalculator, TierCache, RewardSystem in
`core/reward_system.py`). The work is narrow: add a `TierDeterminator` class, extend `AgentConfig`
with four fields and one method, wire a background recalculation loop, and write tests.

Every decision is locked in CONTEXT.md. No technology choices remain open — the implementation
follows patterns already present in the codebase. The only open areas are per-agent error
handling strategy, tier-change logging, and whether recalculation fires immediately at startup or
waits for the first 15-minute interval.

**Primary recommendation:** Follow the HeartbeatService pattern precisely. Use `list_all()` (not a
`list_agents()` method — that method does not exist). Match `stop()` as synchronous, `start()` as
async. Keep `TierDeterminator` pure (no I/O) so it can be unit tested without mocking.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Add `reward_tier: str = ""`, `tier_override: str | None = None`,
`performance_score: float = 0.0`, and `tier_computed_at: str = ""` to the `AgentConfig`
dataclass in `core/agent_manager.py`. Round-trip automatically through existing
`from_dict()`/`to_dict()`/`asdict()` and persist to `agents/{id}.json`.

**D-02:** Add `effective_tier() -> str` method to AgentConfig — returns `tier_override` when
set (not None), otherwise `reward_tier`. Single read point for all downstream consumers.

**D-03:** `tier_override` uses `None` as sentinel (no override). Recalculation loop checks
`tier_override is not None` before skipping an agent. Matches codebase idiom.

**D-04:** New `TierDeterminator` class in `core/reward_system.py` alongside existing classes.
Maps `(score: float, observation_count: int) -> str` using thresholds from `RewardsConfig`.

**D-05:** Returns `"provisional"` when `observation_count < Settings.rewards_min_observations`
(default 10). Provisional agents get default resources, never penalized to Bronze.

**D-06:** Tier names are lowercase strings: `"provisional"`, `"bronze"`, `"silver"`, `"gold"`.
No Enum class — `asdict()` doesn't auto-serialize enums.

**D-07:** Background loop follows HeartbeatService pattern (`core/heartbeat.py:311-329`):
`start()`/`stop()` method pair, `asyncio.create_task(self._recalc_loop())`, `_running` flag,
`stop()` cancels task.

**D-08:** Loop interval: 900 seconds (15 min), matching TierCache TTL from Phase 1.

**D-09:** Recalculation iterates all agents via `AgentManager.list_agents()`, computes score
for each, applies TierDeterminator, updates AgentConfig fields, writes to TierCache. Skips
agents where `tier_override is not None`.

**D-10:** Startup registration in `agent42.py` alongside heartbeat service —
`RewardSystem.start()` called during initialization when `settings.rewards_enabled` is True.

**D-11:** Override stored on AgentConfig field (`tier_override: str | None`), persisted via
existing `agents/{id}.json` mechanism. Set via `AgentManager.update(agent_id, tier_override="gold")`.

**D-12:** No separate overrides file. `AgentManager.update()` already handles partial updates
via `setattr`, making override writes atomic with no new file infrastructure.

### Claude's Discretion

- Whether to emit a log message on tier changes (promotion/demotion)
- Exact error handling in recalculation loop (continue on per-agent error vs. abort)
- Whether recalculation happens immediately on startup or waits for first interval

### Deferred Ideas (OUT OF SCOPE)

- Resource enforcement (model routing, rate limits, concurrency) — Phase 3
- Dashboard REST API for override management — Phase 4
- Dashboard UI for tier display — Phase 4
- Override expiry dates — Phase 4 (dashboard UI needed)
- Tier change audit log — v2
- Hysteresis/cooldown — v2
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TIER-02 | Automatic tier assignment — Bronze/Silver/Gold based on composite score vs configurable thresholds | TierDeterminator.determine(score, obs_count) maps to tier string; thresholds from RewardsConfig.load() |
| TIER-03 | Provisional tier for new agents below minimum observation threshold | TierDeterminator returns "provisional" when obs_count < settings.rewards_min_observations (default 10) |
| ADMN-01 | Admin override stored separately, not clobbered by recalculation | tier_override field on AgentConfig; recalc loop skips agents where tier_override is not None |
| ADMN-03 | Background recalculation runs every 15 minutes, skips overridden agents | TierRecalcLoop with 900s interval; iterates AgentManager.list_all() |
| TEST-02 | Unit tests for tier determination (threshold boundaries, provisional, override precedence) | TestTierDeterminator class + TestAgentConfigTierFields in tests/test_tier_assignment.py |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| asyncio (stdlib) | 3.14 (built-in) | Background task loop via create_task | Already used by HeartbeatService, CronScheduler, SecurityScanner |
| dataclasses (stdlib) | 3.14 (built-in) | AgentConfig field additions | AgentConfig is already a dataclass; asdict() serialization already wired |
| pytest + pytest-asyncio | 9.0.2 + 1.3.0 | Test suite | Project standard; asyncio_mode = "auto" already configured |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| aiofiles | installed | (Not needed here) | Phase 2 has no new file I/O — existing _save() in AgentManager handles it |
| time (stdlib) | built-in | ISO timestamp for tier_computed_at | datetime.utcnow().isoformat() or time.strftime for tier_computed_at string field |

No new package installs required for this phase.

## Architecture Patterns

### Recommended Project Structure

No new files needed beyond what's locked:

```
core/
├── reward_system.py     # ADD: TierDeterminator class (alongside existing classes)
├── agent_manager.py     # EDIT: AgentConfig fields + effective_tier() method
agent42.py               # EDIT: TierRecalcLoop instantiation + start/stop
tests/
└── test_tier_assignment.py   # NEW: Tests for TEST-02 coverage
```

The background loop class (`TierRecalcLoop`) lives in `core/reward_system.py` alongside the
other reward system classes. The CONTEXT.md says "RewardSystem.start()" but RewardSystem
currently has no start/stop — the recalc loop is a new class, or start()/stop() are added
to RewardSystem itself. Either approach works; adding to RewardSystem is cleaner.

### Pattern 1: HeartbeatService Background Loop (canonical)

```python
# Source: core/heartbeat.py:311-329
async def start(self):
    """Start the background loop."""
    self._running = True
    self._task = asyncio.create_task(self._recalc_loop())
    logger.info("TierRecalcLoop started (interval: %ds)", self._interval)

def stop(self):
    """Stop the background loop. Synchronous — matches HeartbeatService."""
    self._running = False
    if self._task:
        self._task.cancel()
        self._task = None
    logger.info("TierRecalcLoop stopped")

async def _recalc_loop(self):
    """Run every interval; skip overridden agents."""
    while self._running:
        try:
            await asyncio.sleep(self._interval)
            await self._run_recalculation()
        except asyncio.CancelledError:
            break
        except Exception as exc:
            logger.error("TierRecalcLoop: unhandled error: %s", exc)
```

**Critical:** `stop()` MUST be synchronous (not async). HeartbeatService.stop() is sync;
agent42.py shutdown currently calls `await self.heartbeat.stop()` which works on a sync method
(Python silently awaits it as a coroutine that returns immediately is not actually awaitable —
this is a pre-existing inconsistency in agent42.py but it does not crash). New TierRecalcLoop
should follow the same sync stop() pattern to stay consistent.

### Pattern 2: TierDeterminator (pure computation, no I/O)

```python
# Source: design decision D-04, D-05, D-06
class TierDeterminator:
    """Maps (score, observation_count) -> tier string.

    Pure computation — no I/O, no side effects.
    Thresholds read from RewardsConfig.load() on each call (mtime-cached, cheap).
    """

    def determine(self, score: float, observation_count: int) -> str:
        """Return tier string: 'provisional', 'bronze', 'silver', or 'gold'."""
        from core.config import settings
        if observation_count < settings.rewards_min_observations:
            return "provisional"
        cfg = RewardsConfig.load()
        if score >= cfg.gold_threshold:
            return "gold"
        if score >= cfg.silver_threshold:
            return "silver"
        return "bronze"
```

**Why pure:** Makes unit tests trivial — no mock needed. Thresholds from RewardsConfig are
mtime-cached so repeated calls in a recalc loop are cheap (one disk read per file change).

### Pattern 3: AgentConfig Field Addition

```python
# Source: core/agent_manager.py:127-167 — existing pattern
@dataclass
class AgentConfig:
    # ... existing fields ...
    reward_tier: str = ""               # D-01: computed tier string
    tier_override: str | None = None    # D-01: admin-set override
    performance_score: float = 0.0     # D-01: last computed score
    tier_computed_at: str = ""          # D-01: ISO timestamp of last computation

    def effective_tier(self) -> str:    # D-02
        """Return override if set, else computed tier."""
        return self.tier_override if self.tier_override is not None else self.reward_tier
```

`from_dict()` uses `{k: v for k, v in data.items() if k in known}` where `known` is the set
of field names. New fields are automatically included in this filter and in `asdict()`.
Existing agent JSON files without these fields will load fine — default values apply.

### Pattern 4: Recalculation Loop Body

```python
async def _run_recalculation(self) -> None:
    """Compute and update tiers for all non-overridden agents."""
    agents = self._agent_manager.list_all()  # NOTE: method is list_all(), not list_agents()
    for agent in agents:
        if agent.tier_override is not None:  # D-03: skip overridden agents
            continue
        try:
            score = await self._reward_system.score(agent.id)
            stats = await self._store.get_agent_stats(agent.id)
            obs_count = stats["task_volume"] if stats else 0
            tier = self._determinator.determine(score, obs_count)
            old_tier = agent.reward_tier
            self._agent_manager.update(
                agent.id,
                reward_tier=tier,
                performance_score=score,
                tier_computed_at=datetime.utcnow().isoformat(),
            )
            if tier != old_tier:
                logger.info("Agent %s tier changed: %s -> %s (score=%.3f)", agent.id, old_tier, tier, score)
        except Exception as exc:
            logger.warning("TierRecalcLoop: error processing agent %s: %s", agent.id, exc)
            # Continue with next agent — per-agent errors must not abort the loop
```

### Pattern 5: Startup Registration in agent42.py

```python
# In Agent42.__init__() after effectiveness_store is set up:
from core.reward_system import RewardSystem, TierDeterminator
# (existing) self.effectiveness_store = EffectivenessStore(data_dir / "effectiveness.db")

self.reward_system = None
self.tier_recalc = None
if settings.rewards_enabled:
    from core.reward_system import TierRecalcLoop
    self.reward_system = RewardSystem(
        effectiveness_store=self.effectiveness_store,
        enabled=True,
        persistence_path=data_dir / "tier_assignments.json",
    )
    self.tier_recalc = TierRecalcLoop(
        agent_manager=self._agent_manager,  # NOTE: agent_manager is in server.py, not agent42.py
        reward_system=self.reward_system,
        effectiveness_store=self.effectiveness_store,
    )

# In Agent42.start():
if self.tier_recalc:
    await self.tier_recalc.start()

# In Agent42.shutdown():
if self.tier_recalc:
    self.tier_recalc.stop()
```

**Important:** `AgentManager` is currently instantiated inside `dashboard/server.py`'s
`create_app()` as `_agent_manager`, not in `agent42.py`. For the recalc loop to access it,
either (a) move `AgentManager` instantiation up to `agent42.py` and pass it into `create_app()`,
or (b) give `TierRecalcLoop` a late-bind `set_agent_manager()` method called after app creation.
Option (a) is cleaner and the right architectural direction.

### Anti-Patterns to Avoid

- **`list_agents()` does not exist:** The correct method is `AgentManager.list_all()`. The
  CONTEXT.md references "list_agents()" but inspection shows the real method name is `list_all()`.
- **Enum for tier names:** `asdict()` does not serialize Enum values to strings automatically
  in all Python versions. Decision D-06 prohibits Enum — use plain lowercase strings.
- **Async stop():** HeartbeatService.stop() is synchronous. Matching it keeps the shutdown
  sequence consistent. Do not make TierRecalcLoop.stop() async.
- **Computing tier in the hot path:** `effective_tier()` reads in-memory `AgentConfig` fields
  — it is O(1). Never call `RewardSystem.score()` (async I/O) from the routing hot path.
- **Clobbering overrides:** The recalc loop MUST check `tier_override is not None` before
  calling `agent_manager.update()`. An unconditional update would overwrite the admin override.
- **Forgetting tier_computed_at on override:** The `tier_computed_at` field only updates when
  the recalc loop runs. Override writes via `update(tier_override="gold")` do NOT change
  `tier_computed_at` — that field tracks computation time, not override time.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic JSON write | Custom file write | `os.replace(tmp, target)` already in TierCache._persist() | Crash-safe; already tested |
| Mtime-cached config | Custom cache | `RewardsConfig.load()` (class-level mtime cache) | Already implemented, already tested |
| Background loop | Custom asyncio machinery | HeartbeatService pattern | Task creation, cancellation, error handling already proven |
| Tier persistence | New persistence layer | TierCache already persists scores; AgentConfig fields persist tier | No new persistence needed |

**Key insight:** Phase 1 did the hard infrastructure work. Phase 2 is mostly wiring.

## Common Pitfalls

### Pitfall 1: Wrong AgentManager Method Name
**What goes wrong:** Calling `agent_manager.list_agents()` raises `AttributeError`.
**Why it happens:** CONTEXT.md references `list_agents()` but the actual method in
`core/agent_manager.py:222` is `list_all()`.
**How to avoid:** Use `agent_manager.list_all()` everywhere.
**Warning signs:** AttributeError on first recalc cycle.

### Pitfall 2: AgentManager Not Available in agent42.py Scope
**What goes wrong:** TierRecalcLoop instantiated in `agent42.py` but `AgentManager` is created
inside `dashboard/server.py::create_app()` and is not accessible from `agent42.py`.
**Why it happens:** The current architecture initializes `_agent_manager` lazily inside `create_app()`.
**How to avoid:** Move `AgentManager` instantiation to `Agent42.__init__()` and pass it as a
parameter to `create_app()`. This is the right direction anyway — agent management is a core
service, not a dashboard concern.
**Warning signs:** NameError or missing attribute when wiring TierRecalcLoop in agent42.py.

### Pitfall 3: Enum Breaks JSON Serialization
**What goes wrong:** `asdict()` serializes Enum members as `<TierName.GOLD: 'gold'>` not `"gold"`.
**Why it happens:** Python's `dataclasses.asdict()` does not convert Enum values to their primitive.
**How to avoid:** Keep tier names as plain lowercase strings per D-06.
**Warning signs:** JSON files contain Enum repr strings instead of clean values.

### Pitfall 4: Recalc Loop Silently Skips All Agents
**What goes wrong:** Loop body has `if tier_override is not None: continue` but the check is
inverted — skips non-overridden agents, recalculates overridden ones.
**Why it happens:** Logic inversion is a common off-by-one in sentinel checks.
**How to avoid:** Write the check as `if agent.tier_override is not None: continue` (skip
overridden, proceed with non-overridden). Test with explicit fixture agents.
**Warning signs:** Overridden agents get their tier reset; non-overridden agents never update.

### Pitfall 5: observation_count from stats Can Be None
**What goes wrong:** `stats["task_volume"]` raises `TypeError` because stats is None for a new agent.
**Why it happens:** `EffectivenessStore.get_agent_stats()` returns None (not empty dict) for
unknown agents — per Phase 1 decision "get_agent_stats() returns None for unknown agent".
**How to avoid:** `obs_count = stats["task_volume"] if stats else 0`; TierDeterminator then
correctly returns `"provisional"`.
**Warning signs:** TypeError in recalc loop for brand-new agents.

### Pitfall 6: from_dict() Ignores Unknown Keys — But only in One Direction
**What goes wrong:** Existing agent files load fine (new fields get defaults). But if you
deploy, create agents, then roll back, the JSON files will have the new fields and old code
will silently ignore them. This is fine for rollback safety but means forward compatibility is
one-way.
**Why it happens:** `from_dict()` filters to known field names: `{k: v for k, v in data.items() if k in known}`.
**How to avoid:** No action needed — this is correct behavior. Just document that the new
fields are additive and backward-compatible.

### Pitfall 7: stop() Async/Sync Mismatch
**What goes wrong:** If `TierRecalcLoop.stop()` is defined as `async def stop()`, then
calling `self.tier_recalc.stop()` in `Agent42.shutdown()` (which uses `await`) would work,
but it would be inconsistent with HeartbeatService and confusing.
**Why it happens:** Easy mistake when following the `async def start()` pattern.
**How to avoid:** Define `stop()` as synchronous. Cancelling a task does not require awaiting.
Note: `agent42.py:224` calls `await self.heartbeat.stop()` on what is actually a sync method.
Python will not error on this but it is a pre-existing bug — don't replicate it.

## Code Examples

### TierDeterminator complete implementation

```python
# Source: core/reward_system.py (to be added alongside existing classes)
class TierDeterminator:
    """Maps (score, observation_count) -> tier string.

    Pure computation — no I/O. Thresholds read from RewardsConfig (mtime-cached).
    Tier names are lowercase strings: 'provisional', 'bronze', 'silver', 'gold'.
    """

    def determine(self, score: float, observation_count: int) -> str:
        """Return tier string for the given score and observation count."""
        from core.config import settings  # Import here to avoid circular at module load
        if observation_count < settings.rewards_min_observations:
            return "provisional"
        cfg = RewardsConfig.load()
        if score >= cfg.gold_threshold:
            return "gold"
        if score >= cfg.silver_threshold:
            return "silver"
        return "bronze"
```

### AgentConfig additions

```python
# Source: core/agent_manager.py — add to existing AgentConfig dataclass
@dataclass
class AgentConfig:
    # ... existing fields ...
    reward_tier: str = ""
    tier_override: str | None = None
    performance_score: float = 0.0
    tier_computed_at: str = ""

    # ... existing methods ...

    def effective_tier(self) -> str:
        """Return override tier if set, otherwise the computed tier.

        This is the single read point for Phase 3 enforcement and Phase 4 dashboard.
        """
        return self.tier_override if self.tier_override is not None else self.reward_tier
```

### Test pattern for TierDeterminator

```python
# Source: tests/test_tier_assignment.py (new file)
class TestTierDeterminator:
    """TEST-02: Tier determination — thresholds, provisional, override precedence."""

    def setup_method(self):
        from core.reward_system import TierDeterminator
        self.det = TierDeterminator()

    def test_below_min_observations_returns_provisional(self):
        # 9 observations < default 10 minimum
        assert self.det.determine(score=0.99, observation_count=9) == "provisional"

    def test_zero_observations_returns_provisional(self):
        assert self.det.determine(score=0.0, observation_count=0) == "provisional"

    def test_at_min_observations_enters_tier_ladder(self):
        # Exactly 10 observations: eligible for bronze/silver/gold
        assert self.det.determine(score=0.0, observation_count=10) == "bronze"

    def test_below_silver_threshold_returns_bronze(self):
        # score=0.64 < silver_threshold=0.65
        assert self.det.determine(score=0.64, observation_count=10) == "bronze"

    def test_at_silver_threshold_returns_silver(self):
        assert self.det.determine(score=0.65, observation_count=10) == "silver"

    def test_between_thresholds_returns_silver(self):
        assert self.det.determine(score=0.75, observation_count=10) == "silver"

    def test_at_gold_threshold_returns_gold(self):
        assert self.det.determine(score=0.85, observation_count=10) == "gold"

    def test_above_gold_threshold_returns_gold(self):
        assert self.det.determine(score=1.0, observation_count=10) == "gold"
```

### Test pattern for AgentConfig tier fields

```python
class TestAgentConfigTierFields:
    """D-01, D-02, D-03: AgentConfig field defaults and effective_tier() logic."""

    def test_new_agent_has_empty_reward_tier(self):
        from core.agent_manager import AgentConfig
        agent = AgentConfig(name="test")
        assert agent.reward_tier == ""
        assert agent.tier_override is None
        assert agent.performance_score == 0.0
        assert agent.tier_computed_at == ""

    def test_effective_tier_returns_reward_tier_when_no_override(self):
        from core.agent_manager import AgentConfig
        agent = AgentConfig(name="test", reward_tier="silver")
        assert agent.effective_tier() == "silver"

    def test_effective_tier_returns_override_when_set(self):
        from core.agent_manager import AgentConfig
        agent = AgentConfig(name="test", reward_tier="bronze", tier_override="gold")
        assert agent.effective_tier() == "gold"

    def test_tier_fields_roundtrip_through_dict(self):
        from core.agent_manager import AgentConfig
        agent = AgentConfig(name="test", reward_tier="silver", tier_override="gold",
                            performance_score=0.77, tier_computed_at="2026-03-22T00:00:00")
        d = agent.to_dict()
        restored = AgentConfig.from_dict(d)
        assert restored.reward_tier == "silver"
        assert restored.tier_override == "gold"
        assert restored.performance_score == pytest.approx(0.77)
        assert restored.tier_computed_at == "2026-03-22T00:00:00"

    def test_from_dict_without_new_fields_uses_defaults(self):
        """Existing agent JSONs without reward fields load without error."""
        from core.agent_manager import AgentConfig
        old_data = {"id": "abc123", "name": "Legacy Agent", "status": "stopped"}
        agent = AgentConfig.from_dict(old_data)
        assert agent.reward_tier == ""
        assert agent.tier_override is None
```

### Test pattern for recalc loop (override skip)

```python
class TestTierRecalcLoop:
    """ADMN-01, ADMN-03: Background recalculation skips overridden agents."""

    @pytest.mark.asyncio
    async def test_overridden_agent_not_recalculated(self, tmp_path):
        from unittest.mock import AsyncMock, MagicMock
        from core.reward_system import TierRecalcLoop
        from core.agent_manager import AgentConfig

        overridden = AgentConfig(id="agent-a", name="A", tier_override="gold")
        plain = AgentConfig(id="agent-b", name="B")

        mock_manager = MagicMock()
        mock_manager.list_all.return_value = [overridden, plain]

        mock_rs = AsyncMock()
        mock_rs.score.return_value = 0.5

        mock_store = AsyncMock()
        mock_store.get_agent_stats.return_value = {"task_volume": 20, "success_rate": 0.5, "avg_speed": 100.0}

        loop = TierRecalcLoop(agent_manager=mock_manager, reward_system=mock_rs,
                              effectiveness_store=mock_store)
        await loop._run_recalculation()

        # agent-a was skipped (has override); agent-b was processed
        calls = [call[0][0] for call in mock_rs.score.call_args_list]
        assert "agent-a" not in calls
        assert "agent-b" in calls
```

## State of the Art

This phase uses only stdlib asyncio patterns — no framework choices involved.

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Enum for status values | Lowercase string constants | Phase 1 established | `asdict()` serializes cleanly; no custom encoder needed |
| Tier computed on every request | Background loop + cache | Phase 1 design | O(1) tier read on hot path |

## Open Questions

1. **Where does `AgentManager` live at init time?**
   - What we know: Currently created inside `dashboard/server.py::create_app()` as a module-level
     side effect (line 3787: `_agent_manager = AgentManager(...)`).
   - What's unclear: Can the TierRecalcLoop reference this after app creation, or must
     `AgentManager` be moved to `agent42.py` scope?
   - Recommendation: Move `AgentManager` instantiation to `Agent42.__init__()` and pass it
     into `create_app()`. This is the cleaner architecture and unblocks Phase 3 resource
     enforcement too.

2. **Immediate recalculation at startup vs. wait for first interval**
   - What we know: CONTEXT.md leaves this to Claude's discretion.
   - Recommendation: Wait for the first interval (sleep first, then recalculate). This matches
     HeartbeatService behavior and avoids a thundering-herd spike at startup when all agents
     compute simultaneously. If needed, TierCache is already warm from file.

3. **Per-agent error handling**
   - What we know: CONTEXT.md leaves this to Claude's discretion.
   - Recommendation: `continue` on per-agent errors (log a warning, don't abort the loop).
     One bad agent should never prevent tier updates for the rest of the fleet.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — phase adds Python classes only, no new tools or services)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest 9.0.2 + pytest-asyncio 1.3.0 |
| Config file | `pyproject.toml` (`asyncio_mode = "auto"`) |
| Quick run command | `python -m pytest tests/test_tier_assignment.py -x -q` |
| Full suite command | `python -m pytest tests/ -x -q` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TIER-02 | Bronze/Silver/Gold thresholds | unit | `pytest tests/test_tier_assignment.py::TestTierDeterminator -x` | Wave 0 |
| TIER-03 | Provisional below min observations | unit | `pytest tests/test_tier_assignment.py::TestTierDeterminator::test_below_min_observations_returns_provisional -x` | Wave 0 |
| ADMN-01 | Override not clobbered by recalc | unit | `pytest tests/test_tier_assignment.py::TestTierRecalcLoop::test_overridden_agent_not_recalculated -x` | Wave 0 |
| ADMN-03 | Recalc runs on schedule, skips overridden | unit | `pytest tests/test_tier_assignment.py::TestTierRecalcLoop -x` | Wave 0 |
| TEST-02 | All tier determination edge cases | unit | `pytest tests/test_tier_assignment.py -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `python -m pytest tests/test_tier_assignment.py tests/test_reward_system.py -x -q`
- **Per wave merge:** `python -m pytest tests/ -x -q`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_tier_assignment.py` — covers TIER-02, TIER-03, ADMN-01, ADMN-03, TEST-02

## Project Constraints (from CLAUDE.md)

| Directive | Category | Impact on Phase 2 |
|-----------|----------|-------------------|
| All I/O is async (aiofiles, httpx, AsyncOpenAI) | Architecture | Recalc loop body must be `async def`; `_run_recalculation()` awaits score() |
| Never use blocking I/O | Architecture | AgentManager._save() uses synchronous `path.write_text()` — this is acceptable as it's existing code and the write is fast; do not replace with aiofiles in this phase |
| Every new module needs `tests/test_*.py` | Testing | New `tests/test_tier_assignment.py` required |
| Use `asyncio_mode = "auto"` (pyproject.toml) | Testing | No `@pytest.mark.asyncio` decorator needed — just `async def test_*` |
| Use class-based test organization | Testing | `class TestTierDeterminator`, `class TestAgentConfigTierFields`, `class TestTierRecalcLoop` |
| Use `tmp_path` fixture for filesystem tests | Testing | Any test that triggers `AgentManager._save()` should use `tmp_path` |
| Mock external services | Testing | Mock `EffectivenessStore` and `RewardSystem` in loop tests (no real DB calls) |
| Graceful degradation — optional services must not crash | Architecture | `TierRecalcLoop` only starts when `settings.rewards_enabled = True`; absent = no-op |
| Use `os.replace()` for atomic writes | Architecture | Already followed in TierCache._persist(); AgentManager._save() does direct write (existing pattern, not changed in this phase) |
| Run `make format` + `python -m pytest tests/ -x -q` after changes | Workflow | Required before task completion |
| `SANDBOX_ENABLED` must remain True | Security | No impact (phase adds no file path operations) |

## Sources

### Primary (HIGH confidence)

- `core/reward_system.py` — Phase 1 implementation read directly; ScoreCalculator, TierCache,
  RewardSystem API confirmed
- `core/agent_manager.py` — AgentConfig dataclass fields (lines 128-167), `from_dict()` filter
  pattern, `list_all()` method name (line 222), `update()` via setattr (lines 225-233)
- `core/heartbeat.py` lines 311-329 — `start()`/`stop()`/`_monitor_loop()` canonical pattern
- `core/rewards_config.py` — RewardsConfig fields: `silver_threshold=0.65`, `gold_threshold=0.85`
- `core/config.py` lines 297-311 — Settings.rewards_enabled, rewards_min_observations=10
- `agent42.py` — Service initialization and startup sequence (lines 81-226)
- `dashboard/server.py` lines 3784-3787 — AgentManager instantiation location
- `tests/test_reward_system.py` — Existing test patterns (30 tests passing)
- `pyproject.toml` — `asyncio_mode = "auto"`, pytest 9.0.2, pytest-asyncio 1.3.0

### Secondary (MEDIUM confidence)

- CONTEXT.md decisions D-01 through D-12 — verified against actual source code for method
  names and signatures; one discrepancy found (`list_agents()` vs actual `list_all()`)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are stdlib or already installed; versions verified
- Architecture: HIGH — patterns read directly from source; method names confirmed
- Pitfalls: HIGH — all pitfalls verified against actual source code (not assumptions)
- Test patterns: HIGH — test framework config confirmed, existing tests read as reference

**Research date:** 2026-03-22
**Valid until:** 2026-04-22 (stable codebase, no third-party dependencies in scope)
