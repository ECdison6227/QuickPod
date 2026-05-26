import AppKit
import Darwin
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private static let reopenNotification = Notification.Name("com.quickpod.app.reopen")

    var statusItem: NSStatusItem!
    private var mainWindow: NSWindow!
    private var statusPopover: NSPopover!
    private var onboardingWindow: NSWindow?
    private var reopenObserver: NSObjectProtocol?
    private var singleInstanceLockFD: Int32 = -1
    private lazy var globalHotkey = GlobalHotkey(
        onPress: { _, _ in
            print("[QuickPod] Global hotkey pressed")
            QuickSwitcherController.shared.hotkeyPressed()
            (NSApp.delegate as? AppDelegate)?.statusPopover.performClose(nil)
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
        setupGlobalHotkey()
        setupQuickSwitcher()
        requestNotificationPermission()
        breakReminder.prepareOnLaunch()
        
        // 检查是否需要显示引导动画
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "QuickPod.hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            showOnboardingWindow()
        } else {
            showMainWindow()
        }

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
    
    private func showOnboardingWindow() {
        struct OnboardingWrapper: View {
            let completion: () -> Void
            
            var body: some View {
                OnboardingAnimationView(isPresented: .constant(true))
                    .onDisappear {
                        completion()
                    }
            }
        }
        
        let wrapperView = OnboardingWrapper { [weak self] in
            self?.onboardingWindow?.orderOut(nil)
            self?.onboardingWindow = nil
            self?.showMainWindow()
        }
        
        let hostingView = NSHostingView(rootView: wrapperView)
        let size = NSSize(width: 440, height: 640)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.autoresizingMask = NSView.AutoresizingMask([.width, .height])
        
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowRect = NSRect(
            x: (screenFrame.width - size.width) / 2,
            y: (screenFrame.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.setContentSize(size)
        window.contentView = hostingView
        window.title = "QuickPod"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.center()
        window.level = .floating
        
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // 统一使用闪电图标作为状态栏图标，根据防睡眠状态变化颜色
            updateStatusBarIcon()
            button.action = #selector(toggleMainWindow)
            button.sendAction(on: [.leftMouseDown])
        }

        // 右键菜单
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置", action: #selector(toggleMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 QuickPod", action: #selector(quitApp), keyEquivalent: ""))
        statusItem.menu = menu

        let popoverView = MenuBarView(
            antiSleep: antiSleep,
            breakReminder: breakReminder,
            openSettings: { [weak self] in
                self?.statusPopover.performClose(nil)
                self?.showMainWindow()
            }
        )
        statusPopover = NSPopover()
        statusPopover.behavior = .transient
        statusPopover.animates = true
        statusPopover.contentSize = NSSize(width: 300, height: 390)
        statusPopover.contentViewController = NSHostingController(rootView: popoverView)

        // 监听防睡眠状态变化，更新图标
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusBarIcon),
            name: AntiSleepManager.statusChangedNotification,
            object: nil
        )
    }

    @objc private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
        
        let imageName = antiSleep.isActive ? "bolt.fill" : "bolt.slash.fill"
        
        if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "QuickPod") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            
            // 添加淡入淡出动画效果
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                button.animator().alphaValue = 0.0
            }, completionHandler: {
                button.image = image
                button.imageScaling = .scaleProportionallyDown
                
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    button.animator().alphaValue = 1.0
                }, completionHandler: nil)
            })
        }
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

    private func showMainWindow() {
        guard mainWindow != nil else {
            print("[QuickPod] Main window was not created successfully")
            return
        }
        mainWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func toggleStatusPopover() {
        guard let button = statusItem.button else { return }
        if statusPopover.isShown {
            statusPopover.performClose(nil)
        } else {
            // 计算弹出位置，使箭头居中对齐到图标
            let iconWidth: CGFloat = 18
            let offsetX = (button.bounds.width - iconWidth) / 2 + iconWidth / 2
            let popoverRect = NSRect(x: offsetX - 4, y: 0, width: 8, height: button.bounds.height)
            statusPopover.show(relativeTo: popoverRect, of: button, preferredEdge: .minY)
            statusPopover.contentViewController?.view.window?.makeKey()
        }
    }

    func showStatusPopover(relativeTo button: NSStatusBarButton) {
        if !statusPopover.isShown {
            let iconWidth: CGFloat = 18
            let offsetX = (button.bounds.width - iconWidth) / 2 + iconWidth / 2
            let popoverRect = NSRect(x: offsetX - 4, y: 0, width: 8, height: button.bounds.height)
            statusPopover.show(relativeTo: popoverRect, of: button, preferredEdge: .minY)
            statusPopover.contentViewController?.view.window?.makeKey()
        }
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
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

    // MARK: - Quick Switcher (Fn+Option 长按)

    private func setupQuickSwitcher() {
        QuickSwitcherController.shared.startListening()
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
        alert.messageText = "启用通知提醒"
        alert.informativeText = "QuickPod 可以发送通知来提醒您休息。是否现在开启通知权限？"
        alert.addButton(withTitle: "允许通知")
        alert.addButton(withTitle: "暂时不用")

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
            title: "需要通知权限",
            message: "QuickPod 需要通知权限来发送休息提醒。请在“系统设置 > 通知”中允许 QuickPod。"
        ) { [weak self] in
            self?.openSystemSettings(urlString: "x-apple.systempreferences:com.apple.preference.notifications")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let reopenObserver {
            DistributedNotificationCenter.default().removeObserver(reopenObserver)
            self.reopenObserver = nil
        }
        releaseSingleInstanceLock()
        globalHotkey.unregister()
        QuickSwitcherController.shared.stopListening()
    }
}
