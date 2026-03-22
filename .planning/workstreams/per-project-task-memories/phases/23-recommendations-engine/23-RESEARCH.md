# Phase 23: Recommendations Engine - Research

**Researched:** 2026-03-22
**Domain:** FastAPI endpoint + hook extension for effectiveness-data-driven tool recommendations
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Extend `proactive-inject.py` hook — no new hook file
- **D-02:** New endpoint `GET /api/recommendations/retrieve` in `dashboard/server.py`
- **D-03:** Hook makes two API calls: learnings (existing) + recommendations (new), both under the same session guard
- **D-04:** Proactive injection only for v1.4 — no standalone MCP tool
- **D-05:** Compact ranked list: tool name, success rate %, avg duration
- **D-06:** Example: "Recommended tools for coding: 1. shell (92% success, 45ms avg) 2. code_intel (87%, 120ms) 3. grep (85%, 30ms)"
- **D-07:** Recommendations injected as a SEPARATE block from learnings — two distinct sections, not merged
- **D-08:** ORDER BY success_rate DESC, tie-break by avg_duration_ms ASC
- **D-09:** Minimum 5 observations per tool+task_type pair — config-driven via `RECOMMENDATIONS_MIN_OBSERVATIONS=5`
- **D-10:** Top-3 cap (RETR-05)
- **D-11:** Config follows Phase 21 pattern: `recommendations_min_observations` in Settings.from_env()
- **D-12:** Tools only — built-in and MCP tools treated equally from EffectivenessStore
- **D-13:** No skill recommendations
- **D-14:** No negative recommendations

### Claude's Discretion

- Exact API response schema for `/api/recommendations/retrieve` beyond required fields
- How to handle edge case where all tools have identical success_rate
- Token budget allocation between learnings and recommendations sections
- Exact stderr formatting and emoji/symbol choices

### Deferred Ideas (OUT OF SCOPE)

- MCP tool for on-demand recommendations (`agent42_recommendations`)
- Skill recommendations
- Negative recommendations ("avoid X tool for Y task type")
- Weighted composite scoring (recency, frequency)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RETR-05 | Recommendations engine suggests top-3 tools/skills by success_rate for given task_type | EffectivenessStore.get_aggregated_stats(task_type=...) already returns success_rate per tool+task_type pair; endpoint wraps with ORDER BY + LIMIT 3 |
| RETR-06 | Recommendations require minimum sample size (>=5 observations per task_type) before surfacing | get_aggregated_stats returns invocations count; WHERE invocations >= 5 filter applied in endpoint; config-driven via RECOMMENDATIONS_MIN_OBSERVATIONS |
</phase_requirements>

## Summary

Phase 23 is a focused extension of two existing systems: the `proactive-inject.py` hook and `dashboard/server.py`. The EffectivenessStore already tracks every tool invocation and exposes `get_aggregated_stats(task_type=...)` which returns `success_rate`, `avg_duration_ms`, and `invocations` per tool+task_type pair. The only missing piece is a filtering/ranking layer that enforces the minimum observation threshold and top-3 cap, plus a new API endpoint to serve it and a second HTTP call in the hook to consume it.

The endpoint pattern is already established by `/api/learnings/retrieve` (lines 3348–3430 in server.py). The recommendations endpoint is simpler — it calls EffectivenessStore directly (no Qdrant, no semantic search), applies a SQL-level filter for minimum observations, sorts by success_rate DESC then avg_duration_ms ASC, and returns at most 3 results. The hook extension adds a `fetch_recommendations()` function mirroring the existing `fetch_learnings()` and a `format_recommendations_output()` function, then appends their output to stderr after the learnings block.

The entire implementation is self-contained: no new dependencies, no new files (hook stays in `.claude/hooks/`, endpoint stays in `server.py`), one new Settings field, and one new `.env.example` comment block.

