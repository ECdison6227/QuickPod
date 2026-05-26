#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="QuickPod"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-1.0.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
DMG_TEMP="$BUILD_DIR/$APP_NAME-temp.dmg"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ 找不到 $APP_BUNDLE，请先运行 ./build.sh"
    exit 1
fi

echo "=== 创建 DMG ==="

# 创建临时目录
TMP_DMG_DIR="$BUILD_DIR/dmg_contents"
rm -rf "$TMP_DMG_DIR"
mkdir -p "$TMP_DMG_DIR"

# 复制 app
cp -R "$APP_BUNDLE" "$TMP_DMG_DIR/"

# 创建 Applications 快捷方式
ln -s /Applications "$TMP_DMG_DIR/Applications"

# 制作 DMG
rm -f "$DMG_PATH" "$DMG_TEMP"
hdiutil create -srcfolder "$TMP_DMG_DIR" -volname "$APP_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -size 100m "$DMG_TEMP" 2>/dev/null

# 挂载
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT="/Volumes/$APP_NAME"

# 排版：设置图标位置、窗口大小
echo '
   tell application "Finder"
     tell disk "'$APP_NAME'"
       open
       set current view of container window to icon view
       set toolbar visible of container window to false
       set statusbar visible of container window to false
       set the bounds of container window to {400, 200, 680, 420}
       set theViewOptions to the icon view options of container window
       set arrangement of theViewOptions to not arranged
       set icon size of theViewOptions to 72
       set position of item "'$APP_NAME'.app" of container window to {140, 100}
       set position of item "Applications" of container window to {420, 100}
       update without registering applications
       delay 1
       close
     end tell
   end tell
' | osascript

# 等待 Finder 操作完成
sleep 2

# 转换为压缩 DMG
hdiutil detach "$DEVICE" 2>/dev/null
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" 2>/dev/null
rm -f "$DMG_TEMP"
rm -rf "$TMP_DMG_DIR"

echo ""
echo "✅ DMG 创建完成: $DMG_PATH"
echo "   文件大小: $(du -h "$DMG_PATH" | cut -f1)"