import Foundation
import AppKit
import UserNotifications

class AntiSleepManager: ObservableObject {
    static let statusChangedNotification = Notification.Name("com.quickpod.antisleep.statusChanged")
    
    // 会话时长选项
    enum SessionDuration: Int, CaseIterable {
        case indefinite = 0  // 无限时长
        case fifteenMinutes = 15
        case thirtyMinutes = 30
        case oneHour = 60
        
        var displayName: String {
            switch self {
            case .indefinite: return "不限时"
            case .fifteenMinutes: return "15 分钟"
            case .thirtyMinutes: return "30 分钟"
            case .oneHour: return "1 小时"
            }
        }
        
        var durationSeconds: TimeInterval {
            switch self {
            case .indefinite: return TimeInterval.infinity
            case .fifteenMinutes: return 15 * 60
            case .thirtyMinutes: return 30 * 60
            case .oneHour: return 60 * 60
            }
        }
    }
    
    @Published var isActive = false
    @Published var sessionDuration: SessionDuration = .indefinite
    @Published var remainingSeconds: TimeInterval = 0
    
    private var process: Process?
    private var sessionTimer: Timer?
    private var startTime: Date?
    
    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate(withDuration: sessionDuration)
        }
    }
    
    func activate(withDuration duration: SessionDuration) {
        sessionDuration = duration
        startTime = Date()
        remainingSeconds = duration.durationSeconds
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        
        // 根据时长设置参数
        if duration == .indefinite {
            p.arguments = ["-dimsu"]
        } else {
            // -t 参数指定秒数
            p.arguments = ["-dimsu", "-t", "\(Int(duration.durationSeconds))"]
        }
        
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        
        do {
            try p.run()
            process = p
            isActive = true
            
            // 如果不是无限时长，启动定时器更新剩余时间
            if duration != .indefinite {
                startSessionTimer()
            }
            
            sendNotification(title: "防睡眠已开启", body: duration == .indefinite ? "Mac 将保持唤醒" : "\(duration.displayName) 后自动关闭")
            notifyStatusChanged()
        } catch {
            print("[QuickPod] 防睡眠启动失败: \(error.localizedDescription)")
        }
    }
    
    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            self.remainingSeconds = max(0, self.sessionDuration.durationSeconds - elapsed)
            
            if self.remainingSeconds <= 0 {
                self.deactivate()
            }
        }
    }
    
    func deactivate() {
        process?.terminate()
        process = nil
        
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        startTime = nil
        remainingSeconds = 0
        isActive = false
        sendNotification(title: "防睡眠已关闭", body: "Mac 将正常休眠")
        notifyStatusChanged()
    }
    
    func getRemainingTimeString() -> String {
        guard isActive, remainingSeconds > 0 else {
            return sessionDuration.displayName
        }
        
        if remainingSeconds == TimeInterval.infinity {
            return "不限时"
        }
        
        let hours = Int(remainingSeconds / 3600)
        let minutes = Int((remainingSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(remainingSeconds.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(
            identifier: "QuickPod.antiSleep.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func notifyStatusChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.statusChangedNotification,
                object: self
            )
        }
    }
}