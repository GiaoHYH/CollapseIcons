import SwiftUI
import Carbon.HIToolbox

// MARK: - Design tokens (Desk Rail)
private enum Rail {
    static let ink     = Color(red: 0.06, green: 0.09, blue: 0.16)   // #0F172A
    static let rail    = Color(red: 0.12, green: 0.16, blue: 0.23)   // #1E293B
    static let plate   = Color(red: 0.16, green: 0.21, blue: 0.30)   // #293548
    static let mist    = Color(red: 0.95, green: 0.96, blue: 0.98)   // #F1F5F9
    static let mute    = Color(red: 0.58, green: 0.64, blue: 0.72)   // #94A3B8
    static let indigo  = Color(red: 0.39, green: 0.40, blue: 0.95)   // #6366F1
    static let glow    = Color(red: 0.65, green: 0.71, blue: 0.99)   // #A5B4FC
    static let mint    = Color(red: 0.20, green: 0.83, blue: 0.60)   // #34D399
}

struct SettingsRoot: View {
    @StateObject private var model = SettingsModel()
    @State private var tab: Tab = .general
    @State private var recordingHotkey = false
    @State private var previewCollapsed = false

    enum Tab: String, CaseIterable, Identifiable {
        case general = "通用"
        case behavior = "行为"
        case look = "外观"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Rail.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                hero
                tabBar
                ScrollView {
                    content
                        .padding(20)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 640)
        .preferredColorScheme(.dark)
        .background(
            HotkeyCaptureRepresentable(isRecording: $recordingHotkey) { code, mods in
                model.setHotkey(code, mods)
                recordingHotkey = false
            }
        )
    }

