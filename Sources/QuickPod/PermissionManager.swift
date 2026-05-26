import Foundation
import AppKit
import UserNotifications
import ServiceManagement

class PermissionManager: ObservableObject {
    @Published var notificationPermission: PermissionStatus = .unknown
    @Published var accessibilityPermission: PermissionStatus = .unknown
    
    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
        case unknown
    }
    
    func checkAllPermissions() {
        checkNotificationPermission()
        checkAccessibilityPermission()
    }
    
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { [weak self] in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self?.notificationPermission = .granted
                case .denied:
                    self?.notificationPermission = .denied
                case .notDetermined:
                    self?.notificationPermission = .notDetermined
                @unknown default:
                    self?.notificationPermission = .unknown
                }
            }
        }
    }
    
    private var accessibilityRetryWork: DispatchWorkItem?

    func checkAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async { [weak self] in
            self?.accessibilityPermission = isTrusted ? .granted : .denied
        }
    }

    /// Re-check accessibility permission repeatedly for up to `duration` seconds
    /// (catches the case where user grants permission while app is still running).
    func pollAccessibilityPermission(duration: TimeInterval = 30, interval: TimeInterval = 2) {
        accessibilityRetryWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.checkAccessibilityPermission()
        }
        accessibilityRetryWork = work
        let repeatCount = Int(duration / interval)
        for i in 0..<repeatCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i + 1), execute: work)
        }
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        AXIsProcessTrustedWithOptions(options)
        pollAccessibilityPermission(duration: 30, interval: 2)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self = self, self.accessibilityPermission != .granted else { return }
            self.showRestartForAccessibilityAlert()
        }
    }

    private func showRestartForAccessibilityAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "需要重启 QuickPod"
        alert.informativeText = "辅助功能权限需要重启应用后才能生效。\n\n请在「系统设置 > 隐私与安全性 > 辅助功能」中确认 QuickPod 已勾选，然后重启。"
        alert.addButton(withTitle: "立即重启")
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            Self.restartApp()
        case .alertSecondButtonReturn:
            openAccessibilitySettings()
        default:
            break
        }
    }

    static func restartApp() {
        let path = Bundle.main.bundlePath
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.open(URL(fileURLWithPath: path), configuration: config)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }
    
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    var hasDeniedPermissions: Bool {
        return notificationPermission == .denied ||
               accessibilityPermission == .denied
    }
}

extension PermissionManager.PermissionStatus {
    var description: String {
        switch self {
        case .granted: return "已授权"
        case .denied: return "已拒绝"
        case .notDetermined: return "未设置"
        case .unknown: return "未知"
        }
    }
    
    var iconName: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "circle"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    var color: NSColor {
        switch self {
        case .granted: return .systemGreen
        case .denied: return .systemRed
        case .notDetermined: return .systemOrange
        case .unknown: return .systemGray
        }
    }
}