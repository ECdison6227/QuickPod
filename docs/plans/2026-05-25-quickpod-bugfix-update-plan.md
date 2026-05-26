# QuickPod Bugfix And Update Plan

**Goal:** 修复 QuickPod 当前需求文档中未满足的功能、打包和交互问题，并补齐用户指定的新图标：白色背景，中间黑色闪电，闪电右下角黑色字母 C。

**Architecture:** 先稳定基础运行链路，再做体验升级。窗口渲染只保留一套毛玻璃实现；系统能力封装在各 manager 中暴露真实成功/失败状态；图标生成脚本从 app target 中移出，作为构建前工具运行。

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, UserNotifications, ServiceManagement, Carbon, shell build scripts.

---

## Evidence Summary

- Requirements checked: `QUICKPOD_REQUIREMENTS.md`
- Local build checked: `bash build.sh` succeeds and creates `build/QuickPod.app`
- Whole-target typecheck checked: `swiftc -typecheck Sources/QuickPod/*.swift ...` fails because `IconGenerator.swift` is inside the app source target with hashbang and top-level script statements
- Existing dependencies checked: no third-party dependencies are declared in `Package.swift`
- Standard/built-in APIs checked: AppKit `NSStatusItem`, `NSWindow`, `NSVisualEffectView`; SwiftUI; `UNUserNotificationCenter`; `SMAppService`; Carbon hotkeys
- External references checked:
  - Apple HIG menu/menu bar guidance: status-menu actions should be clear, submenus should be used sparingly, app-level settings belong in Settings
  - Amphetamine: mature sleep-prevention apps expose session duration/triggers/status rather than only a binary awake toggle
  - ZeroHz / Converge-style focus tools: timer UX benefits from clear current phase, next reminder time, and lightweight focus history
  - Radiant: radial menu launchers need predictable slot count, configurable actions, and clear dismiss behavior

## Confirmed Bugs

### P0: Main window can render blank because glass layers conflict

**Files:**
- `Sources/QuickPod/AppDelegate.swift`
- `Sources/QuickPod/MainWindow.swift`

**Evidence:**
- `AppDelegate.setupMainWindow()` inserts an `NSVisualEffectView`.
- `MainWindowView.body` also inserts `VisualEffectView` with `.behindWindow`.
- `MainWindowView.body` still calls `.fixedSize()`.
- This matches the P0 root cause already documented in `QUICKPOD_REQUIREMENTS.md`.

**Fix decision:** Use requirement方案 A. Keep the AppKit `NSVisualEffectView` in `AppDelegate`; remove SwiftUI `VisualEffectView` from `MainWindow.swift`; remove `.fixedSize()`; give the SwiftUI content a controlled translucent background.

### P0: App icon is not the icon requested by the user

**Files:**
- `Sources/QuickPod/IconGenerator.swift`
- `Sources/QuickPod/AppIcon.icns`
- `Sources/Info.plist`
- `build.sh`

**Evidence:**
- Current generator draws a top-right black dot.
- Extracted icon visually shows white rounded square, black lightning, top-right dot.
- User requested white background, black lightning, black letter C at the lightning lower-right.
- `Info.plist` does not declare `CFBundleIconFile`, so Finder/Dock icon may not use the bundled icon reliably.

**Fix decision:** Redraw icon generator with the black C glyph in the lower-right of the bolt composition, remove the dot, regenerate `AppIcon.icns`, add `CFBundleIconFile = AppIcon`, and keep status item using the app icon rather than swapping to SF Symbols.

### P1: Whole-target build/typecheck fails because IconGenerator is inside app source

**Files:**
- `Sources/QuickPod/IconGenerator.swift`
- `Package.swift`
- `build.sh`

**Evidence:**
- `swiftc -typecheck Sources/QuickPod/*.swift ...` fails with `hashbang line is allowed only in the main file` and top-level statement errors.
- `build.sh` succeeds only because it manually excludes `IconGenerator.swift` and `MenuBarView.swift`.

