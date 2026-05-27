import AppKit
import SwiftUI
import UserNotifications

class BreakReminder: NSObject, ObservableObject {
    private enum Keys {
        static let interval = "QuickPod.breakIntervalMinutes"
        static let isActive = "QuickPod.breakReminderActive"
        static let reminderStyle = "QuickPod.reminderStyle"
    }

    private let notificationIdentifier = "QuickPod.breakReminder.notification"
    private let activationNotificationIdentifier = "QuickPod.breakReminder.activated"
    private let center = UNUserNotificationCenter.current()
    private var isApplyingStateChange = false

    struct TestNotificationOutcome {
        let succeeded: Bool
        let message: String
    }
    
    enum ReminderStyle: Int, CaseIterable {
        case systemNotification = 0
        case alertWindow = 1
        case both = 2
    }

    @Published var isActive = UserDefaults.standard.bool(forKey: Keys.isActive) {
        didSet {
            UserDefaults.standard.set(isActive, forKey: Keys.isActive)
            guard !isApplyingStateChange else { return }
            print("[QuickPod] isActive changed to: \(isActive)")
            if isActive {
                startReminder()
            } else {
                deactivateReminder(clearPublishedState: false)
            }
        }
    }
    
    @Published var intervalMinutes: Int = UserDefaults.standard.integer(forKey: "QuickPod.breakIntervalMinutes") == 0
        ? 45
        : UserDefaults.standard.integer(forKey: "QuickPod.breakIntervalMinutes") {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: Keys.interval)
            if isActive {
                restart()
            }
        }
    }
    
    @Published var reminderStyle: ReminderStyle {
        didSet {
            UserDefaults.standard.set(reminderStyle.rawValue, forKey: Keys.reminderStyle)
            if isActive {
                restart()
            }
        }
    }
    
    // 倒计时相关
    @Published var remainingSeconds: Int = 0
    @Published var progress: Double = 1.0 // 1.0 = 100%
    
    static let intervalOptions = [15, 20, 25, 30, 45, 60, 90, 120]
    static let quickIntervals = [15, 30, 45, 60]
    
    private var reminderTimer: Timer?
    private var countdownTimer: Timer?
    private var reminderPanel: NSPanel?
    
    override init() {
        let rawValue = UserDefaults.standard.integer(forKey: Keys.reminderStyle)
        reminderStyle = ReminderStyle(rawValue: rawValue) ?? .both
        super.init()
        center.delegate = self
        print("[QuickPod] BreakReminder initialized, isActive: \(isActive), interval: \(intervalMinutes)")
    }

    func toggle() {
        print("[QuickPod] toggle() called, current isActive: \(isActive)")
        isActive.toggle()
    }

    func restart() {
        guard isActive else { 
            print("[QuickPod] restart() skipped - not active")
            return 
        }
        print("[QuickPod] restart() called")
        stopTimers()
        startReminder()
    }

    func start(withInterval interval: Int) {
        intervalMinutes = interval
        isActive = true
    }

    func prepareOnLaunch() {
        guard isActive else { 
            print("[QuickPod] prepareOnLaunch() skipped - not active")
            return 
        }
        print("[QuickPod] prepareOnLaunch() called")
        startReminder()
    }

    func sendTestNotification() {
        sendTestNotification(completion: nil)
    }

    func sendTestNotification(completion: ((TestNotificationOutcome) -> Void)?) {
        print("[QuickPod] sendTestNotification() called")

        evaluateAuthorizationStatus { [weak self] status in
            guard let self else { return }

            switch status {
            case .authorized, .provisional, .ephemeral:
                self.reallySendTestNotification(completion: completion)
            case .notDetermined:
                self.requestPermission { granted in
                    if granted {
                        self.reallySendTestNotification(completion: completion)
                    } else {
                        completion?(TestNotificationOutcome(
                            succeeded: false,
                            message: QuickPodText.text(
                                zh: "通知权限还没真正启用，QuickPod 先给你弹应用内测试卡片。",
                                en: "Notification permission is not active yet. QuickPod showed an in-app test card instead."
                            )
                        ))
                        self.showTestReminderPreview()
                    }
                }
            case .denied:
                print("[QuickPod] 通知权限被拒绝")
                completion?(TestNotificationOutcome(
                    succeeded: false,
                    message: QuickPodText.text(
                        zh: "系统通知已被关闭，QuickPod 已改用右上角测试卡片提醒。",
                        en: "System notifications are disabled. QuickPod used the top-right reminder card instead."
                    )
                ))
                self.showTestReminderPreview()
            @unknown default:
                print("[QuickPod] 未知通知权限状态")
                completion?(TestNotificationOutcome(
                    succeeded: false,
                    message: QuickPodText.text(
                        zh: "通知状态未知，QuickPod 已改用应用内测试卡片。",
                        en: "Notification status is unknown. QuickPod used the in-app test card instead."
                    )
                ))
                self.showTestReminderPreview()
            }
        }
    }
    
    private func reallySendTestNotification(completion: ((TestNotificationOutcome) -> Void)?) {
        let content = UNMutableNotificationContent()
        content.title = QuickPodText.text(zh: "测试通知", en: "Test notification")
        content.body = QuickPodText.text(zh: "休息提醒测试 - QuickPod", en: "Break reminder test - QuickPod")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "QuickPod.test.notification",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                print("[QuickPod] 测试通知发送失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion?(TestNotificationOutcome(
                        succeeded: false,
                        message: QuickPodText.text(
                            zh: "系统通知发送失败，QuickPod 已改用右上角测试卡片。",
                            en: "The system notification failed, so QuickPod used the top-right test card instead."
                        )
                    ))
                    self.showTestReminderPreview()
                }
            } else {
                print("[QuickPod] 测试通知已发送")
                DispatchQueue.main.async {
                    completion?(TestNotificationOutcome(
                        succeeded: true,
                        message: QuickPodText.text(
                            zh: "测试通知已提交给系统，同时会弹一个 QuickPod 预览卡片。",
                            en: "The test notification was submitted, and QuickPod also showed a preview card."
                        )
                    ))
                    self.showTestReminderPreview()
                }
            }
        }
    }

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[QuickPod] 请求通知权限失败: \(error.localizedDescription)")
            }
            print("[QuickPod] 通知权限请求结果: \(granted)")
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    private func startReminder() {
        print("[QuickPod] startReminder() called, interval: \(intervalMinutes) minutes")

        evaluateAuthorizationStatus { [weak self] status in
            guard let self = self, self.isActive else { return }

            switch status {
            case .authorized, .provisional, .ephemeral:
                self.scheduleNotifications(notificationAuthorized: true)
                self.sendActivationNotificationIfNeeded(notificationAuthorized: true)
            case .notDetermined:
                self.requestPermission { granted in
                    guard self.isActive else { return }
                    self.scheduleNotifications(notificationAuthorized: granted)
                    self.sendActivationNotificationIfNeeded(notificationAuthorized: granted)
                }
            case .denied:
                print("[QuickPod] 通知权限未授予，改为使用应用内提醒")
                self.scheduleNotifications(notificationAuthorized: false)
                DispatchQueue.main.async {
                    (NSApp.delegate as? AppDelegate)?.presentNotificationPermissionAlert()
                }
            @unknown default:
                self.scheduleNotifications(notificationAuthorized: false)
            }
        }
    }

    private func evaluateAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            print("[QuickPod] 当前通知权限状态: \(settings.authorizationStatus.rawValue)")
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    private func scheduleNotifications(notificationAuthorized: Bool) {
        print("[QuickPod] scheduleNotifications() called, notificationAuthorized: \(notificationAuthorized)")
        
        stopTimers()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
        
        remainingSeconds = intervalMinutes * 60
        progress = 1.0
        
        if notificationAuthorized && (reminderStyle == .systemNotification || reminderStyle == .both) {
            scheduleSystemNotification()
        }
        
        scheduleAlertTimer()
        
        startCountdown()
    }
    
    private func scheduleSystemNotification() {
        print("[QuickPod] scheduleSystemNotification() - interval: \(intervalMinutes * 60) seconds")
        
        let content = UNMutableNotificationContent()
        content.title = QuickPodText.text(zh: "该休息啦", en: "Time for a break")
        content.body = QuickPodText.text(
            zh: "已经工作 \(intervalMinutes) 分钟了，起来活动一下吧",
            en: "You've been working for \(intervalMinutes) minutes. Time to stretch."
        )
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(intervalMinutes * 60),
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("[QuickPod] 系统通知注册失败: \(error.localizedDescription)")
            } else {
                print("[QuickPod] 系统通知已注册，每 \(self.intervalMinutes) 分钟触发")
                self.center.getPendingNotificationRequests { requests in
                    let matches = requests.filter { $0.identifier == self.notificationIdentifier }
                    print("[QuickPod] 当前待发送通知数: \(matches.count)")
                }
            }
        }
    }
    
    private func scheduleAlertTimer() {
        print("[QuickPod] scheduleAlertTimer() - interval: \(intervalMinutes * 60) seconds")

        let timer = Timer(timeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { [weak self] _ in
            print("[QuickPod] 定时器触发，准备显示右上角提醒浮窗")
            DispatchQueue.main.async {
                self?.showBreakReminderAlert()
            }
        }
        reminderTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func startCountdown() {
        print("[QuickPod] startCountdown() called")

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
                self.progress = Double(self.remainingSeconds) / Double(self.intervalMinutes * 60)
            } else {
                // 倒计时结束，重置
                self.remainingSeconds = self.intervalMinutes * 60
                self.progress = 1.0
            }
        }
        countdownTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func stopTimers() {
        reminderTimer?.invalidate()
        reminderTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        print("[QuickPod] 定时器已停止")
    }

    private func sendActivationNotificationIfNeeded(notificationAuthorized: Bool) {
        guard notificationAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = QuickPodText.text(zh: "休息提醒已开启", en: "Break reminder enabled")
        content.body = QuickPodText.text(
            zh: "QuickPod 将在 \(intervalMinutes) 分钟后提醒你休息。",
            en: "QuickPod will remind you to take a break in \(intervalMinutes) minutes."
        )
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: activationNotificationIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.15, repeats: false)
        )

        center.removePendingNotificationRequests(withIdentifiers: [activationNotificationIdentifier])
        center.add(request) { error in
            if let error {
                print("[QuickPod] 启动提醒通知发送失败: \(error.localizedDescription)")
            } else {
                print("[QuickPod] 已发送休息提醒启用通知")
            }
        }
    }
    
    private func showBreakReminderAlert() {
        print("[QuickPod] showBreakReminderAlert() called")

        playReminderSound()
        showReminderPanel(
            title: QuickPodText.text(zh: "该休息啦", en: "Time for a break"),
            message: QuickPodText.text(
                zh: "已经工作 \(intervalMinutes) 分钟了，站起来活动一下，喝口水也行。",
                en: "You've been working for \(intervalMinutes) minutes. Stand up, stretch, and take a sip of water."
            )
        )
    }
    
    private func playReminderSound() {
        NSSound.beep()
    }
    
    func postponeReminder(minutes: Int) {
        print("[QuickPod] postponeReminder(\(minutes)) called")
        
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
        stopTimers()
        
        let originalInterval = intervalMinutes
        
        // 设置延后时间
        remainingSeconds = minutes * 60
        progress = 1.0
        
        if reminderStyle == .systemNotification || reminderStyle == .both {
            let content = UNMutableNotificationContent()
            content.title = QuickPodText.text(zh: "该休息啦", en: "Time for a break")
            content.body = QuickPodText.text(
                zh: "已经工作 \(originalInterval) 分钟了，起来活动一下吧",
                en: "You've been working for \(originalInterval) minutes. Time to stretch."
            )
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(minutes * 60),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: notificationIdentifier,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
        
        if reminderStyle == .alertWindow || reminderStyle == .both {
            let timer = Timer(timeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showBreakReminderAlert()
                }
            }
            reminderTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // 启动临时倒计时
        startCountdown()
        
        // 延后结束后恢复原时间间隔
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(minutes * 60)) { [weak self] in
            guard let self = self, self.isActive else { return }
            self.intervalMinutes = originalInterval
            self.startReminder()
        }
    }

    func stop() {
        print("[QuickPod] stop() called")
        deactivateReminder(clearPublishedState: true)
    }

    private func deactivateReminder(clearPublishedState: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
        stopTimers()
        dismissBreakReminderPanel()
        remainingSeconds = 0
        progress = 0.0

        guard clearPublishedState, isActive else { return }
        isApplyingStateChange = true
        isActive = false
        UserDefaults.standard.set(false, forKey: Keys.isActive)
        isApplyingStateChange = false
    }

    func hasPendingReminder(completion: @escaping (Bool) -> Void) {
        center.getPendingNotificationRequests { requests in
            let exists = requests.contains { $0.identifier == self.notificationIdentifier }
            DispatchQueue.main.async {
                completion(exists)
            }
        }
    }
    
    // 格式化剩余时间
    var formattedRemainingTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    private func showTestReminderPreview() {
        playReminderSound()
        showReminderPanel(
            title: QuickPodText.text(zh: "测试提醒已触发", en: "Test reminder triggered"),
            message: QuickPodText.text(
                zh: "这张右上角小卡片就是到点后的提醒样式。你现在可以把提醒时长设成 1 分钟继续测试。",
                en: "This top-right card is the same reminder style you'll see at the interval. You can now set the timer to 1 minute for testing."
            )
        )
    }

    private func showReminderPanel(title: String, message: String) {
        dismissBreakReminderPanel()

        let contentView = BreakReminderPopupView(
            title: title,
            message: message,
            onConfirm: { [weak self] in
                self?.dismissBreakReminderPanel()
            },
            onSnooze5: { [weak self] in
                self?.dismissBreakReminderPanel()
                self?.postponeReminder(minutes: 5)
            },
            onSnooze10: { [weak self] in
                self?.dismissBreakReminderPanel()
                self?.postponeReminder(minutes: 10)
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: 176)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.maxX - hostingView.frame.width - 18,
                y: visible.maxY - hostingView.frame.height - 18
            )
            panel.setFrameOrigin(origin)
        }

        reminderPanel = panel
        panel.orderFrontRegardless()
    }

    private func dismissBreakReminderPanel() {
        reminderPanel?.orderOut(nil)
        reminderPanel = nil
    }
}