**Primary recommendation:** Implement as two plans — Plan 01: endpoint + config; Plan 02: hook extension + tests.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| aiosqlite | already installed | async SQLite access for EffectivenessStore | Phase 21 established this; no new dep needed |
| FastAPI | already installed | API endpoint in server.py | Existing server framework |
| urllib.request | stdlib | HTTP calls from hook subprocess | proactive-inject.py already uses it; no extra deps |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| fastapi.testclient | already installed | TestClient for endpoint tests | Same pattern as test_proactive_injection.py |
| pytest-asyncio | already installed | async tests for EffectivenessStore | Same as test_effectiveness.py |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct EffectivenessStore call in endpoint | New SQL query method on store | Adding a dedicated `get_recommendations(task_type, min_obs, top_k)` method to EffectivenessStore is cleaner than doing filtering in the endpoint handler — keeps business logic in the data layer |

**Installation:** No new packages required. All dependencies already in requirements.txt.

## Architecture Patterns

### Recommended Project Structure

No new files — all changes go into existing files:

```
dashboard/server.py           # Add GET /api/recommendations/retrieve endpoint
core/config.py                # Add recommendations_min_observations field to Settings
.env.example                  # Add RECOMMENDATIONS_MIN_OBSERVATIONS comment
.claude/hooks/proactive-inject.py  # Add fetch_recommendations() + format_recommendations_output()
tests/test_effectiveness.py   # Extend: recommendations aggregation query tests
tests/test_proactive_injection.py  # Extend: endpoint + hook recommendation tests
```

### Pattern 1: EffectivenessStore Query Method (recommended)

**What:** Add `get_recommendations(task_type, min_observations, top_k)` directly to EffectivenessStore rather than filtering in the endpoint.
**When to use:** Keeps data logic in the data layer; endpoint stays thin; easier to unit test.

```python
# In memory/effectiveness.py — add to EffectivenessStore class
async def get_recommendations(
    self,
    task_type: str,
    min_observations: int = 5,
    top_k: int = 3,
) -> list:
    """Return top tools ranked by success_rate for a given task_type.

    Only includes tools with >= min_observations invocations.
    Ordered by success_rate DESC, avg_duration_ms ASC (tie-break).
    Returns empty list on any failure or insufficient data.
    """
    if not AIOSQLITE_AVAILABLE or not task_type:
        return []
    try:
        await self._ensure_db()
        query = """
            SELECT
                tool_name,
                task_type,
                COUNT(*)                   AS invocations,
                AVG(CAST(success AS REAL)) AS success_rate,
                AVG(duration_ms)           AS avg_duration_ms
            FROM tool_invocations
            WHERE task_type = ?
            GROUP BY tool_name, task_type
            HAVING COUNT(*) >= ?
            ORDER BY success_rate DESC, avg_duration_ms ASC
            LIMIT ?
        """
        async with aiosqlite.connect(self._db_path) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute(query, (task_type, min_observations, top_k)) as cursor:
                rows = await cursor.fetchall()
        return [dict(row) for row in rows]
    except Exception as e:
        logger.warning("EffectivenessStore recommendations query failed: %s", e)
        return []
```

**Note:** This is Claude's discretion — alternatively the filtering could be done entirely in the endpoint handler using `get_aggregated_stats(task_type=...)`. The dedicated method is recommended for testability.

### Pattern 2: API Endpoint (mirror of /api/learnings/retrieve)

**What:** Thin FastAPI endpoint that delegates to EffectivenessStore and returns structured JSON.

```python
# In dashboard/server.py — add alongside /api/effectiveness/stats
@app.get("/api/recommendations/retrieve")
async def retrieve_recommendations(
    task_type: str = "",
    top_k: int = 3,
    min_observations: int = 0,
) -> dict:
    """Return top-N tool recommendations for a given task_type.

    Uses EffectivenessStore historical success_rate data.
    Called by proactive-inject.py hook at session start.

    Query parameters:
      task_type        — Required. Returns empty list when omitted.
      top_k            — Max results (default 3, RETR-05 cap).
      min_observations — Override config minimum (0 = use settings default).

    Returns: {"recommendations": [...], "task_type": str}
    Each item: {tool_name, success_rate, avg_duration_ms, invocations}
    """
    if not task_type:
        return {"recommendations": [], "task_type": ""}
    try:
        if not effectiveness_store:
            return {"recommendations": [], "task_type": task_type}
        min_obs = min_observations if min_observations > 0 else settings.recommendations_min_observations
        recs = await effectiveness_store.get_recommendations(
            task_type=task_type,
            min_observations=min_obs,
            top_k=top_k,
        )
        return {"recommendations": recs, "task_type": task_type}
    except Exception:
        return {"recommendations": [], "task_type": task_type}
```

