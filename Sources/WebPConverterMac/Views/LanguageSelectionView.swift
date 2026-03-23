import SwiftUI

struct LanguageSelectionView: View {
    @Binding var selectedLanguage: String

    var body: some View {
        ZStack {
            Color.nodooBackground
                .ignoresSafeArea()

            WindowBlurView(material: .underWindowBackground)
                .ignoresSafeArea()
                .opacity(0.88)

            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text(L10n.text("app.name"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(L10n.text("language.selection.title"))
                        .font(.title3.weight(.semibold))
                    Text(L10n.text("language.selection.subtitle"))
                        .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                HStack(spacing: 16) {
                    languageButton(code: AppLanguage.fr.rawValue, title: L10n.text("language.selection.french"))
                    languageButton(code: AppLanguage.en.rawValue, title: L10n.text("language.selection.english"))
                }
            }
            .padding(36)
            .glassCard(cornerRadius: 28, fillOpacity: 0.14)
            .padding(32)
        }
        .foregroundStyle(.nodooAdaptiveText)
        .tint(.nodooAccent)
    }

    private func languageButton(code: String, title: String) -> some View {
        Button {
            selectedLanguage = code
        } label: {
            Text(title)
                .frame(minWidth: 180)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.nodooAccent)
    }
}
