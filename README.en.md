# QuickPod

QuickPod is a lightweight macOS menu bar utility built for long-running coding sessions, AI agent workflows, and focused desktop work. It combines anti-sleep controls, break reminders, a quick switcher, and desktop file creation in one small status-bar app.

[中文说明](README.md) | [Architecture](ARCHITECTURE.md)

## Highlights

### Anti-sleep
- Keep your Mac awake with one click
- Presets for `15 min / 30 min / 1 hour / indefinite`
- Clear menu bar state indicator

### Break reminders
- Preset intervals plus custom minute values
- Includes a `1-minute test` shortcut
- Sends an activation confirmation when reminders start
- Uses both macOS notifications and a top-right in-app reminder card
- Supports `5 min` and `10 min` snooze

### Quick switcher
- Global hotkey entry point
- Keyboard-driven selection flow
- Fast access to anti-sleep, reminders, screen cleaner, settings, and file creation

### Create files on Desktop
- Create `TXT / MD / DOCX / XLSX / PPTX`
- Custom default file name
- Custom file extension support such as `log`, `json`, or `todo`

### Update checking
- Checks GitHub Releases for the latest version
- Prefers direct `DMG/ZIP` assets when available
- Falls back to the GitHub release redirect when the API is rate-limited

## Screenshots

![Main window](https://raw.githubusercontent.com/ECdison6227/QuickPod/main/screenshots/main-window.png)
![Quick switcher](https://raw.githubusercontent.com/ECdison6227/QuickPod/main/screenshots/quick-switcher.png)
![Break reminder popup](https://raw.githubusercontent.com/ECdison6227/QuickPod/main/screenshots/break-reminder.png)

## Install

### Download a release
1. Open [Releases](https://github.com/ECdison6227/QuickPod/releases)
2. Download the latest `.dmg`
3. Drag `QuickPod.app` into `Applications`

### Build locally
```bash
git clone https://github.com/ECdison6227/QuickPod.git
cd QuickPod
./build.sh
open build/QuickPod.app
```

## Requirements

- macOS 13 Ventura or later

## Permissions

QuickPod only requires notification permission for its core reminder flow:

1. `Notifications`
Used for break reminders, test notifications, and status confirmations.

2. `Accessibility (optional)`
The current global hotkey path uses Carbon `RegisterEventHotKey`, so accessibility access is optional and only helps with some extra keyboard-monitoring scenarios.

3. `Launch at login`
Optional if you want QuickPod to start automatically after login.

## Development

```bash
./build.sh
./create_dmg.sh
```

## Changelog

### v1.2
- Fixed unstable notification permission detection
- Added the top-right reminder card
- Added custom reminder minutes and a 1-minute test flow
- Added custom file extensions
- Refreshed screenshots and marketing assets

### v1.0.0
- Initial release

## License

MIT
