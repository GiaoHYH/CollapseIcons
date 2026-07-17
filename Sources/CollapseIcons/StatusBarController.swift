import AppKit

/// Collapse trailing menu-bar icons by inflating a separator status item's length.
/// On notched Macs: keep icons out of the camera band; expand by jumping to the LEFT of the notch.
final class StatusBarController {
    private var autoHideTimer: Timer?
    private var hoverTimer: Timer?
    private var overflowWatchTimer: Timer?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var leaveTimer: Timer?

    private let toggle = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let separator = NSStatusBar.system.statusItem(withLength: 1)
    private var alwaysHidden: NSStatusItem?

    private var normalLen: CGFloat = 16
    private var collapsedLen: CGFloat = 2000
    private var presentingOverflow = false

    private var isCollapsed: Bool { separator.length > normalLen + 1 }

    private var positionsOK: Bool {
        guard
            let tx = toggle.button?.window?.frame.origin.x,
            let sx = separator.button?.window?.frame.origin.x
        else { return false }
        return Constant.isLTR ? tx >= sx : tx <= sx
    }

    /// The display our status items currently live on.
    private var activeScreen: NSScreen? {
        ScreenLayout.statusBarScreen(toggle: toggle, separator: separator)
    }

    /// Notch jump only when the *active* display has a notch (and setting on).
    private var notchMode: Bool {
        guard AppSettings.notchAware, let s = activeScreen else { return false }
        return ScreenLayout.hasNotch(on: s)
    }

    init() {
        updateLengths()
        setup()
        rebuildAlwaysHidden()
        setupHover()
        startOverflowWatch()

        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(alwaysHiddenChanged),
                                               name: .alwaysHiddenToggle, object: nil)

        if AppSettings.separatorsHidden { hideSeparators() }

