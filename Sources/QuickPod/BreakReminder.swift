import AppKit
import UserNotifications

class BreakReminder: NSObject, ObservableObject {
    private enum Keys {
        static let interval = "QuickPod.breakIntervalMinutes"
        static let isActive = "QuickPod.breakReminderActive"
        static let reminderStyle = "QuickPod.reminderStyle"
    }

    private let notificationIdentifier = "QuickPod.breakReminder.notification"
    private let center = UNUserNotificationCenter.current()
    
    // 提醒方式
    enum ReminderStyle: Int, CaseIterable {
        case systemNotification = 0  // 系统通知
        case alertWindow = 1         // 弹窗提醒
        case both = 2                // 两者都用
    }

    @Published var isActive = UserDefaults.standard.bool(forKey: Keys.isActive) {
        didSet {
            UserDefaults.standard.set(isActive, forKey: Keys.isActive)
            if isActive {
                scheduleNotifications()
            } else {
                stop()
            }
        }
    }
    @Published var intervalMinutes: Int = UserDefaults.standard.integer(forKey: "QuickPod.breakIntervalMinutes") == 0
        ? 45
        : UserDefaults.standard.integer(forKey: "QuickPod.breakIntervalMinutes") {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: Keys.interval)
            if isActive {
                scheduleNotifications()
            }
        }
    }
    @Published var reminderStyle: ReminderStyle {
        didSet {
            UserDefaults.standard.set(reminderStyle.rawValue, forKey: Keys.reminderStyle)
            if isActive {
                scheduleNotifications()
            }
        }
    }

    static let intervalOptions = [15, 20, 25, 30, 45, 60, 90, 120]
    static let quickIntervals = [15, 30, 45, 60]
    
    override init() {
        let rawValue = UserDefaults.standard.integer(forKey: Keys.reminderStyle)
        reminderStyle = ReminderStyle(rawValue: rawValue) ?? .both
        super.init()
        center.delegate = self
    }

    func toggle() {
        isActive.toggle()
    }

    func restart() {
        guard isActive else { return }
        scheduleNotifications()
    }

    func start(withInterval interval: Int) {
        intervalMinutes = interval
        isActive = true
    }

    func prepareOnLaunch() {
        guard isActive else { return }
        // 直接启动通知调度，权限检查放在发送通知时处理
        scheduleNotifications()
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "测试通知"
        content.body = "休息提醒测试 - QuickPod"
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
            } else {
                print("[QuickPod] 测试通知已发送")
            }
        }
    }

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[QuickPod] 请求通知权限失败: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    private func scheduleNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        reminderTimer?.invalidate()
        reminderTimer = nil
        
        print("[QuickPod] 调度休息提醒: 每 \(intervalMinutes) 分钟")

        // 根据提醒方式选择不同策略
        if reminderStyle == .systemNotification || reminderStyle == .both {
            scheduleSystemNotification()
        }
        
        // 如果是弹窗提醒或两者都用，使用定时器
        if reminderStyle == .alertWindow || reminderStyle == .both {
            scheduleAlertReminder()
        }
    }
    
    private func scheduleSystemNotification() {
        let content = UNMutableNotificationContent()
        content.title = "该休息啦"
        content.body = "已经工作 \(intervalMinutes) 分钟了，起来活动一下吧"
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
                print("[QuickPod] 休息提醒注册失败: \(error.localizedDescription)")
                // 如果通知权限有问题，尝试请求权限
                self.requestPermission { granted in
                    if granted {
                        // 权限已授予，重新调度
                        DispatchQueue.main.async {
                            if self.isActive {
                                self.scheduleNotifications()
                            }
                        }
                    }
                }
            } else {
                print("[QuickPod] 休息提醒已启用 (系统通知): every \(self.intervalMinutes) minutes")
            }
        }
    }
    
    private var reminderTimer: Timer?
    private var postponeWorkItem: DispatchWorkItem?
    
    private func scheduleAlertReminder() {
        reminderTimer?.invalidate()
        reminderTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.showBreakReminderAlert()
            }
        }
        print("[QuickPod] 休息提醒已启用 (弹窗): every \(intervalMinutes) minutes")
    }
    
    private func showBreakReminderAlert() {
        playReminderSound()
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "该休息啦"
        alert.informativeText = "已经工作 \(intervalMinutes) 分钟了，起来活动一下吧"
        alert.addButton(withTitle: "知道了")
        alert.addButton(withTitle: "延后 5 分钟")
        alert.addButton(withTitle: "延后 10 分钟")
        
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        switch response {
        case .alertSecondButtonReturn:
            postponeReminder(minutes: 5)
        case .alertThirdButtonReturn:
            postponeReminder(minutes: 10)
        default:
            break
        }
    }
    
    private func playReminderSound() {
        NSSound.beep()
    }
    
    func postponeReminder(minutes: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        reminderTimer?.invalidate()
        reminderTimer = nil
        postponeWorkItem?.cancel()
        postponeWorkItem = nil
        
        let originalInterval = intervalMinutes
        
        if reminderStyle == .systemNotification || reminderStyle == .both {
            let content = UNMutableNotificationContent()
            content.title = "该休息啦"
            content.body = "已经工作 \(originalInterval) 分钟了，起来活动一下吧"
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
            reminderTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showBreakReminderAlert()
                }
            }
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isActive else { return }
            self.intervalMinutes = originalInterval
            self.scheduleNotifications()
        }
        postponeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(minutes * 60), execute: workItem)
    }

    func stop() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        reminderTimer?.invalidate()
        reminderTimer = nil
        postponeWorkItem?.cancel()
        postponeWorkItem = nil
        isActive = false
        print("[QuickPod] 休息提醒已停止")
    }

    func hasPendingReminder(completion: @escaping (Bool) -> Void) {
        center.getPendingNotificationRequests { requests in
            let exists = requests.contains { $0.identifier == self.notificationIdentifier }
            DispatchQueue.main.async {
                completion(exists)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension BreakReminder: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 确保通知总是显示
        completionHandler([.banner, .list, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
