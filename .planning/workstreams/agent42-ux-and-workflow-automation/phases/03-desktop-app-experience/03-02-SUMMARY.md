---
phase: 03-desktop-app-experience
plan: 02
subsystem: ui
tags: [pwa, desktop-shortcut, setup.sh, windows, macos, linux, chromeless, chrome-app]

# Dependency graph
requires:
  - phase: 03-01
    provides: icon-512.png and icon-192.png PNG icons at dashboard/frontend/dist/assets/icons/
provides:
  - setup.sh create-shortcut subcommand with Windows (.lnk), macOS (.app bundle), Linux (.desktop) support
  - Chromeless --app=http://localhost:8000 launch via Chrome/Edge/Chromium
  - Agent42 icon (icon-512.png) wired into all three platform shortcut formats
affects: [desktop-app-experience, pwa-installability, user-onboarding]

# Tech tracking
tech-stack:
  added: [PowerShell WScript.Shell COM automation for .lnk creation, macOS .app bundle + Info.plist structure]
  patterns: [platform detection via uname -s with case/esac, PowerShell [Environment]::GetFolderPath for OneDrive-aware Desktop path]

key-files:
  created: []
  modified:
    - setup.sh

key-decisions:
  - "Use PowerShell [Environment]::GetFolderPath('Desktop') instead of cmd.exe echo — handles OneDrive-redirected Desktops correctly"
  - "Browser detection: Chrome preferred, Edge fallback on Windows; warn-then-error on macOS if Chrome absent (Safari lacks --app); chromium/google-chrome chain on Linux"

patterns-established:
  - "Desktop path: always use [Environment]::GetFolderPath('Desktop') in PowerShell — never %USERPROFILE%\\Desktop which breaks with OneDrive folder redirection"

requirements-completed: [APP-02, APP-03]

# Metrics
duration: 4min
completed: 2026-03-21
---

# Phase 03 Plan 02: Desktop Shortcut Summary

**setup.sh create-shortcut subcommand creates platform-native Agent42 shortcuts (Windows .lnk, macOS .app, Linux .desktop) launching Chrome in chromeless --app mode with icon-512.png**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-21T02:48:11Z
- **Completed:** 2026-03-21T02:52:24Z
- **Tasks:** 1 auto + 1 human-verify (auto-approved in auto_advance mode)
- **Files modified:** 1

## Accomplishments

- Added `create-shortcut` subcommand to `setup.sh` with full Windows/macOS/Linux support
- Windows: PowerShell WScript.Shell creates `.lnk` on Desktop using Chrome or Edge with Agent42 icon
- macOS: Creates `~/Applications/Agent42.app` bundle with launcher script and Info.plist
- Linux: Writes `~/.local/share/applications/agent42.desktop` with correct Exec and Icon fields
- All platforms: chromeless `--app=http://localhost:8000` launch using the icon-512.png from Plan 01
- Verified: `.lnk` file created successfully on Windows Desktop (OneDrive-redirected)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add create-shortcut subcommand to setup.sh** - `b7c6b04` (feat)
2. **Task 2: Human-verify checkpoint** - auto-approved (auto_advance=true)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified

- `setup.sh` — Added `create-shortcut` subcommand block (~130 lines): platform detection, browser detection, shortcut creation for Windows/macOS/Linux, updated header comment

## Decisions Made

- **PowerShell Desktop path detection:** Used `[Environment]::GetFolderPath('Desktop')` instead of `cmd.exe /c 'echo %USERPROFILE%\\Desktop'`. The `cmd.exe` approach in Git Bash captures the full Windows banner (version, copyright, prompt) — not just the path. PowerShell's environment API is reliable and handles OneDrive folder redirection correctly (Desktop at `C:\Users\rickw\OneDrive\Desktop` not `C:\Users\rickw\Desktop`).
- **Browser detection strategy:** Chrome preferred over Edge on Windows (better `--app` mode experience). macOS warns explicitly that Safari lacks `--app` flag support before erroring. Linux walks `google-chrome` → `google-chrome-stable` → `chromium-browser` → `chromium`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Windows Desktop path detection via cmd.exe capturing shell banner**

- **Found during:** Task 1 (running `bash setup.sh create-shortcut` on Windows)
- **Issue:** `cmd.exe /c 'echo %USERPROFILE%\\Desktop'` in Git Bash does not run the echo inline — it opens an interactive cmd session that emits the full Windows banner (`Microsoft Windows [Version ...]`, copyright line, prompt) into the output. The resulting `DESKTOP` variable contained the entire banner text, causing the .lnk path to be invalid and PowerShell to throw `FileNotFoundException`.
- **Fix:** Replaced `cmd.exe` call with `powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"` invoked directly inside the PowerShell shortcut creation block using `$desktop = [Environment]::GetFolderPath('Desktop')`. This is also OneDrive-aware (returns the actual shell folder path).
- **Files modified:** `setup.sh`
- **Verification:** `bash setup.sh create-shortcut` succeeds with "Shortcut created!" message. Verified .lnk exists at `C:\Users\rickw\OneDrive\Desktop\Agent42.lnk`.
- **Committed in:** `b7c6b04` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug)
**Impact on plan:** Essential fix for Windows correctness. Without it, the shortcut creation silently fails. No scope creep.

## Issues Encountered

- `cmd.exe` called from Git Bash launches an interactive shell rather than running the single echo command. This is a known Git Bash / Windows interop quirk. PowerShell is the correct tool for Windows shell queries from bash scripts.

## Known Stubs

None — shortcut created successfully on Windows Desktop, macOS and Linux paths are structurally correct (not tested on those platforms, but the logic mirrors documented platform patterns).

## User Setup Required

None — run `bash setup.sh create-shortcut` to create the shortcut. No external service configuration required.

## Next Phase Readiness

- Phase 03 complete: PWA manifest + icons (Plan 01) + desktop shortcut (Plan 02)
- APP-01, APP-02, APP-03, APP-04 requirements satisfied
- Ready for Phase 04 (Dashboard GSD integration) — no blockers

## Self-Check: PASSED

- FOUND: setup.sh contains `create-shortcut`
- FOUND: setup.sh contains `--app=http://localhost:8000`
- FOUND: setup.sh contains `CreateShortcut` (Windows)
- FOUND: setup.sh contains `Info.plist` (macOS)
- FOUND: setup.sh contains `[Desktop Entry]` (Linux)
- FOUND: setup.sh contains `icon-512`
- FOUND: commit b7c6b04 (feat: create-shortcut subcommand)
- FOUND: Agent42.lnk on Windows Desktop (verified via PowerShell Test-Path)

---
*Phase: 03-desktop-app-experience*
*Completed: 2026-03-21*
