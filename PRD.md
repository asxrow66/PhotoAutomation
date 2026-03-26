# SD Card Import Assistant
**Product Requirements Document — macOS Native Application**

---

## 1. Overview

SD Card Import Assistant is a lightweight macOS menu bar utility that detects when an SD card is inserted and immediately presents the user with a prompt to name the resulting import folder. It enforces an opinionated folder structure under a designated Photos folder — automating the copy process, naming conventions, and SD card ejection — ultimately reducing folder creation friction and import errors across productions.

---

## 2. Goals & Objectives

- Reduce friction in post-production importing by automating folder creation and file routing
- Enforce a consistent naming convention at events (e.g., JS Baseball, Sunday Dinner)
- Integrate tightly with macOS to minimize reliance on external tools
- Provide a fast, low-interaction UI that appears immediately on SD card detection
- Run passively in the menu bar with user configuration after initial setup

---

## 3. Target User

**Primary user: Cullen Roberts** — a high school student and hobbyist/semi-professional photographer managing photo and video imports for school events, youth events, and sports productions. The user works across multiple event types and needs a dependable, low-friction workflow that enforces folder creation without requiring manual steps.

---

## 4. UI Scope

### 4.1 In Scope
- macOS application (menu bar agent for SD card detection and import)
- Content-aware event prompt UI triggered on SD card insertion
- Auto-populated date using system clock
- Custom event name input (minimum 3 characters)
- Optional custom date override (to handle backdating)
- Automatic file copy of all base files (RAW + JPG) into correct subfolders
- App notifies the user when import is complete

### 4.2 Out of Scope
- Video file triggering (photo-only)
- Cloud upload or backup sync
- Non-SD camera media (CF cards, USB drives with video)
- Editing or post-processing integration (color grading, metadata editing)
- Digital Asset Management (DAM) integration

---

## 5. User Flow

1. User inserts SD card to Mac (via USB adapter)
2. App detects new external volume and scans for image files (JPG + RAW)
3. If image files found, app shows the modal prompt within 1–2 seconds of insertion
4. User sees modal prompt appear on screen
5. User types event name (e.g., "Sunday Dinner", "JV Baseball")
6. User optionally overrides the date (defaults to today)
7. User confirms. App reads today's date from the system clock
8. App creates event folder structure: `raw/` and `jpg/` subfolders
9. App copies all JPG/RAW files into their respective subfolders
10. App shows progress bar during copy (file count, current file)
11. App shows confirmation (checkmark + summary) once all copies complete
12. App automatically ejects SD card after 100% copy + completion confirmation

---

## 6. UI Specification

### 6.1 Prompt Modal
The prompt appears centered on the primary display as a floating panel that does not steal focus from other applications but remains on top. It should appear within 2–3 seconds of SD card insertion.

**Fields:**
- Event Name (text field, auto-focused, minimum 3 characters)
- Date override toggle + date picker (hidden by default)
- Folder name preview (shows final folder name as user types)
- File count from detected SD card
- Cancel / Import buttons

### 6.2 Menu Bar Icon
- Icon appears in the menu bar (SD card system symbol)
- Clicking opens a popover showing:
  - Status: Monitoring / Importing
  - Last Import Folder (clickable, opens in Finder)
  - Open Destination Folder
  - Preferences
  - Quit

### 6.3 Progress Modal
When user confirms the modal, it transitions to a progress state in the same window:
- Progress bar (linear, 0–100%)
- Current file being copied (filename, truncated)
- Files copied count: "Copying file 3 of 8..."
- Percentage display
- Cancel button

### 6.4 Completion State
- Checkmark icon (green)
- Summary: "X files copied to 'Event Name'"
- "Open in Finder" button
- "Done" button (auto-dismisses)

---

## 7. Folder & Naming Convention

### 7.1 Root Destination
Configurable in Preferences. Defaults to `~/Pictures/Projects/`

### 7.2 Event Folder Format
```
{Event Name} [{YYYY-MM-DD}]
```
**Examples:**
- `Sunday Dinner [2025-03-09]`
- `JV Baseball [2025-04-15]`
- `Royal Flush Week 3 [2025-01-28]`

### 7.3 Subfolder Structure
```
{Root}/
└── {Event Name} [{YYYY-MM-DD}]/
    ├── raw/    ← CR3, CR2, ARW, NEF, DNG, RAF, RW2
    └── jpg/    ← JPG, JPEG
```

### 7.4 File Routing Rules

| Extension | Destination |
|-----------|-------------|
| `.cr3`, `.cr2` | `raw/` |
| `.arw`, `.nef`, `.dng`, `.raf`, `.rw2` | `raw/` |
| `.jpg`, `.jpeg` | `jpg/` |
| Other | Skipped (not copied) |

---

## 8. Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Performance | Prompt appears within 2 seconds of SD card insertion |
| Reliability | App must not crash on SD cards without image files |
| Memory | ≤ 30 MB at rest, ~70 MB during import |
| Privacy | No telemetry, no network calls — all operations are local |
| Accessibility | VoiceOver support, tab control, keyboard navigation |
| Duplicate Safety | Alert on duplicate folder name, no silent overwrites |
| Partial Copy | On card ejection mid-copy: show error, keep partial copies |

---

## 9. Preferences

Accessible from the menu bar popover. Settings stored via `UserDefaults`.

| Setting | Default | Description |
|---------|---------|-------------|
| Destination Folder | `~/Pictures/Projects/` | Root folder for all imports |
| Launch at Login | Off | Start app on system login |
| Auto-eject after import | On | Eject SD card after copy completes |
| Notify on Complete | On | Send macOS notification on import complete |
| RAW Extensions | cr3, cr2, arw, nef, dng, raf, rw2 | Configurable list |
| JPEG Extensions | jpg, jpeg | Configurable list |

---

## 10. Technical Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI (macOS 13+) |
| File Operations | `Foundation.FileManager` |
| SD Detection | `NSWorkspace.didMountNotification` |
| Menu Bar | `NSStatusBar` + `NSPopover` |
| Notifications | `UNUserNotificationCenter` |
| Launch at Login | `ServiceManagement.SMAppService` (macOS 13+) |
| Project Build | XcodeGen (`project.yml`) |
| Distribution | Notarized, direct download (no App Store) |

---

## 11. Error Handling

| Scenario | Behavior |
|----------|----------|
| Destination folder missing | Auto-create using `FileManager.createDirectory` |
| Permission denied | Show alert with system error message |
| No images found on card | Show info modal: "No image files found" |
| Duplicate folder name | Alert with message, no overwrite |
| Card ejected mid-copy | Show error, mark import as failed, keep partial copies |
| App not permitted for notifications | Silent fail (notifications simply don't appear) |

---

## 12. Future Enhancements (v2+)

- Duplicate detection using hash comparison (skip already-imported files)
- Auto-tagging import (add metadata via AppleScript or `sips`)
- Multi-card import (two SD cards simultaneously, merged subfolders)
- Custom folder format (configurable date format, template engine)
- Backup integration (automatic secondary copy to backup drive)
- Smart folder tagging using AI (e.g., batch labeling: "portraits", "action", "landscape")
- Custom folder format with drag-and-drop token editor

---

## 13. Success Metrics

- Average prompt appears within 2 seconds of SD card insertion
- Zero file loss: full import of 100+ file test set with no skips or corruption
- Import performance at parity with Finder drag-drop
- Full import completes in under 30 seconds for standard card sizes
