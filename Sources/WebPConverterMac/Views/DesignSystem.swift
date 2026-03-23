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

    static var nodooBackground: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
                if bestMatch == .darkAqua {
                    return NSColor(calibratedRed: 5 / 255, green: 9 / 255, blue: 18 / 255, alpha: 1)
                }

                return NSColor(calibratedRed: 243 / 255, green: 246 / 255, blue: 250 / 255, alpha: 1)
            }
        )
    }

    static var nodooAccent: Color { Color(hex: "#8db3ce") }
    static var nodooSecondary: Color { Color(hex: "#4b708c") }

    static var nodooText: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
                if bestMatch == .darkAqua {
                    return NSColor.white
                }

                return NSColor(calibratedRed: 11 / 255, green: 19 / 255, blue: 32 / 255, alpha: 1)
            }
        )
    }
}

extension ShapeStyle where Self == Color {
    static var nodooBackground: Color { Color.nodooBackground }
    static var nodooAccent: Color { Color.nodooAccent }
    static var nodooSecondary: Color { Color.nodooSecondary }
    static var nodooText: Color { Color.nodooText }
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
    var fillOpacity: Double = 0.08
    var strokeOpacity: Double = 0.2

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background(.thinMaterial, in: shape)
            .overlay(
                shape
                    .fill(Color.white.opacity(fillOpacity))
            )
            .overlay(
                shape
                    .stroke(Color.nodooSecondary.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, fillOpacity: Double = 0.08, strokeOpacity: Double = 0.2) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, fillOpacity: fillOpacity, strokeOpacity: strokeOpacity))
    }
}