    // MARK: Signature — live menubar rail

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("COLLAPSE ICONS")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Rail.glow.opacity(0.85))
                    Text("干净轨道 · 一键跳过刘海")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Rail.mist)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                        previewCollapsed.toggle()
                    }
                } label: {
                    Text(previewCollapsed ? "预览展开" : "预览折叠")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Rail.plate)
                        .clipShape(Capsule())
                        .foregroundStyle(Rail.glow)
                }
                .buttonStyle(.plain)
            }

            MenubarRailPreview(collapsed: previewCollapsed, style: model.iconStyle, thickness: model.separatorThickness)
                .frame(height: 44)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Rail.rail)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Rail.indigo.opacity(0.25), lineWidth: 1)
                        )
                )

            Text("⌘ 拖动真实状态栏图标：左侧折叠 · 右侧常显 · ▶ 为开关")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Rail.mute)
        }
        .padding(.horizontal, 20)
        .padding(.top, 36)
        .padding(.bottom, 16)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { tab = t }
                } label: {
                    Text(t.rawValue)
                        .font(.system(size: 13, weight: tab == t ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(tab == t ? Rail.mist : Rail.mute)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if tab == t {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Rail.plate)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(Rail.indigo.opacity(0.45), lineWidth: 1)
                                        )
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Rail.rail)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general: generalPane
        case .behavior: behaviorPane
        case .look: lookPane
        }
    }

    // MARK: Panes

    private var generalPane: some View {
        VStack(spacing: 14) {
            Card(title: "启动", subtitle: "开机与首次进入") {
                ToggleRow("登录时启动", isOn: $model.launchAtLogin)
                ToggleRow("启动时打开设置", isOn: $model.showOnLaunch)
                ToggleRow("启动后自动折叠", isOn: $model.collapseOnLaunch)
            }

            Card(title: "快捷键", subtitle: "全局折叠 / 展开") {
                ToggleRow("启用全局快捷键", isOn: $model.hotkeyEnabled)
                HStack {
                    Text("当前")
                        .foregroundStyle(Rail.mute)
                    Spacer()
                    Button {
                        recordingHotkey.toggle()
                    } label: {
                        Text(recordingHotkey ? "按下组合键…" : model.hotkeyLabel)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(recordingHotkey ? Rail.mint : Rail.glow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Rail.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(recordingHotkey ? Rail.mint.opacity(0.6) : Rail.indigo.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.hotkeyEnabled)
                }
                Text("默认 ⌥⌘H · 录制时需带修饰键")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Rail.mute)
            }

            Card(title: "摆放", subtitle: "一次就够") {
                VStack(alignment: .leading, spacing: 8) {
                    step(1, "按住 ⌘，把 | 拖到折叠区与常显区之间")
                    step(2, "把 ▶ 留在最右侧")
                    step(3, "点击 ▶ 收起；Option+点击 显示隐藏区")
                }
            }

            Card(title: "当前显示器", subtitle: "跟随状态栏所在屏幕自动适配") {
                DisplayStatusCard()
            }
        }
    }

    private var behaviorPane: some View {
        VStack(spacing: 14) {
            Card(title: "自动折叠", subtitle: "空闲后收起") {
                ToggleRow("启用", isOn: $model.autoHide)
                SliderRow(title: "延迟", value: $model.autoHideSeconds, range: 1...120, step: 1,
                          format: { "\(Int($0))s" })
                .disabled(!model.autoHide)
            }

            Card(title: "悬停", subtitle: "鼠标放上菜单栏即展开") {
                ToggleRow("悬停自动展开", isOn: $model.expandOnHover)
                ToggleRow("移开后自动收起", isOn: $model.collapseOnMouseLeave)
                SliderRow(title: "展开延迟", value: $model.hoverDelay, range: 0.05...1.5, step: 0.05,
                          format: { String(format: "%.2fs", $0) })
                .disabled(!model.expandOnHover)
                Text("悬停当前状态栏所在屏幕的菜单栏区域即可展开")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Rail.mute)
            }

            Card(title: "永久隐藏区", subtitle: "第二分隔符左侧始终收起") {
                ToggleRow("启用永久隐藏区", isOn: $model.alwaysHidden)
                Text("Option+点击（默认）可临时露出")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Rail.mute)
            }

            Card(title: "刘海 / 安全区", subtitle: "右侧折叠 · 左侧展开") {
                ToggleRow("刘海安全模式", isOn: $model.notchAware)
                ToggleRow("展开时跳到刘海另一侧", isOn: $model.expandViaOverflowBar)
                    .disabled(!model.notchAware)
                ToggleRow("溢出自动折叠", isOn: $model.autoCollapseOverflow)
                    .disabled(!model.notchAware)
                Text("隐藏图标显示在刘海左侧菜单栏，不再挤进摄像头后面")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Rail.mute)
            }

            Card(title: "点击映射", subtitle: "每个手势一件事") {
                ActionPicker(title: "左键", selection: $model.leftClick)
                ActionPicker(title: "右键", selection: $model.rightClick)
                ActionPicker(title: "Option", selection: $model.optionClick)
            }
        }
    }

    private var lookPane: some View {
        VStack(spacing: 14) {
            Card(title: "开关图标", subtitle: "模板色，随系统外观") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                    ForEach(AppSettings.IconStyle.allCases) { style in
                        Button {
                            model.iconStyle = style
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: style.symbol)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(height: 22)
                                Text(style.label)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(model.iconStyle == style ? Rail.mist : Rail.mute)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(model.iconStyle == style ? Rail.indigo.opacity(0.28) : Rail.ink)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(model.iconStyle == style ? Rail.indigo : Rail.plate, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Card(title: "分隔符", subtitle: "轨道上的刻度") {
                SliderRow(title: "粗细", value: $model.separatorThickness, range: 1...4, step: 1,
                          format: { "\(Int($0))" })
                ToggleRow("折叠后隐藏开关本身", isOn: $model.hideToggle)
                Text("隐藏后用快捷键或悬停展开")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Rail.mute)
            }

            HStack {
                Button("重置设置") { model.reset() }
                    .buttonStyle(GhostButtonStyle())
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(.top, 4)

            Text("v1.0 · 纯菜单栏工具")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Rail.mute.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(format: "%02d", n))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Rail.indigo)
                .frame(width: 24, alignment: .leading)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Rail.mist.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Menubar rail preview (signature)

private struct MenubarRailPreview: View {
    var collapsed: Bool
    var style: AppSettings.IconStyle
    var thickness: Double

    private let icons = ["wifi", "battery.100", "bell.fill", "music.note", "message.fill", "calendar"]

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            // Always-visible zone (right of separator in real bar — shown left-to-right in preview as visual metaphor)
            HStack(spacing: 10) {
                ForEach(["clock", "control"], id: \.self) { name in
                    Image(systemName: name == "clock" ? "clock.fill" : "switch.2")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Rail.mist.opacity(0.85))
                }
            }

            // Toggle
            Image(systemName: collapsed
                  ? (style == .chevron ? "chevron.left" : style.symbol)
                  : style.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Rail.glow)
                .frame(width: 22)
                .padding(.leading, 8)

            // Separator
            Capsule()
                .fill(Rail.indigo)
                .frame(width: max(1, thickness), height: 16)
                .padding(.horizontal, 8)
                .shadow(color: Rail.indigo.opacity(0.55), radius: 4, y: 0)

            // Collapsible zone
            HStack(spacing: 10) {
                ForEach(Array(icons.enumerated()), id: \.offset) { _, name in
                    Image(systemName: name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Rail.mute)
                        .opacity(collapsed ? 0 : 1)
                        .frame(width: collapsed ? 0 : nil)
                }
            }
            .frame(maxWidth: collapsed ? 0 : .infinity, alignment: .trailing)
            .clipped()

            if collapsed {
                Text("hidden")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Rail.mute.opacity(0.7))
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: collapsed)
        .animation(.easeOut(duration: 0.15), value: style)
        .animation(.easeOut(duration: 0.15), value: thickness)
    }
}

