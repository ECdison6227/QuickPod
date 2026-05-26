import AppKit
import Foundation
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
        }
    }
    @Published var intervalMinutes: Int = UserDefaults.standard.integer(forKey: "QuickPod.breakIntervalMinutes") == 0
        ? 45
        : UserDefaults.standard.integer(forKey: "QuickPod.breakIntervalMinutes") {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: Keys.interval)
        }
    }
    @Published var reminderStyle: ReminderStyle {
        didSet {
            UserDefaults.standard.set(reminderStyle.rawValue, forKey: Keys.reminderStyle)
        }
    }

    static let intervalOptions = [15, 20, 25, 30, 45, 60, 90, 120]
    static let quickIntervals = [15, 30, 45, 60]
    
    override init() {
        let rawValue = UserDefaults.standard.integer(forKey: Keys.reminderStyle)
        reminderStyle = ReminderStyle(rawValue: rawValue) ?? .both
        super.init()
    }

    func toggle() {
        if isActive {
            stop()
        } else {
            ensurePermission { [weak self] granted in
                guard granted else {
                    (NSApp.delegate as? AppDelegate)?.presentNotificationPermissionAlert()
                    return
                }
                self?.start()
            }
        }
    }

    func restart() {
        guard isActive else { return }
        scheduleNotifications()
    }

    func start(withInterval interval: Int) {
        intervalMinutes = interval
        start()
    }

    func prepareOnLaunch() {
        guard isActive else { return }
        ensurePermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.scheduleNotifications()
            } else {
                self.stop()
            }
        }
    }

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    private func start() {
        isActive = true
        scheduleNotifications()
    }

    private func ensurePermission(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(true) }
            case .notDetermined:
                self?.requestPermission(completion: completion)
            case .denied:
                DispatchQueue.main.async { completion(false) }
            @unknown default:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    private func scheduleNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        
        // 注册通知动作处理
        center.delegate = self
        
        // 根据提醒方式选择不同策略
        if reminderStyle == .systemNotification || reminderStyle == .both {
            scheduleSystemNotification()
        }
        
        // 如果是弹窗提醒或两者都用，使用定时器替代系统通知
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
            } else {
                print("[QuickPod] 休息提醒已启用: every \(self.intervalMinutes) minutes")
            }
        }
    }
    
    private var reminderTimer: Timer?
    
    private func scheduleAlertReminder() {
        reminderTimer?.invalidate()
        reminderTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { [weak self] _ in
            self?.showBreakReminderAlert()
        }
    }
    
    private func showBreakReminderAlert() {
        playReminderSound()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "该休息啦"
            alert.informativeText = "已经工作 \(self.intervalMinutes) 分钟了，起来活动一下吧"
            alert.addButton(withTitle: "知道了")
            alert.addButton(withTitle: "延后 5 分钟")
            alert.addButton(withTitle: "延后 10 分钟")
            
            // 激活应用
            NSApp.activate(ignoringOtherApps: true)
            
            let response = alert.runModal()
            switch response {
            case .alertSecondButtonReturn:
                // 延后5分钟
                self.postponeReminder(minutes: 5)
            case .alertThirdButtonReturn:
                // 延后10分钟
                self.postponeReminder(minutes: 10)
            default:
                break
            }
        }
    }
    
    private func playReminderSound() {
        // 使用系统声音
        NSSound.beep()
    }
    
    func postponeReminder(minutes: Int) {
        // 停止当前提醒
        stop()
        
        // 设置新的间隔并重新开始
        let originalInterval = intervalMinutes
        intervalMinutes = minutes
        
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(minutes * 60)) { [weak self] in
            guard let self = self else { return }
            self.intervalMinutes = originalInterval
            self.start()
        }
        
        start(withInterval: minutes)
    }

    func stop() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        reminderTimer?.invalidate()
        reminderTimer = nil
        isActive = false
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
        completionHandler([.alert, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
