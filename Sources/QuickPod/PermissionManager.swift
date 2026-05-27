import Foundation
import AppKit
import UserNotifications
import ServiceManagement

class PermissionManager: ObservableObject {
    @Published var notificationPermission: PermissionStatus = .unknown
    @Published var accessibilityPermission: PermissionStatus = .unknown
    @Published var loginItemPermission: PermissionStatus = .unknown
    @Published var notificationDebugSummary: String = ""
    
    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
        case notRequired
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
                guard let self else { return }

                let notificationChannelsEnabled = [
                    settings.alertSetting,
                    settings.soundSetting,
                    settings.badgeSetting,
                    settings.notificationCenterSetting
                ].contains(.enabled)

                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.notificationPermission = .granted
                case .denied:
                    self.notificationPermission = .denied
                case .notDetermined:
                    self.notificationPermission = notificationChannelsEnabled ? .granted : .notDetermined
                @unknown default:
                    self.notificationPermission = notificationChannelsEnabled ? .granted : .unknown
                }

                let authText = self.authorizationDescription(for: settings.authorizationStatus)
                let entrySummary = self.readNotificationPreferencesSummary()
                self.notificationDebugSummary = QuickPodText.text(
                    zh: "系统状态: \(authText) · \(entrySummary)",
                    en: "System status: \(authText) · \(entrySummary)"
                )

                print("[QuickPod] 通知权限检查: auth=\(settings.authorizationStatus.rawValue) alert=\(settings.alertSetting.rawValue) sound=\(settings.soundSetting.rawValue) badge=\(settings.badgeSetting.rawValue) center=\(settings.notificationCenterSetting.rawValue)")
                print("[QuickPod] 通知权限诊断: \(self.notificationDebugSummary)")
            }
        }
    }
    
    func checkAccessibilityPermission() {
        DispatchQueue.main.async { [weak self] in
            self?.accessibilityPermission = .notRequired
            print("[QuickPod] 辅助功能权限: 当前主路径不依赖辅助功能。全局快捷键使用 Carbon RegisterEventHotKey；辅助功能仅对某些可选键盘监听场景有帮助。")
        }
    }
    
    private func readAccessibilityTCCSummary() -> String {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.quickpod.app"
        let bundlePath = Bundle.main.bundleURL.path
        let tccPath = ("~/Library/Application Support/com.apple.TCC/TCC.db" as NSString).expandingTildeInPath

        guard FileManager.default.isReadableFile(atPath: tccPath) else {
            return "tcc=unreadable"
        }

        let command = """
        /usr/bin/sqlite3 '\(tccPath)' "SELECT client || '|' || COALESCE(CAST(auth_value AS TEXT), CAST(allowed AS TEXT), 'nil') FROM access WHERE service='kTCCServiceAccessibility' AND (client='\(bundleID)' OR client='\(bundlePath)') ORDER BY last_modified DESC LIMIT 1;"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", command]

        let output = Pipe()
        let errors = Pipe()
        task.standardOutput = output
        task.standardError = errors

        do {
            try task.run()
            task.waitUntilExit()

            let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let errorText = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if task.terminationStatus == 0, !outputText.isEmpty {
                return "tcc=\(outputText)"
            }

            if !errorText.isEmpty {
                return "tccError=\(errorText)"
            }
        } catch {
            return "tccError=\(error.localizedDescription)"
        }

        return "tcc=empty"
    }

    private func authorizationDescription(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return QuickPodText.text(zh: "已授权", en: "Authorized")
        case .provisional:
            return QuickPodText.text(zh: "临时授权", en: "Provisional")
        case .ephemeral:
            return QuickPodText.text(zh: "临时会话授权", en: "Ephemeral")
        case .denied:
            return QuickPodText.text(zh: "已拒绝", en: "Denied")
        case .notDetermined:
            return QuickPodText.text(zh: "未登记", en: "Not recorded yet")
        @unknown default:
            return QuickPodText.text(zh: "未知", en: "Unknown")
        }
    }

    private func readNotificationPreferencesSummary() -> String {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.quickpod.app"
        let plistPath = ("~/Library/Preferences/com.apple.ncprefs.plist" as NSString).expandingTildeInPath

        guard FileManager.default.isReadableFile(atPath: plistPath) else {
            return QuickPodText.text(zh: "系统通知记录不可读", en: "Notification prefs unreadable")
        }

        let command = """
        /usr/bin/plutil -extract apps xml1 -o - '\(plistPath)' 2>/dev/null | /usr/bin/grep -A 12 -B 2 '<string>\(bundleID)</string>' | /usr/bin/tr '\n' ' '
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", command]

        let output = Pipe()
        task.standardOutput = output

        do {
            try task.run()
            task.waitUntilExit()
            let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                return QuickPodText.text(
                    zh: "系统未登记当前构建，重编译后的未签名构建可能会被当成新 App",
                    en: "The system has not recorded this build yet. Unsigned rebuilds may be treated as a new app"
                )
            }

            if text.contains("<key>auth</key>") {
                return QuickPodText.text(zh: "系统设置中已存在 QuickPod 记录", en: "QuickPod entry exists in notification prefs")
            }

            return QuickPodText.text(zh: "系统中已找到 QuickPod 条目", en: "QuickPod entry found in notification prefs")
        } catch {
            return QuickPodText.text(zh: "读取系统通知记录失败", en: "Failed to read notification prefs")
        }
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
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
        return notificationPermission == .denied
    }
}

extension PermissionManager.PermissionStatus {
    var description: String {
        switch self {
        case .granted: return QuickPodText.text(zh: "已授权", en: "Granted")
        case .denied: return QuickPodText.text(zh: "已拒绝", en: "Denied")
        case .notDetermined: return QuickPodText.text(zh: "未设置", en: "Not Set")
        case .notRequired: return QuickPodText.text(zh: "可选", en: "Optional")
        case .unknown: return QuickPodText.text(zh: "未知", en: "Unknown")
        }
    }
    
    var iconName: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "circle"
        case .notRequired: return "minus.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    var color: NSColor {
        switch self {
        case .granted: return .systemGreen
        case .denied: return .systemRed
        case .notDetermined: return .systemOrange
        case .notRequired: return .systemGray
        case .unknown: return .systemGray
        }
    }
}