### Pattern 3: Hook Extension

**What:** Two new functions in `proactive-inject.py`, called after the learnings block.

```python
# Add to .claude/hooks/proactive-inject.py

def fetch_recommendations(task_type: str) -> list:
    """Fetch tool recommendations from the Agent42 API.

    Returns list of recommendation dicts or [] on any error.
    """
    try:
        params = urllib.parse.urlencode({"task_type": task_type, "top_k": 3})
        url = f"{DASHBOARD_URL}/api/recommendations/retrieve?{params}"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
        return data.get("recommendations", [])
    except Exception:
        return []


def format_recommendations_output(recs: list, task_type: str) -> str:
    """Format recommendations as a compact ranked list for stderr."""
    if not recs:
        return ""
    parts = []
    for i, r in enumerate(recs, 1):
        name = r.get("tool_name", "?")
        rate = r.get("success_rate", 0.0)
        dur = r.get("avg_duration_ms", 0.0)
        parts.append(f"{i}. {name} ({rate:.0%} success, {dur:.0f}ms avg)")
    ranked = "  " + "  ".join(parts)  # compact, single-line style
    output = f"[agent42-recommendations] Top tools for {task_type}:\n{ranked}"
    if len(output) > MAX_OUTPUT_CHARS:
        output = output[:MAX_OUTPUT_CHARS]
    return output
```

**Integration into `main()`:** After `mark_injection_done()`, fetch recommendations and emit if non-empty:

```python
# After existing learnings block in main():
recs = fetch_recommendations(task_type)
if recs:
    rec_output = format_recommendations_output(recs, task_type)
    if rec_output:
        print(rec_output, file=sys.stderr)
```

**Important:** The session guard (`mark_injection_done`) is called AFTER both blocks — guard triggers only when at least one of (learnings, recommendations) produced output. This matches D-03: both calls are in the same session-guarded execution.

### Pattern 4: Config Addition

**What:** New Settings field following `learning_min_evidence` pattern exactly.

```python
# In core/config.py Settings dataclass (near learning_min_evidence):
recommendations_min_observations: int = 5

# In Settings.from_env():
recommendations_min_observations=int(os.getenv("RECOMMENDATIONS_MIN_OBSERVATIONS", "5")),
```

```bash
# In .env.example (after LEARNING_QUARANTINE_CONFIDENCE block):
# Minimum number of tool invocations required before a recommendation is surfaced
# RECOMMENDATIONS_MIN_OBSERVATIONS=5
```

### Anti-Patterns to Avoid

- **Blocking the hook on API failure:** The `fetch_recommendations()` call must be wrapped in try/except and return `[]` silently. Never raise. The hook always exits 0.
- **Merging learnings and recommendations output:** D-07 requires two distinct stderr blocks. Print them separately.
- **Writing the guard before fetching:** Don't call `mark_injection_done` before the API calls — otherwise if the server is down the guard is written and the session is poisoned.
- **Filtering in the endpoint instead of the store:** Moving HAVING/ORDER logic to the store layer is cleaner for testing. The endpoint should remain thin.
- **Emoji in the hook header:** The existing learnings output uses no emoji. Match that style unless an explicit styling decision is made.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Ranking logic | Custom in-memory sort after fetching all rows | SQL `ORDER BY success_rate DESC, avg_duration_ms ASC LIMIT 3` | Pushes work to SQLite, returns already-ranked minimal result set |
| Min-observations filter | Post-fetch Python list comprehension | SQL `HAVING COUNT(*) >= ?` | Same query, no Python iteration needed |
| Observation counting | Separate `COUNT(*)` query | Already in `get_aggregated_stats` schema; add `HAVING` to new method | Data is already in the aggregation result |

