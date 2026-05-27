import AppKit
import Darwin
import SwiftUI
import UserNotifications
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private static let reopenNotification = Notification.Name("com.quickpod.app.reopen")

    var statusItem: NSStatusItem!
    private var mainWindow: NSWindow!
    private var reopenObserver: NSObjectProtocol?
    private var singleInstanceLockFD: Int32 = -1
    private var cancellables = Set<AnyCancellable>()
    private lazy var globalHotkey = GlobalHotkey(
        onPress: { _, _ in
            print("[QuickPod] Global hotkey pressed")
            QuickSwitcherController.shared.hotkeyPressed()
        },
        onRelease: { _, _ in
            print("[QuickPod] Global hotkey released")
            QuickSwitcherController.shared.hotkeyReleased()
        }
    )

    // Managers
    let antiSleep = AntiSleepManager()
    let breakReminder = BreakReminder()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireSingleInstanceLock() else {
            DistributedNotificationCenter.default().post(
                name: Self.reopenNotification,
                object: Bundle.main.bundleIdentifier ?? "com.quickpod.app"
            )
            NSApplication.shared.terminate(nil)
            return
        }

        observeReopenRequests()
        setupStatusBar()
        setupMainWindow()
        applyAppearancePreference()
        setupGlobalHotkey()

        if ProcessInfo.processInfo.arguments.contains("--render-screenshots") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.renderMarketingScreenshotsAndQuit()
            }
            return
        }

        requestNotificationPermission()
        breakReminder.prepareOnLaunch()
        showMainWindow()

        if ProcessInfo.processInfo.arguments.contains("--show-radial-on-launch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                QuickSwitcherController.shared.show()
            }
        }

        if ProcessInfo.processInfo.arguments.contains("--verify-break-reminder") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                self.breakReminder.start(withInterval: 15)
                self.breakReminder.hasPendingReminder { exists in
                    print("[QuickPod] Break reminder pending request exists: \(exists)")
                    NSApp.terminate(nil)
                }
            }
        }
    }
    
    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateStatusBarIcon()
        rebuildMenu()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusBarIcon),
            name: AntiSleepManager.statusChangedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildMenu),
            name: AntiSleepManager.statusChangedNotification,
            object: nil
        )
        
        breakReminder.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusBarIcon()
            }
        }.store(in: &cancellables)
    }

    @objc private func rebuildMenu() {
        let menu = NSMenu()
        let antiSleepItem = NSMenuItem(
            title: antiSleep.isActive
                ? QuickPodText.text(zh: "✓ 防睡眠已开启", en: "✓ Anti-sleep on")
                : QuickPodText.text(zh: "  防睡眠已关闭", en: "  Anti-sleep off"),
            action: #selector(toggleAntiSleepFromMenu),
            keyEquivalent: ""
        )
        antiSleepItem.image = antiSleep.isActive
            ? NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: nil)
            : NSImage(systemSymbolName: "moon", accessibilityDescription: nil)
        menu.addItem(antiSleepItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: QuickPodText.text(zh: "设置…", en: "Settings…"), action: #selector(showMainWindow), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: QuickPodText.text(zh: "退出", en: "Quit"), action: #selector(quitApp), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func toggleAntiSleepFromMenu() {
        antiSleep.toggle()
    }

    @objc private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }

        if breakReminder.isActive && breakReminder.remainingSeconds > 0 {
            let progress = breakReminder.progress
            button.image = makeProgressRingImage(progress: progress, color: progressColor(for: progress))
            button.imageScaling = .scaleProportionallyDown
            button.contentTintColor = nil
            button.title = breakReminder.formattedRemainingTime
            return
        }

        let imageName = antiSleep.isActive ? "bolt.fill" : "bolt.slash.fill"
        if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "QuickPod") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.imageScaling = .scaleProportionallyDown
            button.contentTintColor = antiSleep.isActive ? NSColor.controlAccentColor : nil
        }
        button.title = ""
    }

    private func progressColor(for progress: Double) -> NSColor {
        if progress >= 0.66 {
            return .systemGreen
        }
        if progress >= 0.33 {
            return .systemYellow
        }
        return .systemRed
    }

    private func makeProgressRingImage(progress: Double, color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let rect = CGRect(origin: .zero, size: size)
        let lineWidth: CGFloat = 2.2
        let inset = lineWidth / 2 + 1
        let ringRect = rect.insetBy(dx: inset, dy: inset)
        let startAngle = -CGFloat.pi / 2
        let clampedProgress = min(max(progress, 0.0), 1.0)
        let endAngle = startAngle + (CGFloat.pi * 2 * clampedProgress)

        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setStrokeColor(NSColor.labelColor.withAlphaComponent(0.16).cgColor)
        context.strokeEllipse(in: ringRect)

        if clampedProgress > 0.001 {
            let path = CGMutablePath()
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: ringRect.width / 2,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
            context.addPath(path)
            context.setStrokeColor(color.cgColor)
            context.strokePath()
        } else {
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(x: rect.midX - 1.4, y: rect.midY - 1.4, width: 2.8, height: 2.8))
        }

        context.setFillColor(NSColor.labelColor.withAlphaComponent(0.88).cgColor)
        context.fillEllipse(in: CGRect(x: rect.midX - 1.6, y: rect.midY - 1.6, width: 3.2, height: 3.2))

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    func applyAppearancePreference() {
        let appearance = NSAppearance(named: .aqua)
        NSApp.appearance = appearance
        mainWindow?.appearance = appearance
        print("[QuickPod] 已应用固定浅色主题")
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Main Window (Frosted Glass)

    private func setupMainWindow() {
        let contentView = MainWindowView(
            antiSleep: antiSleep,
            breakReminder: breakReminder
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 440, height: 640)
        hostingView.autoresizingMask = [.width, .height]

        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        mainWindow.title = "QuickPod 设置"
        mainWindow.center()
        mainWindow.isReleasedWhenClosed = false
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.titleVisibility = .hidden
        mainWindow.standardWindowButton(.closeButton)?.isHidden = false
        mainWindow.standardWindowButton(.zoomButton)?.isHidden = true
        mainWindow.standardWindowButton(.miniaturizeButton)?.isHidden = false
        mainWindow.minSize = NSSize(width: 420, height: 560)
        mainWindow.maxSize = NSSize(width: 520, height: 760)
        mainWindow.level = .floating

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 640))
        containerView.autoresizingMask = [.width, .height]

        // 毛玻璃底层
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.frame = containerView.bounds
        visualEffect.autoresizingMask = [.width, .height]
        containerView.addSubview(visualEffect)
        containerView.addSubview(hostingView)
        mainWindow.contentView = containerView

        // 透明背景
        mainWindow.backgroundColor = .clear
        mainWindow.isOpaque = false
        mainWindow.hasShadow = true

        // 圆角
        mainWindow.contentView?.wantsLayer = true
        mainWindow.contentView?.layer?.cornerRadius = 12
        mainWindow.contentView?.layer?.masksToBounds = true
    }

    @objc private func showMainWindow() {
        guard mainWindow != nil else {
            print("[QuickPod] Main window was not created successfully")
            return
        }
        mainWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func toggleMainWindow() {
        if mainWindow.isVisible {
            mainWindow.orderOut(nil)
        } else {
            showMainWindow()
        }
    }

    func hideMainWindow() {
        mainWindow.orderOut(nil)
    }

    func showMainWindowAgain() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showMainWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Global Hotkey

    private func setupGlobalHotkey() {
        globalHotkey.register()
    }

    func reconfigureHotkey() {
        globalHotkey.reconfigure()
    }

    // MARK: - 通知权限

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // 首次启动时主动申请
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.showInitialNotificationPermissionAlert()
                }
            case .denied:
                print("[QuickPod] 通知权限：已被拒绝")
            case .authorized, .provisional, .ephemeral:
                print("[QuickPod] 通知权限：已授权")
            @unknown default:
                break
            }
        }
    }

    private func showInitialNotificationPermissionAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = QuickPodText.text(zh: "启用通知提醒", en: "Enable notifications")
        alert.informativeText = QuickPodText.text(
            zh: "QuickPod 可以发送通知来提醒您休息。是否现在开启通知权限？",
            en: "QuickPod can send local notifications for break reminders. Allow notifications now?"
        )
        alert.addButton(withTitle: QuickPodText.text(zh: "允许通知", en: "Allow"))
        alert.addButton(withTitle: QuickPodText.text(zh: "暂时不用", en: "Not now"))

        if alert.runModal() == .alertFirstButtonReturn {
            breakReminder.requestPermission { granted in
                if granted {
                    print("[QuickPod] 通知权限：已授权")
                } else {
                    print("[QuickPod] 通知权限：被拒绝")
                }
            }
        }
    }

    private func observeReopenRequests() {
        reopenObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.reopenNotification,
            object: Bundle.main.bundleIdentifier ?? "com.quickpod.app",
            queue: .main
        ) { [weak self] _ in
            self?.showMainWindowAgain()
        }
    }

    private func acquireSingleInstanceLock() -> Bool {
        let lockPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("com.quickpod.app.lock")
        let fd = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
        guard fd >= 0 else {
            print("[QuickPod] 无法创建单实例锁文件: \(lockPath)")
            return true
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            print("[QuickPod] 已检测到运行中的实例")
            return false
        }

        singleInstanceLockFD = fd
        return true
    }

    private func releaseSingleInstanceLock() {
        guard singleInstanceLockFD >= 0 else { return }
        flock(singleInstanceLockFD, LOCK_UN)
        close(singleInstanceLockFD)
        singleInstanceLockFD = -1
    }

    private func openSystemSettings(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func renderMarketingScreenshotsAndQuit() {
        let projectPath = FileManager.default.currentDirectoryPath
        let outputDirectory = URL(fileURLWithPath: projectPath).appendingPathComponent("screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let defaults = UserDefaults.standard
        let previousReminderActive = defaults.object(forKey: "QuickPod.breakReminderActive")
        let previousReminderInterval = defaults.object(forKey: "QuickPod.breakIntervalMinutes")
        let previousReminderStyle = defaults.object(forKey: "QuickPod.reminderStyle")

        let breakReminder = BreakReminder()
        breakReminder.intervalMinutes = 25
        breakReminder.isActive = true
        breakReminder.remainingSeconds = 18 * 60 + 42
        breakReminder.progress = 0.75

        let mainView = MainWindowView(
            antiSleep: antiSleep,
            breakReminder: breakReminder
        )
        renderSwiftUIView(
            mainView,
            size: NSSize(width: 440, height: 760),
            to: outputDirectory.appendingPathComponent("main-window.png")
        )

        let quickSwitcherModel = QuickSwitcherModel()
        quickSwitcherModel.currentScreen = .root
        quickSwitcherModel.selectedIndex = 2
        quickSwitcherModel.isVisible = true
        let quickSwitcherItems = [
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "防睡眠", en: "Anti-sleep"),
                subtitle: QuickPodText.text(zh: "已开启", en: "Enabled"),
                icon: "moon.zzz.fill",
                kind: .action,
                action: nil
            ),
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "屏幕清洁", en: "Screen cleaner"),
                subtitle: QuickPodText.text(zh: "全屏清洁", en: "Full-screen cleaner"),
                icon: "sparkles",
                kind: .action,
                action: nil
            ),
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "休息提醒", en: "Break reminders"),
                subtitle: QuickPodText.text(zh: "1 分钟测试", en: "1 min test"),
                icon: "timer",
                kind: .submenu(.breakPicker),
                action: nil
            ),
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "新建文件", en: "Create file"),
                subtitle: QuickPodText.text(zh: "支持自定义后缀", en: "Custom extensions"),
                icon: "doc.badge.plus",
                kind: .submenu(.filePicker),
                action: nil
            )
        ]
        let quickSwitcherView = QuickSwitcherView(
            model: quickSwitcherModel,
            itemsProvider: { _ in quickSwitcherItems },
            onSelect: {}
        )
        renderSwiftUIView(
            quickSwitcherView
                .frame(width: 420, height: 360)
                .background(Color.clear),
            size: NSSize(width: 420, height: 360),
            to: outputDirectory.appendingPathComponent("quick-switcher.png")
        )

        let reminderPopupView = BreakReminderPopupView(
            title: QuickPodText.text(zh: "该休息啦", en: "Time for a break"),
            message: QuickPodText.text(
                zh: "已经工作 25 分钟了，站起来活动一下，喝口水也行。",
                en: "You've been working for 25 minutes. Stand up, stretch, and take a sip of water."
            ),
            onConfirm: {},
            onSnooze5: {},
            onSnooze10: {}
        )
        renderSwiftUIView(
            reminderPopupView,
            size: NSSize(width: 340, height: 176),
            to: outputDirectory.appendingPathComponent("break-reminder.png")
        )

        let statusPreview = StatusBarPreviewShotView()
        renderSwiftUIView(
            statusPreview,
            size: NSSize(width: 380, height: 220),
            to: outputDirectory.appendingPathComponent("status-bar-panel.png")
        )

        restoreDefault(previousReminderActive, key: "QuickPod.breakReminderActive")
        restoreDefault(previousReminderInterval, key: "QuickPod.breakIntervalMinutes")
        restoreDefault(previousReminderStyle, key: "QuickPod.reminderStyle")

        print("[QuickPod] 已生成最新 README 截图到 \(outputDirectory.path)")
        NSApp.terminate(nil)
    }

    private func renderSwiftUIView<V: View>(_ view: V, size: NSSize, to url: URL) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            print("[QuickPod] 无法创建截图位图: \(url.lastPathComponent)")
            return
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("[QuickPod] 无法编码 PNG: \(url.lastPathComponent)")
            return
        }

        do {
            try pngData.write(to: url)
        } catch {
            print("[QuickPod] 写入截图失败 \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func restoreDefault(_ value: Any?, key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func showPermissionAlert(title: String, message: String, openHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            openHandler()
        }
    }

    func presentNotificationPermissionAlert() {
        showPermissionAlert(
            title: QuickPodText.text(zh: "需要通知权限", en: "Notification permission needed"),
            message: QuickPodText.text(
                zh: "QuickPod 需要通知权限来发送休息提醒。请在“系统设置 > 通知”中允许 QuickPod。",
                en: "QuickPod needs notification permission for break reminders. Please allow it in System Settings > Notifications."
            )
        ) { [weak self] in
            self?.openSystemSettings(urlString: "x-apple.systempreferences:com.apple.preference.notifications")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let reopenObserver {
            DistributedNotificationCenter.default().removeObserver(reopenObserver)
            self.reopenObserver = nil
        }
        antiSleep.shutdownForTermination()
        releaseSingleInstanceLock()
        globalHotkey.unregister()
        QuickSwitcherController.shared.hide()
    }
}

private struct StatusBarPreviewShotView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.10), lineWidth: 7)
                        .frame(width: 54, height: 54)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(
                            Color(red: 0.29, green: 0.72, blue: 0.45),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)
                    Circle()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 8, height: 8)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("QuickPod")
                        .font(.system(size: 18, weight: .bold))
                    Text(QuickPodText.text(zh: "状态栏圆环会跟随提醒进度变化", en: "The menu bar ring mirrors reminder progress"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 10) {
                statusRow("✓ 防睡眠已开启", icon: "moon.zzz.fill")
                statusRow("设置…", icon: "gearshape")
                statusRow("退出", icon: "power")
            }
        }
        .padding(22)
        .frame(width: 380, height: 220, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private func statusRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.03))
        )
    }
}
