import AppKit
import SwiftUI
import UserNotifications
import Carbon

// MARK: - Quick Switcher Model

final class QuickSwitcherModel: ObservableObject {
    @Published var selectedIndex = 0
    @Published var isVisible = false
    @Published var currentScreen: QuickSwitcherScreen = .root
}

enum QuickSwitcherScreen: Equatable {
    case root
    case breakPicker
    case filePicker

    var title: String {
        switch self {
        case .root: return "QuickPod"
        case .breakPicker: return "休息提醒"
        case .filePicker: return "新建文件"
        }
    }
}

struct QuickSwitcherItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    let kind: Kind
    let action: (() -> Void)?

    enum Kind: Equatable {
        case action
        case submenu(QuickSwitcherScreen)
    }
}

// MARK: - Quick Switcher Controller

final class QuickSwitcherController: ObservableObject {
    static let shared = QuickSwitcherController()

    @Published var isActive = false
    private let model = QuickSwitcherModel()
    private let fileCreator = FileCreator()

    private var switcherWindow: NSWindow?
    private var keyMonitor: Any?
    private var isHotkeyHeld = false

    private let screenCleanerState = ScreenCleanerState.shared

    private init() {}

    func hotkeyPressed() {
        if !isActive {
            isHotkeyHeld = true
            show()
        } else {
            // Cycle to next item
            model.selectedIndex = (model.selectedIndex + 1) % itemsCount()
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }

    func hotkeyReleased() {
        guard isActive else { return }
        isHotkeyHeld = false
        
        // Execute selected item
        executeSelectedItem()
        
        hide()
    }

    private func itemsCount() -> Int {
        items(for: model.currentScreen).count
    }

    func show() {
        guard !isActive else { return }
        guard let screen = targetScreen() else {
            print("[QuickPod] Unable to determine target screen for quick switcher")
            return
        }

        model.currentScreen = .root
        model.selectedIndex = 0
        model.isVisible = true

        let switcherView = QuickSwitcherView(
            model: model,
            itemsProvider: { [weak self] screen in
                self?.items(for: screen) ?? []
            },
            onSelect: { [weak self] in
                self?.executeSelectedItem()
            }
        )

        let hostingView = NSHostingView(rootView: switcherView)
        let size = NSSize(width: 420, height: 360)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.autoresizingMask = [.width, .height]

        let screenFrame = screen.frame
        let windowRect = NSRect(
            x: (screenFrame.width - size.width) / 2,
            y: screenFrame.maxY - size.height - 120,
            width: size.width,
            height: size.height
        )

        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.setContentSize(size)
        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.setFrame(windowRect, display: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        switcherWindow = window
        isActive = true
        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        print("[QuickPod] Quick switcher shown on screen: \(screen.localizedName)")
    }

    func hide() {
        guard isActive else { return }
        isActive = false
        isHotkeyHeld = false
        model.isVisible = false
        model.currentScreen = .root
        model.selectedIndex = 0
        
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        switcherWindow?.orderOut(nil)
        switcherWindow = nil
        print("[QuickPod] Quick switcher hidden")
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            
            switch event.keyCode {
            case UInt16(kVK_Escape):
                if self.model.currentScreen == .root {
                    self.hide()
                } else {
                    self.model.currentScreen = .root
                    self.model.selectedIndex = 0
                }
                return nil
            case UInt16(kVK_UpArrow):
                // Navigate up
                let count = self.itemsCount()
                if count > 0 {
                    self.model.selectedIndex = (self.model.selectedIndex - 1 + count) % count
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
                return nil
            case UInt16(kVK_DownArrow):
                // Navigate down
                let count = self.itemsCount()
                if count > 0 {
                    self.model.selectedIndex = (self.model.selectedIndex + 1) % count
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
                return nil
            case UInt16(kVK_Return), UInt16(kVK_Space):
                // Execute selected item
                self.executeSelectedItem()
                return nil
            default:
                return event
            }
        }
    }

    private func executeSelectedItem() {
        let items = items(for: model.currentScreen)
        guard model.selectedIndex < items.count else { return }
        
        let item = items[model.selectedIndex]
        
        switch item.kind {
        case .submenu(let screen):
            model.currentScreen = screen
            model.selectedIndex = 0
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        case .action:
            hide()
            item.action?()
        }
    }

    // MARK: - Items

    private func items(for screen: QuickSwitcherScreen) -> [QuickSwitcherItem] {
        switch screen {
        case .root:
            return rootItems()
        case .breakPicker:
            return breakItems()
        case .filePicker:
            return fileItems()
        }
    }

    private func rootItems() -> [QuickSwitcherItem] {
        [
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "防睡眠", en: "Anti-sleep"),
                subtitle: (NSApp.delegate as? AppDelegate)?.antiSleep.isActive == true
                    ? QuickPodText.text(zh: "已开启", en: "Enabled")
                    : QuickPodText.text(zh: "防止休眠", en: "Keep Mac awake"),
                icon: "moon.zzz.fill",
                kind: .action
            ) {
                (NSApp.delegate as? AppDelegate)?.antiSleep.toggle()
            },
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "屏幕清洁", en: "Screen cleaner"),
                subtitle: screenCleanerState.isActive ? QuickPodText.text(zh: "退出", en: "Exit") : QuickPodText.text(zh: "全屏清洁", en: "Full-screen cleaner"),
                icon: "sparkles",
                kind: .action
            ) { [weak self] in
                self?.activateScreenCleaner()
            },
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "休息提醒", en: "Break reminders"),
                subtitle: nil,
                icon: "timer",
                kind: .submenu(.breakPicker),
                action: nil
            ),
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "新建文件", en: "Create file"),
                subtitle: nil,
                icon: "doc.badge.plus",
                kind: .submenu(.filePicker),
                action: nil
            ),
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "设置", en: "Settings"),
                subtitle: nil,
                icon: "gearshape",
                kind: .action
            ) {
                NSApp.activate(ignoringOtherApps: true)
                (NSApp.delegate as? AppDelegate)?.showMainWindowAgain()
            },
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "退出", en: "Quit"),
                subtitle: nil,
                icon: "power",
                kind: .action
            ) {
                NSApplication.shared.terminate(nil)
            }
        ]
    }

    private func breakItems() -> [QuickSwitcherItem] {
        let intervals: [(String, Int)] = [
            (QuickPodText.text(zh: "1 分钟测试", en: "1 min test"), 1),
            (QuickPodText.text(zh: "15 分钟", en: "15 min"), 15),
            (QuickPodText.text(zh: "30 分钟", en: "30 min"), 30),
            (QuickPodText.text(zh: "45 分钟", en: "45 min"), 45),
            (QuickPodText.text(zh: "60 分钟", en: "60 min"), 60)
        ]
        return intervals.map { label, minutes in
            QuickSwitcherItem(
                title: label,
                subtitle: nil,
                icon: "clock.badge.checkmark",
                kind: .action
            ) { [weak self] in
                self?.startBreakReminder(minutes: minutes)
            }
        } + [
            QuickSwitcherItem(
                title: QuickPodText.text(zh: "停止提醒", en: "Stop reminders"),
                subtitle: nil,
                icon: "bell.slash.fill",
                kind: .action
            ) {
                (NSApp.delegate as? AppDelegate)?.breakReminder.stop()
            }
        ]
    }

    private func fileItems() -> [QuickSwitcherItem] {
        FileCreator.availableFileTypes.map { type in
            QuickSwitcherItem(
                title: type.shortName,
                subtitle: type == .custom ? type.displayName : nil,
                icon: iconForFileType(type),
                kind: .action
            ) { [weak self] in
                self?.promptForFileCreation(type: type)
            }
        }
    }

    private func iconForFileType(_ type: FileCreator.FileType) -> String {
        switch type {
        case .txt: return "doc.text"
        case .md: return "text.document"
        case .docx: return "doc.richtext"
        case .xlsx: return "tablecells"
        case .pptx: return "rectangle.on.rectangle"
        case .custom: return "doc.badge.gearshape"
        }
    }

    // MARK: - Actions

    private func activateScreenCleaner() {
        if screenCleanerState.isActive {
            screenCleanerState.deactivate()
            sendTransientNotification(
                title: QuickPodText.text(zh: "屏幕清洁已退出", en: "Screen cleaner closed"),
                body: QuickPodText.text(zh: "按任意键或点击即可退出", en: "Press any key or click to exit")
            )
        } else {
            screenCleanerState.onDeactivateExtra = nil
            sendTransientNotification(
                title: QuickPodText.text(zh: "屏幕清洁已开启", en: "Screen cleaner enabled"),
                body: QuickPodText.text(zh: "按任意键或点击即可退出", en: "Press any key or click to exit")
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.screenCleanerState.activate()
            }
        }
    }

    private func startBreakReminder(minutes: Int) {
        guard let reminder = (NSApp.delegate as? AppDelegate)?.breakReminder else { return }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    reminder.start(withInterval: minutes)
                }
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        if granted {
                            reminder.start(withInterval: minutes)
                        } else {
                            self.showNotificationPermissionAlert()
                        }
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    self.showNotificationPermissionAlert()
                }
            @unknown default:
                break
            }
        }
    }

    private func showNotificationPermissionAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = QuickPodText.text(zh: "需要通知权限", en: "Notification permission needed")
        alert.informativeText = QuickPodText.text(
            zh: "QuickPod 需要通知权限来发送休息提醒。请在\"系统设置 > 通知\"中允许 QuickPod。",
            en: "QuickPod needs notification permission for break reminders. Please allow it in System Settings > Notifications."
        )
        alert.addButton(withTitle: QuickPodText.text(zh: "打开系统设置", en: "Open settings"))
        alert.addButton(withTitle: QuickPodText.text(zh: "稍后", en: "Later"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
        }
    }

    private func promptForFileCreation(type: FileCreator.FileType) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = QuickPodText.text(zh: "新建 \(type.shortName)", en: "Create \(type.shortName)")
        alert.informativeText = QuickPodText.text(zh: "输入文件名后将直接创建到桌面。", en: "Enter a file name. The file will be created directly on the Desktop.")
        alert.addButton(withTitle: QuickPodText.text(zh: "创建", en: "Create"))
        alert.addButton(withTitle: QuickPodText.text(zh: "取消", en: "Cancel"))

        let textField = SelectableTextField(string: FileCreator.defaultFileName)
        textField.placeholderString = QuickPodText.text(zh: "文件名", en: "File name")
        textField.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        textField.isSelectable = true
        alert.accessoryView = textField

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        fileCreator.create(type, customBaseName: textField.stringValue) { [weak self] result in
            self?.handleFileResult(result)
        }
    }

    private func handleFileResult(_ result: FileCreator.CreationResult) {
        switch result {
        case .success(let url):
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            sendTransientNotification(
                title: QuickPodText.text(zh: "文件已创建", en: "File created"),
                body: QuickPodText.text(zh: "\(url.lastPathComponent) 已保存到桌面", en: "\(url.lastPathComponent) was saved to the Desktop")
            )
        case .failure(let error):
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            sendTransientNotification(title: QuickPodText.text(zh: "创建失败", en: "Creation failed"), body: error.localizedDescription)
        }
    }

    private func sendTransientNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let containingScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return containingScreen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }


}

