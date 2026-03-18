# Deferred Items — Phase 01 Setup Foundation

## Pre-existing Test Failures (Out of Scope)

### test_auth_flow.py::TestAuthIntegration::test_protected_endpoint_requires_auth

- **Status**: Pre-existing failure, not caused by 01-03 changes
- **Failure**: `assert 404 == 401` — `/api/tasks` returns 404 (route not found) instead of 401 (unauthorized)
- **Root cause**: Route likely removed or changed during Agent42 dashboard refactoring; test expectation stale
- **Scope**: dashboard/server.py routing — unrelated to setup scripts, MCP config, or hooks
- **Recommendation**: Fix in a dashboard-focused phase; check if `/api/tasks` endpoint still exists and update test accordingly
