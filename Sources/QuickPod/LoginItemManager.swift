import ServiceManagement
import AppKit

class LoginItemManager: ObservableObject {
    @Published var isEnabled: Bool

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            isEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            print("Login item toggle failed: \(error)")
        }
    }
}