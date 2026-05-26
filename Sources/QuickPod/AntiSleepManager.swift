import Foundation
import AppKit

class AntiSleepManager: ObservableObject {
    @Published var isActive = false
    private var process: Process?

    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    func activate() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        p.arguments = ["-dimsu"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        process = p

        isActive = true
        updateIcon()
    }

    func deactivate() {
        process?.terminate()
        process = nil

        isActive = false
        updateIcon()
    }

    private func updateIcon() {
        DispatchQueue.main.async {
            if let appDelegate = NSApp.delegate as? AppDelegate,
               let button = appDelegate.statusItem?.button {
                button.image = NSImage(
                    systemSymbolName: self.isActive ? "bolt.fill" : "bolt.slash.fill",
                    accessibilityDescription: "QuickPod"
                )
            }
        }
    }
}