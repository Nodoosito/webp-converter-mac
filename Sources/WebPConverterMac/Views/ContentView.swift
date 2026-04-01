import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ContentView: View {
    @StateObject private var viewModel = ConversionViewModel()
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
            HeaderView(viewModel: viewModel, settingsMenu: settingsMenu)

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
                    updatePercentage: updatePercentage,
                    updateWidth: updateWidth,
                    updateHeight: updateHeight
                )
                .frame(width: 280)

                MainAreaView(
                    viewModel: viewModel,
                    uiStatusText: uiStatusText(for:),
                    uiAfterSizeText: uiAfterSizeText(for:),
                    commitAllResizeInputs: commitAllResizeInputs
                )
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

    private func uiStatusText(for status: FileConversionStatus) -> String {
        switch status {
        case .pending: return L10n.text("status.pending", language: currentLanguage)
        case .processing: return L10n.text("status.processing", language: currentLanguage)
        case .success: return L10n.text("status.success", language: currentLanguage)
        case .failure(let message): return message
        }
    }

    private func uiAfterSizeText(for item: FileConversionItem) -> String {
        switch item.status {
        case .success(_, let outputSize):
            return viewModel.formattedSize(outputSize)
        default:
            return "-"
        }
    }

    private func ensureLanguageFallback() {
        if AppLanguage(rawValue: selectedLanguage) == nil {
            selectedLanguage = AppLanguage.fallback.rawValue
        }
    }

    private func commitAllResizeInputs() {
        updatePercentage()
        updateWidth()
        updateHeight()
    }

    private func updatePercentage() {
        let sanitized = digitsOnly(percentageInput)
        let source = sanitized.isEmpty ? "100" : sanitized
        let value = Double(source) ?? viewModel.settings.resizeSettings.percentage
        viewModel.updatePercentage(value)
        percentageInput = String(Int(viewModel.settings.resizeSettings.percentage.rounded()))
    }

    private func updateWidth() {
        let sanitized = digitsOnly(widthInput)
        let source = sanitized.isEmpty ? "1" : sanitized
        let value = Double(source) ?? viewModel.settings.resizeSettings.width
        viewModel.updateWidth(value)
        widthInput = String(Int(viewModel.settings.resizeSettings.width.rounded()))
    }

    private func updateHeight() {
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

@MainActor
private struct HeaderView<SettingsMenu: View>: View {
    @ObservedObject var viewModel: ConversionViewModel
    let settingsMenu: SettingsMenu

    var body: some View {
        HStack {
            Text("Orlo — Batch Image Converter")
                .font(.title3.weight(.bold))
                .lineLimit(1)

            Spacer()

            Button("Ajouter des fichiers") {
                viewModel.addFilesFromPanel()
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.accent)
            .controlSize(.large)

            settingsMenu
        }
    }
}

@MainActor
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
    let updatePercentage: () -> Void
    let updateWidth: () -> Void
    let updateHeight: () -> Void

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
                .frame(width: 145)

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
            titleWithInfo(
                L10n.text("settings.metadata.label", language: currentLanguage),
                help: L10n.text("settings.metadata.help", language: currentLanguage),
                isPresented: $isMetadataHelpPresented
            )
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
            titleWithInfo(
                L10n.text("settings.suffix.label", language: currentLanguage),
                help: L10n.text("settings.suffix.help", language: currentLanguage),
                isPresented: $isSuffixHelpPresented
            )
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.settings.suffixMode },
                set: { viewModel.updateSuffixMode($0) }
            )) {
                ForEach(SuffixMode.allCases) { mode in
                    Text(mode.localizedTitle).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 120)
        }
    }

    private var resizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                titleWithInfo(
                    L10n.text("settings.resize.label", language: currentLanguage),
                    help: L10n.text("settings.resize.help", language: currentLanguage),
                    isPresented: $isResizeHelpPresented
                )
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
                    AppKitCommitTextField(
                        placeholder: "100",
                        text: $percentageInput,
                        onCommit: { Task { @MainActor in updatePercentage() } }
                    )
                    .frame(width: 70, height: 24)
                    Text("%")
                case .width:
                    AppKitCommitTextField(
                        placeholder: "1920",
                        text: $widthInput,
                        onCommit: { Task { @MainActor in updateWidth() } }
                    )
                    .frame(width: 84, height: 24)
                    Text("px")
                case .height:
                    AppKitCommitTextField(
                        placeholder: "1080",
                        text: $heightInput,
                        onCommit: { Task { @MainActor in updateHeight() } }
                    )
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

@MainActor
private struct MainAreaView: View {
    @ObservedObject var viewModel: ConversionViewModel
    let uiStatusText: (FileConversionStatus) -> String
    let uiAfterSizeText: (FileConversionItem) -> String
    let commitAllResizeInputs: () -> Void

    @State private var tableSelection: Set<UUID> = []
    @State private var thumbnails: [UUID: NSImage] = [:]

