import AppKit

enum IconFactory {
    static func toggleImage(collapsed: Bool, style: AppSettings.IconStyle = AppSettings.iconStyle) -> NSImage {
        let name: String
        switch style {
        case .chevron:
            name = collapsed
                ? (Constant.isLTR ? "chevron.left" : "chevron.right")
                : (Constant.isLTR ? "chevron.right" : "chevron.left")
        case .arrows:
            name = collapsed ? "arrow.left.to.line.compact" : "arrow.right.to.line.compact"
        case .dots:
            name = collapsed ? "ellipsis" : "rectangle.split.2x1"
        case .minus:
            name = collapsed ? "plus" : "minus"
        case .eye:
            name = collapsed ? "eye" : "eye.slash"
        }
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            img.isTemplate = true
            return img
        }
        return lineImage(thickness: 2)
    }

    static func lineImage(thickness: Double = AppSettings.separatorThickness) -> NSImage {
        let w = max(1, min(thickness, 4))
        let img = NSImage(size: NSSize(width: w + 4, height: 16), flipped: false) { rect in
            let r = NSRect(x: (rect.width - w) / 2, y: 2, width: w, height: rect.height - 4)
            NSColor.labelColor.withAlphaComponent(0.55).setFill()
            NSBezierPath(roundedRect: r, xRadius: w / 2, yRadius: w / 2).fill()
            return true
        }
        img.isTemplate = true
        return img
    }
}
