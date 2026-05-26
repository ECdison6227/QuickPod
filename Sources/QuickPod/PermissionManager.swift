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
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async { [weak self] in
            self?.accessibilityPermission = isTrusted ? .granted : .denied
        }
    }
    
    func checkLoginItemPermission() {
        let url = Bundle.main.bundleURL
        let identifier = "com.quickpod.app"
        
        if let jobDictionaries = SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: Any]] {
            let isInLoginItems = jobDictionaries.contains { dict in
                if let jobURL = dict["ProgramArguments"] as? [String],
                   let firstArg = jobURL.first,
                   firstArg.contains(url.lastPathComponent) {
                    return true
                }
                return false
            }
            DispatchQueue.main.async { [weak self] in
                self?.loginItemPermission = isInLoginItems ? .granted : .notDetermined
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.loginItemPermission = .unknown
            }
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
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else {
            // 备用路径
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.users") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    var allPermissionsGranted: Bool {
        return notificationPermission == .granted &&
               accessibilityPermission == .granted &&
               loginItemPermission == .granted
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