        if AppSettings.collapseOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.collapse() }
        } else {
            // Still auto-tuck anything that lands under the notch.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.collapseOverflowIfNeeded()
            }
        }
        scheduleAutoHide()
    }

    deinit {
        autoHideTimer?.invalidate()
        hoverTimer?.invalidate()
        leaveTimer?.invalidate()
        overflowWatchTimer?.invalidate()
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        NotificationCenter.default.removeObserver(self)
    }

    func expandCollapse() {
        if presentingOverflow || OverflowBarPanel.shared.isPresenting {
            dismissOverflowBar()
            collapse()
            return
        }
        isCollapsed ? expand() : collapse()
    }

    func reloadFromSettings() {
        updateLengths()
        refreshIcons()
        rebuildAlwaysHidden()
        setupHover()
        startOverflowWatch()
        scheduleAutoHide()
        if AppSettings.separatorsHidden { hideSeparators() }
        else if !isCollapsed { showSeparators() }
        collapseOverflowIfNeeded()
    }

    // MARK: - Setup

    private func setup() {
        toggle.autosaveName = .init("ci_toggle")
        separator.autosaveName = .init("ci_sep")

        if let b = toggle.button {
            b.target = self
            b.action = #selector(pressed(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
            b.toolTip = notchMode
                ? "CollapseIcons · 点击后图标跳到刘海另一侧"
                : "CollapseIcons"
        }
        separator.button?.toolTip = "⌘-拖动：左侧折叠 · 右侧常显（避开刘海）"
        separator.menu = contextMenu()
        refreshIcons()
        separator.button?.image = IconFactory.lineImage()
        if !AppSettings.separatorsHidden { separator.length = normalLen }
    }

    private func rebuildAlwaysHidden() {
        if AppSettings.alwaysHidden {
            if alwaysHidden == nil {
                alwaysHidden = NSStatusBar.system.statusItem(withLength: normalLen)
                alwaysHidden?.autosaveName = .init("ci_always")
                alwaysHidden?.button?.image = IconFactory.lineImage(thickness: 1)
                alwaysHidden?.button?.toolTip = "永久隐藏区分隔符"
            }
            alwaysHidden?.length = AppSettings.separatorsHidden ? 0 : normalLen
        } else if let item = alwaysHidden {
            NSStatusBar.system.removeStatusItem(item)
            alwaysHidden = nil
        }
    }

    private func updateLengths() {
        let screen = activeScreen ?? NSScreen.main
        let w = screen?.frame.width ?? 1728
        // Collapse length scales to the display that hosts the bar.
        let base: CGFloat
        if let screen, ScreenLayout.hasNotch(on: screen) {
            // Only need to push past the right-safe band + a margin.
            let rightW = ScreenLayout.rightSafeRect(on: screen)?.width ?? (w * 0.4)
            base = max(400, min(rightW + 200, 3200))
        } else {
            base = max(500, min(w + 200, 4000))
        }
        collapsedLen = base
        normalLen = max(8, CGFloat(AppSettings.separatorThickness) * 8 + 4)
    }

    private func refreshIcons() {
        let collapsed = isCollapsed && !presentingOverflow
        toggle.button?.image = IconFactory.toggleImage(collapsed: collapsed)
        if let s = activeScreen {
            let label = ScreenLayout.displayLabel(for: s)
            if notchMode {
                toggle.button?.toolTip = presentingOverflow
                    ? "收起 · \(label)"
                    : "展开到刘海左侧 · \(label)"
            } else {
                toggle.button?.toolTip = presentingOverflow
                    ? "收起 · \(label)"
                    : "CollapseIcons · \(label)"
            }
        }
    }

    // MARK: - Actions

    @objc private func pressed(_ sender: NSStatusBarButton) {
        guard let e = NSApp.currentEvent else { return }
        let action: AppSettings.ClickAction
        if e.modifierFlags.contains(.option) { action = AppSettings.optionClick }
        else if e.type == .rightMouseUp { action = AppSettings.rightClick }
        else { action = AppSettings.leftClick }
        run(action)
    }

    private func run(_ action: AppSettings.ClickAction) {
        switch action {
        case .toggleCollapse: expandCollapse()
        case .toggleSeparators: toggleSeparators()
        case .openSettings: SettingsWindowController.shared.show()
        case .doNothing: break
        }
    }

    func collapse() {
        dismissOverflowBar(syncCollapse: false)
        guard !isCollapsed else {
            refreshIcons()
            return
        }
        guard positionsOK else { showSetupHint(); return }

        separator.length = collapsedLen
        if AppSettings.alwaysHidden { alwaysHidden?.length = collapsedLen }
        if AppSettings.hideToggleWhenCollapsed { toggle.isVisible = false }
        refreshIcons()
        separator.menu = contextMenu()
        autoHideTimer?.invalidate(); autoHideTimer = nil
    }

    func expand() {
        // Only jump-over-notch when the display hosting OUR bar actually has a notch.
        if notchMode && AppSettings.expandViaOverflowBar {
            showOverflowBar()
            return
        }

        guard isCollapsed else { return }
        toggle.isVisible = true
        separator.length = AppSettings.separatorsHidden ? 0 : normalLen
        if AppSettings.alwaysHidden {
            alwaysHidden?.length = AppSettings.separatorsHidden ? 0 : collapsedLen
        }
        refreshIcons()
        separator.menu = contextMenu()
        scheduleAutoHide()
        // After expanding, if this display has a notch, tuck overflow.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.collapseOverflowIfNeeded()
        }
    }

    // MARK: - Jump over notch (left-side strip)

    private func showOverflowBar() {
        toggle.isVisible = true
        presentingOverflow = true
        refreshIcons()
        separator.menu = contextMenu()
        autoHideTimer?.invalidate(); autoHideTimer = nil

        // Resolve the display *now* from our status item — not mouse, not main.
        guard let screen = activeScreen ?? NSScreen.main else { return }
        let auto = AppSettings.autoHide ? AppSettings.autoHideSeconds : nil
        let useNotchJump = ScreenLayout.hasNotch(on: screen) && AppSettings.expandViaOverflowBar

        // 1) Briefly expand menubar on this display to snapshot icons.
        // 2) Re-collapse.
        // 3) Show strip on THIS display only (left of notch if notched; else menubar strip).
        if isCollapsed {
            separator.length = AppSettings.separatorsHidden ? 0 : normalLen
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
            guard let self else { return }
            // Re-resolve in case the item moved screens mid-flight.
            let screen = self.activeScreen ?? screen

            var items = StatusItemCapture.capture(on: screen, preferLeftOfRightSafe: useNotchJump)
            if items.isEmpty {
                items = StatusItemCapture.capture(on: screen, preferLeftOfRightSafe: false)
            }

            self.separator.length = self.collapsedLen
            if AppSettings.alwaysHidden { self.alwaysHidden?.length = self.collapsedLen }

            OverflowBarPanel.shared.show(
                items: items,
                on: screen,
                autoHideAfter: auto,
                onActivate: { [weak self] item in
                    self?.activateOverflowItem(item, on: screen)
                },
                onDismiss: { [weak self] in
                    self?.presentingOverflow = false
                    self?.refreshIcons()
                    self?.separator.menu = self?.contextMenu()
                }
            )
            self.refreshIcons()
        }
    }

    /// Expand right side just long enough to deliver a real click on the original item.
    private func activateOverflowItem(_ item: OverflowItem, on screen: NSScreen) {
        // Keep strip up; momentarily expand menubar so the real status item is hittable.
        let restoreCollapsed = isCollapsed
        separator.length = AppSettings.separatorsHidden ? 0 : normalLen

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            // Prefer synthetic click at last-known frame (often still valid after expand).
            Self.postClick(at: item.frame)
            if let app = NSRunningApplication(processIdentifier: item.pid) {
                app.activate(options: [.activateIgnoringOtherApps])
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self else { return }
                // Collapse again; strip stays until user dismisses / auto-hide.
                if restoreCollapsed || AppSettings.expandViaOverflowBar {
                    self.separator.length = self.collapsedLen
                    if AppSettings.alwaysHidden { self.alwaysHidden?.length = self.collapsedLen }
                }
            }
        }
    }

    private static func postClick(at frame: CGRect) {
        let globalMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        let q = CGPoint(x: frame.midX, y: globalMaxY - frame.midY)
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: q, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: q, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(15_000)
        up?.post(tap: .cghidEventTap)
    }

    private func dismissOverflowBar(syncCollapse: Bool = true) {
        if OverflowBarPanel.shared.isPresenting {
            OverflowBarPanel.shared.dismiss()
        }
        presentingOverflow = false
        if syncCollapse {
            // Ensure still collapsed after dismissing the strip.
            if !isCollapsed {
                separator.length = collapsedLen
            }
        }
        refreshIcons()
    }

    // MARK: - Auto tuck items under notch

    private func startOverflowWatch() {
        overflowWatchTimer?.invalidate()
        overflowWatchTimer = nil
        // Always track display moves lightly; notch tuck only when enabled.
        overflowWatchTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.updateLengths()
            if AppSettings.notchAware && AppSettings.autoCollapseOverflow {
                self.collapseOverflowIfNeeded()
            }
            // Keep tooltip / menu in sync when status bar migrates across displays.
            self.refreshIcons()
        }
    }

    /// If our separator sits too far left (icons would spill under the notch), collapse.
    private func collapseOverflowIfNeeded() {
        guard AppSettings.notchAware, AppSettings.autoCollapseOverflow else { return }
        guard !presentingOverflow, !OverflowBarPanel.shared.isPresenting else { return }
        // Only the display that owns our status items matters.
        guard let screen = activeScreen, ScreenLayout.hasNotch(on: screen) else { return }

        if !isCollapsed {
            if let sepFrame = separator.button?.window?.frame, ScreenLayout.isObscuredByNotch(sepFrame, on: screen) {
                collapse()
                return
            }
            if let toggleFrame = toggle.button?.window?.frame, ScreenLayout.isObscuredByNotch(toggleFrame, on: screen) {
                collapse()
                return
            }
            if let sx = separator.button?.window?.frame.midX,
               let right = ScreenLayout.rightSafeRect(on: screen),
               sx < right.minX + 8 {
                collapse()
                return
            }
        }
    }

    private func toggleSeparators() {
        AppSettings.separatorsHidden ? showSeparators() : hideSeparators()
        if isCollapsed { expand() }
    }

    private func showSeparators() {
        AppSettings.separatorsHidden = false
        if !isCollapsed { separator.length = normalLen }
        if AppSettings.alwaysHidden {
            alwaysHidden?.length = isCollapsed ? collapsedLen : normalLen
        }
    }

    private func hideSeparators() {
        AppSettings.separatorsHidden = true
        if !isCollapsed { separator.length = 0 }
        alwaysHidden?.length = 0
    }

    private func scheduleAutoHide() {
        autoHideTimer?.invalidate(); autoHideTimer = nil
        guard AppSettings.autoHide, !isCollapsed, !presentingOverflow else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: AppSettings.autoHideSeconds, repeats: false) { [weak self] _ in
            self?.collapse()
        }
    }

    private func setupHover() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor); self.mouseMonitor = nil }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor); self.localMouseMonitor = nil }
        hoverTimer?.invalidate(); hoverTimer = nil
        leaveTimer?.invalidate(); leaveTimer = nil

        // Always install monitors when hover-expand OR leave-collapse is on.
        guard AppSettings.expandOnHover || AppSettings.collapseOnMouseLeave else { return }

        let handler: (NSEvent) -> Void = { [weak self] _ in
            self?.onMouseMove()
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged],
            handler: handler
        )
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { event in
            handler(event)
            return event
        }
    }

    private func onMouseMove() {
        let mouse = NSEvent.mouseLocation
        let overBar = isMouseInMenuBar(mouse) || isMouseOverOurItems(mouse) || isMouseOverOverflowStrip(mouse)

        // —— Expand on hover ——
        if AppSettings.expandOnHover, overBar, !presentingOverflow, isCollapsed {
            leaveTimer?.invalidate(); leaveTimer = nil
            if hoverTimer == nil {
                hoverTimer = Timer.scheduledTimer(
                    withTimeInterval: AppSettings.hoverDelay,
                    repeats: false
                ) { [weak self] _ in
                    guard let self else { return }
                    self.hoverTimer = nil
                    // Still over the bar?
                    let m = NSEvent.mouseLocation
                    if self.isMouseInMenuBar(m) || self.isMouseOverOurItems(m) {
                        self.expand()
                    }
                }
            }
        } else if !overBar {
            hoverTimer?.invalidate(); hoverTimer = nil
        }

        // —— Collapse when leaving menubar ——
        if AppSettings.collapseOnMouseLeave {
            let expanded = !isCollapsed || presentingOverflow || OverflowBarPanel.shared.isPresenting
            if expanded && !overBar {
                if leaveTimer == nil {
                    leaveTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                        guard let self else { return }
                        self.leaveTimer = nil
                        let m = NSEvent.mouseLocation
                        let stillOut = !(self.isMouseInMenuBar(m) || self.isMouseOverOurItems(m) || self.isMouseOverOverflowStrip(m))
                        guard stillOut else { return }
                        if OverflowBarPanel.shared.isPresenting {
                            self.dismissOverflowBar(syncCollapse: true)
                        }
                        if !self.isCollapsed {
                            self.collapse()
                        }
                    }
                }
            } else if overBar {
                leaveTimer?.invalidate(); leaveTimer = nil
            }
        }
    }

    private func isMouseOverOurItems(_ mouse: NSPoint) -> Bool {
        for item in [toggle, separator, alwaysHidden].compactMap({ $0 }) {
            guard let w = item.button?.window else { continue }
            if w.frame.insetBy(dx: -10, dy: -8).contains(mouse) { return true }
        }
        return false
    }

    private func isMouseOverOverflowStrip(_ mouse: NSPoint) -> Bool {
        guard OverflowBarPanel.shared.isPresenting else { return false }
        return OverflowBarPanel.shared.frame.insetBy(dx: -6, dy: -6).contains(mouse)
    }

    /// True when cursor is in the menu-bar band of the screen that hosts our status items.
    private func isMouseInMenuBar(_ mouse: NSPoint) -> Bool {
        guard let screen = activeScreen ?? ScreenLayout.screen(containing: CGRect(origin: mouse, size: CGSize(width: 1, height: 1))) else {
            return false
        }
        // Only react on the display that owns our bar (multi-display safe).
        if let active = activeScreen,
           ScreenLayout.displayID(of: active) != ScreenLayout.displayID(of: screen) {
            return false
        }
        let h = ScreenLayout.menuBarHeight(on: screen) + 4
        let band = CGRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - h,
            width: screen.frame.width,
            height: h
        )
        // On notched screens, expand when hovering either left or right safe band
        // (and a bit of the center so moving across the notch still counts).
        if ScreenLayout.hasNotch(on: screen) {
            if let left = ScreenLayout.leftSafeRect(on: screen), left.insetBy(dx: -4, dy: -4).contains(mouse) {
                return true
            }
            if let right = ScreenLayout.rightSafeRect(on: screen), right.insetBy(dx: -4, dy: -4).contains(mouse) {
                return true
            }
            // Small pad over notch so cursor path doesn't cancel expand mid-flight.
            if let notch = ScreenLayout.notchRect(on: screen), notch.insetBy(dx: 0, dy: -4).contains(mouse) {
                return true
            }
            return band.contains(mouse)
        }
        return band.contains(mouse)
    }

    private func contextMenu() -> NSMenu {
        let m = NSMenu()
        let title: String
        if presentingOverflow { title = "收起展开条" }
        else { title = isCollapsed ? "展开图标" : "折叠图标" }
        let t = NSMenuItem(title: title, action: #selector(menuToggle), keyEquivalent: "")
        t.target = self; m.addItem(t)

        let a = NSMenuItem(title: AppSettings.autoHide ? "关闭自动折叠" : "开启自动折叠", action: #selector(menuAuto), keyEquivalent: "")
        a.target = self; m.addItem(a)

        if let s = activeScreen, ScreenLayout.hasNotch(on: s) {
            let n = NSMenuItem(
                title: AppSettings.expandViaOverflowBar ? "改为在右侧菜单栏展开" : "改为跳到刘海左侧展开",
                action: #selector(menuToggleOverflowMode),
                keyEquivalent: ""
            )
            n.target = self
            m.addItem(n)
        }

        if let s = activeScreen {
            let info = NSMenuItem(title: "当前屏：\(ScreenLayout.displayLabel(for: s))", action: nil, keyEquivalent: "")
            info.isEnabled = false
            m.addItem(info)
        }

        m.addItem(.separator())
        let s = NSMenuItem(title: "设置…", action: #selector(menuSettings), keyEquivalent: ",")
        s.target = self; m.addItem(s)
        m.addItem(.separator())
        let q = NSMenuItem(title: "退出 CollapseIcons", action: #selector(menuQuit), keyEquivalent: "q")
        q.target = self; m.addItem(q)
        return m
    }

    @objc private func menuToggle() { expandCollapse(); separator.menu = contextMenu() }
    @objc private func menuAuto() { AppSettings.autoHide.toggle(); separator.menu = contextMenu() }
    @objc private func menuSettings() { SettingsWindowController.shared.show() }
    @objc private func menuQuit() { NSApp.terminate(nil) }
    @objc private func menuToggleOverflowMode() {
        AppSettings.expandViaOverflowBar.toggle()
        separator.menu = contextMenu()
    }

    @objc private func screenChanged() {
        // Displays reconfigured / menu bar moved — drop strip and re-fit to new screen.
        if OverflowBarPanel.shared.isPresenting {
            dismissOverflowBar(syncCollapse: true)
        }
        updateLengths()
        if isCollapsed { separator.length = collapsedLen }
        collapseOverflowIfNeeded()
        refreshIcons()
        separator.menu = contextMenu()
    }

    @objc private func alwaysHiddenChanged() {
        rebuildAlwaysHidden()
        updateLengths()
    }

    private func showSetupHint() {
        let a = NSAlert()
        a.messageText = "调整状态栏顺序"
        let notchTip: String
        if let s = activeScreen, ScreenLayout.hasNotch(on: s) {
            notchTip = "\n\n当前屏 \(ScreenLayout.displayLabel(for: s))\n请把 | 与 ▶ 放在刘海右侧；展开时隐藏图标跳到刘海左侧。"
        } else if let s = activeScreen {
            notchTip = "\n\n当前屏 \(ScreenLayout.displayLabel(for: s))（无刘海，使用常规展开）"
        } else {
            notchTip = ""
        }
        a.informativeText = """
        按住 ⌘ 拖动图标，从左到右：

        [可折叠…]  |  [常显…]  ▶
        \(notchTip)
        """
        a.alertStyle = .informational
        a.addButton(withTitle: "知道了")
        a.addButton(withTitle: "打开设置")
        if a.runModal() == .alertSecondButtonReturn {
            SettingsWindowController.shared.show()
        }
    }
}