**Key insight:** The EffectivenessStore schema (`tool_invocations` with `invocations`, `success_rate`, `avg_duration_ms`) already contains everything needed. The recommendations engine is essentially a single SQL query with a HAVING clause and ORDER BY.

## Common Pitfalls

### Pitfall 1: Session Guard Written Before API Calls

**What goes wrong:** `mark_injection_done()` is called before `fetch_recommendations()`. If the server is down or the endpoint returns empty, the guard file is written and the session is permanently poisoned — no injection ever happens in that session.
**Why it happens:** Copying the Phase 22 guard placement without reading the full flow.
**How to avoid:** Call `mark_injection_done()` AFTER both `fetch_learnings()` and `fetch_recommendations()` — only when at least one returned results (or when any task_type was inferred). Review the existing Phase 22 flow in `main()`.
**Warning signs:** In tests, after mocking the server down, the guard file exists but nothing was printed to stderr.

**Correction:** Looking at the existing `main()` code in `proactive-inject.py` (lines 290–339): `mark_injection_done()` is called AFTER the `format_injection_output()` print, and the function returns early (sys.exit(0)) if `results` is empty. The same early-exit pattern should apply to recommendations — but note the guard should be written after BOTH calls have run, not after each one individually. Current design: guard is written at the very end after learnings are printed. Recommendations fetch and print should happen between learnings output and `mark_injection_done()`.

### Pitfall 2: effectiveness_store is None in the Endpoint

**What goes wrong:** `effectiveness_store` is a closure variable in `create_app()`. If the server starts without it being injected (e.g., in TestClient tests), the endpoint crashes with NameError or AttributeError.
**Why it happens:** The endpoint accesses `effectiveness_store` from closure scope — if not injected, it is `None` by default.
**How to avoid:** Guard with `if not effectiveness_store: return {"recommendations": [], "task_type": task_type}` at the top of the endpoint handler — exactly as `/api/effectiveness/stats` does at line 3190.
**Warning signs:** TestClient tests crash with NameError rather than returning empty.

### Pitfall 3: get_recommendations Called on Empty EffectivenessStore

**What goes wrong:** RETR-06 specifies silence when < 5 observations. If the store is brand new (no data), `get_recommendations()` must return `[]` silently, not error.
**Why it happens:** The HAVING clause only filters — if no rows match, SQLite returns an empty result set, which is correct. But if `_ensure_db()` hasn't been called and the DB file doesn't exist yet, `aiosqlite.connect()` will create an empty DB and the query returns `[]` correctly.
**How to avoid:** No special handling needed — the existing `_ensure_db()` + try/except wrapping in EffectivenessStore handles this. Add a test case for this specifically.

### Pitfall 4: Test Setup for the Recommendations Endpoint

**What goes wrong:** Tests use `_make_app_with_mock_store()` from the existing test file, which only mocks `memory_store`. The recommendations endpoint uses `effectiveness_store`, which is a different closure variable in `create_app()`.
**Why it happens:** Two separate optional injections in `create_app()` — `memory_store` and `effectiveness_store`.
**How to avoid:** Add a new `_make_app_with_mock_effectiveness_store()` helper (or extend the existing factory) that passes `effectiveness_store=mock_store` to `create_app()`. Look at how `agent42.py` passes both (lines 204–205).

### Pitfall 5: Identical success_rate Tie-Break

**What goes wrong:** Two tools both have 100% success_rate — the ORDER BY needs a stable secondary sort.
**Why it happens:** New tools with 5 invocations all successful have success_rate = 1.0.
**How to avoid:** The `ORDER BY success_rate DESC, avg_duration_ms ASC` tie-break (D-08) handles this — faster tool wins. This is already built into the SQL. No special Python handling needed.

