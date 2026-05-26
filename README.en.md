# QuickPod

macOS Menu Bar Productivity Toolkit - Anti-sleep, Break Reminder, Screen Cleaner, Quick Switcher

## Features

### 🔋 Anti-Sleep
- Prevent Mac from auto-sleep
- Support timed shutdown (15min/30min/1hour)
- Real-time status indicator in menu bar

### ⏰ Break Reminder
- Customizable reminder intervals
- System notification and alert window support
- Postpone by 5/10 minutes

### 🧹 Screen Cleaner
- Full-screen black cleaning mode
- Exit on any key press or click

### ⚡ Quick Switcher
- Global hotkey to invoke
- Quick access to frequently used features

### 📝 New File Creator
- Support TXT, MD, DOCX, XLSX, PPTX
- Customizable default file name

### 🔄 Auto Update
- Check GitHub Releases for updates
- One-click download

## Installation

### Method 1: Download DMG (Recommended)
1. Download the latest version from [Releases](https://github.com/ECdison6227/QuickPod/releases)
2. Double-click the `.dmg` file
3. Drag `QuickPod.app` to Applications folder

### Method 2: Build from Source
```bash
git clone https://github.com/ECdison6227/QuickPod.git
cd QuickPod
./build.sh
open build/QuickPod.app
```

## System Requirements

- macOS 13.0 (Ventura) or later

## Permissions

QuickPod requires the following permissions:

1. **Notification Permission** - For break reminders
2. **Accessibility** - For global hotkeys
3. **Full Disk Access** - (Optional) For advanced features

## Usage

1. After running, QuickPod appears in the menu bar
2. Click the menu bar icon to open the quick panel
3. Click the gear icon to open settings

## Development

### Tech Stack
- Swift 5.9+
- SwiftUI
- AppKit
- UserNotifications
- ServiceManagement

### Build
```bash
./build.sh
```

### Package DMG
```bash
./create_dmg.sh
```

## Changelog

### v1.0.0 (2026-05-26)
- Initial release
- Anti-sleep feature
- Break reminder
- Screen cleaner
- Quick switcher
- New file templates
- Auto-update checker

## License

MIT License

## Contributing

Issues and Pull Requests are welcome!
