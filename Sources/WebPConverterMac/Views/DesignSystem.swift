import AppKit
import SwiftUI

extension Color {
    static let nodooBackground = Color("nodooBackground", bundle: .module)
    static let nodooAccent = Color("nodooAccent", bundle: .module)
    static let nodooSecondary = Color("nodooSecondary", bundle: .module)
    static let nodooText = Color("nodooText", bundle: .module)

    static let nodooAdaptiveText = Color(
        nsColor: NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            switch bestMatch {
            case .aqua:
                return NSColor(calibratedRed: 11 / 255, green: 19 / 255, blue: 32 / 255, alpha: 1)
            default:
                return NSColor(named: NSColor.Name("nodooText"), bundle: .module)
                    ?? NSColor(calibratedWhite: 0.91, alpha: 1)
            }
        }
    )
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
