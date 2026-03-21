---
status: partial
phase: 03-desktop-app-experience
source: [03-VERIFICATION.md]
started: 2026-03-21T03:13:24Z
updated: 2026-03-21T03:13:24Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. PWA install prompt appears in Chrome
expected: Visit http://localhost:8000 in Chrome with Agent42 running. An install icon appears in the address bar. Clicking it installs Agent42 as a standalone app with no white flash on launch (background_color #0f1117 is displayed instead).
result: [pending]

### 2. Chromeless launch via desktop shortcut
expected: Double-click the Desktop shortcut created by `bash setup.sh create-shortcut`. Agent42 opens in a dedicated window with no browser address bar, no tab bar, and no browser chrome visible.
result: [pending]

### 3. Agent42 branding in OS taskbar
expected: The Agent42 robot-face icon (not a generic Chrome/Edge icon) appears in the OS taskbar for the running shortcut window. The app name shown is "Agent42" (not "localhost:8000").
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