// MARK: - Building blocks

private struct Card<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Rail.mist)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Rail.mute)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Rail.rail)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Rail.mist.opacity(0.92))
        }
        .toggleStyle(.switch)
        .tint(Rail.indigo)
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Rail.mist.opacity(0.92))
                Spacer()
                Text(format(value))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Rail.glow)
            }
            Slider(value: $value, in: range, step: step)
                .tint(Rail.indigo)
        }
    }
}

private struct ActionPicker: View {
    let title: String
    @Binding var selection: AppSettings.ClickAction

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Rail.mute)
                .frame(width: 56, alignment: .leading)
            Picker("", selection: $selection) {
                ForEach(AppSettings.ClickAction.allCases) { a in
                    Text(a.label).tag(a)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Rail.mist)
        }
    }
}

private struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Rail.mute)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Rail.plate.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(Capsule())
    }
}


// MARK: - Live display status

private struct DisplayStatusCard: View {
    @State private var lines: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(line.contains("指针") ? Rail.glow : Rail.mute)
            }
            if lines.isEmpty {
                Text("检测中…")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Rail.mute)
            }
            Text("展开/折叠会跟随状态栏所在那一块屏幕自动适配")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Rail.mute)
                .padding(.top, 4)
        }
        .onAppear(perform: refresh)
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            refresh()
        }
    }

    private func refresh() {
        let mouse = NSEvent.mouseLocation
        var out: [String] = []
        for s in NSScreen.screens {
            let hit = s.frame.contains(mouse)
            var tag = ScreenLayout.displayLabel(for: s)
            if hit { tag += "  ← 指针" }
            let mode = ScreenLayout.hasNotch(on: s) ? "跳刘海左侧" : "常规右侧展开"
            out.append(tag)
            out.append("  模式：\(mode)  ·  \(Int(s.frame.width))×\(Int(s.frame.height))")
        }
        lines = out
    }
}

// MARK: - Model

