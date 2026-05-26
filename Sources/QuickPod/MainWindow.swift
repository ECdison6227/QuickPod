import SwiftUI
import UserNotifications

// MARK: - 主窗口视图

struct MainWindowView: View {
    @ObservedObject var antiSleep: AntiSleepManager
    @ObservedObject var breakReminder: BreakReminder
    @StateObject private var loginItem = LoginItemManager()
    @StateObject private var screenCleanerState = ScreenCleanerState()
    @StateObject private var permissionManager = PermissionManager()

    @State private var defaultFileName: String = FileCreator.defaultFileName
    @State private var showFileNameEditor = false
    @State private var fileStatusMessage: String?
    @State private var hasSeenIntro = UserDefaults.standard.bool(forKey: "QuickPod.hasSeenIntro")
    @State private var isRecordingShortcut = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            permissionStatusBanner
            ScrollView {
                VStack(spacing: 12) {
                    if !hasSeenIntro {
                        firstLaunchCard
                    }
                    coreControlsSection
                    fileSettingsSection
                    reminderSettingsSection
                    shortcutSection
                    permissionSection
                    appSettingsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .frame(width: 440)
        .frame(minHeight: 560)
        .background(LiquidGlassBackground())
        .onAppear {
            permissionManager.checkAllPermissions()
        }
    }

    // MARK: - Permission Status Banner

    private var permissionStatusBanner: some View {
        if permissionManager.hasDeniedPermissions {
            return AnyView(
                HStack(spacing: 8) {
                    Image(systemName: "alert.triangle")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text("部分权限未开启，某些功能可能无法正常工作")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("检查") {
                        permissionManager.checkAllPermissions()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(nsImage: appIconImage())
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("QuickPod 设置")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text("状态栏快捷操作、权限、提醒和文件模板")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private func appIconImage() -> NSImage {
        if let icon = NSImage(named: "AppIcon") {
            return icon
        }
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: path) {
            return icon
        }
        return NSImage(systemSymbolName: "bolt.circle.fill",
                       accessibilityDescription: "QuickPod") ?? NSImage()
    }

    private var firstLaunchCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("第一次使用", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("知道了") {
                    hasSeenIntro = true
                    UserDefaults.standard.set(true, forKey: "QuickPod.hasSeenIntro")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            }
                Text("QuickPod 会待在菜单栏里。点击状态栏图标打开快捷面板；打开设置窗口可以改默认文件名、休息提醒间隔、开机启动，并查看快捷键说明。圆形快捷菜单会在按住快捷键时显示，松开后关闭。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .liquidCard(cornerRadius: 16)
    }

    private var coreControlsSection: some View {
        settingsSection("核心功能", subtitle: "常用开关也可以从状态栏快捷面板操作") {
            VStack(spacing: 0) {
                MiniToggleRow(
                    title: "防睡眠",
                    subtitle: antiSleep.isActive ? "剩余时间: \(antiSleep.getRemainingTimeString())" : "正常休眠",
                    isOn: antiSleep.isActive,
                    action: { antiSleep.toggle() }
                )
                
                if antiSleep.isActive {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("会话时长")
                            .font(.system(size: 12, weight: .medium))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(AntiSleepManager.SessionDuration.allCases, id: \.self) { duration in
                                Button(duration.displayName) {
                                    antiSleep.activate(withDuration: duration)
                                }
                                .buttonStyle(LiquidPillButtonStyle(isSelected: antiSleep.sessionDuration == duration))
                                .font(.system(size: 11, weight: .medium))
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(12)
                }
                
                thinDivider
                MiniButtonRow(title: "屏幕清洁", subtitle: "全屏黑色清洁模式，按任意键或点击退出") {
                    screenCleanerState.onDeactivateExtra = { [weak appDelegate = NSApp.delegate as? AppDelegate] in
                        appDelegate?.showMainWindowAgain()
                    }
                    screenCleanerState.activate()
                }
            }
        }
    }

    private var fileSettingsSection: some View {
        settingsSection("新建文件到桌面", subtitle: "先设置默认文件名，再点击类型按钮创建文件") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("默认文件名", text: $defaultFileName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onChange(of: defaultFileName) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            FileCreator.defaultFileName = trimmed
                        }
                    }
                HStack(spacing: 8) {
                    ForEach(FileCreator.FileType.allCases, id: \.self) { type in
                        Button(type.shortName) {
                            FileCreator().create(type) { result in
                                switch result {
                                case .success(let url):
                                    fileStatusMessage = "\(url.lastPathComponent) 已创建到桌面"
                                case .failure(let error):
                                    fileStatusMessage = error.localizedDescription
                                }
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .buttonStyle(LiquidPillButtonStyle(isSelected: false))
                    }
                }
                if let fileStatusMessage {
                    Text(fileStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
    }

    private var reminderSettingsSection: some View {
        settingsSection("休息提醒", subtitle: "选择提醒间隔，开启后会按周期发送系统通知") {
            MiniToggleRow(
                title: "启用休息提醒",
                subtitle: breakReminder.isActive ? "每 \(breakReminder.intervalMinutes) 分钟提醒" : "关闭",
                isOn: breakReminder.isActive,
                action: { breakReminder.toggle() }
            )
            thinDivider
            VStack(alignment: .leading, spacing: 8) {
                Text("提醒间隔")
                    .font(.system(size: 12, weight: .medium))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(BreakReminder.intervalOptions, id: \.self) { minutes in
                        Button("\(minutes) 分钟") {
                            breakReminder.intervalMinutes = minutes
                            if breakReminder.isActive {
                                breakReminder.restart()
                            }
                        }
                        .buttonStyle(LiquidPillButtonStyle(isSelected: breakReminder.intervalMinutes == minutes))
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(12)
            thinDivider
            MiniButtonRow(title: "发送测试通知", subtitle: "立即发送一条通知，确认通知系统正常") {
                sendTestNotification()
            }
        }
    }

    private func sendTestNotification() {
        fileStatusMessage = "正在发送测试通知..."
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    let content = UNMutableNotificationContent()
                    content.title = "QuickPod 测试通知"
                    content.body = "通知系统正常工作！"
                    content.sound = .default
                    let request = UNNotificationRequest(
                        identifier: "QuickPod.testNotification",
                        content: content,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
                    )
                    UNUserNotificationCenter.current().add(request)
                    self.fileStatusMessage = "测试通知已发送，请检查通知中心"
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        DispatchQueue.main.async {
                            if granted {
                                self.sendTestNotification()
                            } else {
                                self.fileStatusMessage = "通知权限被拒绝，请在系统设置中开启"
                            }
                        }
                    }
                case .denied:
                    self.fileStatusMessage = "通知权限已关闭，请在系统设置中开启"
                @unknown default:
                    self.fileStatusMessage = "无法发送测试通知"
                }
            }
        }
    }

    private var shortcutSection: some View {
        settingsSection("快捷键", subtitle: "录制用于呼出快捷菜单的快捷键，按住显示，松手关闭") {
            VStack(spacing: 0) {
                HStack {
                    Text("打开快捷菜单")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button(action: {
                        isRecordingShortcut = true
                        installShortcutRecorder()
                    }) {
                        Text(isRecordingShortcut ? "按下新快捷键..." : GlobalHotkey.displayString)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(isRecordingShortcut ? .orange : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isRecordingShortcut
                                        ? Color.orange.opacity(0.15)
                                        : Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
        }
    }

    private func installShortcutRecorder() {
        guard NSApp.keyWindow ?? NSApp.windows.first != nil else { return }
        var monitor: Any?
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let combo = extractHotKeyFromEvent(event) else { return event }
            GlobalHotkey.keyCode = combo.keyCode
            GlobalHotkey.modifiers = combo.modifiers
            self.isRecordingShortcut = false
            if let m = monitor { NSEvent.removeMonitor(m) }
            (NSApp.delegate as? AppDelegate)?.reconfigureHotkey()
            return nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            guard self.isRecordingShortcut else { return }
            self.isRecordingShortcut = false
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }

    private var permissionSection: some View {
        settingsSection("权限管理", subtitle: "确保以下权限已正确配置") {
            VStack(spacing: 0) {
                PermissionRow(
                    title: "通知权限",
                    description: "用于休息提醒通知",
                    status: permissionManager.notificationPermission,
                    action: { permissionManager.openNotificationSettings() }
                )
                thinDivider
                PermissionRow(
                    title: "辅助功能",
                    description: "用于快捷键全局监听",
                    status: permissionManager.accessibilityPermission,
                    action: { permissionManager.openAccessibilitySettings() }
                )
                thinDivider
                PermissionRow(
                    title: "开机启动",
                    description: "登录时自动启动",
                    status: permissionManager.loginItemPermission,
                    action: { permissionManager.openLoginItemsSettings() }
                )
            }
        }
    }

    private var appSettingsSection: some View {
        settingsSection("应用设置", subtitle: nil) {
            MiniToggleRow(
                title: "开机启动",
                subtitle: loginItem.isEnabled ? "已开启" : "关闭",
                isOn: loginItem.isEnabled,
                action: { loginItem.toggle() }
            )
            thinDivider
            MiniButtonRow(title: "退出 QuickPod", subtitle: "关闭菜单栏常驻进程") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 2)
            VStack(spacing: 0) {
                content()
            }
            .liquidCard(cornerRadius: 16)
        }
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 16)
    }

}

// MARK: - Mini Row Components

struct MiniToggleRow: View {
    let title: String
    let subtitle: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Circle()
                    .fill(isOn ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidRowButtonStyle())
    }
}

struct MiniButtonRow: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidRowButtonStyle())
    }
}

struct InfoRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PermissionManager.PermissionStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: status.iconName)
                    .foregroundColor(Color(status.color))
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Text(status.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(status.color))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidRowButtonStyle())
    }
}

struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.16),
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct LiquidCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.045), radius: 7, x: 0, y: 3)
    }
}

extension View {
    func liquidCard(cornerRadius: CGFloat) -> some View {
        modifier(LiquidCardModifier(cornerRadius: cornerRadius))
    }
}

struct LiquidRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed ? Color.white.opacity(0.12) : Color.clear)
            )
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

struct LiquidPillButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.green.opacity(0.22) : Color.white.opacity(0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.48 : 0.28), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}

// MARK: - Screen Cleaner State Wrapper

class ScreenCleanerState: ObservableObject {
    private var cleaner = ScreenCleaner()
    @Published var isActive = false

    /// Extra action to run after deactivation (e.g., restore a window).
    /// Set to nil when cleaner is triggered from the radial menu (no restore needed).
    var onDeactivateExtra: (() -> Void)?

    init() {
        cleaner.onDeactivate = { [weak self] in
            DispatchQueue.main.async {
                self?.isActive = false
                self?.onDeactivateExtra?()
            }
        }
    }

    func activate() {
        isActive = true
        // Hide main window before entering cleaner mode
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.hideMainWindow()
        }
        cleaner.activate()
    }

    func deactivate() {
        cleaner.deactivate()
    }
}
