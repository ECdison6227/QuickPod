import AppKit
import Foundation
import UserNotifications

class BreakReminder: ObservableObject {
    private enum Keys {
        static let interval = "QuickPod.breakIntervalMinutes"
        static let isActive = "QuickPod.breakReminderActive"
    }

    private let notificationIdentifier = "QuickPod.breakReminder.notification"
    private let center = UNUserNotificationCenter.current()

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

    static let intervalOptions = [15, 20, 25, 30, 45, 60, 90, 120]

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

    func stop() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        isActive = false
    }
}
