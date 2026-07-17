import Foundation
import Carbon.HIToolbox

enum AppSettings {
    private static let d = UserDefaults.standard

    enum IconStyle: String, CaseIterable, Identifiable {
        case chevron, arrows, dots, minus, eye
        var id: String { rawValue }
        var label: String {
            switch self {
            case .chevron: return "Chevron"
            case .arrows: return "Arrows"
            case .dots: return "Dots"
            case .minus: return "Minus"
            case .eye: return "Eye"
            }
        }
        var symbol: String {
            switch self {
            case .chevron: return "chevron.right"
            case .arrows: return "arrow.right.to.line.compact"
            case .dots: return "ellipsis"
            case .minus: return "minus"
            case .eye: return "eye"
            }
        }
    }

    enum ClickAction: String, CaseIterable, Identifiable {
        case toggleCollapse, toggleSeparators, openSettings, doNothing
        var id: String { rawValue }
        var label: String {
            switch self {
            case .toggleCollapse: return "折叠 / 展开"
            case .toggleSeparators: return "显示分隔符"
            case .openSettings: return "打开设置"
            case .doNothing: return "无操作"
            }
        }
    }

    static func registerDefaults() {
        // One-shot: enable hover-expand for installs that never touched the key.
        if d.object(forKey: "expandOnHover") == nil {
            d.set(true, forKey: "expandOnHover")
        }
        if d.object(forKey: "collapseOnMouseLeave") == nil {
            d.set(true, forKey: "collapseOnMouseLeave")
        }
        d.register(defaults: [
            "launchAtLogin": false,
            "showPrefsOnLaunch": true,
            "autoHide": true,
            "autoHideSeconds": 10.0,
            "collapseOnLaunch": true,
            "alwaysHidden": false,
            "separatorsHidden": false,
            "hotkeyEnabled": true,
            "hotkeyKeyCode": Int(kVK_ANSI_H),
            "hotkeyModifiers": Int(cmdKey | optionKey),
            "expandOnHover": true,
            "hoverDelay": 0.2,
            "collapseOnMouseLeave": true,
            "iconStyle": IconStyle.chevron.rawValue,
            "leftClick": ClickAction.toggleCollapse.rawValue,
            "rightClick": ClickAction.openSettings.rawValue,
            "optionClick": ClickAction.toggleSeparators.rawValue,
            "hideToggleWhenCollapsed": false,
            "separatorThickness": 1.0,
            "notchAware": true,
            "expandViaOverflowBar": true,
            "autoCollapseOverflow": true
        ])
    }

    private static func notify() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    private static func set(_ key: String, _ value: Any) {
        d.set(value, forKey: key)
        notify()
    }

