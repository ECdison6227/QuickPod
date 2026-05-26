# QuickPod Wheel Redesign Implementation Plan

> For this task, we are executing inline in the current session against the approved `GTA Glass` interaction model and `Apple Pro` visual direction.

**Goal:** Rebuild QuickPod's radial menu into a polished hold-to-show command wheel with nested quick actions, better file creation, cleaner screen-clean mode behavior, and verified break notifications.

**Architecture:** Keep the existing AppKit + SwiftUI shell, but replace the current one-shot radial overlay with a small state machine that supports nested wheels, press-and-hold visibility, and modal quick actions. Reuse the existing managers where they are sound, and isolate the redesign in the radial menu, file creation flow, break reminder flow, and screen cleaner wrapper.

**Tech Stack:** Swift, AppKit, SwiftUI, UserNotifications, Carbon hotkeys

---

## Files in Scope

- Modify: `Sources/QuickPod/AppDelegate.swift`
- Modify: `Sources/QuickPod/GlobalHotkey.swift`
- Modify: `Sources/QuickPod/RadialMenu.swift`
- Modify: `Sources/QuickPod/BreakReminder.swift`
- Modify: `Sources/QuickPod/FileCreator.swift`
- Modify: `Sources/QuickPod/MainWindow.swift`
- Modify: `Sources/QuickPod/ScreenCleaner.swift`

## Execution Outline

1. Replace the current tap-style radial menu with a hold-to-show wheel that tracks hotkey press/release and supports nested action groups.
2. Restyle the wheel to the approved `Apple Pro` direction: restrained glass, quieter palette, icon-first layout, no heavy black framing.
3. Turn `Break Reminder` into a nested quick chooser that can schedule 15/30/45/60 minute notifications directly from the wheel and validate notification registration.
4. Turn `New File` into a nested quick chooser for file type plus a naming prompt, while preserving existing desktop creation behavior.
5. Make `Screen Cleaner` exit stay silent instead of reopening settings, and align its toggle semantics with the new hold-based wheel.
6. Build and verify with runtime logs, screenshots, and direct notification state inspection.
