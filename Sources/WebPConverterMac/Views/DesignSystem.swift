import AppKit
import SwiftUI

extension Color {
    static let nodooBackground = Color("nodooBackground", bundle: .module)
    static let nodooAccent = Color("nodooAccent", bundle: .module)
    static let nodooSecondary = Color("nodooSecondary", bundle: .module)
    static let nodooText = Color("nodooText", bundle: .module)
}

extension ShapeStyle where Self == Color {
    static var nodooAdaptiveText: Color {
        Color(nsColor: NSColor { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            switch bestMatch {
            case .aqua:
                return NSColor(calibratedRed: 11 / 255, green: 19 / 255, blue: 32 / 255, alpha: 1)
            default:
                return NSColor(named: NSColor.Name("nodooText"), bundle: .module) ?? NSColor(calibratedWhite: 0.91, alpha: 1)
            }
        })
    }
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

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    WindowBlurView(material: .hudWindow, blendingMode: .withinWindow)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(fillOpacity))
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.nodooSecondary.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, fillOpacity: Double = 0.14, strokeOpacity: Double = 0.2) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, fillOpacity: fillOpacity, strokeOpacity: strokeOpacity))
    }
}
