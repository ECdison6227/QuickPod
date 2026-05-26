import AppKit
import ApplicationServices
import Darwin
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private static let reopenNotification = Notification.Name("com.quickpod.app.reopen")

    var statusItem: NSStatusItem!
    private var mainWindow: NSWindow!
    private var statusPopover: NSPopover!
    private var reopenObserver: NSObjectProtocol?
    private var singleInstanceLockFD: Int32 = -1
    private let globalHotkey = GlobalHotkey { _, _ in
        RadialMenuController.shared.showQuickMenu()
        (NSApp.delegate as? AppDelegate)?.statusPopover.performClose(nil)
    }

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
        setupRadialMenu()
        requestNotificationPermission()
        breakReminder.prepareOnLaunch()
        promptForAccessibilityIfNeeded()
        showMainWindow()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
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
            button.action = #selector(toggleStatusPopover)
        }

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
            statusPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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

    // MARK: - Radial Menu (Fn+Option 长按)

    private func setupRadialMenu() {
        RadialMenuController.shared.startListening()
    }

    // MARK: - 通知权限

    private func requestNotificationPermission() {
        breakReminder.requestPermission { granted in
            if granted {
                print("[QuickPod] 通知权限: 已授权")
            } else {
                print("[QuickPod] 通知权限: 被拒绝")
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

    private func promptForAccessibilityIfNeeded() {
        guard !isAccessibilityTrusted(prompt: false) else { return }

        _ = isAccessibilityTrusted(prompt: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.presentAccessibilityPermissionAlert()
        }
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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

    func presentAccessibilityPermissionAlert() {
        showPermissionAlert(
            title: "需要辅助功能权限",
            message: "QuickPod 需要辅助功能权限来响应全局快捷键。请在“系统设置 > 隐私与安全性 > 辅助功能”中允许 QuickPod。"
        ) { [weak self] in
            self?.openSystemSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
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
        RadialMenuController.shared.stopListening()
    }
}
