import AppKit
import SwiftUI

class ScreenCleaner {
    private var window: NSWindow?
    private var countdownWindow: NSWindow?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var activatedAt: Date?
    var onDeactivate: (() -> Void)?

    /// 显示 3-2-1 倒计时，结束后自动进入清洁模式
    func activateWithCountdown() {
        guard let screen = NSScreen.main else { return }

        let rect = screen.frame
        let cw = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        cw.isReleasedWhenClosed = false
        cw.backgroundColor = .clear
        cw.isOpaque = false
        cw.level = .screenSaver
        cw.ignoresMouseEvents = true
        cw.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: CountdownView(onFinished: { [weak self] in
            DispatchQueue.main.async {
                cw.orderOut(nil)
                self?.countdownWindow = nil
                self?.activate()
            }
        }))
        hostingView.frame = rect
        hostingView.autoresizingMask = [.width, .height]
        cw.contentView = hostingView
        cw.makeKeyAndOrderFront(nil)
        countdownWindow = cw
    }

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

        // 全局事件拦截
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

        countdownWindow?.orderOut(nil)
        countdownWindow = nil

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        window?.orderOut(nil)
        window = nil
        activatedAt = nil

        if wasActive {
            onDeactivate?()
        }
    }
}

// MARK: - Countdown Overlay

private struct CountdownView: View {
    let onFinished: () -> Void

    @State private var phase = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)

            Text(countdownText)
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .scaleEffect(phase > 0 && phase < 4 ? 1 : 0.5)
                .opacity(phase > 0 && phase < 4 ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: phase)

            Text("即将进入屏幕清洁模式")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .offset(y: 90)
                .opacity(phase > 0 && phase < 4 ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: phase)
        }
        .onAppear {
            animateCountdown()
        }
    }

    private var countdownText: String {
        switch phase {
        case 1: return "3"
        case 2: return "2"
        case 3: return "1"
        default: return ""
        }
    }

    private func animateCountdown() {
        phase = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { phase = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { phase = 3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            phase = 4
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onFinished()
            }
        }
    }
}
