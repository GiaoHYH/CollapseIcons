import AppKit
import CoreGraphics

/// Per-display menu-bar geometry. Always resolve against the screen that
/// actually hosts our status items — never assume the built-in / main display.
enum ScreenLayout {

    // MARK: - Display identity

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return CGDirectDisplayID(num?.uint32Value ?? 0)
    }

    static func isBuiltin(_ screen: NSScreen) -> Bool {
        CGDisplayIsBuiltin(displayID(of: screen)) != 0
    }

    // MARK: - Which screen owns the menu bar / our items

    /// Screen that currently hosts a given status item window.
    static func screen(for item: NSStatusItem) -> NSScreen? {
        guard let frame = item.button?.window?.frame else { return nil }
        return screen(containing: frame)
    }

    /// Prefer intersection with the status-item frame; fall back to mid-point hit test.
    /// Returns nil when the frame cannot be associated with a connected display.
    static func screen(containing frame: CGRect) -> NSScreen? {
        let inset = frame.insetBy(dx: -1, dy: -1)
        // Highest vertical overlap wins (status items sit in the menubar strip).
        var best: (NSScreen, CGFloat)?
        for s in NSScreen.screens {
            let inter = s.frame.intersection(inset)
            guard !inter.isNull, inter.width > 0, inter.height > 0 else { continue }
            let score = inter.width * inter.height
            if best == nil || score > best!.1 { best = (s, score) }
        }
        if let best { return best.0 }

        let mid = CGPoint(x: frame.midX, y: frame.midY)
        if let hit = NSScreen.screens.first(where: { $0.frame.insetBy(dx: -2, dy: -2).contains(mid) }) {
            return hit
        }
        return nil
    }

    /// The display our status items currently live on.
    /// Layout callers must retain their last confirmed screen when this is nil rather
    /// than guessing from the mouse position or the main display.
    static func statusBarScreen(toggle: NSStatusItem? = nil, separator: NSStatusItem? = nil) -> NSScreen? {
        if let toggle, let s = screen(for: toggle) { return s }
        if let separator, let s = screen(for: separator) { return s }
        return nil
    }

    // MARK: - Notch / safe areas (always pass the target screen)

    static func hasNotch(on screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            if screen.safeAreaInsets.top > 0 { return true }
            if screen.auxiliaryTopLeftArea != nil || screen.auxiliaryTopRightArea != nil { return true }
        }
        return false
    }

    static func menuBarHeight(on screen: NSScreen) -> CGFloat {
        // Prefer auxiliary area height when present (matches notch menubar precisely).
        if #available(macOS 12.0, *) {
            if let l = screen.auxiliaryTopLeftArea { return max(l.height, 24) }
            if let r = screen.auxiliaryTopRightArea { return max(r.height, 24) }
        }
        let h = screen.frame.maxY - screen.visibleFrame.maxY
        return h > 0 ? h : 24
    }

    /// Left of notch — free menubar band (AppKit coords, screen-local global space).
    static func leftSafeRect(on screen: NSScreen) -> CGRect? {
        if #available(macOS 12.0, *), let r = screen.auxiliaryTopLeftArea {
            return r
        }
        guard hasNotch(on: screen), let notch = notchRect(on: screen) else { return nil }
        let h = menuBarHeight(on: screen)
        return CGRect(x: screen.frame.minX, y: screen.frame.maxY - h,
                      width: max(0, notch.minX - screen.frame.minX), height: h)
    }

    /// Right of notch — status-item band.
    static func rightSafeRect(on screen: NSScreen) -> CGRect? {
        if #available(macOS 12.0, *), let r = screen.auxiliaryTopRightArea {
            return r
        }
        guard hasNotch(on: screen), let notch = notchRect(on: screen) else { return nil }
        let h = menuBarHeight(on: screen)
        return CGRect(x: notch.maxX, y: screen.frame.maxY - h,
                      width: max(0, screen.frame.maxX - notch.maxX), height: h)
    }

    /// Camera / notch band between left and right safe areas.
    static func notchRect(on screen: NSScreen) -> CGRect? {
        if #available(macOS 12.0, *) {
            if let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
                let h = max(l.height, r.height)
                let y = max(l.minY, r.minY)
                return CGRect(x: l.maxX, y: y, width: max(0, r.minX - l.maxX), height: h)
            }
            if screen.safeAreaInsets.top > 0 {
                let h = menuBarHeight(on: screen)
                let mid = screen.frame.midX
                let half: CGFloat = 100
                return CGRect(x: mid - half, y: screen.frame.maxY - h, width: half * 2, height: h)
            }
        }
        return nil
    }

    static func notchXRange(on screen: NSScreen) -> ClosedRange<CGFloat>? {
        guard let n = notchRect(on: screen), n.width > 0 else { return nil }
        return n.minX...n.maxX
    }

    /// Strip frame on the LEFT of the notch (same menubar row), clamped to that screen only.
    static func leftOfNotchStripFrame(width: CGFloat, on screen: NSScreen) -> CGRect {
        let h = menuBarHeight(on: screen)
        let y = screen.frame.maxY - h
        guard let left = leftSafeRect(on: screen) else {
            let w = min(width, max(120, screen.frame.width * 0.4))
            return CGRect(x: screen.frame.minX + 8, y: y, width: w, height: h)
        }
        let pad: CGFloat = 4
        let maxW = max(80, left.width - pad * 2)
        let w = min(max(width, 100), maxW)
        let x = left.maxX - w - pad
        return CGRect(
            x: max(left.minX + pad, x),
            y: left.minY,
            width: w,
            height: left.height > 0 ? left.height : h
        )
    }

    /// For non-notched displays: a right-aligned strip just under/in the menubar
    /// near the status items (classic expand affordance).
    static func rightStatusStripFrame(width: CGFloat, anchorX: CGFloat?, on screen: NSScreen) -> CGRect {
        let h = menuBarHeight(on: screen)
        let y = screen.frame.maxY - h
        let maxW = max(120, screen.frame.width - 16)
        let w = min(max(width, 120), maxW)
        let preferred = (anchorX ?? screen.frame.maxX - 80) - w
        let x = min(max(preferred, screen.frame.minX + 8), screen.frame.maxX - w - 8)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    static func isObscuredByNotch(_ frame: CGRect, on screen: NSScreen) -> Bool {
        guard hasNotch(on: screen) else { return false }
        if let notch = notchRect(on: screen), frame.intersects(notch.insetBy(dx: -2, dy: 0)) {
            return true
        }
        if let right = rightSafeRect(on: screen), frame.midX < right.minX {
            return true
        }
        return false
    }

    /// Human-readable label for settings / tooltips.
    static func displayLabel(for screen: NSScreen) -> String {
        let name = screen.localizedName
        let notch = hasNotch(on: screen) ? " · 刘海" : ""
        let builtin = isBuiltin(screen) ? " · 内建" : ""
        return "\(name)\(builtin)\(notch)"
    }
}