    static var launchAtLogin: Bool {
        get { d.bool(forKey: "launchAtLogin") }
        set { set("launchAtLogin", newValue) }
    }
    static var showPrefsOnLaunch: Bool {
        get { d.bool(forKey: "showPrefsOnLaunch") }
        set { set("showPrefsOnLaunch", newValue) }
    }
    static var autoHide: Bool {
        get { d.bool(forKey: "autoHide") }
        set { set("autoHide", newValue) }
    }
    static var autoHideSeconds: Double {
        get { let v = d.double(forKey: "autoHideSeconds"); return v > 0 ? v : 10 }
        set { set("autoHideSeconds", newValue) }
    }
    static var collapseOnLaunch: Bool {
        get { d.bool(forKey: "collapseOnLaunch") }
        set { set("collapseOnLaunch", newValue) }
    }
    static var alwaysHidden: Bool {
        get { d.bool(forKey: "alwaysHidden") }
        set {
            d.set(newValue, forKey: "alwaysHidden")
            NotificationCenter.default.post(name: .alwaysHiddenToggle, object: nil)
            notify()
        }
    }
    static var separatorsHidden: Bool {
        get { d.bool(forKey: "separatorsHidden") }
        set { d.set(newValue, forKey: "separatorsHidden") }
    }
    static var hotkeyEnabled: Bool {
        get { d.bool(forKey: "hotkeyEnabled") }
        set { set("hotkeyEnabled", newValue) }
    }
    static var hotkeyKeyCode: Int {
        get { d.integer(forKey: "hotkeyKeyCode") }
        set { set("hotkeyKeyCode", newValue) }
    }
    static var hotkeyModifiers: UInt32 {
        get { UInt32(d.integer(forKey: "hotkeyModifiers")) }
        set { set("hotkeyModifiers", Int(newValue)) }
    }
    static var expandOnHover: Bool {
        get { d.bool(forKey: "expandOnHover") }
        set { set("expandOnHover", newValue) }
    }
    static var hoverDelay: Double {
        get { let v = d.double(forKey: "hoverDelay"); return v > 0 ? v : 0.2 }
        set { set("hoverDelay", newValue) }
    }
    static var collapseOnMouseLeave: Bool {
        get {
            if d.object(forKey: "collapseOnMouseLeave") == nil { return true }
            return d.bool(forKey: "collapseOnMouseLeave")
        }
        set { set("collapseOnMouseLeave", newValue) }
    }
    static var iconStyle: IconStyle {
        get { IconStyle(rawValue: d.string(forKey: "iconStyle") ?? "") ?? .chevron }
        set { set("iconStyle", newValue.rawValue) }
    }
    static var leftClick: ClickAction {
        get { ClickAction(rawValue: d.string(forKey: "leftClick") ?? "") ?? .toggleCollapse }
        set { set("leftClick", newValue.rawValue) }
    }
    static var rightClick: ClickAction {
        get { ClickAction(rawValue: d.string(forKey: "rightClick") ?? "") ?? .openSettings }
        set { set("rightClick", newValue.rawValue) }
    }
    static var optionClick: ClickAction {
        get { ClickAction(rawValue: d.string(forKey: "optionClick") ?? "") ?? .toggleSeparators }
        set { set("optionClick", newValue.rawValue) }
    }
    static var hideToggleWhenCollapsed: Bool {
        get { d.bool(forKey: "hideToggleWhenCollapsed") }
        set { set("hideToggleWhenCollapsed", newValue) }
    }
    static var separatorThickness: Double {
        get { let v = d.double(forKey: "separatorThickness"); return v > 0 ? v : 1 }
        set { set("separatorThickness", newValue) }
    }

    static var notchAware: Bool {
        get { d.bool(forKey: "notchAware") }
        set { set("notchAware", newValue) }
    }
    /// On notched Macs, expand into a below-menubar strip instead of the menubar.
    static var expandViaOverflowBar: Bool {
        get { d.bool(forKey: "expandViaOverflowBar") }
        set { set("expandViaOverflowBar", newValue) }
    }
    /// Auto-collapse when status items spill under the notch / left of the safe zone.
    static var autoCollapseOverflow: Bool {
        get { d.bool(forKey: "autoCollapseOverflow") }
        set { set("autoCollapseOverflow", newValue) }
    }

    static var hotkeyLabel: String {
        var parts: [String] = []
        let m = hotkeyModifiers
        if m & UInt32(controlKey) != 0 { parts.append("⌃") }
        if m & UInt32(optionKey) != 0 { parts.append("⌥") }
        if m & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if m & UInt32(cmdKey) != 0 { parts.append("⌘") }
        let map: [Int: String] = [
            kVK_ANSI_A:"A",kVK_ANSI_B:"B",kVK_ANSI_C:"C",kVK_ANSI_D:"D",
            kVK_ANSI_E:"E",kVK_ANSI_F:"F",kVK_ANSI_G:"G",kVK_ANSI_H:"H",
            kVK_ANSI_I:"I",kVK_ANSI_J:"J",kVK_ANSI_K:"K",kVK_ANSI_L:"L",
            kVK_ANSI_M:"M",kVK_ANSI_N:"N",kVK_ANSI_O:"O",kVK_ANSI_P:"P",
            kVK_ANSI_Q:"Q",kVK_ANSI_R:"R",kVK_ANSI_S:"S",kVK_ANSI_T:"T",
            kVK_ANSI_U:"U",kVK_ANSI_V:"V",kVK_ANSI_W:"W",kVK_ANSI_X:"X",
            kVK_ANSI_Y:"Y",kVK_ANSI_Z:"Z",
            kVK_Space:"Space",kVK_Return:"↩",kVK_Escape:"⎋"
        ]
        parts.append(map[hotkeyKeyCode] ?? "Key\(hotkeyKeyCode)")
        return parts.joined()
    }

    static func reset() {
        Bundle.main.bundleIdentifier.map { d.removePersistentDomain(forName: $0) }
        registerDefaults()
        notify()
    }
}

extension Notification.Name {
    static let settingsDidChange = Notification.Name("ci.settings")
    static let alwaysHiddenToggle = Notification.Name("ci.alwaysHidden")
}

enum Constant {
    static var isLTR = true
}