## Code Examples

### Aggregation Query (verified from effectiveness.py)

```python
# Source: memory/effectiveness.py lines 110-142
# Existing get_aggregated_stats — basis for get_recommendations
query = """
    SELECT
        tool_name,
        task_type,
        COUNT(*)                   AS invocations,
        AVG(CAST(success AS REAL)) AS success_rate,
        AVG(duration_ms)           AS avg_duration_ms
    FROM tool_invocations
    WHERE (? = '' OR tool_name = ?)
      AND (? = '' OR task_type = ?)
    GROUP BY tool_name, task_type
    ORDER BY invocations DESC
"""
```

The `get_recommendations` method replaces the flexible WHERE with a targeted WHERE + HAVING + ORDER BY:

```sql
SELECT tool_name, task_type,
       COUNT(*) AS invocations,
       AVG(CAST(success AS REAL)) AS success_rate,
       AVG(duration_ms) AS avg_duration_ms
FROM tool_invocations
WHERE task_type = ?
GROUP BY tool_name, task_type
HAVING COUNT(*) >= ?
ORDER BY success_rate DESC, avg_duration_ms ASC
LIMIT ?
```

### create_app() Signature (verified from server.py line 470-473)

```python
# Source: dashboard/server.py lines 470-473
def create_app(
    websocket_manager,
    agent=None,
    github_account_store=None,
    memory_store=None,
    effectiveness_store=None,   # <-- already a parameter, use this in tests
) -> FastAPI:
```

### Test Pattern for Endpoint (verified from test_proactive_injection.py)

```python
# Source: tests/test_proactive_injection.py lines 56-68
# Adapt this pattern for effectiveness_store:
def _make_app_with_mock_effectiveness_store(mock_recs: list):
    ws = WebSocketManager()
    ag = MagicMock()
    mock_store = MagicMock()
    mock_store.get_recommendations = AsyncMock(return_value=mock_recs)
    with patch("dashboard.server.settings") as mock_settings:
        mock_settings.get_cors_origins.return_value = []
        mock_settings.max_websocket_connections = 50
        mock_settings.recommendations_min_observations = 5
        app = create_app(ws, ag, effectiveness_store=mock_store)
    return TestClient(app), mock_store
```

### Config Field Pattern (verified from config.py lines 279-282)

```python
# Source: core/config.py lines 279-282
# Learning extraction (Phase 21) — follow this pattern exactly:
learning_min_evidence: int = 3
learning_quarantine_confidence: float = 0.6

# Add after these two lines:
recommendations_min_observations: int = 5
```

```python
# Source: core/config.py lines 496-498
# from_env() pattern:
learning_min_evidence=int(os.getenv("LEARNING_MIN_EVIDENCE", "3")),
learning_quarantine_confidence=float(os.getenv("LEARNING_QUARANTINE_CONFIDENCE", "0.6")),

# Add after:
recommendations_min_observations=int(os.getenv("RECOMMENDATIONS_MIN_OBSERVATIONS", "5")),
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No recommendations | EffectivenessStore has data, no surfacing mechanism | Phase 21 complete | Phase 23 adds the surfacing layer |
| Single-call hook | Dual-call hook (learnings + recommendations) | Phase 23 | Hook complexity increases but remains under 350 LOC |

## Open Questions

1. **Should `mark_injection_done()` be called even when recommendations are empty?**
   - What we know: The current hook exits 0 early if learnings are empty (line 327: `if not results: sys.exit(0)`). This means if there are no learnings AND no recommendations, the guard is never written and the hook re-runs on next prompt.
   - What's unclear: Whether recommendations should also trigger an early exit if both are empty, or whether recommendations alone (without learnings) should be sufficient to write the guard.
   - Recommendation: Recommendations-only output (no learnings) should still write the guard and emit to stderr — otherwise the hook re-runs on every subsequent prompt. Emit recommendations independently if learnings are empty.

2. **Where exactly to place the new endpoint in server.py?**
   - What we know: `/api/effectiveness/stats` is at line 3187 and `/api/effectiveness/record` at 3166. The learnings endpoint is at 3348. There is a comment block `# -- Effectiveness Tracking API --` at 3164.
   - Recommendation: Add `/api/recommendations/retrieve` in the Effectiveness Tracking API block (after line 3193, before `_maybe_promote_quarantined`). This groups it with the data it depends on.

