# Phase 1: Store Foundation — Context

**Gathered:** 2026-03-20
**Status:** Ready for planning
**Source:** Conversation context (new-project discussion)

<domain>
## Phase Boundary

Phase 1 delivers a working FastAPI web app living at `apps/meatheadgear/` that:
- Authenticates customers (sign up, log in, JWT sessions)
- Syncs and displays the Printful product catalog (t-shirts, hoodies, leggings, shorts, hats, bags)
- Shows product detail pages with sizes, colors, and retail prices calculated at ≥30% margin
- Runs under Agent42's app system at port 8001

No payments, no design studio, no agents in this phase. Just browsing works end-to-end.

</domain>

<decisions>
## Implementation Decisions

### App Location & Structure
- Lives at `apps/meatheadgear/` inside the agent42 repository
- Own `requirements.txt`, own `.env`, own port
- Port: 8001 (Agent42 dashboard is on 8000)
- Entry point: `apps/meatheadgear/main.py`
- FastAPI + Uvicorn

### Database
- SQLite with aiosqlite (async, matches Agent42 conventions)
- Tables: `users`, `products`, `product_variants`, `product_images`
- DB file: `apps/meatheadgear/.data/meatheadgear.db`
- Alembic for migrations

### Authentication
- JWT tokens via python-jose[cryptography]
- bcrypt for password hashing (passlib[bcrypt])
- Token expiry: 7 days (convenience for customers)
- Endpoints: POST /api/auth/register, POST /api/auth/login, GET /api/auth/me
- Protected routes require `Authorization: Bearer <token>` header

### Pricing
- Retail price = Printful base cost ÷ (1 - 0.35) → 35% gross margin target
- Round up to nearest $0.99 (e.g., $18.46 → $18.99)
- Stripe fee (2.9% + $0.30) already factored into the 35% margin floor

### Printful Integration
- Printful API v2 (production-safe, OAuth2 or API key)
- Catalog sync: fetch products from Printful catalog, filter to gym wear categories
- Sync on startup + background refresh every 6 hours
- Store product data locally in SQLite (avoid rate limits, fast page loads)
- Product categories to include: t-shirts, hoodies, leggings, shorts, hats, gym bags

### Frontend
- Vanilla JS + minimal CSS (Agent42 convention — no build step)
- Single-page layout: landing → product grid → product detail → auth modal
- Files: `apps/meatheadgear/frontend/index.html`, `app.js`, `style.css`
- Served as StaticFiles via FastAPI
- Mobile-responsive (customers will be on phones)
- Brand aesthetic: dark background (#0d0d0d), electric red accent (#ff2020), bold typography

### All I/O Async
- aiofiles for file operations
- httpx.AsyncClient for Printful API calls
- aiosqlite for database
- No blocking I/O anywhere (Agent42 convention)

### Configuration
- `.env` file with: SECRET_KEY, PRINTFUL_API_KEY, DATABASE_URL, PORT
- `config.py` frozen dataclass loaded from environment at import time (Agent42 pattern)

### Claude's Discretion
- Specific SQL schema column names (follow FastAPI/SQLAlchemy conventions)
- CSS design details beyond brand colors
- Printful category IDs to filter (research during implementation)
- Error page design

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Requirements
- `.planning/workstreams/meatheadgear-platform/REQUIREMENTS.md` — AUTH-01–04, CAT-01–04 requirement specs

### Project Research
- `.planning/research/POD-SERVICES.md` — Printful API details, product categories, pricing
- `.planning/research/AGENT-ARCHITECTURE.md` — Service architecture, how agents will consume the app later

### Agent42 Patterns (for consistency)
- `core/config.py` — Frozen dataclass config pattern to replicate
- `agent42.py` — App startup pattern (register tools, init services)

</canonical_refs>

<specifics>
## Specific Ideas

- Brand name display: "MEATHEAD GEAR" in all-caps, heavy weight font
- Tag line ideas: "BUILT DIFFERENT. WEAR IT." / "FOR THE ANIMALS IN THE GYM"
- Product grid: 3 columns desktop, 2 columns tablet, 1 column mobile
- Product card: product photo, name, price range (S-XXL may have same price), "Design It" CTA
- Auth modal: minimal — email + password only for v1, no OAuth
- Nav: logo left, "Shop" / "My Orders" / "Sign In" right
- Color swatch selector on product detail page
- Size guide modal (static content, sizes S-XXL with measurements)

</specifics>

<deferred>
## Deferred Ideas

- Payment / checkout — Phase 3
- Design studio — Phase 2
- AI generation — Phase 2
- Agent integrations — Phase 4+
- Social auth (Google/Apple) — v2
- Wishlist / favorites — v2
- Product reviews — v2
- Search / filter — v2

</deferred>

---
*Phase: 01-store-foundation*
*Context gathered: 2026-03-20 via conversation context*