struct BreakReminderPopupView: View {
    let title: String
    let message: String
    let onConfirm: () -> Void
    let onSnooze5: () -> Void
    let onSnooze10: () -> Void

    var bodyView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.99, green: 0.87, blue: 0.66),
                                    Color(red: 0.96, green: 0.71, blue: 0.44)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.68), lineWidth: 1)
                        )
                    Image(systemName: "mug.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(red: 0.47, green: 0.30, blue: 0.16))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(nsColor: .labelColor))
                    Text(QuickPodText.text(zh: "QuickPod 休息提醒", en: "QuickPod reminder"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
                Spacer()
            }

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: onConfirm) {
                    Text(QuickPodText.text(zh: "知道了", en: "Got it"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BreakReminderPrimaryButtonStyle())

                Button(action: onSnooze5) {
                    Text(QuickPodText.text(zh: "5 分钟后", en: "5 min"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BreakReminderSecondaryButtonStyle())

                Button(action: onSnooze10) {
                    Text(QuickPodText.text(zh: "10 分钟后", en: "10 min"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BreakReminderSecondaryButtonStyle())
            }
        }
        .padding(18)
        .frame(width: 340, height: 176)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            Color(red: 0.99, green: 0.98, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
        .compositingGroup()
    }

    var body: some View {
        bodyView
    }
}

private struct BreakReminderPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.29, green: 0.72, blue: 0.45))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct BreakReminderSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(nsColor: .labelColor))
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension BreakReminder: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("[QuickPod] willPresent notification")
        completionHandler([.banner, .list, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        print("[QuickPod] didReceive notification response")
        completionHandler()
    }
}