// MARK: - Helper TextField

private class SelectableTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let cmdA = event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a"
        if cmdA {
            selectText(nil)
            return true
        }
        if event.modifierFlags.contains(.command) {
            let char = event.charactersIgnoringModifiers
            if char == "c" {
                if let editor = currentEditor() {
                    editor.copy(nil)
                    return true
                }
            } else if char == "v" {
                if let editor = currentEditor() {
                    editor.paste(nil)
                    return true
                }
            } else if char == "x" {
                if let editor = currentEditor() {
                    editor.cut(nil)
                    return true
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Quick Switcher View

struct QuickSwitcherView: View {
    @ObservedObject var model: QuickSwitcherModel
    let itemsProvider: (QuickSwitcherScreen) -> [QuickSwitcherItem]
    let onSelect: () -> Void

    @State private var appear = false

    private let palette = QuickSwitcherPalette()

    var body: some View {
        let items = itemsProvider(model.currentScreen)

        VStack(spacing: 0) {
            // Header
            headerView()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(palette.headerBg)

            // List
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            QuickSwitcherItemView(
                                item: item,
                                isSelected: model.selectedIndex == index
                            )
                            .id(index)
                            .onTapGesture {
                                model.selectedIndex = index
                                onSelect()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onAppear {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        appear = true
                    }
                }
                .onChange(of: model.selectedIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
                .onChange(of: model.currentScreen) { _, _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        appear = true
                    }
                }
            }
            .background(palette.listBg)
        }
        .frame(width: 420, height: 360)
        .background(palette.background)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    @ViewBuilder
    private func headerView() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.currentScreen.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(palette.primaryText)

            Text("方向键切换选项，Enter 确认选择")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Quick Switcher Item View

struct QuickSwitcherItemView: View {
    let item: QuickSwitcherItem
    let isSelected: Bool

    private let palette = QuickSwitcherPalette()

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isSelected ? palette.iconBgSelected : palette.iconBg)
                    .frame(width: 36, height: 36)

                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? palette.iconSelected : palette.iconNormal)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? palette.primaryText : palette.secondaryText)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(palette.tertiaryText)
                }
            }

            Spacer()

            // Checkmark or arrow
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(palette.accent)
            } else if case .submenu = item.kind {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(palette.tertiaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? palette.selectedBg : palette.itemBg)
        )
        .padding(.horizontal, 12)
    }
}

// MARK: - Color Palette

private struct QuickSwitcherPalette {
    let background = Color(NSColor.windowBackgroundColor)
    let headerBg = Color(NSColor.controlBackgroundColor).opacity(0.5)
    let listBg = Color.clear
    let itemBg = Color.clear
    let selectedBg = Color.white.opacity(0.12)
    
    let primaryText = Color(NSColor.labelColor)
    let secondaryText = Color(NSColor.secondaryLabelColor)
    let tertiaryText = Color(NSColor.tertiaryLabelColor)
    
    let iconBg = Color.white.opacity(0.06)
    let iconBgSelected = Color.white.opacity(0.15)
    let iconNormal = Color(NSColor.secondaryLabelColor)
    let iconSelected = Color(NSColor.labelColor)
    
    let accent = Color.blue
}