## Environment Availability

Step 2.6: SKIPPED — this phase is pure code/config changes extending existing Python modules. No external tools, services, or runtimes beyond what is already running.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pytest + pytest-asyncio (asyncio_mode = "auto") |
| Config file | `pyproject.toml` |
| Quick run command | `python -m pytest tests/test_effectiveness.py tests/test_proactive_injection.py -x -q` |
| Full suite command | `python -m pytest tests/ -x -q` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| RETR-05 | `GET /api/recommendations/retrieve?task_type=coding` returns ranked list of up to 3 tools | unit (TestClient) | `python -m pytest tests/test_proactive_injection.py::TestRecommendationsRetrieve -x -q` | Wave 0 (extend test_proactive_injection.py) |
| RETR-05 | Ranking is success_rate DESC, tie-break avg_duration_ms ASC | unit (EffectivenessStore) | `python -m pytest tests/test_effectiveness.py::TestEffectivenessRecommendations -x -q` | Wave 0 (extend test_effectiveness.py) |
| RETR-06 | Tools with < 5 observations excluded from recommendations | unit (EffectivenessStore + endpoint) | `python -m pytest tests/test_effectiveness.py::TestEffectivenessRecommendations::test_min_observations_threshold -x -q` | Wave 0 |
| RETR-06 | Task type with 0 matching tools returns empty recommendations (silent) | unit | `python -m pytest tests/test_proactive_injection.py::TestRecommendationsRetrieve::test_empty_task_type_returns_empty -x -q` | Wave 0 |

### Sampling Rate

- **Per task commit:** `python -m pytest tests/test_effectiveness.py tests/test_proactive_injection.py -x -q`
- **Per wave merge:** `python -m pytest tests/ -x -q`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/test_effectiveness.py` — add `TestEffectivenessRecommendations` class covering `get_recommendations()` method
- [ ] `tests/test_proactive_injection.py` — add `TestRecommendationsRetrieve` class covering the new endpoint and `TestRecommendationsHook` class covering the hook extension

*(Framework and conftest.py already exist — no new infrastructure needed)*

## Sources

### Primary (HIGH confidence)

- `memory/effectiveness.py` — verified: `get_aggregated_stats()` schema, query structure, `is_available` pattern, graceful degradation
- `dashboard/server.py` lines 3164–3193, 3348–3430 — verified: effectiveness API block location, `create_app` signature, learnings endpoint pattern
- `.claude/hooks/proactive-inject.py` — verified: full hook code, `fetch_learnings()`, `format_injection_output()`, session guard logic, main() flow
- `core/config.py` lines 279–282, 496–498 — verified: Learning extraction config pattern to follow
- `tests/test_effectiveness.py` — verified: existing test class structure, async test patterns
- `tests/test_proactive_injection.py` — verified: TestClient helper pattern, mock store setup, hook test loading pattern
- `agent42.py` lines 134–138, 200–205 — verified: how effectiveness_store is initialized and passed to create_app

### Secondary (MEDIUM confidence)

- `REQUIREMENTS.md` RETR-05/RETR-06 — source of truth for requirements
- `23-CONTEXT.md` — all decisions verified against actual code; decisions are consistent with codebase patterns

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all libraries already installed, verified in requirements
- Architecture: HIGH — exact patterns verified from source files
- Pitfalls: HIGH — identified from direct code inspection, not speculation
- Test patterns: HIGH — existing test files provide exact templates

**Research date:** 2026-03-22
**Valid until:** 2026-04-22 (stable codebase, no fast-moving dependencies)
