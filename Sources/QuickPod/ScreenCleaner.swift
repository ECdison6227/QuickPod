import AppKit
import SwiftUI

class ScreenCleaner {
    private var window: NSWindow?
    private var globalMonitor: Any?
    private var localMonitor: Any?
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

        // 全局事件拦截（ESC / 空格 / 任意按键退出）
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            self?.deactivate()
        }

        // 本地事件拦截
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .flagsChanged]
        ) { [weak self] event in
            self?.deactivate()
            return nil
        }
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

        if wasActive {
            onDeactivate?()
        }
    }
}
