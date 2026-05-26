# QuickPod DeepSeek Handoff

## 1. Decision

This redesign should follow a hybrid reference:

- **Interaction model:** borrow the *behavior* of `Loop`'s radial menu
- **Visual language:** borrow the *feel* of `MacControlCenterUI`
- **Implementation strategy:** rewrite inside QuickPod's current AppKit + SwiftUI architecture

Do **not** copy GPL code from Loop.

## 2. Why this choice

### Loop

Loop is the closest product reference for the interaction we want:

- hold trigger to show a radial menu
- directional / radial command selection
- command-wheel mental model

Source:
- README describes the radial menu as hold-trigger based and cursor-driven
- license is GPL-3.0, so code should not be copied into QuickPod

Reference:
- [Loop on GitHub](https://github.com/MrKai77/Loop)

### MacControlCenterUI

MacControlCenterUI is the best visual reference for the aesthetic we want:

- clean macOS-native glass feeling
- restrained animation
- quiet, premium, high-legibility styling
- MIT licensed, so visual ideas and even some implementation patterns are safer to borrow

Reference:
- [MacControlCenterUI on GitHub](https://github.com/orchetect/MacControlCenterUI)

## 3. Source notes

Loop GitHub README states:

- the radial menu is triggered by holding a trigger key
- users move the cursor in the desired direction while holding
- theming is customizable
- project license is GPL-3.0

MacControlCenterUI GitHub README states:

- it closely mimics macOS Control Center menus
- supports light and dark mode
- license is MIT

## 4. Product direction

QuickPod is **not** a game HUD.

It should feel like:

- a tiny premium macOS utility
- fast and tactile
- visually minimal
- calm, cold, clean, high-end

It should **not** feel like:

- a flashy GTA clone
- a gamer overlay
- a thick black radial weapon wheel
- a cute decorative toy UI

## 5. Final design target

### Overall style

- `Apple Pro`
- cold white glass
- quiet grayscale palette
- subtle translucency
- very restrained accent color usage
- no thick border
- no heavy shadow blobs
- no bright gradients

### Wheel structure

- center hub + 6 outer items
- icon-first layout
- labels should be small and secondary
- default state should feel airy and uncluttered
- highlighted item may brighten slightly, but not glow like a game HUD

### Motion

- show quickly
- feel frictionless
- no bouncy playful animation
- use short, tight easing

## 6. Interaction requirements

### Hotkey behavior

Required:

- **press and hold shows wheel**
- **release hides wheel**

Desired behavior:

- if the user hovers or nudges toward a sector while holding, the active sector should become visually clear
- on release, either:
  - execute the currently highlighted action, or
  - close with no action if nothing is actively selected

This should feel close to Loop's interaction model, but adapted to QuickPod's simpler tool use case.

### Center hub

Center hub should not feel like a big button.

It should act as:

- state indicator
- back affordance in nested levels
- quiet anchor

### Dismiss behavior

- releasing the trigger closes the wheel
- `Esc` closes the wheel
- clicking outside closes the wheel

## 7. Information architecture

### Root wheel

Root wheel should have exactly 6 slots:

1. 防睡眠
2. 屏幕清洁
3. 休息提醒
4. 新建文件
5. 设置
6. 退出 / 关闭 QuickPod

### Nested wheel: 休息提醒

This should open a second wheel or submode with:

- 15 min
- 30 min
- 45 min
- 60 min
- stop reminder

Selecting one should immediately schedule the local notification cycle.

### Nested wheel: 新建文件

This should open a second wheel or submode with:

- TXT
- MD
- Word
- Excel
- PPT

After selecting a type:

- prompt for filename
- create on desktop
- notify success/failure

## 8. Screen cleaner requirements

Current issue to avoid:

- entering screen-clean mode should not bounce back into settings

Required behavior:

- entering cleaner should show a truly clean fullscreen black view
- exiting should return to prior context quietly
- the initial click used to enter cleaner must not immediately dismiss cleaner

## 9. Break reminder requirements

Required:

- selecting 15/30/45/60 min from the wheel must register an actual pending local notification
- notifications must continue to use `UNUserNotificationCenter`
- app must verify or gracefully handle permission state

Success condition:

- after selecting one interval, there is a pending request for QuickPod's break reminder identifier

## 10. File creation requirements

Required:

- choose type first
- then allow naming
- use current desktop creation behavior
- avoid empty names
- preserve unique filename handling

## 11. Visual rules for DeepSeek

DeepSeek should not improvise into a decorative style.

### Must do

- keep the wheel geometrically clean
- use thin strokes
- use subtle material backgrounds
- keep labels legible but secondary
- use SF Symbols where possible
- keep contrast professional

### Must not do

- thick black outer ring
- neon glow
- colorful candy palette
- oversized labels
- cartoon icons
- heavy game HUD styling
- fake luxury gold decoration

## 12. Implementation boundaries

QuickPod currently uses:

- AppKit app shell
- SwiftUI views
- Carbon hotkeys
- `UNUserNotificationCenter`

DeepSeek should stay inside this architecture unless a change is clearly justified.

Preferred approach:

- reuse current managers where possible
- rewrite wheel UI and wheel interaction cleanly
- avoid introducing large new dependencies

## 13. License guidance

### Allowed

- borrow interaction ideas from Loop
- borrow visual direction from screenshots / README demos
- borrow UI patterns from MacControlCenterUI
- reuse MIT-compatible ideas and patterns

### Not allowed

- copying Loop source code
- porting Loop internals verbatim
- using GPL-3.0 code inside QuickPod unless the whole project intentionally becomes GPL-compatible

## 14. Acceptance criteria

The redesign is only acceptable if all of these are true:

1. Wheel looks materially better than the current version
2. Wheel opens on hold and closes on release
3. Wheel no longer looks like a crude black overlay
4. Screen cleaner no longer bounces back into settings
5. Break reminder can be chosen from the wheel and registers a pending local notification
6. New file action supports both file type and naming
7. Overall feel is closer to Apple utility UI than gamer HUD

## 15. Suggested implementation order

1. Replace wheel interaction model with hold-to-show / release-to-close
2. Rebuild wheel layout and visual styling
3. Add highlight / hover / selection logic
4. Implement nested reminder wheel
5. Implement nested file wheel + naming prompt
6. Fix screen cleaner enter/exit behavior
7. Verify local notification registration
8. Polish spacing, font weights, icon scale, and animation timing

## 16. What Codex should review afterward

After DeepSeek finishes, Codex should review:

- hotkey press/release correctness
- wheel geometry and size
- whether highlighted state is obvious enough
- whether release behavior accidentally fires wrong actions
- whether screen cleaner still consumes the entry click
- whether notification requests are truly pending
- whether naming flow is ergonomic
- whether the UI still feels too heavy, too dark, or too game-like

## 17. Copy-paste prompt for DeepSeek

Use this prompt as-is or with small edits:

```text
You are redesigning QuickPod, a macOS menu bar utility built with AppKit + SwiftUI.

Your task is to redesign and implement its radial command wheel.

IMPORTANT REFERENCE STRATEGY:
- Borrow the interaction model from Loop: hold trigger to show the radial menu, release to close/confirm.
- Borrow the visual language from MacControlCenterUI: restrained, premium, macOS-native, glassy, minimal.
- Do NOT copy GPL code from Loop.
- Stay inside QuickPod's current architecture unless absolutely necessary.

DESIGN TARGET:
- Apple Pro aesthetic
- cold white glass
- grayscale / very restrained palette
- high-end, minimal, quiet, premium
- not flashy, not decorative, not a game HUD

INTERACTION REQUIREMENTS:
- Press and hold the hotkey to show the wheel
- Release hides the wheel
- Esc closes the wheel
- Clicking outside closes the wheel
- Center hub acts as anchor / back control in nested levels

ROOT WHEEL MUST HAVE 6 ITEMS:
1. 防睡眠
2. 屏幕清洁
3. 休息提醒
4. 新建文件
5. 设置
6. 退出 / 关闭 QuickPod

NESTED WHEEL: 休息提醒
- 15 min
- 30 min
- 45 min
- 60 min
- stop reminder
- selecting one must register an actual pending local notification using UNUserNotificationCenter

NESTED WHEEL: 新建文件
- TXT
- MD
- Word
- Excel
- PPT
- after selecting a type, ask for filename
- create the file on the desktop
- preserve unique filename behavior

SCREEN CLEANER REQUIREMENTS:
- entering cleaner must not immediately dismiss itself from the triggering click
- exiting cleaner must not bounce back into settings
- cleaner should feel clean and intentional

VISUAL RULES:
- no thick black border
- no neon glow
- no candy colors
- no chunky gamer styling
- use thin strokes, subtle material, small refined labels, SF Symbols where possible

DELIVERABLES:
1. Implement the redesigned wheel UI
2. Implement hold-to-show/release-to-close behavior
3. Implement nested reminder chooser
4. Implement nested file chooser + naming prompt
5. Fix screen cleaner enter/exit behavior
6. Verify that reminder selection creates a pending notification request

When done, summarize:
- files changed
- interaction changes
- how reminder registration was verified
- any remaining UI compromises
```

