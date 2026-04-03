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

    private let columnWidths: [CGFloat] = [280, 100, 100, 90, 220, 60]

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .fallback
    }

    private var themeLabel: String {
        currentLanguage == .fr ? "Thème" : "Theme"
    }

    private var themeSystemLabel: String {
        currentLanguage == .fr ? "Système" : "System"
    }

    private var themeLightLabel: String {
        currentLanguage == .fr ? "Clair" : "Light"
    }

    private var themeDarkLabel: String {
        currentLanguage == .fr ? "Sombre" : "Dark"
    }

    var body: some View {
        VStack(spacing: 16) {
            HeaderView()

            HStack(alignment: .top, spacing: 16) {
                SidebarSettings()

                VStack(spacing: 16) {
                    header
                    settingsPanel
                    listPanel
                    footer
                }
                .padding(20)
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
                        set: { isPresented in
                            if !isPresented {
                                presetPendingDeletion = nil
                            }
                        }
                    ),
                    actions: {
                        Button(L10n.text("alert.cancel", language: currentLanguage), role: .cancel) {
                            presetPendingDeletion = nil
                        }
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

            Spacer()

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

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 8) {
                    Text(themeLabel)
                    Picker(themeLabel, selection: $appTheme) {
                        Text(themeSystemLabel).tag(0)
                        Text(themeLightLabel).tag(1)
                        Text(themeDarkLabel).tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }

                Picker(L10n.text("settings.preset.label", language: currentLanguage), selection: Binding<UUID?>(
                    get: { viewModel.selectedPresetID },
                    set: { viewModel.applyPreset(id: $0) }
                )) {
                    Text(L10n.text("settings.preset.current", language: currentLanguage)).tag(UUID?.none)
                    ForEach(viewModel.presets) { preset in
                        Text(viewModel.displayName(for: preset)).tag(Optional(preset.id))
                    }
                }
                .frame(maxWidth: 280)

                if let selectedPreset = viewModel.selectedPreset, viewModel.canDeleteSelectedPreset {
                    Button(role: .destructive) {
                        presetPendingDeletion = selectedPreset
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help(L10n.text("settings.preset.delete_help", language: currentLanguage))
                }

                TextField(L10n.text("settings.preset.new_name.placeholder", language: currentLanguage), text: $presetNameInput)

                Button(L10n.text("button.save", language: currentLanguage)) {
                    commitAllResizeInputs()
                    viewModel.saveCurrentPreset(named: presetNameInput)
                    if viewModel.globalError == nil {
                        presetNameInput = ""
                    }
                }
                .disabled(presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                labelWithInfo(
                    L10n.text("settings.quality.label", language: currentLanguage),
                    help: L10n.text("settings.quality.help", language: currentLanguage),
                    isPresented: $isQualityHelpPresented
                )

                Slider(
                    value: Binding(
                        get: { viewModel.settings.quality },
                        set: { viewModel.updateQuality($0) }
                    ),
                    in: 0.1...1.0,
                    step: 0.05
                )

                Text("\(Int(viewModel.settings.quality * 100))%")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 50)
            }

            Toggle(
                isOn: Binding(
                    get: { viewModel.settings.removeMetadata },
                    set: { viewModel.updateRemoveMetadata($0) }
                )
            ) {
                labelWithInfo(
                    L10n.text("settings.metadata.label", language: currentLanguage),
                    help: L10n.text("settings.metadata.help", language: currentLanguage),
                    isPresented: $isMetadataHelpPresented
                )
            }
            .toggleStyle(.checkbox)

            HStack {
                labelWithInfo(
                    L10n.text("settings.suffix.label", language: currentLanguage),
                    help: L10n.text("settings.suffix.help", language: currentLanguage),
                    isPresented: $isSuffixHelpPresented
                )

                Picker(L10n.text("settings.suffix.label", language: currentLanguage), selection: Binding(
                    get: { viewModel.settings.suffixMode },
                    set: { viewModel.updateSuffixMode($0) }
                )) {
                    ForEach(SuffixMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
                .frame(maxWidth: 220)
            }

            HStack {
                labelWithInfo(
                    L10n.text("settings.resize.label", language: currentLanguage),
                    help: L10n.text("settings.resize.help", language: currentLanguage),
                    isPresented: $isResizeHelpPresented
                )

                Picker(L10n.text("settings.resize.label", language: currentLanguage), selection: Binding(
                    get: { viewModel.settings.resizeSettings.mode },
                    set: { viewModel.updateResizeMode($0) }
                )) {
                    ForEach(ResizeMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
                .frame(maxWidth: 260)

                switch viewModel.settings.resizeSettings.mode {
                case .percentage:
                    HStack {
                        Text("%")
                        AppKitCommitTextField(
                            placeholder: "100",
                            text: $percentageInput,
                            onCommit: commitPercentageInput
                        )
                        .frame(width: 80, height: 24)
                    }

                case .width:
                    HStack {
                        Text("px")
                        AppKitCommitTextField(
                            placeholder: "1920",
                            text: $widthInput,
                            onCommit: commitWidthInput
                        )
                        .frame(width: 100, height: 24)
                    }

                case .height:
                    HStack {
                        Text("px")
                        AppKitCommitTextField(
                            placeholder: "1080",
                            text: $heightInput,
                            onCommit: commitHeightInput
                        )
                        .frame(width: 100, height: 24)
                    }

                case .original:
                    EmptyView()
                }

                if viewModel.settings.resizeSettings.mode == .width ||
                    viewModel.settings.resizeSettings.mode == .height {
                    Toggle(L10n.text("settings.keep_aspect_ratio", language: currentLanguage), isOn: Binding(
                        get: { viewModel.settings.resizeSettings.keepAspectRatio },
                        set: { viewModel.updateKeepAspectRatio($0) }
                    ))
                }
            }

            HStack {
                Text(L10n.text("settings.output.label", language: currentLanguage))

                Text(viewModel.settings.outputFolder?.path ?? L10n.text("settings.output.none", language: currentLanguage))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(L10n.text("button.choose", language: currentLanguage)) {
                    viewModel.selectOutputFolder()
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var listPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.text("files.section.title", language: currentLanguage))
                    .font(.headline)

                Spacer()

                Button(L10n.text("button.clear", language: currentLanguage)) {
                    viewModel.clearAll()
                }
                .disabled(viewModel.items.isEmpty || viewModel.isConverting)
            }

            tableHeader

            List(selection: Binding(
                get: { viewModel.selectedItemID.map { Set([$0]) } ?? [] },
                set: { newValue in
                    viewModel.updateSelectedItem(id: newValue.first)
                }
            )) {
                ForEach(viewModel.sortedItems) { item in
                    fileRow(item)
                        .tag(item.id)
                }
            }
            .frame(maxHeight: .infinity)

            previewPanel
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            sortHeader(L10n.text("table.name", language: currentLanguage), column: .name, width: columnWidths[0], alignment: .leading)
            sortHeader(L10n.text("table.before", language: currentLanguage), column: .beforeSize, width: columnWidths[1], alignment: .trailing)
            sortHeader(L10n.text("table.after", language: currentLanguage), column: .afterSize, width: columnWidths[2], alignment: .trailing)
            sortHeader(L10n.text("table.gain", language: currentLanguage), column: .gain, width: columnWidths[3], alignment: .trailing)
            sortHeader(L10n.text("table.status", language: currentLanguage), column: .status, width: columnWidths[4], alignment: .leading)
            Text(L10n.text("table.action", language: currentLanguage))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary.opacity(0.85))
                .frame(width: columnWidths[5], alignment: .center)
        }
        .padding(.horizontal, 8)
    }

    private func sortHeader(_ title: String, column: ConversionViewModel.SortColumn, width: CGFloat, alignment: Alignment) -> some View {
        Button {
            viewModel.cycleSort(for: column)
        } label: {
            HStack(spacing: 4) {
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
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
    }

    private func fileRow(_ item: FileConversionItem) -> some View {
        HStack(spacing: 12) {
            Text(item.filename)
                .lineLimit(1)
                .frame(width: columnWidths[0], alignment: .leading)

            Text(viewModel.formattedSize(item.inputSize))
                .font(.system(.body, design: .monospaced))
                .frame(width: columnWidths[1], alignment: .trailing)

            Text(afterSizeText(for: item))
                .font(.system(.body, design: .monospaced))
                .frame(width: columnWidths[2], alignment: .trailing)

            Text(viewModel.formattedGain(for: item))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[3], alignment: .trailing)

            statusView(for: item.status)
                .frame(width: columnWidths[4], alignment: .leading)

            Button(role: .destructive) {
                viewModel.removeItem(item)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isConverting)
            .frame(width: columnWidths[5], alignment: .center)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.updateSelectedItem(id: item.id)
        }
    }

    private var previewPanel: some View {
        HStack(spacing: 12) {
            previewCard(title: L10n.text("preview.original", language: currentLanguage), info: viewModel.originalPreview, gainText: nil)
            previewCard(
                title: L10n.text("preview.converted", language: currentLanguage),
                info: viewModel.convertedPreview,
                gainText: viewModel.selectedItem.map { viewModel.formattedGain(for: $0) }
            )
        }
        .frame(height: 250)
    }

    private func previewCard(title: String, info: ConversionViewModel.PreviewInfo?, gainText: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Group {
                if let image = info?.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 150)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary.opacity(0.4))
                        .overlay(
                            Text(viewModel.previewMessage)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(8)
                        )
                        .frame(maxWidth: .infinity, maxHeight: 150)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                if let info {
                    Text(L10n.format("preview.size", language: currentLanguage, viewModel.formattedSize(info.fileSize)))
                        .foregroundStyle(.secondary)
                    if let dimensions = info.dimensions {
                        Text(L10n.format("preview.dimensions", language: currentLanguage, Int(dimensions.width), Int(dimensions.height)))
                            .foregroundStyle(.secondary)
                    }
                    if let gainText, gainText != "-" {
                        Text(L10n.format("preview.gain", language: currentLanguage, gainText))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
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
        VStack(spacing: 8) {
            if let error = viewModel.globalError {
                Text(error)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if viewModel.isConverting {
                    ProgressView(value: viewModel.progress)
                        .frame(maxWidth: 240)
                    Text(progressLabel)
                        .foregroundStyle(.secondary)
                    Button(L10n.text("button.stop", language: currentLanguage)) {
                        viewModel.stopConversion()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text(progressLabel)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(L10n.text("button.convert", language: currentLanguage)) {
                    commitAllResizeInputs()
                    viewModel.convertAll()
                }
                .disabled(viewModel.items.isEmpty || viewModel.isConverting)
            }
        }
    }

    private var progressLabel: String {
        L10n.format("progress.label", language: currentLanguage, Int(viewModel.progress * 100))
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

    private func labelWithInfo(_ title: String, help: String, isPresented: Binding<Bool>) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Button {
                isPresented.wrappedValue.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: isPresented, arrowEdge: .bottom) {
                Text(help)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: 280, alignment: .leading)
            }
        }
    }
}
