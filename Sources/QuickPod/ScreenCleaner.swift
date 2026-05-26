import AppKit
import SwiftUI

class ScreenCleaner {
    private var window: NSWindow?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var activatedAt: Date?
    var onDeactivate: (() -> Void)?

    func activate() {
        guard let screen = NSScreen.main else { return }

        let rect = screen.frame
        window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window?.isReleasedWhenClosed = false
        window?.backgroundColor = .black
        window?.level = .screenSaver
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window?.makeKeyAndOrderFront(nil)
        activatedAt = Date()

        // 全局事件拦截（ESC / 空格 / 任意按键退出）
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            guard self?.shouldHandleDeactivateEvent == true else { return }
            self?.deactivate()
        }

        // 本地事件拦截
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .flagsChanged]
        ) { [weak self] event in
            guard self?.shouldHandleDeactivateEvent == true else { return event }
            self?.deactivate()
            return nil
        }
    }

    private var shouldHandleDeactivateEvent: Bool {
        guard let activatedAt else { return true }
        return Date().timeIntervalSince(activatedAt) > 0.25
    }

    func deactivate() {
        let wasActive = window != nil || globalMonitor != nil || localMonitor != nil

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        // 使用 orderOut 而不是 close 避免卡顿
        window?.orderOut(nil)
        window = nil
        activatedAt = nil

        if wasActive {
            onDeactivate?()
        }
    }
}