**Fix decision:** Move the generator to `Tools/IconGenerator.swift` or `Scripts/IconGenerator.swift`, update `build.sh` to run it explicitly, and exclude tool files from app compilation.

### P1: Screen cleaner does not restore the main window after event-driven exit

**Files:**
- `Sources/QuickPod/MainWindow.swift`
- `Sources/QuickPod/ScreenCleaner.swift`
- `Sources/QuickPod/RadialMenu.swift`

**Evidence:**
- `ScreenCleanerState.activate()` hides the main window, then calls `cleaner.activate()`.
- `ScreenCleaner` exits from event monitors by calling its own `deactivate()`.
- That exit path never calls `ScreenCleanerState.deactivate()` or `AppDelegate.showMainWindowAgain()`.
- Radial menu creates a fresh `ScreenCleanerState()` and loses any shared state.

**Fix decision:** Give `ScreenCleaner` an `onDeactivate` callback. `ScreenCleanerState` owns the cleaner, sets the callback once, and restores the main window for every exit path.

### P1: Radial menu monitor lifecycle is broken

**Files:**
- `Sources/QuickPod/RadialMenu.swift`

**Evidence:**
- `startListening()` stores the long-lived flags listener in `localMonitor`.
- `show()` overwrites `localMonitor` with a menu-specific listener.
- `hide()` removes `localMonitor`, which may remove the long-lived listener and prevent future triggers.
- `handleFlags()` only hides when both Fn and Option are released, but the requirement says releasing either key should close and execute selection.

**Fix decision:** Split monitor handles into `hotkeyMonitor`, `dismissLocalMonitor`, and `dismissGlobalMonitor`. Change close condition to `!fn || !option`. Preserve long-lived listener across menu show/hide.

### P1: File creation reports success even when creation or notification fails

**Files:**
- `Sources/QuickPod/FileCreator.swift`
- `Sources/QuickPod/MainWindow.swift`

**Evidence:**
- `FileManager.default.createFile(...)` return value is ignored.
- Notification is scheduled without checking notification authorization first.
- If Desktop access, ZIP creation, or notification permission fails, UI still implies success or says nothing useful.

**Fix decision:** Make `FileCreator.create` return a result enum such as `success(URL)` / `failure(String)`. Request notification permission before first notification. Show a compact status line in the main window for success/failure.

### P1: Generated OOXML files are structurally incomplete

**Files:**
- `Sources/QuickPod/FileCreator.swift`

**Evidence:**
- `.xlsx` references `r:id` without declaring the relationships namespace on `<workbook>`.
- `.xlsx` has no worksheet part or workbook relationships file under `xl/_rels/workbook.xml.rels`.
- `.pptx` has only `presentation.xml` and no slide master/theme/presentation relationships.
- These files may be rejected or repaired by Office apps.

**Fix decision:** Either generate truly empty text-only files for Office formats with clear naming, or create minimal valid OOXML packages with the required rels and parts. Recommended: create valid minimal packages because the UI says Word/Excel/PPT.

### P2: Focus/DND automation is fragile across languages and macOS versions

**Files:**
- `Sources/QuickPod/FocusManager.swift`

**Evidence:**
- Scripts hard-code English strings: `Do Not Disturb`, `Focus`, `Control`.
- Requirement already calls out Chinese/English compatibility.
- State is optimistically set after script execution, not after a reliable re-sync.

**Fix decision:** Add localized candidate names and AX-role fallback matching. After every toggle, call `syncWithSystem()` or read the resulting state before updating UI.

### P2: Anti-sleep and login item status are optimistic

**Files:**
- `Sources/QuickPod/AntiSleepManager.swift`
- `Sources/QuickPod/LoginItemManager.swift`
- `Sources/QuickPod/MainWindow.swift`

**Evidence:**
- `AntiSleepManager.activate()` ignores `try? p.run()` failure and sets `isActive = true`.
- `LoginItemManager.toggle()` prints errors but does not surface them in UI.
- `SMAppService` can fail if app is not properly signed or not launched from an expected bundle location.

