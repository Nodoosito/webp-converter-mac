import SwiftUI

public struct LanguageSelectionView: View {
    @Binding var selectedLanguage: String

    public init(selectedLanguage: Binding<String>) {
        _selectedLanguage = selectedLanguage
    }

    public var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(L10n.text("app.name"))
                    .font(.largeTitle.bold())
                Text(L10n.text("language.selection.title"))
                    .font(.title3.weight(.semibold))
                Text(L10n.text("language.selection.subtitle"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 16) {
                languageButton(code: AppLanguage.fr.rawValue, title: L10n.text("language.selection.french"))
                languageButton(code: AppLanguage.en.rawValue, title: L10n.text("language.selection.english"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(.quaternary.opacity(0.2))
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
    }
}