@MainActor
final class SettingsModel: ObservableObject {
    @Published var launchAtLogin = AppSettings.launchAtLogin { didSet { AppSettings.launchAtLogin = launchAtLogin } }
    @Published var showOnLaunch = AppSettings.showPrefsOnLaunch { didSet { AppSettings.showPrefsOnLaunch = showOnLaunch } }
    @Published var collapseOnLaunch = AppSettings.collapseOnLaunch { didSet { AppSettings.collapseOnLaunch = collapseOnLaunch } }
    @Published var autoHide = AppSettings.autoHide { didSet { AppSettings.autoHide = autoHide } }
    @Published var autoHideSeconds = AppSettings.autoHideSeconds { didSet { AppSettings.autoHideSeconds = autoHideSeconds } }
    @Published var alwaysHidden = AppSettings.alwaysHidden { didSet { AppSettings.alwaysHidden = alwaysHidden } }
    @Published var hotkeyEnabled = AppSettings.hotkeyEnabled { didSet { AppSettings.hotkeyEnabled = hotkeyEnabled } }
    @Published var hotkeyLabel = AppSettings.hotkeyLabel
    @Published var expandOnHover = AppSettings.expandOnHover { didSet { AppSettings.expandOnHover = expandOnHover } }
    @Published var collapseOnMouseLeave = AppSettings.collapseOnMouseLeave { didSet { AppSettings.collapseOnMouseLeave = collapseOnMouseLeave } }
    @Published var hoverDelay = AppSettings.hoverDelay { didSet { AppSettings.hoverDelay = hoverDelay } }
    @Published var iconStyle = AppSettings.iconStyle { didSet { AppSettings.iconStyle = iconStyle } }
    @Published var leftClick = AppSettings.leftClick { didSet { AppSettings.leftClick = leftClick } }
    @Published var rightClick = AppSettings.rightClick { didSet { AppSettings.rightClick = rightClick } }
    @Published var optionClick = AppSettings.optionClick { didSet { AppSettings.optionClick = optionClick } }
    @Published var hideToggle = AppSettings.hideToggleWhenCollapsed { didSet { AppSettings.hideToggleWhenCollapsed = hideToggle } }
    @Published var separatorThickness = AppSettings.separatorThickness { didSet { AppSettings.separatorThickness = separatorThickness } }
    @Published var notchAware = AppSettings.notchAware { didSet { AppSettings.notchAware = notchAware } }
    @Published var expandViaOverflowBar = AppSettings.expandViaOverflowBar { didSet { AppSettings.expandViaOverflowBar = expandViaOverflowBar } }
    @Published var autoCollapseOverflow = AppSettings.autoCollapseOverflow { didSet { AppSettings.autoCollapseOverflow = autoCollapseOverflow } }

    func setHotkey(_ code: Int, _ mods: UInt32) {
        AppSettings.hotkeyKeyCode = code
        AppSettings.hotkeyModifiers = mods
        hotkeyLabel = AppSettings.hotkeyLabel
    }

    func reset() {
        AppSettings.reset()
        launchAtLogin = AppSettings.launchAtLogin
        showOnLaunch = AppSettings.showPrefsOnLaunch
        collapseOnLaunch = AppSettings.collapseOnLaunch
        autoHide = AppSettings.autoHide
        autoHideSeconds = AppSettings.autoHideSeconds
        alwaysHidden = AppSettings.alwaysHidden
        hotkeyEnabled = AppSettings.hotkeyEnabled
        hotkeyLabel = AppSettings.hotkeyLabel
        expandOnHover = AppSettings.expandOnHover
        collapseOnMouseLeave = AppSettings.collapseOnMouseLeave
        hoverDelay = AppSettings.hoverDelay
        iconStyle = AppSettings.iconStyle
        leftClick = AppSettings.leftClick
        rightClick = AppSettings.rightClick
        optionClick = AppSettings.optionClick
        hideToggle = AppSettings.hideToggleWhenCollapsed
        separatorThickness = AppSettings.separatorThickness
        notchAware = AppSettings.notchAware
        expandViaOverflowBar = AppSettings.expandViaOverflowBar
        autoCollapseOverflow = AppSettings.autoCollapseOverflow
    }
}

// MARK: - Hotkey capture (invisible first-responder host)

struct HotkeyCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (Int, UInt32) -> Void

    func makeNSView(context: Context) -> HotkeyCaptureView {
        let v = HotkeyCaptureView()
        v.onCapture = onCapture
        return v
    }

    func updateNSView(_ v: HotkeyCaptureView, context: Context) {
        v.isRecording = isRecording
        v.onCapture = onCapture
        if isRecording { v.window?.makeFirstResponder(v) }
    }
}

final class HotkeyCaptureView: NSView {
    var isRecording = false
    var onCapture: ((Int, UInt32) -> Void)?
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        if event.keyCode == UInt16(kVK_Escape) { isRecording = false; return }

        var carbon: UInt32 = 0
        let f = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if f.contains(.control) { carbon |= UInt32(controlKey) }
        if f.contains(.option)  { carbon |= UInt32(optionKey) }
        if f.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if f.contains(.command) { carbon |= UInt32(cmdKey) }
        guard carbon != 0 else { return }
        onCapture?(Int(event.keyCode), carbon)
        isRecording = false
    }
}
