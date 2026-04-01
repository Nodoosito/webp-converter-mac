import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ConversionViewModel
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var showPresetNameField = false

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .fallback
    }

    var body: some View {
        VStack(spacing: 14) {
            HeaderView(
                addAction: viewModel.addFilesFromPanel,
                settingsMenu: settingsMenu
            )

            HStack(spacing: 20) {
                SidebarView(
                    viewModel: viewModel,
                    currentLanguage: currentLanguage,
                    presetNameInput: $presetNameInput,
                    showPresetNameField: $showPresetNameField,
                    percentageInput: $percentageInput,
                    widthInput: $widthInput,
                    heightInput: $heightInput,
                    isQualityHelpPresented: $isQualityHelpPresented,
                    isMetadataHelpPresented: $isMetadataHelpPresented,
                    isSuffixHelpPresented: $isSuffixHelpPresented,
                    isResizeHelpPresented: $isResizeHelpPresented,
                    presetPendingDeletion: $presetPendingDeletion,
                    commitAllResizeInputs: commitAllResizeInputs,
                    commitPercentageInput: commitPercentageInput,
                    commitWidthInput: commitWidthInput,
                    commitHeightInput: commitHeightInput
                )
                .frame(width: 280)

                mainPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(minWidth: 1000, minHeight: 700)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(windowBackground)
        .onAppear {
            syncInputsFromSettings()
            ensureLanguageFallback()
        }
        .onChange(of: viewModel.settings.resizeSettings.percentage) { _ in syncInputsFromSettings() }
        .onChange(of: viewModel.settings.resizeSettings.width) { _ in syncInputsFromSettings() }
        .onChange(of: viewModel.settings.resizeSettings.height) { _ in syncInputsFromSettings() }
        .onChange(of: viewModel.settings.resizeSettings.mode) { _ in syncInputsFromSettings() }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
        .alert(
            L10n.text("alert.preset.delete.title", language: currentLanguage),
            isPresented: Binding(
                get: { presetPendingDeletion != nil },
                set: { isPresented in if !isPresented { presetPendingDeletion = nil } }
            ),
            actions: {
                Button(L10n.text("alert.cancel", language: currentLanguage), role: .cancel) { presetPendingDeletion = nil }
                Button(L10n.text("alert.delete", language: currentLanguage), role: .destructive) {
                    guard let presetPendingDeletion else { return }
                    viewModel.deletePreset(id: presetPendingDeletion.id)
                    self.presetPendingDeletion = nil
                }
            },
            message: {
                if let presetPendingDeletion {
                    Text(L10n.format("alert.preset.delete.message", language: currentLanguage, presetPendingDeletion.localizedDisplayName))
                }
            }
        )
        .alert(L10n.text("alert.conversion.complete.title", language: currentLanguage), isPresented: $viewModel.showCompletionAlert) {
            Button(L10n.text("alert.ok", language: currentLanguage), role: .cancel) {}
        } message: {
            Text(L10n.format("alert.conversion.complete.message", language: currentLanguage, viewModel.formattedTotalGain))
        }
    }

    private var windowBackground: some View {
        Group {
            if colorScheme == .dark {
                Palette.darkBackground
            } else {
                LinearGradient(colors: [Palette.surfaceLight.opacity(0.7), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .ignoresSafeArea()
    }

    private var mainPanel: some View {
        VStack(spacing: 12) {
            VSplitView {
                queuePanel
                    .frame(minHeight: 220)

                comparisonPanel
                    .frame(minHeight: 300)
            }

            actionBar
        }
    }

    private var queuePanel: some View {
        VStack(spacing: 0) {
            queueHeader
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(viewModel.sortedItems) { item in
                        QueueRowView(
                            item: item,
                            onDelete: { viewModel.removeItem(item) },
                            onTap: { viewModel.updateSelectedItem(id: item.id) },
                            statusText: statusText(for: item.status),
                            beforeText: viewModel.formattedSize(item.inputSize),
                            afterText: afterSizeText(for: item),
                            gainText: viewModel.formattedGain(for: item),
                            canDelete: !viewModel.isConverting
                        )
                    }
                }
                .padding(10)
            }
        }
        .liquidCard(cornerRadius: 18)
    }

    private var queueHeader: some View {
        HStack(spacing: 10) {
            headerCell("Thumbnail", width: 56)
            headerCell("Filename", width: 260)
            headerCell("Type", width: 64)
            headerCell("Original Size", width: 110)
            headerCell("Est. After", width: 110)
            headerCell("Gain", width: 90)
            headerCell("Status", width: 190)
            headerCell("Action", width: 70)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var comparisonPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comparaison")
                .font(.headline)
                .foregroundStyle(Palette.primary)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            if viewModel.selectedItem == nil {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Text("Sélectionnez un fichier pour un aperçu comparatif")
                            .foregroundStyle(Palette.primary.opacity(0.8))
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            } else if let original = viewModel.originalPreview?.image,
                      let converted = viewModel.convertedPreview?.image {
                ComparisonSliderView(original: original, converted: converted)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(Text(viewModel.previewMessage).foregroundStyle(Palette.primary.opacity(0.75)))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .liquidCard(cornerRadius: 18)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            ProgressView(value: viewModel.progress)
                .tint(Palette.accent)
                .frame(maxWidth: .infinity)

            Text("\(Int(viewModel.progress * 100))%")
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(Palette.primary)

            Button("Annuler") { viewModel.stopConversion() }
                .disabled(!viewModel.isConverting)

            Button {
                commitAllResizeInputs()
                if viewModel.isConverting {
                    viewModel.stopConversion()
                } else {
                    viewModel.convertAll()
                }
            } label: {
                Text("Optimiser et convertir tout")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(colors: [Palette.accent, Palette.primary], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
            .disabled(viewModel.items.isEmpty)
            .buttonStyle(.plain)
        }
        .padding(14)
        .liquidCard(cornerRadius: 18)
    }

    private func headerCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.primary)
            .frame(width: width, alignment: .leading)
    }

    private func afterSizeText(for item: FileConversionItem) -> String {
        switch item.status {
        case .success(_, let outputSize):
            return viewModel.formattedSize(outputSize)
        default:
            return "-"
        }
    }

    private func statusText(for status: FileConversionStatus) -> String {
        switch status {
        case .pending: return L10n.text("status.pending", language: currentLanguage)
        case .processing: return L10n.text("status.processing", language: currentLanguage)
        case .success: return L10n.text("status.success", language: currentLanguage)
        case .failure(let message): return message
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
            Section("Theme") {
                Picker("Theme", selection: $appTheme) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(Palette.primary)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .menuStyle(.borderlessButton)
    }

    private func ensureLanguageFallback() {
        if AppLanguage(rawValue: selectedLanguage) == nil {
            selectedLanguage = AppLanguage.fallback.rawValue
        }
    }

    private func digitsOnly(_ text: String) -> String { text.filter { $0.isNumber } }

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

private struct HeaderView<SettingsMenu: View>: View {
    let addAction: () -> Void
    let settingsMenu: SettingsMenu

    var body: some View {
        HStack {
            Text("Orlo — Batch Image Converter")
                .font(.title3.weight(.bold))
                .lineLimit(1)

            Spacer()

            Button("Ajouter des fichiers", action: addAction)
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .controlSize(.large)

            settingsMenu
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var viewModel: ConversionViewModel
    let currentLanguage: AppLanguage
    @Binding var presetNameInput: String
    @Binding var showPresetNameField: Bool
    @Binding var percentageInput: String
    @Binding var widthInput: String
    @Binding var heightInput: String
    @Binding var isQualityHelpPresented: Bool
    @Binding var isMetadataHelpPresented: Bool
    @Binding var isSuffixHelpPresented: Bool
    @Binding var isResizeHelpPresented: Bool
    @Binding var presetPendingDeletion: ConversionPreset?
    let commitAllResizeInputs: () -> Void
    let commitPercentageInput: () -> Void
    let commitWidthInput: () -> Void
    let commitHeightInput: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            presetSection
            qualitySection
            metadataSection
            suffixSection
            resizeSection

            Spacer()

            outputFolderButton
        }
        .padding(18)
        .liquidCard(cornerRadius: 18)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Préréglage")
                    .foregroundStyle(Palette.primary)
                Spacer()
                Picker("", selection: Binding<UUID?>(
                    get: { viewModel.selectedPresetID },
                    set: { viewModel.applyPreset(id: $0) }
                )) {
                    Text("Actuel").tag(UUID?.none)
                    ForEach(viewModel.presets) { preset in
                        Text(viewModel.displayName(for: preset)).tag(Optional(preset.id))
                    }
                }
                .labelsHidden()
                .frame(width: 150)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPresetNameField.toggle()
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Palette.primary)
                }
                .buttonStyle(.plain)
            }

            if showPresetNameField {
                HStack(spacing: 8) {
                    TextField("Nom du préréglage", text: $presetNameInput)
                    Button("Save") {
                        commitAllResizeInputs()
                        viewModel.saveCurrentPreset(named: presetNameInput)
                        if viewModel.globalError == nil {
                            presetNameInput = ""
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showPresetNameField = false
                            }
                        }
                    }
                    .disabled(presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let selectedPreset = viewModel.selectedPreset, viewModel.canDeleteSelectedPreset {
                Button(role: .destructive) {
                    presetPendingDeletion = selectedPreset
                } label: {
                    Label("Supprimer le préréglage", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleWithInfo("Qualité webp", help: L10n.text("settings.quality.help", language: currentLanguage), isPresented: $isQualityHelpPresented)
            HStack {
                Slider(
                    value: Binding(
                        get: { viewModel.settings.quality * 100 },
                        set: { viewModel.updateQuality($0 / 100) }
                    ),
                    in: 0...100,
                    step: 1
                )
                .tint(Palette.accent)

                Text("\(Int(viewModel.settings.quality * 100))%")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Palette.primary)
            }
        }
    }

    private var metadataSection: some View {
        HStack {
            titleWithInfo(L10n.text("settings.metadata.label", language: currentLanguage), help: L10n.text("settings.metadata.help", language: currentLanguage), isPresented: $isMetadataHelpPresented)
            Spacer()
            Toggle("", isOn: Binding(
                get: { viewModel.settings.removeMetadata },
                set: { viewModel.updateRemoveMetadata($0) }
            ))
            .labelsHidden()
        }
    }

    private var suffixSection: some View {
        HStack {
            titleWithInfo(L10n.text("settings.suffix.label", language: currentLanguage), help: L10n.text("settings.suffix.help", language: currentLanguage), isPresented: $isSuffixHelpPresented)
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.settings.suffixMode },
                set: { viewModel.updateSuffixMode($0) }
            )) {
                ForEach(SuffixMode.allCases) { mode in Text(mode.localizedTitle).tag(mode) }
            }
            .labelsHidden()
            .frame(width: 120)
        }
    }

    private var resizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                titleWithInfo(L10n.text("settings.resize.label", language: currentLanguage), help: L10n.text("settings.resize.help", language: currentLanguage), isPresented: $isResizeHelpPresented)
                Spacer()
                Picker("", selection: Binding(
                    get: { viewModel.settings.resizeSettings.mode },
                    set: { viewModel.updateResizeMode($0) }
                )) {
                    ForEach(ResizeMode.allCases) { mode in Text(mode.localizedTitle).tag(mode) }
                }
                .labelsHidden()
                .frame(width: 120)
            }

            HStack {
                switch viewModel.settings.resizeSettings.mode {
                case .percentage:
                    AppKitCommitTextField(placeholder: "100", text: $percentageInput, onCommit: commitPercentageInput)
                        .frame(width: 70, height: 24)
                    Text("%")
                case .width:
                    AppKitCommitTextField(placeholder: "1920", text: $widthInput, onCommit: commitWidthInput)
                        .frame(width: 84, height: 24)
                    Text("px")
                case .height:
                    AppKitCommitTextField(placeholder: "1080", text: $heightInput, onCommit: commitHeightInput)
                        .frame(width: 84, height: 24)
                    Text("px")
                case .original:
                    Text("Original")
                }
                Spacer()
            }
        }
    }

    private var outputFolderButton: some View {
        Button {
            viewModel.selectOutputFolder()
        } label: {
            Label(outputFolderTitle, systemImage: "folder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Palette.primary.opacity(0.3), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }

    private var outputFolderTitle: String {
        viewModel.settings.outputFolder?.lastPathComponent ?? "Aucun dossier"
    }

    private func titleWithInfo(_ title: String, help: String, isPresented: Binding<Bool>) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(Palette.primary)
            Button {
                isPresented.wrappedValue.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(Palette.primary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: isPresented, arrowEdge: .bottom) {
                Text(help)
                    .font(.callout)
                    .padding(12)
                    .frame(width: 250, alignment: .leading)
            }
        }
    }
}

private struct QueueRowView: View {
    let item: FileConversionItem
    let onDelete: () -> Void
    let onTap: () -> Void
    let statusText: String
    let beforeText: String
    let afterText: String
    let gainText: String
    let canDelete: Bool

    @State private var isHovering = false
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .padding(9)
                        .foregroundStyle(Palette.primary.opacity(0.6))
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.filename).lineLimit(1).frame(width: 260, alignment: .leading)
            Text(item.inputURL.pathExtension.uppercased()).frame(width: 64, alignment: .leading)
            Text(beforeText).font(.system(.caption, design: .monospaced)).frame(width: 110, alignment: .leading)
            Text(afterText).font(.system(.caption, design: .monospaced)).frame(width: 110, alignment: .leading)
            Text(gainText).bold().frame(width: 90, alignment: .leading)
            Text(statusText).lineLimit(1).frame(width: 190, alignment: .leading)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .disabled(!canDelete)
            .buttonStyle(.borderless)
            .frame(width: 70, alignment: .leading)

            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(Palette.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Palette.primary.opacity(isHovering ? 0.05 : 0), in: RoundedRectangle(cornerRadius: 12))
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onTap)
        .task(id: item.id) {
            thumbnail = NSImage(contentsOf: item.inputURL)
        }
    }
}

struct ComparisonSliderView: View {
    let original: NSImage
    let converted: NSImage
    @State private var sliderOffset: CGFloat = 0.5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(nsImage: original)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Image(nsImage: converted)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width * sliderOffset)
                    }

                let x = geometry.size.width * sliderOffset
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .center) {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
                    }
                    .position(x: x, y: geometry.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        sliderOffset = min(max(value.location.x / max(geometry.size.width, 1), 0), 1)
                    }
            )
        }
        .frame(minHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .liquidCard(cornerRadius: 12)
    }
}

private enum Palette {
    static let accent = Color(hex: "#8DB3CE")
    static let primary = Color(hex: "#4B708C")
    static let surfaceLight = Color(hex: "#E6E8E9")
    static let darkBackground = Color(hex: "#050A12")
}

private extension View {
    func liquidCard(cornerRadius: CGFloat) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Palette.primary.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 10)
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