    var body: some View {
        VStack(spacing: 12) {
            VSplitView {
                queuePanel
                    .frame(minHeight: 220)

                comparisonPanel
                    .frame(minHeight: 300)
            }

            actionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.selectedItemID) { selectedID in
            tableSelection = selectedID.map { Set([$0]) } ?? []
        }
        .task(id: viewModel.items.map(\.id)) {
            for item in viewModel.items where thumbnails[item.id] == nil {
                thumbnails[item.id] = NSImage(contentsOf: item.inputURL)
            }
        }
    }

    private var queuePanel: some View {
        Table(viewModel.sortedItems, selection: $tableSelection) {
            TableColumn("Thumbnail") { item in
                Group {
                    if let image = thumbnails[item.id] {
                        Image(nsImage: image)
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
                .task {
                    if thumbnails[item.id] == nil {
                        thumbnails[item.id] = NSImage(contentsOf: item.inputURL)
                    }
                }
            }
            .width(min: 56, ideal: 60, max: 64)

            TableColumn("Filename") { item in
                QueueRowView(viewModel: viewModel, text: item.filename)
            }
            .width(min: 240, ideal: 280)

            TableColumn("Type") { item in
                QueueRowView(viewModel: viewModel, text: item.inputURL.pathExtension.uppercased())
            }
            .width(min: 64, ideal: 72, max: 80)

            TableColumn("Original Size") { item in
                Text(viewModel.formattedSize(item.inputSize))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(min: 100, ideal: 112, max: 124)

            TableColumn("Est. After") { item in
                Text(uiAfterSizeText(item))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(min: 100, ideal: 112, max: 124)

            TableColumn("Gain") { item in
                Text(viewModel.formattedGain(for: item))
                    .fontWeight(.bold)
            }
            .width(min: 82, ideal: 96, max: 108)

            TableColumn("Status") { item in
                QueueRowView(viewModel: viewModel, text: uiStatusText(item.status))
            }
            .width(min: 180, ideal: 220)

            TableColumn("Action") { item in
                Button(role: .destructive) {
                    viewModel.removeItem(item)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isConverting)
            }
            .width(min: 64, ideal: 72, max: 80)
        }
        .tableStyle(.inset)
        .onChange(of: tableSelection) { newSelection in
            viewModel.updateSelectedItem(id: newSelection.first)
        }
        .liquidCard(cornerRadius: 18)
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
                ComparisonSliderView(viewModel: viewModel, original: original, converted: converted)
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

            Button("Annuler") {
                viewModel.stopConversion()
            }
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
}

@MainActor
private struct QueueRowView: View {
    @ObservedObject var viewModel: ConversionViewModel
    let text: String

    var body: some View {
        Text(text)
            .lineLimit(1)
    }
}

@MainActor
private struct ComparisonSliderView: View {
    @ObservedObject var viewModel: ConversionViewModel
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

                let xPosition = geometry.size.width * sliderOffset
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
                    .position(x: xPosition, y: geometry.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        sliderOffset = min(max(value.location.x / max(geometry.size.width, 1), 0), 1)
                    }
            )
        }
        .frame(minHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .liquidCard(cornerRadius: 12)
    }
}

private enum ResizeCommitMode {
    case percentage
    case width
    case height
}

private func digitsOnly(_ text: String) -> String {
    text.filter { $0.isNumber }
}

private func commitSingleResizeInput(
    viewModel: ConversionViewModel,
    text: Binding<String>,
    fallback: String,
    mode: ResizeCommitMode
) {
    let sanitized = digitsOnly(text.wrappedValue)
    let source = sanitized.isEmpty ? fallback : sanitized

    switch mode {
    case .percentage:
        let value = Double(source) ?? viewModel.settings.resizeSettings.percentage
        viewModel.updatePercentage(value)
        text.wrappedValue = String(Int(viewModel.settings.resizeSettings.percentage.rounded()))
    case .width:
        let value = Double(source) ?? viewModel.settings.resizeSettings.width
        viewModel.updateWidth(value)
        text.wrappedValue = String(Int(viewModel.settings.resizeSettings.width.rounded()))
    case .height:
        let value = Double(source) ?? viewModel.settings.resizeSettings.height
        viewModel.updateHeight(value)
        text.wrappedValue = String(Int(viewModel.settings.resizeSettings.height.rounded()))
    }
}

private func commitAllResizeInputs(
    viewModel: ConversionViewModel,
    percentageInput: Binding<String>,
    widthInput: Binding<String>,
    heightInput: Binding<String>
) {
    commitSingleResizeInput(viewModel: viewModel, text: percentageInput, fallback: "100", mode: .percentage)
    commitSingleResizeInput(viewModel: viewModel, text: widthInput, fallback: "1", mode: .width)
    commitSingleResizeInput(viewModel: viewModel, text: heightInput, fallback: "1", mode: .height)
}

private enum Palette {
    static let accent = Color(hexString: "#8DB3CE")
    static let primary = Color(hexString: "#4B708C")
    static let surfaceLight = Color(hexString: "#E6E8E9")
    static let darkBackground = Color(hexString: "#050A12")
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
    init(hexString: String) {
        let normalized = hexString.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)

        let r: UInt64
        let g: UInt64
        let b: UInt64

        if normalized.count == 6 {
            r = (value >> 16) & 0xFF
            g = (value >> 8) & 0xFF
            b = value & 0xFF
        } else {
            r = 0
            g = 0
            b = 0
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
