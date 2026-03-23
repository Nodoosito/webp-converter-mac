import AppKit
import SwiftUI

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue)
    }

    static var nodooBackground: Color { Color(hex: "#050912") }
    static var nodooAccent: Color { Color(hex: "#8db3ce") }
    static var nodooSecondary: Color { Color(hex: "#4b708c") }
    static var nodooText: Color { Color(hex: "#e6e8e9") }
}

extension ShapeStyle where Self == Color {
    static var nodooBackground: Color { Color(hex: "#050912") }
    static var nodooAccent: Color { Color(hex: "#8db3ce") }
    static var nodooSecondary: Color { Color(hex: "#4b708c") }
    static var nodooText: Color { Color(hex: "#e6e8e9") }
}

struct WindowBlurView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var emphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = emphasized
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = emphasized
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var fillOpacity: Double = 0.14
    var strokeOpacity: Double = 0.2

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background(
                WindowBlurView(material: .hudWindow, blendingMode: .withinWindow)
                    .overlay(
                        shape
                            .fill(Color.white.opacity(fillOpacity))
                    )
                    .clipShape(shape)
            )
            .overlay(
                shape
                    .stroke(Color.nodooSecondary.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, fillOpacity: Double = 0.14, strokeOpacity: Double = 0.2) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, fillOpacity: fillOpacity, strokeOpacity: strokeOpacity))
    }
}
