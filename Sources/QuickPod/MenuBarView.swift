import SwiftUI

struct MenuBarView: View {
    @ObservedObject var antiSleep: AntiSleepManager
    @ObservedObject var breakReminder: BreakReminder
    let openSettings: () -> Void

    @StateObject private var loginItem = LoginItemManager()
    @StateObject private var screenCleanerState = ScreenCleanerState()

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            sectionView
            Divider()
            footerView
        }
        .frame(width: 300)
        .padding(.vertical, 8)
        .background(LiquidGlassBackground())
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(nsImage: appIconImage())
                .resizable()
                .frame(width: 24, height: 24)
            Text("QuickPod")
                .font(.headline)
            Spacer()
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
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

    // MARK: - Section

    private var sectionView: some View {
        VStack(spacing: 2) {
            // 防睡眠
            ToggleRow(
                icon: antiSleep.isActive ? "bolt.fill" : "bolt.slash.fill",
                iconColor: antiSleep.isActive ? .green : .secondary,
                title: "防睡眠",
                subtitle: antiSleep.isActive ? "已开启，Mac 不会休眠" : "关闭",
                isOn: antiSleep.isActive
            ) {
                antiSleep.toggle()
            }

            // 屏幕清洁
            ButtonRow(
                icon: "sparkles",
                iconColor: .blue,
                title: "屏幕清洁",
                subtitle: "点击进入清洁模式"
            ) {
                screenCleanerState.activate()
            }

            // 新建文件
            fileCreationMenu

            // 休息提醒
            VStack(spacing: 0) {
                ToggleRow(
                    icon: "timer",
                    iconColor: breakReminder.isActive ? .orange : .secondary,
                    title: "休息提醒",
                    subtitle: breakReminder.isActive
                        ? "每 \(breakReminder.intervalMinutes) 分钟提醒"
                        : "关闭",
                    isOn: breakReminder.isActive
                ) {
                    breakReminder.toggle()
                }

                if breakReminder.isActive {
                    HStack {
                        Text("间隔")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $breakReminder.intervalMinutes) {
                            ForEach(BreakReminder.intervalOptions, id: \.self) { minutes in
                                Text("\(minutes) 分钟").tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: breakReminder.intervalMinutes) { _, _ in
                            breakReminder.restart()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - File Creation

    private var fileCreationMenu: some View {
        Menu {
            ForEach(FileCreator.FileType.allCases, id: \.self) { type in
                Button(type.displayName) {
                    FileCreator().create(type)
                }
            }
        } label: {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundColor(.purple)
                Text("新建文件")
                    .font(.system(size: 13))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 2) {
            // 开机启动
            ToggleRow(
                icon: "power",
                iconColor: loginItem.isEnabled ? .green : .secondary,
                title: "开机启动",
                subtitle: loginItem.isEnabled ? "已开启" : "关闭",
                isOn: loginItem.isEnabled
            ) {
                loginItem.toggle()
            }

            ButtonRow(
                icon: "gearshape",
                iconColor: .secondary,
                title: "打开设置",
                subtitle: "完整设置窗口"
            ) {
                openSettings()
            }

            // 退出
            ButtonRow(
                icon: "xmark.circle",
                iconColor: .secondary,
                title: "退出 QuickPod",
                subtitle: ""
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Reusable Rows

struct ToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundColor(iconColor)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 13))
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Circle()
                    .fill(isOn ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidRowButtonStyle())
    }
}

struct ButtonRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundColor(iconColor)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 13))
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidRowButtonStyle())
    }
}
