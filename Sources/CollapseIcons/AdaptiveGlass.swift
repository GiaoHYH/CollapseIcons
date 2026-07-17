import SwiftUI

/// Liquid Glass on macOS 26, with a system-material fallback on earlier macOS.
/// Keep the availability boundary here so callers can use one visual API while
/// the app continues to target macOS 13.
struct AdaptiveGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(liquidGlass, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
    }

    @available(macOS 26.0, *)
    private var liquidGlass: Glass {
        var glass: Glass = .regular
        if let tint {
            glass = glass.tint(tint)
        }
        return glass.interactive(interactive)
    }
}

extension View {
    func adaptiveGlass(
        cornerRadius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(AdaptiveGlassSurface(
            cornerRadius: cornerRadius,
            tint: tint,
            interactive: interactive
        ))
    }
}
