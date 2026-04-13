import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ConversionViewModel
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = AppLanguage.fallback.rawValue
    @AppStorage("appTheme") private var appTheme: Int = 0

    @State private var presetPendingDeletion: ConversionPreset?
    @State private var presetNameInput = ""
    @State private var percentageInput = "100"
    @State private var widthInput = "1920"
    @State private var heightInput = "1080"
    @State private var isQualityHelpPresented = false
    @State private var isMetadataHelpPresented = false
    @State private var isSuffixHelpPresented = false
    @State private var isResizeHelpPresented = false
    @State private var showSettings = false
    @State private var previewSplit: CGFloat = 0.5
    private let sectionSpacing: CGFloat = 16

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .fallback
    }

    var body: some View {
        VStack(spacing: sectionSpacing) {

            HeaderView(
                onAddFiles: {
                    viewModel.addFilesFromPanel()
                },
                onSettings: {
                    showSettings = true
                },
                appTheme: $appTheme
            )

            GeometryReader { proxy in
                let sidebarWidth = max(300, min(360, proxy.size.width * 0.28))

                HStack(alignment: .top, spacing: sectionSpacing) {
                    SidebarSettings(
                        viewModel: viewModel,
                        currentLanguage: currentLanguage,
                        presetPendingDeletion: $presetPendingDeletion,
                        presetNameInput: $presetNameInput,
                        percentageInput: $percentageInput,
                        widthInput: $widthInput,
                        heightInput: $heightInput,
                        isQualityHelpPresented: $isQualityHelpPresented,
                        isMetadataHelpPresented: $isMetadataHelpPresented,
                        isSuffixHelpPresented: $isSuffixHelpPresented,
                        isResizeHelpPresented: $isResizeHelpPresented,
                        commitAllResizeInputs: commitAllResizeInputs,
                        commitPercentageInput: commitPercentageInput,
                        commitWidthInput: commitWidthInput,
                        commitHeightInput: commitHeightInput
                    )
                    .frame(width: sidebarWidth)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                    VStack(spacing: sectionSpacing) {
                        listPanel
                        previewPanel
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#8DB3CE").opacity(0.35),
                    Color(hex: "#4B708C").opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )

        .onAppear {
            syncInputsFromSettings()
            ensureLanguageFallback()
        }
        .onChange(of: viewModel.settings.resizeSettings.percentage) { _ in
            syncInputsFromSettings()
        }
        .onChange(of: viewModel.settings.resizeSettings.width) { _ in
            syncInputsFromSettings()
        }
        .onChange(of: viewModel.settings.resizeSettings.height) { _ in
            syncInputsFromSettings()
        }
        .onChange(of: viewModel.settings.resizeSettings.mode) { _ in
            syncInputsFromSettings()
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
        .alert(
            L10n.text("alert.preset.delete.title", language: currentLanguage),
            isPresented: Binding(
                get: { presetPendingDeletion != nil },
                set: { if !$0 { presetPendingDeletion = nil } }
            )
        ) {
            Button(L10n.text("alert.cancel", language: currentLanguage), role: .cancel) {
                presetPendingDeletion = nil
            }
            Button(L10n.text("alert.delete", language: currentLanguage), role: .destructive) {
                guard let presetPendingDeletion else { return }
                viewModel.deletePreset(id: presetPendingDeletion.id)
                self.presetPendingDeletion = nil
            }
        } message: {
            if let presetPendingDeletion {
                Text(
                    L10n.format(
                        "alert.preset.delete.message",
                        language: currentLanguage,
                        presetPendingDeletion.localizedDisplayName
                    )
                )
            }
        }
        .alert(
            L10n.text("alert.conversion.complete.title", language: currentLanguage),
            isPresented: $viewModel.showCompletionAlert
        ) {
            Button(L10n.text("alert.ok", language: currentLanguage), role: .cancel) {}
        } message: {
            Text(
                L10n.format(
                    "alert.conversion.complete.message",
                    language: currentLanguage,
                    viewModel.formattedTotalGain
                )
            )
        }
        .sheet(isPresented: $showSettings) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.headline)

                Picker("Language", selection: $selectedLanguage) {
                    Text(L10n.text("settings.language.french", language: currentLanguage)).tag(AppLanguage.fr.rawValue)
                    Text(L10n.text("settings.language.english", language: currentLanguage)).tag(AppLanguage.en.rawValue)
                }

                HStack {
                    Button("Close") {
                        showSettings = false
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
            .frame(minWidth: 320)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text("app.header.title", language: currentLanguage))
                    .font(.title.bold())
                Text(LocalizedStringKey(L10n.text("app.header.tagline", language: currentLanguage)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            settingsMenu

            Button(L10n.text("button.add_files", language: currentLanguage)) {
                viewModel.addFilesFromPanel()
            }
        }
    }

    private var settingsMenu: some View {
        Menu {
            Section(L10n.text("settings.language.section", language: currentLanguage)) {
                Picker(L10n.text("settings.language.label", language: currentLanguage), selection: $selectedLanguage) {
                    Text(L10n.text("settings.language.french", language: currentLanguage)).tag(AppLanguage.fr.rawValue)
                    Text(L10n.text("settings.language.english", language: currentLanguage)).tag(AppLanguage.en.rawValue)
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.title3)
        }
        .menuStyle(.borderlessButton)
        .help(L10n.text("settings.menu", language: currentLanguage))
    }

    private var listPanel: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Fichiers dans la file d'attente")
                        .font(.headline)
                    Spacer()
                    Button("Effacer la file d'attente") {
                        viewModel.clearAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.items.isEmpty || viewModel.isConverting)
                }

                tableHeader

                List {
                    ForEach(viewModel.sortedItems) { item in
                        fileRow(item)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.cycleSort(for: .name)
            } label: {
                HStack(spacing: 4) {
                    Text(L10n.text("table.name", language: currentLanguage))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary.opacity(0.85))
                    Spacer(minLength: 0)
                    if let symbol = viewModel.sortIndicator(for: .name) {
                        Image(systemName: symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.cycleSort(for: .beforeSize)
            } label: {
                HStack(spacing: 4) {
                    Text(L10n.text("table.before", language: currentLanguage))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary.opacity(0.85))
                    Spacer(minLength: 0)
                    if let symbol = viewModel.sortIndicator(for: .beforeSize) {
                        Image(systemName: symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, alignment: .trailing)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.cycleSort(for: .afterSize)
            } label: {
                HStack(spacing: 4) {
                    Text(L10n.text("table.after", language: currentLanguage))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary.opacity(0.85))
                    Spacer(minLength: 0)
                    if let symbol = viewModel.sortIndicator(for: .afterSize) {
                        Image(systemName: symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, alignment: .trailing)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.cycleSort(for: .gain)
            } label: {
                HStack(spacing: 4) {
                    Text(L10n.text("table.gain", language: currentLanguage))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary.opacity(0.85))
                    Spacer(minLength: 0)
                    if let symbol = viewModel.sortIndicator(for: .gain) {
                        Image(systemName: symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, alignment: .trailing)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.cycleSort(for: .status)
            } label: {
                HStack(spacing: 4) {
                    Text(L10n.text("table.status", language: currentLanguage))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary.opacity(0.85))
                    Spacer(minLength: 0)
                    if let symbol = viewModel.sortIndicator(for: .status) {
                        Image(systemName: symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 140, alignment: .leading)
            }
            .buttonStyle(.plain)

            Text(L10n.text("table.action", language: currentLanguage))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary.opacity(0.85))
                .frame(width: 60, alignment: .center)
        }
        .frame(height: 24)
        .layoutPriority(1)
    }

    private func sortHeader(_ title: String, column: ConversionViewModel.SortColumn, width: CGFloat?, alignment: Alignment) -> some View {
        Button {
            viewModel.cycleSort(for: column)
        } label: {
            let content = HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary.opacity(0.85))
                Spacer(minLength: 0)
                if let symbol = viewModel.sortIndicator(for: column) {
                    Image(systemName: symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let width {
                content
                    .frame(width: width, alignment: alignment)
            } else {
                content
            }
        }
        .buttonStyle(.plain)
    }

    private func fileRow(_ item: FileConversionItem) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                if let image = NSImage(contentsOf: item.inputURL) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 32, height: 32)
                }

                Text(item.filename)
                    .lineLimit(1)
            }
            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

            Text(viewModel.formattedSize(item.inputSize))
                .font(.system(.body, design: .monospaced))
                .frame(width: 90, alignment: .trailing)

            Text(afterSizeText(for: item))
                .font(.system(.body, design: .monospaced))
                .frame(width: 90, alignment: .trailing)

            Text(viewModel.formattedGain(for: item))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)

            statusView(for: item.status)
                .frame(width: 140, alignment: .leading)

            Button(role: .destructive) {
                viewModel.removeItem(item)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isConverting)
            .frame(width: 60, alignment: .center)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.updateSelectedItem(id: item.id)
        }
        .frame(height: 40)
    }

    private var previewPanel: some View {
        LiquidGlassCard {
            if let originalImage = viewModel.originalPreview?.image,
               let convertedImage = viewModel.convertedPreview?.image {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Aperçu de la conversion")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)

                    GeometryReader { proxy in
                        let width = max(proxy.size.width, 1)
                        let clampedSplit = min(max(previewSplit, 0), 1)
                        let splitX = width * clampedSplit

                        ZStack(alignment: .leading) {
                            Image(nsImage: originalImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: proxy.size.width, height: proxy.size.height)

                            Image(nsImage: convertedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .mask(alignment: .trailing) {
                                    Rectangle()
                                        .frame(width: width - splitX)
                                }

                            Rectangle()
                                .fill(Color.white.opacity(0.85))
                                .frame(width: 2, height: proxy.size.height)
                                .offset(x: splitX - 1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    previewSplit = min(max(value.location.x / width, 0), 1)
                                }
                        )
                    }
                    .frame(height: 170)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Slider(value: $previewSplit, in: 0...1)
                        .tint(Color(hex: "#4B708C"))
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.4))
                    .overlay(
                        VStack(spacing: 10) {
                            Text("Aperçu de la conversion")
                                .font(.headline)
                            Text("Sélectionnez un fichier pour voir l’aperçu comparatif")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
    }

    private func afterSizeText(for item: FileConversionItem) -> String {
        switch item.status {
        case .success(_, let outputSize):
            return viewModel.formattedSize(outputSize)
        default:
            return "-"
        }
    }

    @ViewBuilder
    private func statusView(for status: FileConversionStatus) -> some View {
        switch status {
        case .pending:
            Text(L10n.text("status.pending", language: currentLanguage)).foregroundStyle(.secondary)
        case .processing:
            Text(L10n.text("status.processing", language: currentLanguage)).foregroundStyle(.orange)
        case .success:
            Text(L10n.text("status.success", language: currentLanguage)).foregroundStyle(.green)
        case .failure(let message):
            Text(message).foregroundStyle(.red).lineLimit(2)
        }
    }

    private var footer: some View {
        LiquidGlassCard {
            HStack(spacing: 12) {
                ProgressView(value: viewModel.progress)
                    .tint(Color(hex: "#4B708C"))
                    .scaleEffect(y: 0.8)
                    .frame(maxWidth: .infinity)

                HStack(spacing: sectionSpacing) {
                    Text(L10n.format("progress.label", language: currentLanguage, Int(viewModel.progress * 100)))
                        .foregroundStyle(.secondary)

                    Button(L10n.text("button.convert", language: currentLanguage)) {
                        commitAllResizeInputs()
                        viewModel.convertAll()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.items.isEmpty || viewModel.isConverting)
                }
                .frame(width: 180, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func ensureLanguageFallback() {
        if AppLanguage(rawValue: selectedLanguage) == nil {
            selectedLanguage = AppLanguage.fallback.rawValue
        }
    }

    private func digitsOnly(_ text: String) -> String {
        text.filter { $0.isNumber }
    }

    private func commitAllResizeInputs() {
        commitPercentageInput()
        commitWidthInput()
        commitHeightInput()
    }

    private func commitPercentageInput() {
        let sanitized = digitsOnly(percentageInput)
        let source = sanitized.isEmpty ? "100" : sanitized
        let value = Double(source) ?? viewModel.settings.resizeSettings.percentage
        viewModel.updatePercentage(value)
        percentageInput = String(Int(viewModel.settings.resizeSettings.percentage.rounded()))
    }

    private func commitWidthInput() {
        let sanitized = digitsOnly(widthInput)
        let source = sanitized.isEmpty ? "1" : sanitized
        let value = Double(source) ?? viewModel.settings.resizeSettings.width
        viewModel.updateWidth(value)
        widthInput = String(Int(viewModel.settings.resizeSettings.width.rounded()))
    }

    private func commitHeightInput() {
        let sanitized = digitsOnly(heightInput)
        let source = sanitized.isEmpty ? "1" : sanitized
        let value = Double(source) ?? viewModel.settings.resizeSettings.height
        viewModel.updateHeight(value)
        heightInput = String(Int(viewModel.settings.resizeSettings.height.rounded()))
    }

    private func syncInputsFromSettings() {
        percentageInput = String(Int(viewModel.settings.resizeSettings.percentage.rounded()))
        widthInput = String(Int(viewModel.settings.resizeSettings.width.rounded()))
        heightInput = String(Int(viewModel.settings.resizeSettings.height.rounded()))
    }

}
