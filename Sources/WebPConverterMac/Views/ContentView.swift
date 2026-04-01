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

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .fallback
    }

    var body: some View {
        HStack(spacing: 20) {
            sidebar
                .frame(width: 280)

            mainPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
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

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("app.header.title", language: currentLanguage))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Palette.primary)
                    Text(LocalizedStringKey(L10n.text("app.header.tagline", language: currentLanguage)))
                        .font(.footnote)
                        .foregroundStyle(Palette.primary.opacity(0.75))
                }
                Spacer()
                settingsMenu
            }

            controlCard

            Spacer()

            Button {
                viewModel.selectOutputFolder()
            } label: {
                Label("Dossier de sortie", systemImage: "folder")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Palette.primary.opacity(0.3), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .liquidCard(cornerRadius: 18)
    }

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            qualitySection
            metadataToggle
            suffixSection
            resizeSection

            HStack {
                Text("Préréglage")
                    .foregroundStyle(Palette.primary)
                Spacer()
                Picker("Préréglage", selection: Binding<UUID?>(
                    get: { viewModel.selectedPresetID },
                    set: { viewModel.applyPreset(id: $0) }
                )) {
                    Text("Actuel").tag(UUID?.none)
                    ForEach(viewModel.presets) { preset in
                        Text(viewModel.displayName(for: preset)).tag(Optional(preset.id))
                    }
                }
                .frame(width: 140)
            }

            HStack(spacing: 8) {
                TextField("Nom du préréglage", text: $presetNameInput)
                Button("Save") {
                    commitAllResizeInputs()
                    viewModel.saveCurrentPreset(named: presetNameInput)
                    if viewModel.globalError == nil { presetNameInput = "" }
                }
                .disabled(presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let selectedPreset = viewModel.selectedPreset, viewModel.canDeleteSelectedPreset {
                    Button(role: .destructive) { presetPendingDeletion = selectedPreset } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Qualité webp")
                    .foregroundStyle(Palette.primary)
                infoButton(help: L10n.text("settings.quality.help", language: currentLanguage), isPresented: $isQualityHelpPresented)
                Spacer()
                Text("\(Int(viewModel.settings.quality * 100))%")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Palette.primary)
            }
            Slider(
                value: Binding(
                    get: { viewModel.settings.quality * 100 },
                    set: { viewModel.updateQuality($0 / 100) }
                ),
                in: 0...100,
                step: 1
            )
            .tint(Palette.accent)
        }
    }

    private var metadataToggle: some View {
        Toggle(isOn: Binding(
            get: { viewModel.settings.removeMetadata },
            set: { viewModel.updateRemoveMetadata($0) }
        )) {
            HStack(spacing: 6) {
                Text(L10n.text("settings.metadata.label", language: currentLanguage))
                    .foregroundStyle(Palette.primary)
                infoButton(help: L10n.text("settings.metadata.help", language: currentLanguage), isPresented: $isMetadataHelpPresented)
            }
        }
        .toggleStyle(.switch)
    }

    private var suffixSection: some View {
        HStack {
            Text(L10n.text("settings.suffix.label", language: currentLanguage))
                .foregroundStyle(Palette.primary)
            infoButton(help: L10n.text("settings.suffix.help", language: currentLanguage), isPresented: $isSuffixHelpPresented)
            Spacer()
            Picker("Suffix", selection: Binding(
                get: { viewModel.settings.suffixMode },
                set: { viewModel.updateSuffixMode($0) }
            )) {
                ForEach(SuffixMode.allCases) { mode in
                    Text(mode.localizedTitle).tag(mode)
                }
            }
            .frame(width: 130)
        }
    }

    private var resizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.text("settings.resize.label", language: currentLanguage))
                    .foregroundStyle(Palette.primary)
                infoButton(help: L10n.text("settings.resize.help", language: currentLanguage), isPresented: $isResizeHelpPresented)
                Spacer()
                Picker("Resize", selection: Binding(
                    get: { viewModel.settings.resizeSettings.mode },
                    set: { viewModel.updateResizeMode($0) }
                )) {
                    ForEach(ResizeMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
                .frame(width: 130)
            }

            HStack(spacing: 8) {
                switch viewModel.settings.resizeSettings.mode {
                case .percentage:
                    AppKitCommitTextField(placeholder: "100", text: $percentageInput, onCommit: commitPercentageInput)
                        .frame(width: 60, height: 24)
                    Text("%")
                case .width:
                    AppKitCommitTextField(placeholder: "1920", text: $widthInput, onCommit: commitWidthInput)
                        .frame(width: 80, height: 24)
                    Text("px")
                case .height:
                    AppKitCommitTextField(placeholder: "1080", text: $heightInput, onCommit: commitHeightInput)
                        .frame(width: 80, height: 24)
                    Text("px")
                case .original:
                    Text("Original")
                        .foregroundStyle(Palette.primary.opacity(0.7))
                }
                Spacer()
            }
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 14) {
            queuePanel
                .frame(maxHeight: .infinity)

            comparisonPanel
                .frame(height: 240)

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
                            language: currentLanguage,
                            onDelete: { viewModel.removeItem(item) },
                            onTap: { viewModel.updateSelectedItem(id: item.id) },
                            statusText: statusText(for: item.status),
                            beforeText: viewModel.formattedSize(item.inputSize),
                            afterText: afterSizeText(for: item),
                            gainText: viewModel.formattedGain(for: item),
                            thumbnail: viewModel.selectedItemID == item.id ? viewModel.originalPreview?.image : nil,
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
            headerCell("Thumbnail", width: 76)
            headerCell("Filename", width: 220)
            headerCell("Type", width: 56)
            headerCell("Original Size", width: 90)
            headerCell("Est. After", width: 90)
            headerCell("Gain", width: 70)
            headerCell("Status", width: 160)
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

            Group {
                if let original = viewModel.originalPreview?.image,
                   let converted = viewModel.convertedPreview?.image {
                    ComparisonSliderView(original: original, converted: converted)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Palette.surfaceLight.opacity(0.35))
                        .overlay(Text(viewModel.previewMessage).foregroundStyle(Palette.primary.opacity(0.7)))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
            }
        }
        .liquidCard(cornerRadius: 18)
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            if let error = viewModel.globalError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
                .font(.title3)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .menuStyle(.borderlessButton)
    }

    private func infoButton(help: String, isPresented: Binding<Bool>) -> some View {
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
                .frame(width: 260, alignment: .leading)
        }
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

private struct QueueRowView: View {
    let item: FileConversionItem
    let language: AppLanguage
    let onDelete: () -> Void
    let onTap: () -> Void
    let statusText: String
    let beforeText: String
    let afterText: String
    let gainText: String
    let thumbnail: NSImage?
    let canDelete: Bool

    @State private var isHovering = false

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
                        .padding(8)
                        .foregroundStyle(Palette.primary.opacity(0.6))
                }
            }
            .frame(width: 52, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.filename).lineLimit(1).frame(width: 220, alignment: .leading)
            Text(item.inputURL.pathExtension.uppercased()).frame(width: 56, alignment: .leading)
            Text(beforeText).font(.system(.caption, design: .monospaced)).frame(width: 90, alignment: .leading)
            Text(afterText).font(.system(.caption, design: .monospaced)).frame(width: 90, alignment: .leading)
            Text(gainText).bold().frame(width: 70, alignment: .leading)
            Text(statusText).lineLimit(1).frame(width: 160, alignment: .leading)

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
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
