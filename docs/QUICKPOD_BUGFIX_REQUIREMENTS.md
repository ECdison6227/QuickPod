# QuickPod Bugfix Requirements Document

## 概述

QuickPod 是一款 macOS 菜单栏工具应用，当前存在三个核心功能故障：
1. **全局快捷键无法触发圆形菜单**
2. **应用无法正常启动/打开**
3. **定时休息提醒功能失效**

本文档详细列出每个问题的根因分析、复现步骤和修复需求。

---

## 问题一：全局快捷键无法触发圆形菜单

### 严重程度：高

### 现象
- 按 `Command + Option + Space` 无任何反应
- 按 `Fn + Option` 长按也无任何反应
- 状态栏图标点击正常，但快捷键完全失效

### 根因分析

#### 1.1 Carbon RegisterEventHotKey 缺少辅助功能权限声明
**文件**: `Sources/Info.plist`

当前 `Info.plist` 中**没有任何**与辅助功能（Accessibility）或事件监听相关的权限声明：
- 缺少 `NSAppleEventsUsageDescription`
- 缺少 `kTCCServiceAccessibility` 相关描述
- 在 macOS 10.15+ 上，使用 Carbon `RegisterEventHotKey` 需要应用被用户手动添加到 **系统偏好设置 > 安全性与隐私 > 辅助功能** 白名单中
- 但应用没有任何引导用户授权的逻辑，也没有在 plist 中声明用途描述

#### 1.2 Carbon 热键签名冲突
**文件**: `Sources/QuickPod/GlobalHotkey.swift` (第 163 行)

```swift
let hotkeyID = EventHotKeyID(signature: OSType(0x51504B44), id: id)
```

- 所有热键使用相同的固定签名 `0x51504B44`（即 "QPKD"）
- 当应用重新注册热键时（如重新配置快捷键），旧的热键引用没有被正确清理
- `unregister()` 方法只清理了当前实例的 `hotkeyRefs`，但 `hotkeyHandlers` 字典中的 handler 没有被移除
- 这导致热键回调时可能调用到已释放的 handler 或重复 handler

#### 1.3 热键注册目标错误
**文件**: `Sources/QuickPod/GlobalHotkey.swift` (第 175 行)

```swift
let status = RegisterEventHotKey(kc, mods, hotkeyID, GetApplicationEventTarget(), 0, &ref)
```

- 使用 `GetApplicationEventTarget()` 而非 `GetEventDispatcherTarget()`
- 在后台运行的菜单栏应用中，`GetApplicationEventTarget()` 可能无法正确接收全局事件
- 应该使用 `GetEventDispatcherTarget()` 来确保热键在应用未激活时也能被捕获

#### 1.4 Fn+Option 备用触发逻辑错误
**文件**: `Sources/QuickPod/RadialMenu.swift` (第 140-160 行)

```swift
private func processFlags(_ event: NSEvent) {
    let flags = event.modifierFlags
    let fn = flags.contains(.function)
    let option = flags.contains(.option)
    // ...
}
```

- 在 macOS 上，`NSEvent.ModifierFlags.function` 标志位**不可靠**，Fn 键通常不会作为独立的 modifier flag 被系统报告
- 大多数键盘上 Fn 键是硬件级别的，不会通过 `flagsChanged` 事件暴露给应用
- 这段代码实际上永远不会满足 `fn && option` 的条件

#### 1.5 热键 handler 中的循环引用风险
**文件**: `Sources/QuickPod/GlobalHotkey.swift` (第 167-170 行)

```swift
Self.hotkeyHandlers[key]?.append { [weak self] _, _ in
    self?.handler?(kc, mods)
}
```

- `hotkeyHandlers` 是静态字典，存储的闭包捕获了 `self`
- 虽然使用了 `[weak self]`，但 `handler` 闭包本身在 `init` 时被传入，可能形成循环引用
- 更重要的是：`unregister()` 没有从 `hotkeyHandlers` 中移除对应的 handler，导致内存泄漏和重复回调

### 修复需求

1. **在 Info.plist 中添加辅助功能权限声明**：
   ```xml
   <key>NSAppleEventsUsageDescription</key>
   <string>QuickPod 需要辅助功能权限来注册全局快捷键</string>
   ```

2. **修复热键注册目标**：将 `GetApplicationEventTarget()` 改为 `GetEventDispatcherTarget()`

