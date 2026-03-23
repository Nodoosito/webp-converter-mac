import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ConversionViewModel
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = AppLanguage.fallback.rawValue

    @State private var presetPendingDeletion: ConversionPreset?
    @State private var presetNameInput = ""
    @State private var percentageInput = "100"
    @State private var widthInput = "1920"
    @State private var heightInput = "1080"
    @State private var isQualityHelpPresented = false
    @State private var isMetadataHelpPresented = false
    @State private var isSuffixHelpPresented = false
    @State private var isResizeHelpPresented = false
    @State private var isDropTargeted = false

    private let columnWidths: [CGFloat] = [280, 100, 100, 90, 220, 60]

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .fallback
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: 300)
                .background(.ultraThinMaterial)
        } detail: {
            mainCanvas
        }
        .navigationSplitViewStyle(.balanced)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(windowBackground)
        .tint(.nodooAccent)
        .foregroundStyle(.nodooAdaptiveText)
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

    private var windowBackground: some View {
        ZStack {
            Color.nodooBackground
            WindowBlurView(material: .underWindowBackground)
                .opacity(0.85)
            LinearGradient(
                colors: [
                    Color.nodooAccent.opacity(0.18),
                    .clear,
                    Color.nodooSecondary.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sidebarHeader
                presetsSection
                qualitySection
                suffixSection
                resizeSection
                languageSection
                exportSection
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("app.header.title", language: currentLanguage))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(LocalizedStringKey(L10n.text("app.header.tagline", language: currentLanguage)))
                .font(.subheadline)
                .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var presetsSection: some View {
        sidebarSection(title: L10n.text("settings.preset.label", language: currentLanguage), systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 12) {
                Picker(L10n.text("settings.preset.label", language: currentLanguage), selection: Binding<UUID?>(
                    get: { viewModel.selectedPresetID },
                    set: { viewModel.applyPreset(id: $0) }
                )) {
                    Text(L10n.text("settings.preset.current", language: currentLanguage)).tag(UUID?.none)
                    ForEach(viewModel.presets) { preset in
                        Text(viewModel.displayName(for: preset)).tag(Optional(preset.id))
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 10) {
                    TextField(L10n.text("settings.preset.new_name.placeholder", language: currentLanguage), text: $presetNameInput)
                        .textFieldStyle(.roundedBorder)

                    Button(L10n.text("button.save", language: currentLanguage)) {
                        commitAllResizeInputs()
                        viewModel.saveCurrentPreset(named: presetNameInput)
                        if viewModel.globalError == nil {
                            presetNameInput = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let selectedPreset = viewModel.selectedPreset, viewModel.canDeleteSelectedPreset {
                    Button(role: .destructive) {
                        presetPendingDeletion = selectedPreset
                    } label: {
                        Label(L10n.text("settings.preset.delete_help", language: currentLanguage), systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var qualitySection: some View {
        sidebarSection(title: L10n.text("settings.quality.label", language: currentLanguage), systemImage: "dial.medium") {
            VStack(alignment: .leading, spacing: 14) {
                labelWithInfo(
                    L10n.text("settings.quality.label", language: currentLanguage),
                    help: L10n.text("settings.quality.help", language: currentLanguage),
                    isPresented: $isQualityHelpPresented
                )

                HStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { viewModel.settings.quality },
                            set: { viewModel.updateQuality($0) }
                        ),
                        in: 0.1...1.0,
                        step: 0.05
                    )
                    .tint(.nodooAccent)

                    Text("\(Int(viewModel.settings.quality * 100))%")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 52, alignment: .trailing)
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
                .toggleStyle(.switch)
                .tint(.nodooAccent)
            }
        }
    }

    private var suffixSection: some View {
        sidebarSection(title: L10n.text("settings.suffix.label", language: currentLanguage), systemImage: "textformat") {
            VStack(alignment: .leading, spacing: 12) {
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
                .pickerStyle(.segmented)
            }
        }
    }

    private var resizeSection: some View {
        sidebarSection(title: L10n.text("settings.resize.label", language: currentLanguage), systemImage: "arrow.up.left.and.arrow.down.right") {
            VStack(alignment: .leading, spacing: 12) {
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
                .pickerStyle(.menu)

                resizeInputPanel

                if viewModel.settings.resizeSettings.mode == .width ||
                    viewModel.settings.resizeSettings.mode == .height {
                    Toggle(L10n.text("settings.keep_aspect_ratio", language: currentLanguage), isOn: Binding(
                        get: { viewModel.settings.resizeSettings.keepAspectRatio },
                        set: { viewModel.updateKeepAspectRatio($0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(.nodooAccent)
                }
            }
        }
    }

    @ViewBuilder
    private var resizeInputPanel: some View {
        switch viewModel.settings.resizeSettings.mode {
        case .percentage:
            metricInputCard(label: "%", placeholder: "100", text: $percentageInput, onCommit: commitPercentageInput)
        case .width:
            metricInputCard(label: "px", placeholder: "1920", text: $widthInput, onCommit: commitWidthInput)
        case .height:
            metricInputCard(label: "px", placeholder: "1080", text: $heightInput, onCommit: commitHeightInput)
        case .original:
            EmptyView()
        }
    }

    private func metricInputCard(label: String, placeholder: String, text: Binding<String>, onCommit: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
                .frame(width: 34, alignment: .leading)

            AppKitCommitTextField(
                placeholder: placeholder,
                text: text,
                onCommit: onCommit
            )
            .frame(height: 28)
        }
        .padding(12)
        .glassCard(cornerRadius: 16, fillOpacity: 0.1)
    }

    private var languageSection: some View {
        sidebarSection(title: L10n.text("settings.language.section", language: currentLanguage), systemImage: "globe") {
            Picker(L10n.text("settings.language.label", language: currentLanguage), selection: $selectedLanguage) {
                Text(L10n.text("settings.language.french", language: currentLanguage)).tag(AppLanguage.fr.rawValue)
                Text(L10n.text("settings.language.english", language: currentLanguage)).tag(AppLanguage.en.rawValue)
            }
            .pickerStyle(.segmented)
        }
    }

    private var exportSection: some View {
        sidebarSection(title: L10n.text("settings.output.label", language: currentLanguage), systemImage: "folder") {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.settings.outputFolder?.path ?? L10n.text("settings.output.none", language: currentLanguage))
                    .font(.caption)
                    .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
                    .lineLimit(2)
                    .truncationMode(.middle)

                Button(L10n.text("button.choose", language: currentLanguage)) {
                    viewModel.selectOutputFolder()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func sidebarSection<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.nodooAdaptiveText)

            content()
        }
        .padding(18)
        .glassCard(cornerRadius: 24, fillOpacity: 0.12)
    }

    private var mainCanvas: some View {
        VStack(alignment: .leading, spacing: 18) {
            topBar
            dropCanvas
            fileListPanel
            previewPanel
            footer
        }
        .padding(24)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("files.section.title", language: currentLanguage))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(viewModel.items.isEmpty ? L10n.text("app.header.tagline", language: currentLanguage) : progressLabel)
                    .font(.subheadline)
                    .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
            }

            Spacer()

            Button(L10n.text("button.clear", language: currentLanguage)) {
                viewModel.clearAll()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.items.isEmpty || viewModel.isConverting)

            Button(L10n.text("button.add_files", language: currentLanguage)) {
                viewModel.addFilesFromPanel()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var dropCanvas: some View {
        VStack(spacing: 14) {
            Image(systemName: isDropTargeted ? "sparkles.rectangle.stack.fill" : "square.and.arrow.down.on.square")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.nodooAccent)

            Text(L10n.text("button.add_files", language: currentLanguage))
                .font(.title3.weight(.semibold))

            Text(LocalizedStringKey(L10n.text("app.header.tagline", language: currentLanguage)))
                .foregroundStyle(.nodooAdaptiveText.opacity(0.68))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 170)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.nodooAccent.opacity(0.85) : Color.nodooSecondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 1.5 : 1, dash: [8, 8])
                )
        )
        .glassCard(cornerRadius: 28, fillOpacity: isDropTargeted ? 0.2 : 0.1)
    }

    private var fileListPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            tableHeader

            if viewModel.sortedItems.isEmpty {
                emptyFilesState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.sortedItems) { item in
                            fileRow(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var emptyFilesState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.stack")
                .font(.system(size: 28))
                .foregroundStyle(.nodooSecondary)
            Text(L10n.text("files.section.title", language: currentLanguage))
                .font(.headline)
            Text(LocalizedStringKey(L10n.text("app.header.tagline", language: currentLanguage)))
                .font(.callout)
                .foregroundStyle(.nodooAdaptiveText.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180)
        .glassCard(cornerRadius: 24, fillOpacity: 0.08)
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
                .foregroundStyle(.nodooAdaptiveText.opacity(0.62))
                .frame(width: columnWidths[5], alignment: .center)
        }
        .padding(.horizontal, 16)
    }

    private func sortHeader(_ title: String, column: ConversionViewModel.SortColumn, width: CGFloat, alignment: Alignment) -> some View {
        Button {
            viewModel.cycleSort(for: column)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.nodooAdaptiveText.opacity(0.62))
                Spacer(minLength: 0)
                if let symbol = viewModel.sortIndicator(for: column) {
                    Image(systemName: symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.nodooSecondary)
                }
            }
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
    }

    private func fileRow(_ item: FileConversionItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename)
                    .lineLimit(1)
                    .font(.headline)
                Text(item.inputURL.path)
                    .font(.caption)
                    .foregroundStyle(.nodooAdaptiveText.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: columnWidths[0], alignment: .leading)

            Text(viewModel.formattedSize(item.inputSize))
                .font(.system(.body, design: .monospaced))
                .frame(width: columnWidths[1], alignment: .trailing)

            Text(afterSizeText(for: item))
                .font(.system(.body, design: .monospaced))
                .frame(width: columnWidths[2], alignment: .trailing)

            Text(viewModel.formattedGain(for: item))
                .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 20, fillOpacity: 0.1, strokeOpacity: 0.2)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(viewModel.selectedItemID == item.id ? Color.nodooAccent.opacity(0.55) : .clear, lineWidth: 1.2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            viewModel.updateSelectedItem(id: item.id)
        }
    }

    private var previewPanel: some View {
        HStack(spacing: 14) {
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
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Group {
                if let image = info?.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 150)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            Text(viewModel.previewMessage)
                                .foregroundStyle(.nodooAdaptiveText.opacity(0.65))
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(10)
                        )
                        .frame(maxWidth: .infinity, maxHeight: 150)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                if let info {
                    Text(L10n.format("preview.size", language: currentLanguage, viewModel.formattedSize(info.fileSize)))
                        .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
                    if let dimensions = info.dimensions {
                        Text(L10n.format("preview.dimensions", language: currentLanguage, Int(dimensions.width), Int(dimensions.height)))
                            .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
                    }
                    if let gainText, gainText != "-" {
                        Text(L10n.format("preview.gain", language: currentLanguage, gainText))
                            .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
                    }
                }
            }
            .font(.caption)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(cornerRadius: 24, fillOpacity: 0.1)
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
            Text(L10n.text("status.pending", language: currentLanguage)).foregroundStyle(.nodooAdaptiveText.opacity(0.68))
        case .processing:
            Text(L10n.text("status.processing", language: currentLanguage)).foregroundStyle(.orange)
        case .success:
            Text(L10n.text("status.success", language: currentLanguage)).foregroundStyle(.green)
        case .failure(let message):
            Text(message).foregroundStyle(.red).lineLimit(2)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let error = viewModel.globalError {
                Text(error)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if viewModel.isConverting {
                    ProgressView(value: viewModel.progress)
                        .tint(.nodooAccent)
                        .frame(maxWidth: 240)
                    Text(progressLabel)
                        .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
                    Button(L10n.text("button.stop", language: currentLanguage)) {
                        viewModel.stopConversion()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text(progressLabel)
                        .foregroundStyle(.nodooAdaptiveText.opacity(0.72))
                }

                Spacer()

                Button(L10n.text("button.convert", language: currentLanguage)) {
                    commitAllResizeInputs()
                    viewModel.convertAll()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.items.isEmpty || viewModel.isConverting)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 24, fillOpacity: 0.08)
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
        HStack(spacing: 6) {
            Text(title)
            Button {
                isPresented.wrappedValue.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.nodooSecondary)
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
