import SwiftUI

extension View {
    /// Liquid Glass on macOS 26, with a system-material fallback on earlier macOS.
    @ViewBuilder
    func adaptiveGlass(
        cornerRadius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(macOS 26.0, *) {
            let glass = (tint.map { Glass.regular.tint($0) } ?? .regular).interactive(interactive)
            self.glassEffect(glass, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(.ultraThinMaterial))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
    }
}
