---
plan: 02-03
phase: 02-design-studio
status: complete
completed: "2026-03-25"
requirements_completed: ["DES-07", "DES-09"]
human_verified: false
---

# Summary: Plan 02-03 — Wiring Endpoints + Integration

## What shipped

- `apps/meatheadgear/routers/design.py` — 3 new endpoints: POST /mockup (Printful mockup from canvas export + product_id), POST /save (persist design status to 'saved'), POST /upload (accept user file upload, store locally, create design record). Added MockupRequest, SaveDesignRequest Pydantic models and image_path to DesignResponse.
- `apps/meatheadgear/models_design.py` — Added `image_path: str | None = None` field to Design dataclass and `image_path TEXT` column to DESIGN_SCHEMA_SQL.
- `apps/meatheadgear/services/design_session.py` — Integrated post-generation pipeline: after AI generation, runs BiRefNet bg removal + ESRGAN upscale + local storage via `process_design()`. Pipeline failure is graceful (design saved with remote URL). Updated `_row_to_design()` to include image_path.
- `apps/meatheadgear/main.py` — Mounted `/designs` static files for serving generated/uploaded images. Creates designs directory in lifespan.
- `apps/meatheadgear/database.py` — Added ALTER TABLE migration for `image_path` column on existing databases.

## Deviations

- Task 1 committed by previous agent session; Task 2 completed after context resume. Same content as planned.

## Key decisions

- Pipeline integration uses lazy import (`from services.image_pipeline import process_design` inside the try block) to avoid circular import issues and allow ruff to not strip unused top-level import.
- Upload handler uses raw `fetch()` not `authFetch()` to avoid Content-Type override breaking multipart boundary (decision from Phase 01 context).
