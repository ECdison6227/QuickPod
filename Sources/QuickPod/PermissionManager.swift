import Foundation
import AppKit
import UserNotifications
import ServiceManagement

class PermissionManager: ObservableObject {
    @Published var notificationPermission: PermissionStatus = .unknown
    @Published var accessibilityPermission: PermissionStatus = .unknown
    @Published var loginItemPermission: PermissionStatus = .unknown
    
    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
        case unknown
    }
    
    func checkAllPermissions() {
        checkNotificationPermission()
        checkAccessibilityPermission()
        checkLoginItemPermission()
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
    
    func checkAccessibilityPermission() {
        DispatchQueue.global().async { [weak self] in
            // 使用 AXIsProcessTrustedWithOptions 检测辅助功能权限
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: false]
            let isTrusted = AXIsProcessTrustedWithOptions(options)
            
            DispatchQueue.main.async {
                if isTrusted {
                    self?.accessibilityPermission = .granted
                } else {
                    // 使用 AppleScript 检查更准确的权限状态
                    let script = """
                    tell application "System Events"
                        set isEnabled to UI elements enabled
                    end tell
                    return isEnabled
                    """
                    
                    var error: NSDictionary?
                    let scriptObject = NSAppleScript(source: script)
                    let result = scriptObject?.executeAndReturnError(&error)
                    
                    if error != nil {
                        // AppleScript 失败，使用默认判断
                        self?.accessibilityPermission = .notDetermined
                    } else {
                        if result?.booleanValue ?? false {
                            // 用户已授权系统事件，但可能还没授权本应用
                            // 直接使用 AXIsProcessTrusted 的结果
                            self?.accessibilityPermission = isTrusted ? .granted : .notDetermined
                        } else {
                            self?.accessibilityPermission = .notDetermined
                        }
                    }
                }
            }
        }
    }
    
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
        // 延迟检查权限状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }
    
    func checkLoginItemPermission() {
        if #available(macOS 13.0, *) {
            DispatchQueue.global().async { [weak self] in
                let status = SMAppService.mainApp.status
                DispatchQueue.main.async {
                    self?.loginItemPermission = status == .enabled ? .granted : .notDetermined
                }
            }
        } else {
            loginItemPermission = .unknown
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
    
    func openLoginItemsSettings() {
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.users") {
            NSWorkspace.shared.open(url)
        }
    }
    
    var hasDeniedPermissions: Bool {
        return notificationPermission == .denied || accessibilityPermission == .denied
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
