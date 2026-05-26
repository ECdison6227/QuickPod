import AppKit
import SwiftUI
import UserNotifications

// MARK: - 圆形滑轮菜单项

struct RadialMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
}

// MARK: - 圆形滑轮菜单控制器

class RadialMenuController: ObservableObject {
    static let shared = RadialMenuController()

    @Published var isActive = false

    private var menuWindow: NSWindow?
    private var dismissGlobalMonitor: Any?
    private var dismissLocalMonitor: Any?
    private let screenCleanerState = ScreenCleanerState()

    private init() {}

    func showQuickMenu() {
        triggerRadialMenu()
    }

    func show(with items: [RadialMenuItem]) {
        guard !isActive else { return }
        isActive = true

        let wheelView = RadialWheelView(
            items: items,
            onSelect: { [weak self] index in
                guard let self = self, index >= 0, index < items.count else { return }
                self.hide()
                items[index].action()
            }
        )

        let hostingController = NSHostingController(rootView: wheelView)

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let size: CGFloat = 360
        let windowRect = NSRect(
            x: (screenFrame.width - size) / 2,
            y: (screenFrame.height - size) / 2,
            width: size,
            height: size
        )

        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.makeKeyAndOrderFront(nil)

        menuWindow = window

        // 监听按键释放来关闭
        dismissLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyUp]) { [weak self] event in
            self?.handleFlags(event)
            return nil
        }

        dismissGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlags(event)
        }
    }

    func hide() {
        isActive = false
        if let m = dismissGlobalMonitor {
            NSEvent.removeMonitor(m)
            dismissGlobalMonitor = nil
        }
        if let m = dismissLocalMonitor {
            NSEvent.removeMonitor(m)
            dismissLocalMonitor = nil
        }
        menuWindow?.orderOut(nil)
        menuWindow = nil
    }

    private func handleFlags(_ event: NSEvent) {
        hide()
    }

    // MARK: - Key listener

    func startListening() {
        // Fn 作为独立修饰键在 macOS 上不稳定，这里保留接口但不再注册备用触发监听。
    }

    func stopListening() {
        hide()
    }

    private func triggerRadialMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let menuItems = self.buildMenuItems()
            self.show(with: menuItems)
        }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment, performanceTime: .default
        )
    }

    private func buildMenuItems() -> [RadialMenuItem] {
        return [
            RadialMenuItem(title: "防睡眠", icon: "bolt.fill", color: .green) {
                (NSApp.delegate as? AppDelegate)?.antiSleep.toggle()
            },
            RadialMenuItem(title: "设置", icon: "gearshape.fill", color: .indigo) {
                NSApp.activate(ignoringOtherApps: true)
                (NSApp.delegate as? AppDelegate)?.showMainWindowAgain()
            },
            RadialMenuItem(title: "休息", icon: "timer", color: .orange) {
                (NSApp.delegate as? AppDelegate)?.breakReminder.toggle()
            },
            RadialMenuItem(title: "清洁", icon: "sparkles", color: .blue) {
                self.screenCleanerState.activate()
            },
            RadialMenuItem(title: "新建 TXT", icon: "doc.text", color: .purple) {
                FileCreator().create(.txt) { self.handleFileResult($0) }
            },
            RadialMenuItem(title: "新建 MD", icon: "doc.richtext", color: .cyan) {
                FileCreator().create(.md) { self.handleFileResult($0) }
            },
        ]
    }

    private func handleFileResult(_ result: FileCreator.CreationResult) {
        switch result {
        case .success(let url):
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            sendNotification(title: "文件已创建", body: "\(url.lastPathComponent) → 桌面")
        case .failure(let error):
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            sendNotification(title: "创建失败", body: error.localizedDescription)
        }
    }

    private func sendNotification(title: String, body: String) {
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
}

// MARK: - Radial Wheel SwiftUI View

struct RadialWheelView: View {
    let items: [RadialMenuItem]
    let onSelect: (Int) -> Void

    @State private var appear = false
    @State private var hoverIndex: Int = -1

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 半透明遮罩
                Color.black.opacity(appear ? 0.45 : 0)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.2), value: appear)

                // 中心 QuickPod 标识
                Circle()
                    .fill(Material.ultraThickMaterial)
                    .frame(width: 54, height: 54)
                    .overlay(
                        Text("QP")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    )
                    .scaleEffect(appear ? 1 : 0.4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: appear)

                // 环形菜单项
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let angle = angleForIndex(index, total: items.count)
                    let radius = min(geometry.size.width, geometry.size.height) * 0.35
                    let dx = cos(angle) * radius
                    let dy = sin(angle) * radius

                    Button(action: { onSelect(index) }) {
                        RadialItemView(
                            item: item,
                            isHighlighted: hoverIndex == index
                        )
                    }
                    .buttonStyle(.plain)
                    .offset(x: appear ? dx : 0, y: appear ? dy : 0)
                    .scaleEffect(appear ? 1 : 0.2)
                    .opacity(appear ? 1 : 0)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(index) * 0.03),
                        value: appear
                    )
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.15)) {
                            hoverIndex = hovering ? index : -1
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                appear = true
            }
        }
    }

    private func angleForIndex(_ index: Int, total: Int) -> Double {
        let startAngle = -Double.pi / 2
        let step = 2 * Double.pi / Double(total)
        return startAngle + Double(index) * step
    }
}

// MARK: - Individual Item View

struct RadialItemView: View {
    let item: RadialMenuItem
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isHighlighted ? item.color : Color.white.opacity(0.2))
                    .frame(width: isHighlighted ? 56 : 48, height: isHighlighted ? 56 : 48)
                    .shadow(color: item.color.opacity(isHighlighted ? 0.5 : 0.1), radius: isHighlighted ? 12 : 4)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: isHighlighted ? 56 : 48, height: isHighlighted ? 56 : 48)
                    )

                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isHighlighted ? .white : item.color)
            }

            Text(item.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHighlighted ? .white : .white.opacity(0.6))
                .shadow(color: .black.opacity(0.5), radius: 2)
        }
    }
}
