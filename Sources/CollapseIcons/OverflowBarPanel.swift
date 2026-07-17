import AppKit
import SwiftUI

/// Thin strip drawn *in the menu-bar band*, on the LEFT of the notch —
/// so hidden icons "jump over" the camera to the other side.
final class OverflowBarPanel: NSPanel {
    static let shared = OverflowBarPanel()

    private var dismissTimer: Timer?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var onDismiss: (() -> Void)?
    private var onActivate: ((OverflowItem) -> Void)?

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 32),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        // Above menu bar windows so we're clickable, still looks like menubar chrome.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
    }

    func show(
        items: [OverflowItem],
        on screen: NSScreen,
        autoHideAfter: TimeInterval?,
        onActivate: ((OverflowItem) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.onDismiss = onDismiss
        self.onActivate = onActivate

        // Bind panel to the target display's space.
        if let sid = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            // Keep panel on the same display as status items.
            _ = sid
        }

        let model = OverflowBarModel(items: items, screen: screen)
        let root = OverflowBarView(model: model,
                                   onActivate: { [weak self] item in self?.onActivate?(item) },
                                   onClose: { [weak self] in self?.dismiss() })
        let host = NSHostingView(rootView: root)
        contentView = host

        let notched = ScreenLayout.hasNotch(on: screen)
        let height = ScreenLayout.menuBarHeight(on: screen)
        let fitting = host.fittingSize

        func place(width rawW: CGFloat) -> CGRect {
            if notched {
                let leftW = ScreenLayout.leftSafeRect(on: screen)?.width ?? screen.frame.width * 0.4
                let w = min(max(rawW, 100), max(80, leftW - 8))
                let f = ScreenLayout.leftOfNotchStripFrame(width: w, on: screen)
                return CGRect(x: f.minX, y: f.minY, width: w, height: height)
            } else {
                // External / no-notch: sit in the menubar near the status items (right side).
                let maxW = screen.frame.width - 16
                let w = min(max(rawW, 120), maxW)
                // Anchor near right edge of this screen's menubar.
                let anchor = screen.frame.maxX - 40
                let f = ScreenLayout.rightStatusStripFrame(width: w, anchorX: anchor, on: screen)
                return CGRect(x: f.minX, y: f.minY, width: w, height: height)
            }
        }

        setFrame(place(width: fitting.width + 6), display: true)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setFrame(place(width: host.fittingSize.width + 6), display: true)
        }

        // Ensure we're on the correct screen's coordinate space after layout.
        orderFrontRegardless()
        installClickOutside()

        dismissTimer?.invalidate()
        if let autoHideAfter, autoHideAfter > 0 {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: autoHideAfter, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        dismissTimer?.invalidate(); dismissTimer = nil
        removeClickOutside()
        orderOut(nil)
        contentView = nil
        onActivate = nil
        let cb = onDismiss
        onDismiss = nil
        cb?()
    }

    var isPresenting: Bool { isVisible }

    private func installClickOutside() {
        removeClickOutside()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] e in
            self?.handleClick(e); return e
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] e in
            self?.handleClick(e)
        }
    }

    private func removeClickOutside() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
    }

    private func handleClick(_ event: NSEvent) {
        let screenPoint: NSPoint
        if let w = event.window {
            screenPoint = w.convertPoint(toScreen: event.locationInWindow)
        } else {
            screenPoint = NSEvent.mouseLocation
        }
        // Clicks on our strip are fine; anything else dismisses.
        if !frame.insetBy(dx: -2, dy: -2).contains(screenPoint) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                self?.dismiss()
            }
        } else {
            // User is interacting — reset auto-hide.
            if AppSettings.autoHide {
                dismissTimer?.invalidate()
                dismissTimer = Timer.scheduledTimer(withTimeInterval: AppSettings.autoHideSeconds, repeats: false) { [weak self] _ in
                    self?.dismiss()
                }
            }
        }
    }
}

// MARK: - Capture

struct OverflowItem: Identifiable {
    let id: CGWindowID
    let name: String
    let image: NSImage?
    let frame: CGRect
    let pid: pid_t
}

