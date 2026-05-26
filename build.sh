#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCES="$PROJECT_DIR/Sources"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="QuickPod"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "=== 清理旧构建 ==="
rm -rf "$BUILD_DIR"

echo "=== 创建 App Bundle 结构 ==="
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "=== 生成 App 图标 ==="
swift "$PROJECT_DIR/Tools/IconGenerator.swift"

echo "=== 编译 Swift 源码 ==="
SRC_DIR="$PROJECT_DIR/Sources/QuickPod"
swiftc \
    -o "$MACOS_DIR/$APP_NAME" \
    -framework AppKit \
    -framework SwiftUI \
    -framework UserNotifications \
    -framework ServiceManagement \
    -framework ApplicationServices \
    -Xlinker -sectcreate \
    -Xlinker __TEXT \
    -Xlinker __info_plist \
    -Xlinker "$PROJECT_DIR/Sources/Info.plist" \
    "$SRC_DIR/main.swift" \
    "$SRC_DIR/AppDelegate.swift" \
    "$SRC_DIR/MainWindow.swift" \
    "$SRC_DIR/MenuBarView.swift" \
    "$SRC_DIR/GlobalHotkey.swift" \
    "$SRC_DIR/AntiSleepManager.swift" \
    "$SRC_DIR/ScreenCleaner.swift" \
    "$SRC_DIR/FileCreator.swift" \
    "$SRC_DIR/BreakReminder.swift" \
    "$SRC_DIR/LoginItemManager.swift" \
    "$SRC_DIR/QuickSwitcher.swift" \
    "$SRC_DIR/OnboardingAnimationView.swift" \
    "$SRC_DIR/PermissionManager.swift"

echo "  编译完成: $MACOS_DIR/$APP_NAME"

echo "=== 复制 Info.plist ==="
cp "$PROJECT_DIR/Sources/Info.plist" "$CONTENTS/Info.plist"

echo "=== 复制图标 (如果有) ==="
if [ -f "$PROJECT_DIR/Sources/QuickPod/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Sources/QuickPod/AppIcon.icns" "$RESOURCES_DIR/"
fi

echo "=== 签名 ==="
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || echo "  (签名跳过，开发模式也可运行)"

echo ""
echo "✅ 构建完成: $APP_BUNDLE"
echo "   运行: open $APP_BUNDLE"
echo ""
echo "   如需 DMG，运行: ./create_dmg.sh"
