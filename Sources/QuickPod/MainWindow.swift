import SwiftUI
import UserNotifications

// MARK: - 主窗口视图

struct MainWindowView: View {
    @ObservedObject var antiSleep: AntiSleepManager
    @ObservedObject var breakReminder: BreakReminder
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @StateObject private var loginItem = LoginItemManager()
    @ObservedObject private var screenCleanerState = ScreenCleanerState.shared
    @StateObject private var permissionManager = PermissionManager()

    @State private var defaultFileName: String = FileCreator.defaultFileName
    @State private var customFileExtension: String = FileCreator.customFileExtension
    @State private var customReminderMinutes: String = ""
    @State private var showFileNameEditor = false
    @State private var fileStatusMessage: String?
    @State private var reminderStatusMessage: String?
    @State private var hasSeenIntro = UserDefaults.standard.bool(forKey: "QuickPod.hasSeenIntro")
    @State private var isRecordingShortcut = false
    @AppStorage(AppPreferences.languageKey) private var appLanguageRawValue = AppLanguage.system.rawValue
    
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
            if customReminderMinutes.isEmpty {
                customReminderMinutes = "\(breakReminder.intervalMinutes)"
            }
            permissionManager.checkAllPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionManager.checkAllPermissions()
        }
    }

    // MARK: - Permission Status Banner

    private var permissionStatusBanner: some View {
        if permissionManager.notificationPermission == .denied {
            return AnyView(
                HStack(spacing: 8) {
                    Image(systemName: "alert.triangle")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text(QuickPodText.text(zh: "通知权限未开启", en: "Notifications are disabled"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(QuickPodText.text(zh: "设置", en: "Settings")) {
                        permissionManager.openNotificationSettings()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            )
        } else if permissionManager.notificationPermission == .notDetermined {
            return AnyView(
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text(QuickPodText.text(
                        zh: "系统还没有为当前构建登记通知权限。点一次“发送测试通知”或去系统设置里重新允许，可让这次 build 重新注册。",
                        en: "macOS has not recorded notification permission for this build yet. Sending a test notification or re-enabling it in System Settings should register this build."
                    ))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(QuickPodText.text(zh: "打开设置", en: "Open settings")) {
                        permissionManager.openNotificationSettings()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.08))
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
                Text(QuickPodText.text(zh: "QuickPod 设置", en: "QuickPod Settings"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(QuickPodText.text(zh: "状态栏快捷操作、权限、提醒和文件模板", en: "Menu bar actions, permissions, reminders, and file templates"))
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
                Label(QuickPodText.text(zh: "第一次使用", en: "First launch"), systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(QuickPodText.text(zh: "知道了", en: "Got it")) {
                    hasSeenIntro = true
                    UserDefaults.standard.set(true, forKey: "QuickPod.hasSeenIntro")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            }
                Text(QuickPodText.text(
                    zh: "QuickPod 会待在菜单栏里。点击状态栏图标打开快捷面板；打开设置窗口可以改默认文件名、休息提醒间隔、开机启动，并查看快捷键说明。圆形快捷菜单会在按住快捷键时显示，松开后关闭。",
                    en: "QuickPod lives in the menu bar. Use the status item for quick actions, and open Settings to change the default file name, break interval, launch-at-login, and shortcuts. The radial switcher appears while you hold the hotkey and closes when you release it."
                ))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .liquidCard(cornerRadius: 16)
    }

    private var coreControlsSection: some View {
        settingsSection(QuickPodText.text(zh: "核心功能", en: "Core features"), subtitle: QuickPodText.text(zh: "常用开关也可以从状态栏快捷面板操作", en: "These controls are also available from the quick panel")) {
            VStack(spacing: 0) {
                MiniToggleRow(
                    title: QuickPodText.text(zh: "防睡眠", en: "Anti-sleep"),
                    subtitle: antiSleep.isActive
                        ? QuickPodText.text(zh: "剩余时间: \(antiSleep.getRemainingTimeString())", en: "Time left: \(antiSleep.getRemainingTimeString())")
                        : QuickPodText.text(zh: "正常休眠", en: "Normal sleep behavior"),
                    isOn: antiSleep.isActive,
                    action: { antiSleep.toggle() }
                )
                
                if antiSleep.isActive {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(QuickPodText.text(zh: "会话时长", en: "Session duration"))
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
                MiniButtonRow(title: QuickPodText.text(zh: "屏幕清洁", en: "Screen cleaner"), subtitle: QuickPodText.text(zh: "全屏黑色清洁模式，按任意键或点击退出", en: "Full-screen black cleaning mode. Press any key or click to exit")) {
                    screenCleanerState.onDeactivateExtra = { [weak appDelegate = NSApp.delegate as? AppDelegate] in
                        appDelegate?.showMainWindowAgain()
                    }
                    screenCleanerState.activate()
                }
            }
        }
    }

    private var fileSettingsSection: some View {
        settingsSection(QuickPodText.text(zh: "新建文件到桌面", en: "Create files on Desktop"), subtitle: QuickPodText.text(zh: "先设置默认文件名，再点击类型按钮创建文件", en: "Set the default file name, then choose a file type")) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(QuickPodText.text(zh: "默认文件名", en: "Default file name"), text: $defaultFileName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onChange(of: defaultFileName) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            FileCreator.defaultFileName = trimmed
                        }
                    }
                HStack(spacing: 8) {
                    ForEach(FileCreator.availableFileTypes, id: \.self) { type in
                        Button(type.shortName) {
                            FileCreator().create(type) { result in
                                switch result {
                                case .success(let url):
                                    fileStatusMessage = QuickPodText.text(zh: "\(url.lastPathComponent) 已创建到桌面", en: "\(url.lastPathComponent) was created on the Desktop")
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
                HStack(spacing: 10) {
                    TextField(QuickPodText.text(zh: "自定义后缀", en: "Custom extension"), text: $customFileExtension)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onChange(of: customFileExtension) { _, newValue in
                            let sanitized = FileCreator.sanitizeExtension(newValue)
                            customFileExtension = sanitized
                            FileCreator.customFileExtension = sanitized
                        }

                    Button(QuickPodText.text(zh: "创建自定义文件", en: "Create custom file")) {
                        FileCreator.customFileExtension = FileCreator.sanitizeExtension(customFileExtension)
                        customFileExtension = FileCreator.customFileExtension
                        FileCreator().create(.custom) { result in
                            switch result {
                            case .success(let url):
                                fileStatusMessage = QuickPodText.text(zh: "\(url.lastPathComponent) 已创建到桌面", en: "\(url.lastPathComponent) was created on the Desktop")
                            case .failure(let error):
                                fileStatusMessage = error.localizedDescription
                            }
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(LiquidPillButtonStyle(isSelected: false))
                    .disabled(FileCreator.sanitizeExtension(customFileExtension).isEmpty)
                }
                Text(
                    QuickPodText.text(
                        zh: "输入后缀名即可，例如 `log`、`json`、`todo`。Quick Switcher 里也会同步显示。",
                        en: "Enter an extension like `log`, `json`, or `todo`. Quick Switcher will mirror it too."
                    )
                )
                .font(.system(size: 11))
                .foregroundColor(.secondary)
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
        settingsSection(QuickPodText.text(zh: "休息提醒", en: "Break reminders"), subtitle: QuickPodText.text(zh: "选择提醒间隔，开启后会按周期发送系统通知", en: "Choose an interval and QuickPod will remind you on schedule")) {
            MiniToggleRow(
                title: QuickPodText.text(zh: "启用休息提醒", en: "Enable break reminders"),
                subtitle: breakReminder.isActive
                    ? QuickPodText.text(zh: "每 \(breakReminder.intervalMinutes) 分钟提醒", en: "Remind me every \(breakReminder.intervalMinutes) minutes")
                    : QuickPodText.text(zh: "关闭", en: "Off"),
                isOn: breakReminder.isActive,
                action: { breakReminder.toggle() }
            )
            thinDivider
            VStack(alignment: .leading, spacing: 8) {
                Text(QuickPodText.text(zh: "提醒间隔", en: "Reminder interval"))
                    .font(.system(size: 12, weight: .medium))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(BreakReminder.intervalOptions, id: \.self) { minutes in
                        Button(QuickPodText.text(zh: "\(minutes) 分钟", en: "\(minutes) min")) {
                            breakReminder.intervalMinutes = minutes
                            customReminderMinutes = "\(minutes)"
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
            HStack(spacing: 10) {
                TextField(QuickPodText.text(zh: "自定义分钟数", en: "Custom minutes"), text: $customReminderMinutes)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                Button(QuickPodText.text(zh: "应用", en: "Apply")) {
                    applyCustomReminderInterval()
                }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(LiquidPillButtonStyle(isSelected: false))

                Button(QuickPodText.text(zh: "1 分钟测试", en: "1 min test")) {
                    customReminderMinutes = "1"
                    applyCustomReminderInterval()
                }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(LiquidPillButtonStyle(isSelected: breakReminder.intervalMinutes == 1))
            }
            .padding(12)
            if let reminderStatusMessage {
                Text(reminderStatusMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
            thinDivider
            MiniButtonRow(title: QuickPodText.text(zh: "发送测试通知", en: "Send test notification"), subtitle: QuickPodText.text(zh: "立即发送一条通知，确认通知系统正常", en: "Send one now to verify the notification pipeline")) {
                sendTestNotification()
            }
        }
    }

    private func sendTestNotification() {
        reminderStatusMessage = QuickPodText.text(zh: "正在发送测试通知并弹出预览卡片...", en: "Sending a test notification and showing the preview card...")
        breakReminder.sendTestNotification { outcome in
            DispatchQueue.main.async {
                self.reminderStatusMessage = outcome.message
                self.permissionManager.checkNotificationPermission()
            }
        }
    }

    private func applyCustomReminderInterval() {
        let trimmed = customReminderMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Int(trimmed), minutes > 0, minutes <= 720 else {
            reminderStatusMessage = QuickPodText.text(
                zh: "请输入 1 到 720 之间的分钟数。",
                en: "Enter a value between 1 and 720 minutes."
            )
            return
        }

        breakReminder.intervalMinutes = minutes
        reminderStatusMessage = QuickPodText.text(
            zh: "提醒间隔已改成 \(minutes) 分钟。",
            en: "The reminder interval is now \(minutes) minutes."
        )
        if breakReminder.isActive {
            breakReminder.restart()
            reminderStatusMessage = QuickPodText.text(
                zh: "提醒已重新开始，将在 \(minutes) 分钟后弹出。",
                en: "The reminder restarted and will appear again in \(minutes) minutes."
            )
        }
    }

    @State private var flashedKey: String?

    private var shortcutSection: some View {
        settingsSection(QuickPodText.text(zh: "快捷键", en: "Shortcut"), subtitle: QuickPodText.text(zh: "录制用于呼出快捷菜单的快捷键，按住显示，松手关闭", en: "Record the hotkey used to show the quick switcher")) {
            VStack(spacing: 0) {
                HStack {
                    Text(QuickPodText.text(zh: "打开快捷菜单", en: "Open quick switcher"))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button(action: {
                        isRecordingShortcut = true
                        installShortcutRecorder()
                    }) {
                        HStack(spacing: 6) {
                            if isRecordingShortcut {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 6, height: 6)
                                    .opacity(0.6)
                            }
                            Text(isRecordingShortcut ? QuickPodText.text(zh: "按下新快捷键...", en: "Press new shortcut...") : GlobalHotkey.displayString)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(isRecordingShortcut ? .orange : .primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isRecordingShortcut
                                    ? Color.orange.opacity(0.15)
                                    : Color.primary.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecordingShortcut ? Color.orange.opacity(0.5) : .clear, lineWidth: 1)
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
        var keyMonitor: Any?
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let combo = extractHotKeyFromEvent(event) else { return event }

            GlobalHotkey.keyCode = combo.keyCode
            GlobalHotkey.modifiers = combo.modifiers
            self.isRecordingShortcut = false
            if let m = monitor { NSEvent.removeMonitor(m) }
            if let m = keyMonitor { NSEvent.removeMonitor(m) }
            (NSApp.delegate as? AppDelegate)?.reconfigureHotkey()
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
            return nil
        }
        // Show modifier changes in real-time
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let parts: [String] = [
                (mods.contains(.command) ? "⌘" : ""),
                (mods.contains(.option) ? "⌥" : ""),
                (mods.contains(.control) ? "⌃" : ""),
                (mods.contains(.shift) ? "⇧" : "")
            ].filter { !$0.isEmpty }
            self.flashedKey = parts.isEmpty ? nil : parts.joined()
            return event
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            guard self.isRecordingShortcut else { return }
            self.isRecordingShortcut = false
            self.flashedKey = nil
            if let m = monitor { NSEvent.removeMonitor(m) }
            if let m = keyMonitor { NSEvent.removeMonitor(m) }
        }
    }

    private var permissionSection: some View {
        settingsSection(QuickPodText.text(zh: "权限管理", en: "Permissions"), subtitle: QuickPodText.text(zh: "确保以下权限已正确配置", en: "Review the permissions relevant to this build")) {
            VStack(spacing: 0) {
                PermissionRow(
                    title: QuickPodText.text(zh: "通知权限", en: "Notifications"),
                    description: permissionManager.notificationDebugSummary.isEmpty
                        ? QuickPodText.text(zh: "用于休息提醒通知", en: "Used for break reminders and status notifications")
                        : permissionManager.notificationDebugSummary,
                    status: permissionManager.notificationPermission,
                    action: { permissionManager.openNotificationSettings() }
                )
                thinDivider
                PermissionRow(
                    title: QuickPodText.text(zh: "辅助功能（可选）", en: "Accessibility (optional)"),
                    description: QuickPodText.text(zh: "当前全局快捷键不依赖此权限；仅对某些可选键盘监听场景有帮助", en: "The current global hotkey does not require this permission. It only helps with some optional keyboard-monitoring scenarios."),
                    status: permissionManager.accessibilityPermission,
                    action: { permissionManager.openAccessibilitySettings() }
                )
                thinDivider
                PermissionRow(
                    title: QuickPodText.text(zh: "开机启动", en: "Launch at login"),
                    description: QuickPodText.text(zh: "登录时自动启动", en: "Start automatically after login"),
                    status: permissionManager.loginItemPermission,
                    action: { permissionManager.openLoginItemsSettings() }
                )
            }
        }
    }

    private var appSettingsSection: some View {
        settingsSection(QuickPodText.text(zh: "应用设置", en: "App settings"), subtitle: nil) {
            MiniToggleRow(
                title: QuickPodText.text(zh: "开机启动", en: "Launch at login"),
                subtitle: loginItem.isEnabled ? QuickPodText.text(zh: "已开启", en: "Enabled") : QuickPodText.text(zh: "关闭", en: "Off"),
                isOn: loginItem.isEnabled,
                action: { loginItem.toggle() }
            )
            thinDivider
            PickerRow(
                title: QuickPodText.text(zh: "语言", en: "Language"),
                selection: Binding(
                    get: { AppLanguage(rawValue: appLanguageRawValue) ?? .system },
                    set: { newValue in
                        appLanguageRawValue = newValue.rawValue
                        permissionManager.checkAllPermissions()
                    }
                ),
                options: [
                    QuickPodText.text(zh: "跟随系统", en: "System"),
                    "中文",
                    "English"
                ]
            )
            thinDivider
            InfoRow(
                title: QuickPodText.text(zh: "外观", en: "Appearance"),
                detail: QuickPodText.text(zh: "固定浅色模式", en: "Light mode only")
            )
            thinDivider
            InfoRow(
                title: QuickPodText.text(zh: "更新状态", en: "Update status"),
                detail: updateStatusSummary
            )
            thinDivider
            MiniButtonRow(title: QuickPodText.text(zh: "检查更新", en: "Check for updates"), subtitle: QuickPodText.text(zh: "检查 QuickPod 是否有新版本", en: "Check whether a newer QuickPod build is available")) {
                UpdateChecker.shared.checkForUpdates(showAlert: true)
            }
            thinDivider
            MiniButtonRow(title: QuickPodText.text(zh: "退出 QuickPod", en: "Quit QuickPod"), subtitle: QuickPodText.text(zh: "关闭菜单栏常驻进程", en: "Close the persistent menu bar process")) {
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

    private var updateStatusSummary: String {
        if updateChecker.isChecking {
            return QuickPodText.text(zh: "检查中…", en: "Checking…")
        }

        guard let lastCheckedAt = updateChecker.lastCheckedAt else {
            return QuickPodText.text(zh: "尚未检查", en: "Not checked yet")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: lastCheckedAt)
        let source = updateChecker.lastCheckSource?.displayName ?? QuickPodText.text(zh: "未知来源", en: "Unknown source")
        return QuickPodText.text(zh: "\(time) · \(source)", en: "\(time) · \(source)")
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

struct PickerRow<Value: Hashable>: View {
    let title: String
    let selection: Binding<Value>
    let options: [String]

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option).tag(tag(for: index))
                }
            }
            .labelsHidden()
            .frame(width: 172)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func tag(for index: Int) -> Value {
        switch Value.self {
        case is AppTheme.Type:
            return AppTheme.allCases[index] as! Value
        case is AppLanguage.Type:
            return AppLanguage.allCases[index] as! Value
        default:
            fatalError("Unsupported picker value type")
        }
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
    static let shared = ScreenCleanerState()
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
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.hideMainWindow()
        }
        cleaner.activateWithCountdown()
    }

    func deactivate() {
        cleaner.deactivate()
    }
}