enum StatusItemCapture {
    static func capture(on screen: NSScreen, preferLeftOfRightSafe: Bool = true) -> [OverflowItem] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return [] }

        let mbH = ScreenLayout.menuBarHeight(on: screen)
        let mbTop = screen.frame.maxY
        let mbBottom = mbTop - mbH - 4
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let globalMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? mbTop
        let right = ScreenLayout.rightSafeRect(on: screen)

        var items: [OverflowItem] = []
        for win in list {
            guard
                let layer = win[kCGWindowLayer as String] as? Int,
                (20...25).contains(layer),
                let bounds = win[kCGWindowBounds as String] as? [String: CGFloat],
                let pid = win[kCGWindowOwnerPID as String] as? pid_t,
                pid != ownPID,
                let number = win[kCGWindowNumber as String] as? UInt32
            else { continue }

            let qx = bounds["X"] ?? 0
            let qy = bounds["Y"] ?? 0
            let qw = bounds["Width"] ?? 0
            let qh = bounds["Height"] ?? 0
            guard qw >= 8, qw <= 72, qh >= 10, qh <= 36 else { continue }

            let frame = CGRect(x: qx, y: globalMaxY - qy - qh, width: qw, height: qh)
            // Must belong to THIS screen only (multi-display safe).
            guard screen.frame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: frame.midX, y: frame.midY)) else { continue }
            guard frame.midY >= mbBottom, frame.midY <= mbTop + 2 else { continue }

            if preferLeftOfRightSafe, let right {
                // Keep only items that sit left of (or at the start of) the right safe zone —
                // i.e. the ones that would be under/near the notch or in the collapsible pack.
                if frame.minX >= right.minX + 24 { continue }
            }

            let owner = (win[kCGWindowOwnerName as String] as? String) ?? "App"
            let title = win[kCGWindowName as String] as? String
            let name = (title?.isEmpty == false ? title! : owner)
            let image = snapshot(CGWindowID(number), CGSize(width: qw, height: qh))
            items.append(OverflowItem(id: CGWindowID(number), name: name, image: image, frame: frame, pid: pid))
        }

        items.sort { $0.frame.minX < $1.frame.minX }
        var deduped: [OverflowItem] = []
        for item in items {
            if let last = deduped.last, abs(last.frame.midX - item.frame.midX) < 3 { continue }
            deduped.append(item)
        }
        return deduped
    }

    private static func snapshot(_ id: CGWindowID, _ size: CGSize) -> NSImage? {
        guard let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .nominalResolution]) else {
            return nil
        }
        return NSImage(cgImage: cg, size: size)
    }
}

// MARK: - Model / View

@MainActor
final class OverflowBarModel: ObservableObject {
    @Published var items: [OverflowItem]
    let hasNotch: Bool

    init(items: [OverflowItem], screen: NSScreen) {
        self.items = items
        self.hasNotch = ScreenLayout.hasNotch(on: screen)
    }
}

struct OverflowBarView: View {
    @ObservedObject var model: OverflowBarModel
    var onActivate: (OverflowItem) -> Void
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Leading chevron hints "continued from the other side of the notch"
            Image(systemName: "chevron.compact.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.45))
                .padding(.leading, 6)
                .padding(.trailing, 2)

            if model.items.isEmpty {
                Text(model.hasNotch ? "无隐藏图标" : "无溢出图标")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .padding(.horizontal, 8)
            } else {
                HStack(spacing: 2) {
                    ForEach(model.items) { item in
                        Button {
                            onActivate(item)
                        } label: {
                            Group {
                                if let image = item.image {
                                    Image(nsImage: image)
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 12))
                                }
                            }
                            .frame(width: 26, height: 24)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(item.name)
                    }
                }
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.45))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
            .padding(.trailing, 6)
            .help("收起")
        }
        .frame(height: 28)
        .background(
            VisualEffectBackground(material: .menu, blending: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }
}

/// AppKit material behind SwiftUI content — matches real menu bar chrome.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .followsWindowActiveState
        v.isEmphasized = true
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}