**Fix decision:** Introduce explicit `lastError` properties or a shared status-message mechanism. Only set active state after process launch or service registration succeeds.

### P2: Window chrome does not fully match the visual spec

**Files:**
- `Sources/QuickPod/AppDelegate.swift`

**Evidence:**
- Requirement says hide close/minimize/zoom buttons.
- Current code hides minimize/zoom but not close, and includes `.closable`.
- Window has fixed content rect but no explicit `minSize`/`maxSize`.

**Fix decision:** Hide close button or remove `.closable`; set `minSize` and `maxSize` to 280 width with content-driven height bounds.

### P2: Duplicate or dead UI code risks drift

**Files:**
- `Sources/QuickPod/MenuBarView.swift`
- `Sources/QuickPod/MainWindow.swift`
- `build.sh`

**Evidence:**
- `MenuBarView.swift` defines another `ScreenCleanerState`.
- `build.sh` does not compile `MenuBarView.swift`.
- SwiftPM target would include it and potentially cause duplicate type conflicts after toolchain issues are fixed.

**Fix decision:** Decide whether `MenuBarView` is needed. Recommended: delete or archive it if the product is the floating panel; otherwise wire it as the actual status item popover and remove duplicate row/state definitions.

## Upgrade Opportunities From Similar Apps

### Sleep prevention

Inspired by Amphetamine-style tools, QuickPod should add optional session durations:
- Indefinite
- 15 min
- 30 min
- 1 hour
- Until battery below threshold (later version)

This makes the anti-sleep feature safer than a hidden permanent toggle.

### Break reminder

Inspired by focus timer menu bar apps, show:
- Next reminder time
- Pause/resume
- One-click postpone 5/10 minutes
- Last reminder timestamp

Avoid a full analytics dashboard for now; the app should stay compact.

### Radial menu

Inspired by radial launchers, make slots predictable:
- Keep six default actions.
- Add future configuration only after core behavior is stable.
- Ensure any-key release/selection behavior is deterministic.

### First-run experience

Add a compact checklist row at the top only when needed:
- Notifications
- Accessibility
- Login item

Do not turn the app into a tutorial screen. The checklist should disappear when all permissions are healthy.

### Accessibility and keyboard use

Add VoiceOver labels and values to all custom rows, and make status messages textual rather than color-only.

## Implementation Plan

### Task 1: Stabilize window rendering

**Files:**
- Modify: `Sources/QuickPod/MainWindow.swift`
- Modify: `Sources/QuickPod/AppDelegate.swift`

**Steps:**
- [ ] Remove `VisualEffectView` usage from `MainWindowView.body`.
- [ ] Remove `.fixedSize()`.
- [ ] Keep the AppKit `NSVisualEffectView` in `AppDelegate.setupMainWindow()`.
- [ ] Set the SwiftUI `VStack` to `.background(Color.white.opacity(0.08))` or equivalent translucent fill.
- [ ] Hide the close button as well as minimize/zoom.
- [ ] Run `bash build.sh`.
- [ ] Launch `build/QuickPod.app` and visually verify the content is visible.

### Task 2: Fix icon generation and bundle icon declaration

**Files:**
- Move: `Sources/QuickPod/IconGenerator.swift` to `Tools/IconGenerator.swift`
- Modify: `Tools/IconGenerator.swift`
- Modify: `Sources/Info.plist`
- Modify: `build.sh`
- Regenerate: `Sources/QuickPod/AppIcon.icns`

**Steps:**
- [ ] Move the generator outside the app target.
- [ ] Replace the top-right dot with a black `C` placed at the lower-right of the lightning composition.
- [ ] Add `CFBundleIconFile` with value `AppIcon` to `Sources/Info.plist`.
- [ ] Update `build.sh` to run `swift Tools/IconGenerator.swift` before copying resources.
- [ ] Extract the 512px icon with `iconutil -c iconset` and inspect it.
- [ ] Run `bash build.sh`.
- [ ] Confirm `build/QuickPod.app/Contents/Resources/AppIcon.icns` exists and `Info.plist` contains `CFBundleIconFile`.

