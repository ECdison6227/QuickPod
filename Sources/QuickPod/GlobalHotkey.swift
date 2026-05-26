import AppKit
import Carbon

/// 全局快捷键管理器
/// 使用 Carbon RegisterEventHotKey 注册系统级快捷键，比 NSEvent 全局监听更可靠
/// 快捷键可录制自定义，持久化到 UserDefaults
class GlobalHotkey {
    typealias Handler = (UInt32, UInt32) -> Void  // keyCode, modifiers

    private var hotkeyRefs: [EventHotKeyRef?] = []
    private var registeredHandlerKey: String?
    private let handler: Handler?

    // MARK: - 快捷键配置持久化

    static var keyCode: UInt32 {
        get {
            let v = UserDefaults.standard.integer(forKey: "QuickPod.hotkey.keyCode")
            return v != 0 ? UInt32(v) : UInt32(kVK_Space)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: "QuickPod.hotkey.keyCode") }
    }

    static var modifiers: UInt32 {
        get {
            let v = UserDefaults.standard.integer(forKey: "QuickPod.hotkey.modifiers")
            return v != 0 ? UInt32(v) : UInt32(cmdKey | optionKey)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: "QuickPod.hotkey.modifiers") }
    }

    /// 显示用文本，如 "⌘⌥Space"
    static var displayString: String {
        let mods = Self.modifiers
        var parts: [String] = []
        if mods & UInt32(cmdKey) != 0      { parts.append("⌘") }
        if mods & UInt32(optionKey) != 0    { parts.append("⌥") }
        if mods & UInt32(controlKey) != 0   { parts.append("⌃") }
        if mods & UInt32(shiftKey) != 0     { parts.append("⇧") }
        let name = Self.nameForKeyCode(Self.keyCode) ?? "?"
        parts.append(name)
        return parts.joined()
    }

    static func nameForKeyCode(_ kc: UInt32) -> String? {
        let functionKeys: [UInt32: String] = [
            UInt32(kVK_F1): "F1",
            UInt32(kVK_F2): "F2",
            UInt32(kVK_F3): "F3",
            UInt32(kVK_F4): "F4",
            UInt32(kVK_F5): "F5",
            UInt32(kVK_F6): "F6",
            UInt32(kVK_F7): "F7",
            UInt32(kVK_F8): "F8",
            UInt32(kVK_F9): "F9",
            UInt32(kVK_F10): "F10",
            UInt32(kVK_F11): "F11",
            UInt32(kVK_F12): "F12"
        ]

        switch kc {
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Escape): return "Esc"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_ForwardDelete): return "Fn-Delete"
        case UInt32(kVK_UpArrow): return "↑"
        case UInt32(kVK_DownArrow): return "↓"
        case UInt32(kVK_LeftArrow): return "←"
        case UInt32(kVK_RightArrow): return "→"
        default:
            return functionKeys[kc] ?? Self.tisKeyName(kc)
        }
    }

    private static func tisKeyName(_ kc: UInt32) -> String? {
        guard let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let cfData = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue()
        let ptr = CFDataGetBytePtr(cfData)
        let keyLayout = ptr?.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 }
        guard let layoutPtr = keyLayout else { return nil }
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var len = 0
        let err = UCKeyTranslate(
            layoutPtr,
            UInt16(kc),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &len,
            &chars
        )
        guard err == noErr else { return nil }
        return String(utf16CodeUnits: chars, count: len).uppercased()
    }

    // MARK: - Carbon 热键静态注册表

    private static var installed = false
    private static var eventHandlerRef: EventHandlerRef?
    private static var hotkeyHandlers: [String: Handler] = [:]
    // 递增 ID 保证每个注册有唯一标识
    private static var nextID: UInt32 = 1

    private static func handlerKey(for hotkeyID: EventHotKeyID) -> String {
        "\(UInt32(hotkeyID.signature)):\(hotkeyID.id)"
    }

    private static let carbonCallback: @convention(c) (EventHandlerCallRef?, EventRef?, UnsafeMutableRawPointer?) -> OSStatus = { _, event, _ in
        var hkID = EventHotKeyID()
        let err = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hkID
        )
        if err == noErr {
            let key = handlerKey(for: hkID)
            DispatchQueue.main.async {
                if let handler = GlobalHotkey.hotkeyHandlers[key] {
                    handler(hkID.id, UInt32(hkID.signature))
                }
            }
        }
        return noErr
    }

    private static func ensureInstalled() {
        guard !installed else { return }
        installed = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            carbonCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        if status != noErr && status != eventAlreadyPostedErr {
            print("[QuickPod] InstallEventHandler failed: \(status)")
            installed = false
        }
    }

    // MARK: - 实例方法

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// 注册当前配置的快捷键
    func register() {
        unregister()
        Self.ensureInstalled()

        let kc = Self.keyCode
        let mods = Self.modifiers

        let id = Self.nextID
        Self.nextID += 1

        let hotkeyID = EventHotKeyID(signature: OSType(0x51504B44), id: id)
        let key = Self.handlerKey(for: hotkeyID)
        registeredHandlerKey = key

        Self.hotkeyHandlers[key] = { [weak self] _, _ in
            self?.handler?(kc, mods)
        }

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(kc, mods, hotkeyID, GetEventDispatcherTarget(), 0, &ref)
        if status == noErr, let ref = ref {
            hotkeyRefs.append(ref)
            print("[QuickPod] HotKey registered: \(Self.displayString)")
        } else {
            Self.hotkeyHandlers.removeValue(forKey: key)
            registeredHandlerKey = nil
            print("[QuickPod] RegisterEventHotKey failed: \(status) for keyCode=\(kc) mods=\(mods)")
        }
    }

    /// 重新配置快捷键（录制新键后调用）
    func reconfigure() {
        register()
    }

    func unregister() {
        for ref in hotkeyRefs {
            if let r = ref {
                UnregisterEventHotKey(r)
            }
        }
        hotkeyRefs.removeAll()
        if let key = registeredHandlerKey {
            Self.hotkeyHandlers.removeValue(forKey: key)
            registeredHandlerKey = nil
        }
    }

    deinit {
        unregister()
    }
}

/// 便捷函数：从 NSEvent 提取 keyCode 和修饰键
func extractHotKeyFromEvent(_ event: NSEvent) -> (keyCode: UInt32, modifiers: UInt32)? {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    // 排除纯修饰键按下
    guard event.keyCode != 0 || flags.isEmpty else { return nil }
    var carbonMods: UInt32 = 0
    if flags.contains(.command)   { carbonMods |= UInt32(cmdKey) }
    if flags.contains(.option)    { carbonMods |= UInt32(optionKey) }
    if flags.contains(.control)   { carbonMods |= UInt32(controlKey) }
    if flags.contains(.shift)     { carbonMods |= UInt32(shiftKey) }
    // 必须至少有一个修饰键
    guard carbonMods != 0 else { return nil }
    return (UInt32(event.keyCode), carbonMods)
}