3. **修复 unregister 逻辑**：在 `unregister()` 中同时从 `hotkeyHandlers` 静态字典中移除对应的 handler

4. **移除或修复 Fn+Option 备用触发**：要么完全移除这段不可靠的代码，要么改用 `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` 配合正确的 modifier 检测

5. **添加快捷键权限检查和引导**：在应用启动时检查辅助功能权限状态，如未授权则弹出引导对话框

---

## 问题二：应用无法正常启动/打开

### 严重程度：高

### 现象
- 双击 `QuickPod.app` 无反应
- 状态栏没有出现 QuickPod 图标
- 应用进程可能闪退或根本没有启动

### 根因分析

#### 2.1 单实例检测逻辑导致自我终止
**文件**: `Sources/QuickPod/AppDelegate.swift` (第 19-28 行)

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.quickpod.app"
    let runningApps = NSRunningApplication.runningApplications(
        withBundleIdentifier: bundleIdentifier
    )
    if runningApps.count > 1 {
        if let existingApp = runningApps.first(where: { $0 != NSRunningApplication.current }) {
            existingApp.activate(options: [])
        }
        NSApplication.shared.terminate(nil)
        return
    }
    // ...
}
```

- 当应用通过 `swiftc` 直接编译为二进制并放入 `.app` bundle 时，`Bundle.main.bundleIdentifier` 可能为 `nil`
- 因为 `swiftc` 编译的可执行文件不会自动嵌入 bundle identifier
- 当 `bundleIdentifier` 为 `nil` 时，回退到硬编码的 `"com.quickpod.app"`
- 但 `NSRunningApplication.runningApplications(withBundleIdentifier:)` 在 bundleIdentifier 不匹配时可能返回空数组
- 更严重的是：如果用户之前通过不同方式启动过（比如命令行 `swift run` 或旧的构建产物），`runningApps` 可能包含多个实例，导致新启动的实例立即自毁
- 此外，`existingApp.activate(options: [])` 在应用是菜单栏应用（无 Dock 图标）时可能无效，因为菜单栏应用通常没有"激活"的概念

#### 2.2 缺少 LSUIElement 配置
**文件**: `Sources/Info.plist`

当前 `Info.plist` 中：
```xml
<key>LSBackgroundOnly</key>
<false/>
```

- 菜单栏应用应该设置 `LSUIElement` 为 `true`，这样应用不会在 Dock 中显示图标
- 当前设置 `LSBackgroundOnly` 为 `false`，且没有 `LSUIElement`，导致应用以普通应用模式运行
- 当用户点击 Dock 图标时，会触发 `applicationShouldHandleReopen`，但主窗口的显示逻辑可能和预期不符
- 更重要的是：`main.swift` 中设置了 `app.setActivationPolicy(.regular)`，这与菜单栏应用的行为冲突

#### 2.3 主窗口初始化时可能崩溃
**文件**: `Sources/QuickPod/AppDelegate.swift` (第 100-110 行)

```swift
private func showMainWindow() {
    mainWindow.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
}
```

- `mainWindow` 是隐式解包可选类型（`NSWindow!`）
- 如果 `setupMainWindow()` 因为某种原因（如 SwiftUI 视图初始化失败）没有成功创建窗口，`mainWindow` 将为 `nil`
- 调用 `mainWindow.makeKeyAndOrderFront(nil)` 会导致崩溃

#### 2.4 构建脚本未正确嵌入 Info.plist
**文件**: `build.sh`

```bash
cp "$PROJECT_DIR/Sources/Info.plist" "$CONTENTS/Info.plist"
```

- `swiftc` 编译的可执行文件不会自动读取 bundle 中的 `Info.plist`
- 对于纯 `swiftc` 构建的 `.app`，`Bundle.main.bundleIdentifier` 可能无法正确从 `Info.plist` 读取
- 这导致单实例检测和 bundle 相关的功能全部失效

#### 2.5 状态栏图标加载失败导致崩溃
**文件**: `Sources/QuickPod/AppDelegate.swift` (第 39-48 行)

```swift
if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
   let icon = NSImage(contentsOfFile: iconPath) {
    icon.size = NSSize(width: 18, height: 18)
    button.image = icon
} else {
    button.image = NSImage(
        systemSymbolName: "bolt.fill",
        accessibilityDescription: "QuickPod"
    )
}
```

- 如果 `AppIcon.icns` 不存在且系统符号名称加载失败（在某些 macOS 版本上可能），`button.image` 可能被设为 `nil`
- 虽然 `NSImage(systemSymbolName:)` 通常返回非 nil，但如果 `AppIcon.icns` 加载失败且系统符号也失败，状态栏按钮将没有图像
- 这不是崩溃的直接原因，但会导致用户体验问题

### 修复需求

1. **修复单实例检测**：
   - 使用文件锁（File Lock）或 Unix Domain Socket 替代 `NSRunningApplication`
   - 或者使用 `NSWorkspace` 检测并正确比较进程 ID
   - 确保在 `Bundle.main.bundleIdentifier` 为 `nil` 时有可靠的回退机制

2. **修正应用启动模式**：
   - 在 `Info.plist` 中添加 `<key>LSUIElement</key><true/>`
   - 移除 `main.swift` 中的 `app.setActivationPolicy(.regular)`，改为 `.accessory`

3. **防御性编程**：在 `showMainWindow()` 中添加 `mainWindow != nil` 的检查

4. **确保 Info.plist 被正确嵌入**：考虑使用 `xcodebuild` 或正确配置 `swiftc` 的 `-Xlinker -sectcreate` 参数来嵌入 Info.plist

---

## 问题三：定时休息提醒功能失效

### 严重程度：高

### 现象
- 开启"休息提醒"后，到达设定时间没有任何通知
- 状态栏显示"每 X 分钟提醒"，但实际从未提醒

### 根因分析

#### 3.1 Timer 在后台线程无法触发
**文件**: `Sources/QuickPod/BreakReminder.swift` (第 52-62 行)

```swift
private func scheduleTimer() {
    let content = UNMutableNotificationContent()
    // ...
    timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { _ in
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
```

- `Timer.scheduledTimer` 需要运行在**有 RunLoop 的线程**上
- 当前代码在 `start()` 中直接调用 `scheduleTimer()`，而 `start()` 是在主线程调用的（通过 UI 点击）
- 但是：`Timer.scheduledTimer` 创建的 timer 会被添加到**当前线程**的 RunLoop 中
- 如果 `start()` 在某个没有 RunLoop 的上下文中被调用（比如后台队列），timer 永远不会触发
- 更关键的是：`UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)` 设置为 1 秒后触发，但通知内容说"已经工作 X 分钟"，这是**逻辑错误**——通知应该立即触发，而不是 1 秒后

#### 3.2 UNNotificationRequest 的 trigger 设置错误
**文件**: `Sources/QuickPod/BreakReminder.swift` (第 57-60 行)

```swift
let request = UNNotificationRequest(
    identifier: UUID().uuidString,
    content: content,
    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
)
```

- 使用 `UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)` 意味着通知会在 1 秒后触发
- 但用户期望的是：工作 X 分钟后收到提醒
- 正确的做法应该是：使用 `UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(intervalMinutes * 60), repeats: true)` 来替代 `Timer`
- 或者保留 `Timer` 但移除 `UNNotificationRequest` 的 trigger（设为 `nil` 表示立即触发）

#### 3.3 通知权限请求时机问题
**文件**: `Sources/QuickPod/BreakReminder.swift` (第 33-37 行)

```swift
private func requestPermission(completion: @escaping (Bool) -> Void) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
        DispatchQueue.main.async { completion(granted) }
    }
}
```

- 在 `toggle()` 中调用 `requestPermission`，但用户可能在首次点击时拒绝授权
- 拒绝后没有任何重试机制或提示
- 此外，`UNUserNotificationCenter` 的权限请求是异步的，但 UI 状态（`isActive`）在权限请求完成前就被切换了

#### 3.4 Timer 没有添加到 RunLoop 的 common modes
**文件**: `Sources/QuickPod/BreakReminder.swift` (第 55 行)

```swift
timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { _ in
```

- `scheduledTimer` 默认将 timer 添加到 `.default` mode
- 当用户与 UI 交互（如滚动、显示菜单）时，RunLoop 会切换到 `.eventTracking` mode
- 在 `.eventTracking` mode 下，`.default` mode 的 timer 会被暂停
- 这导致 timer 在用户活跃操作 UI 时不会触发
- 应该使用 `RunLoop.main.add(timer, forMode: .common)` 确保 timer 在所有 mode 下都运行

#### 3.5 应用进入后台后 Timer 被暂停
- 作为菜单栏应用，QuickPod 不会真正"进入后台"，但系统可能在资源紧张时限制后台 timer
- 使用 `UNUserNotificationCenter` 的本地通知是更可靠的方案，因为系统会负责在指定时间触发通知，即使应用被挂起

### 修复需求

1. **使用 UNUserNotificationCenter 替代 Timer**：
   - 移除 `Timer` 相关代码
   - 使用 `UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(intervalMinutes * 60), repeats: true)` 创建重复通知
   - 这样即使应用被挂起，系统也会在正确的时间触发通知

2. **正确处理通知权限**：
   - 在应用启动时（`AppDelegate.applicationDidFinishLaunching`）预请求通知权限
   - 在 `BreakReminder.toggle()` 中先检查权限状态，未授权时引导用户到系统设置

3. **如果保留 Timer，确保它在 common modes 下运行**：
   ```swift
   timer = Timer(timeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { _ in
       // 发送通知
   }
   RunLoop.main.add(timer!, forMode: .common)
   ```

---

## 附加问题

### 4.1 构建脚本缺少 `-sectcreate` 参数
**文件**: `build.sh`

当前 `swiftc` 编译命令没有将 `Info.plist` 嵌入到可执行文件中：
```bash
swiftc \
    -o "$MACOS_DIR/$APP_NAME" \
    -framework AppKit \
    ...
```

应该添加：
```bash
-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$PROJECT_DIR/Sources/Info.plist"
```

### 4.2 缺少 `NSUserNotificationAlertStyle` 声明
在 `Info.plist` 中应该添加：
```xml
<key>NSUserNotificationAlertStyle</key>
<string>alert</string>
```

### 4.3 `ScreenCleaner` 的 `globalMonitor` 不可靠
**文件**: `Sources/QuickPod/ScreenCleaner.swift` (第 35-38 行)

```swift
globalMonitor = NSEvent.addGlobalMonitorForEvents(
    matching: [.keyDown, .flagsChanged]
) { [weak self] event in
    self?.deactivate()
}
```

- `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` **需要辅助功能权限**
- 如果没有权限，`globalMonitor` 实际上不会接收到任何事件
- 但 `localMonitor` 仍然可以工作（因为是在应用自己的窗口内）
- 这不是主要问题，但应该在代码中注释说明

---

## 修复优先级

| 优先级 | 问题 | 影响 |
|--------|------|------|
| P0 | 应用无法启动（单实例检测 + 启动模式） | 应用完全不可用 |
| P0 | 全局快捷键失效（热键注册目标 + 权限） | 核心功能不可用 |
| P0 | 休息提醒失效（Timer/通知逻辑错误） | 核心功能不可用 |
| P1 | Info.plist 缺少权限声明 | 功能受限，用户体验差 |
| P1 | 构建脚本未正确嵌入 Info.plist | 可能导致 bundle 信息读取失败 |
| P2 | Fn+Option 备用触发不可靠 | 次要功能，可移除 |
| P2 | 热键 handler 内存泄漏 | 长期运行稳定性 |

---

## 建议的修复方案概要

### 方案 A：最小改动修复（推荐先实施）

1. 修复 `Info.plist`：
   - 添加 `LSUIElement = true`
   - 添加 `NSAppleEventsUsageDescription`
   - 添加 `NSUserNotificationAlertStyle = alert`

2. 修复 `main.swift`：
   - 将 `app.setActivationPolicy(.regular)` 改为 `.accessory`

3. 修复 `GlobalHotkey.swift`：
   - 将 `GetApplicationEventTarget()` 改为 `GetEventDispatcherTarget()`
   - 在 `unregister()` 中清理 `hotkeyHandlers`

4. 修复 `BreakReminder.swift`：
   - 使用 `UNUserNotificationCenter` 的重复通知替代 `Timer`
   - 或修复 Timer 的 RunLoop mode 问题

5. 修复 `AppDelegate.swift`：
   - 简化或移除不可靠的单实例检测，改用文件锁
   - 添加主窗口 nil 检查

### 方案 B：重构建议（长期）

- 将项目迁移到 Xcode 项目（`.xcodeproj`）而非纯 `swiftc` 脚本构建
- 使用 `CGEvent.tapCreate` 替代 Carbon 热键 API，更现代且可靠
- 使用 `@main` App 结构替代手动 `NSApplication.shared` 管理