### Task 3: Repair screen cleaner lifecycle

**Files:**
- Modify: `Sources/QuickPod/ScreenCleaner.swift`
- Modify: `Sources/QuickPod/MainWindow.swift`
- Modify: `Sources/QuickPod/RadialMenu.swift`

**Steps:**
- [ ] Add `var onDeactivate: (() -> Void)?` to `ScreenCleaner`.
- [ ] Ensure `deactivate()` is idempotent and calls `onDeactivate` after monitors are removed.
- [ ] Set the callback in `ScreenCleanerState` to clear `isActive` and call `AppDelegate.showMainWindowAgain()`.
- [ ] Reuse a shared cleaner path for radial-menu screen cleaning instead of creating a throwaway state object.
- [ ] Run `bash build.sh`.
- [ ] Manually verify: open cleaner, press a key, main window returns after about 0.2 seconds.

### Task 4: Fix radial menu monitoring

**Files:**
- Modify: `Sources/QuickPod/RadialMenu.swift`

**Steps:**
- [ ] Replace `localMonitor` with `hotkeyMonitor`, `dismissLocalMonitor`, and `dismissGlobalMonitor`.
- [ ] Make `startListening()` no-op if `hotkeyMonitor` is already installed.
- [ ] Change release condition from `!fn && !option` to `!fn || !option`.
- [ ] Ensure `hide()` removes only dismiss monitors and keeps `hotkeyMonitor`.
- [ ] Add teardown method for app termination if needed.
- [ ] Run `bash build.sh`.
- [ ] Manually verify repeated Fn+Option invocations work more than once.

### Task 5: Make file creation reliable

**Files:**
- Modify: `Sources/QuickPod/FileCreator.swift`
- Modify: `Sources/QuickPod/MainWindow.swift`

**Steps:**
- [ ] Change `create(_:)` to report `Result<URL, FileCreatorError>` or a small custom enum.
- [ ] Check `createFile` return value.
- [ ] Request notification permission before scheduling notifications.
- [ ] Add success/failure status text in `MainWindowView`.
- [ ] Fix minimal OOXML package generation or intentionally scope Word/Excel/PPT creation to valid empty templates.
- [ ] Run `bash build.sh`.
- [ ] Create TXT/MD/DOCX/XLSX/PPTX files and verify they open or fail with clear feedback.

### Task 6: Harden Focus/DND and manager state feedback

**Files:**
- Modify: `Sources/QuickPod/FocusManager.swift`
- Modify: `Sources/QuickPod/AntiSleepManager.swift`
- Modify: `Sources/QuickPod/LoginItemManager.swift`
- Modify: `Sources/QuickPod/MainWindow.swift`

**Steps:**
- [ ] Add localized Focus/DND candidate names.
- [ ] Re-sync DND state after every script action.
- [ ] Make anti-sleep activation fail visibly when `caffeinate` cannot launch.
- [ ] Surface login item failures in the UI instead of printing only.
- [ ] Run `bash build.sh`.
- [ ] Verify each failure path has a visible status message.

### Task 7: Decide the UI architecture and remove drift

**Files:**
- Modify or delete: `Sources/QuickPod/MenuBarView.swift`
- Modify: `build.sh`
- Modify: `Package.swift`

**Steps:**
- [ ] Decide whether the app is a floating panel app or a status-item popover app.
- [ ] If floating panel is the product, delete or archive `MenuBarView.swift`.
- [ ] If popover is the product, wire `MenuBarView` to the status item and remove duplicate `ScreenCleanerState`.
- [ ] Make `Package.swift` and `build.sh` compile the same app source set.
- [ ] Run `bash build.sh`.
- [ ] Run whole-target typecheck again after moving the icon tool.

