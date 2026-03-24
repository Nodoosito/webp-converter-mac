import AppKit
import SwiftUI

//@main
struct WebPConverterMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = ConversionViewModel()
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = ""
    @AppStorage("appearanceMode") private var appearanceMode = 0

    private var effectiveLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage).map { $0 } ?? .fallback
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case 1:
            return .light
        case 2:
            return .dark
        default:
            return nil
        }
    }

    var body: some Scene {
        WindowGroup(L10n.text("app.window.title", language: effectiveLanguage)) {
            Group {
                if selectedLanguage.isEmpty {
                    LanguageSelectionView(selectedLanguage: $selectedLanguage)
                        .environment(\.locale, .init(identifier: effectiveLanguage.rawValue))
                } else {
                    ContentView(viewModel: viewModel)
                        .environment(\.locale, .init(identifier: effectiveLanguage.rawValue))
                }
            }
            .preferredColorScheme(preferredColorScheme)
            .frame(minWidth: 960, minHeight: 680)
            .background(MainWindowConfigurator())
        }
        .windowResizability(.contentSize)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            AppDelegate.makeMainWindowKeyAndFront()
        }
    }

    @MainActor
    static func makeMainWindowKeyAndFront() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeKey && $0.isVisible })
            ?? NSApp.mainWindow
            ?? NSApp.windows.first else {
            return
        }

        window.title = L10n.text("app.window.title", language: .current)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MainWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        Task { @MainActor in
            AppDelegate.makeMainWindowKeyAndFront()
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            guard let window = nsView.window else { return }

            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }

            window.title = L10n.text("app.window.title", language: .current)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unifiedCompact

            if !window.isKeyWindow {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