### Task 8: Accessibility and polish pass

**Files:**
- Modify: `Sources/QuickPod/MainWindow.swift`
- Modify: `Sources/QuickPod/RadialMenu.swift`

**Steps:**
- [ ] Add `accessibilityLabel`, `accessibilityValue`, and `accessibilityHint` to custom rows.
- [ ] Add tooltips/help text for menu bar button and radial items where AppKit supports it.
- [ ] Keep AppIcon as the status item image; show anti-sleep state via tooltip/status row instead of swapping symbols.
- [ ] Run `bash build.sh`.
- [ ] Use VoiceOver or Accessibility Inspector for a quick sanity pass.

## Verification Checklist

- [ ] `bash build.sh` succeeds.
- [ ] Whole-source typecheck succeeds after moving `IconGenerator.swift`.
- [ ] `build/QuickPod.app/Contents/Info.plist` includes `CFBundleIconFile`.
- [ ] Extracted icon shows white background, black lightning, lower-right black C.
- [ ] Main window content is visible, not blank.
- [ ] Closing/minimizing/zoom buttons are hidden according to spec.
- [ ] Screen cleaner exits on key/mouse and restores main window.
- [ ] Radial menu can be triggered repeatedly and closes when either Fn or Option is released.
- [ ] File creation handles denied notification permission and file-system failure.
- [ ] Focus mode works on at least English and Chinese macOS labels, or fails with clear permission guidance.
- [ ] Login item failure is visible in UI.

## Suggested Execution Order

1. Task 1 and Task 2 first because they unblock the visible app and packaged identity.
2. Task 3 and Task 4 next because they fix lifecycle bugs.
3. Task 5 and Task 6 next because they add reliable user feedback.
4. Task 7 before broad testing so the build graph stops drifting.
5. Task 8 last as a polish/accessibility pass.

## Checkpoint Notes

- This project is not currently a git repository. Do not run `git init` without explicit user approval.
- Do not run `git add`, `git commit`, or `git push` without explicit user approval.
- After implementation, consider writing `.ai/memory/QUICKPOD_CONTEXT.md` and `.ai/state.json` only after user approval.

## 2026-05-25 Implementation Progress

- Completed: Task 1 window glass stabilization. SwiftUI glass bridge and `.fixedSize()` were removed; the AppKit glass layer is the single source of the frosted background; close/minimize/zoom buttons are hidden.
- Completed: Task 2 icon generation chain. `IconGenerator.swift` moved to `Tools/`, the icon now uses the requested white background, black lightning, and lower-right black `C`; `CFBundleIconFile` was added to `Sources/Info.plist`; `build.sh` now runs the generator before compilation.
- Completed: Task 3 screen cleaner lifecycle. `ScreenCleaner` now has an `onDeactivate` callback and restores the main window after event-driven exit.
- Completed: Task 4 radial menu monitor split. Long-lived hotkey monitoring is separate from menu-dismiss monitoring, and releasing either Fn or Option closes the menu.
- Partially completed: Task 5 file creation reliability. File creation now returns success/failure to the UI, checks `createFile`, and requests notification permission before sending notifications. Full valid OOXML templates for Word/Excel/PPT still need a dedicated pass.
- Completed extra cleanup: Removed duplicate `ScreenCleanerState` from `MenuBarView.swift` so whole-source typecheck can succeed.
- Verification: `swiftc -typecheck Sources/QuickPod/*.swift ...` passes.
- Verification: manual `swiftc` compile to `/tmp/QuickPod-check` passes.
- Verification: generated `Sources/QuickPod/AppIcon.icns` is a valid macOS icon and the 512px extraction was visually checked.
- Not run: `bash build.sh`, because it contains an automatic `rm -rf "$BUILD_DIR"` step and project instructions require explicit approval before destructive cleanup commands.
- Still blocked by environment: `swift build` fails while linking the SwiftPM manifest with missing `PackageDescription.Package` symbols, matching the earlier toolchain-level failure.
