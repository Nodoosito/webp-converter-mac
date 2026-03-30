import SwiftUI
import UniformTypeIdentifiers

public typealias WebPConverterContentView = ContentView


public struct ContentView: View {
    @ObservedObject private var viewModel: ConversionViewModel
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = AppLanguage.fallback.rawValue
    @AppStorage(AppStorageKeys.appearanceMode) private var appearanceMode = 0

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

    public init(viewModel: ConversionViewModel) {
        self.viewModel = viewModel
    }

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .fallback
    }

    private var hasFiles: Bool {
        !viewModel.items.isEmpty
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: 300, idealWidth: 340)
                .background(.thinMaterial)
        } detail: {
            mainCanvas
        }
        .navigationSplitViewStyle(.balanced)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(windowBackground)
        .tint(.nodooAccent)
        .foregroundStyle(.nodooText)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                appearanceToggleButton
            }
        }
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
                    Text(
                        L10n.format(
                            "alert.preset.delete.message",
                            language: currentLanguage,
                            presetPendingDeletion.localizedDisplayName
                        )
                    )
                }
            }
        )
        .alert(L10n.text("alert.conversion.complete.title", language: currentLanguage), isPresented: $viewModel.showCompletionAlert) {
            Button(L10n.text("alert.ok", language: currentLanguage), role: .cancel) {}
        } message: {
            Text(L10n.format("alert.conversion.complete.message", language: currentLanguage, viewModel.formattedTotalGain))
        }
    }

    @ViewBuilder
    private var windowBackground: some View {
        ZStack {
            Color.nodooBackground
            WindowBlurView(material: .underWindowBackground)
                .opacity(0.78)
            LinearGradient(
                colors: [
                    Color.nodooAccent.opacity(0.12),
                    .clear,
                    Color.nodooSecondary.opacity(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var appearanceToggleButton: some View {
        Button {
            cycleAppearanceMode()
        } label: {
            Image(systemName: appearanceMode == 2 ? "moon.fill" : "sun.max.fill")
                .foregroundStyle(.nodooAccent)
        }
        .help(appearanceModeHelp)
    }

    private var appearanceModeHelp: String {
        switch appearanceMode {
        case 1:
            return "Appearance: Light"
        case 2:
            return "Appearance: Dark"
        default:
            return "Appearance: Auto"
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sidebarHeader
                presetsSection
                qualitySection
                suffixSection
                resizeSection
                languageSection
                exportSection
                if hasFiles {
                    sidebarConvertSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("app.header.title", language: currentLanguage))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.nodooAccent)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(LocalizedStringKey(L10n.text("app.header.tagline", language: currentLanguage)))
                .font(.footnote)
                .foregroundStyle(.nodooText.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var presetsSection: some View {
        sidebarSection(
            title: L10n.text("settings.preset.label", language: currentLanguage),
            systemImage: "slider.horizontal.3"
        ) {
            Picker(
                L10n.text("settings.preset.label", language: currentLanguage),
                selection: Binding<UUID?>(
                    get: { viewModel.selectedPresetID },
                    set: { viewModel.applyPreset(id: $0) }
                )
            ) {
                Text(L10n.text("settings.preset.current", language: currentLanguage)).tag(UUID?.none)
                ForEach(viewModel.presets) { preset in
                    Text(viewModel.displayName(for: preset)).tag(Optional(preset.id))
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 10) {
                TextField(
                    L10n.text("settings.preset.new_name.placeholder", language: currentLanguage),
                    text: $presetNameInput
                )
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

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

            presetDeleteButton
        }
    }

    @ViewBuilder
    private var qualitySection: some View {
        sidebarSection(
            title: L10n.text("settings.quality.label", language: currentLanguage),
            systemImage: "dial.medium"
        ) {
            labelWithInfo(
                L10n.text("settings.quality.label", language: currentLanguage),
                help: L10n.text("settings.quality.help", language: currentLanguage),
                isPresented: $isQualityHelpPresented
            )

            HStack(alignment: .center, spacing: 12) {
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

    @ViewBuilder
    private var suffixSection: some View {
        sidebarSection(
            title: L10n.text("settings.suffix.label", language: currentLanguage),
            systemImage: "textformat"
        ) {
            labelWithInfo(
                L10n.text("settings.suffix.label", language: currentLanguage),
                help: L10n.text("settings.suffix.help", language: currentLanguage),
                isPresented: $isSuffixHelpPresented
            )

            Picker(
                L10n.text("settings.suffix.label", language: currentLanguage),
                selection: Binding(
                    get: { viewModel.settings.suffixMode },
                    set: { viewModel.updateSuffixMode($0) }
                )
            ) {
                ForEach(SuffixMode.allCases) { mode in
                    Text(mode.localizedTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var resizeSection: some View {
        sidebarSection(
            title: L10n.text("settings.resize.label", language: currentLanguage),
            systemImage: "arrow.up.left.and.arrow.down.right"
        ) {
            labelWithInfo(
                L10n.text("settings.resize.label", language: currentLanguage),
                help: L10n.text("settings.resize.help", language: currentLanguage),
                isPresented: $isResizeHelpPresented
            )

            Picker(
                L10n.text("settings.resize.label", language: currentLanguage),
                selection: Binding(
                    get: { viewModel.settings.resizeSettings.mode },
                    set: { viewModel.updateResizeMode($0) }
                )
            ) {
                ForEach(ResizeMode.allCases) { mode in
                    Text(mode.localizedTitle).tag(mode)
                }
            }
            .pickerStyle(.menu)

            resizeInputPanel

            if viewModel.settings.resizeSettings.mode == .width ||
                viewModel.settings.resizeSettings.mode == .height {
                Toggle(
                    L10n.text("settings.keep_aspect_ratio", language: currentLanguage),
                    isOn: Binding(
                        get: { viewModel.settings.resizeSettings.keepAspectRatio },
                        set: { viewModel.updateKeepAspectRatio($0) }
                    )
                )
                .toggleStyle(.switch)
                .tint(.nodooAccent)
            }
        }
    }

    @ViewBuilder
    private var languageSection: some View {
        sidebarSection(
            title: L10n.text("settings.language.section", language: currentLanguage),
            systemImage: "globe"
        ) {
            Picker(L10n.text("settings.language.label", language: currentLanguage), selection: $selectedLanguage) {
                Text(L10n.text("settings.language.french", language: currentLanguage)).tag(AppLanguage.fr.rawValue)
                Text(L10n.text("settings.language.english", language: currentLanguage)).tag(AppLanguage.en.rawValue)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        sidebarSection(
            title: L10n.text("settings.output.label", language: currentLanguage),
            systemImage: "folder"
        ) {
            Text(viewModel.settings.outputFolder?.path ?? L10n.text("settings.output.none", language: currentLanguage))
                .font(.caption)
                .foregroundStyle(.nodooText.opacity(0.72))
                .lineLimit(2)
                .truncationMode(.middle)

            Button(L10n.text("button.choose", language: currentLanguage)) {
                viewModel.selectOutputFolder()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var sidebarConvertSection: some View {
        sidebarSection(
            title: L10n.text("button.convert", language: currentLanguage),
            systemImage: "play.fill"
        ) {
            convertButton
                .frame(maxWidth: .infinity)

            Button(L10n.text("button.clear", language: currentLanguage)) {
                viewModel.clearAll()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .disabled(viewModel.items.isEmpty || viewModel.isConverting)
        }
    }

    @ViewBuilder
    private var presetDeleteButton: some View {
        if let selectedPreset = viewModel.selectedPreset, viewModel.isCustomPreset(selectedPreset) {
            Button(role: .destructive) {
                presetPendingDeletion = selectedPreset
            } label: {
                Label(L10n.text("settings.preset.delete_help", language: currentLanguage), systemImage: "trash")
            }
            .buttonStyle(.bordered)
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

    private func sidebarSection<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.nodooText)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24, fillOpacity: 0.06)
    }

    private func metricInputCard(label: String, placeholder: String, text: Binding<String>, onCommit: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.nodooText.opacity(0.72))
                .frame(width: 34, alignment: .leading)

            AppKitCommitTextField(
                placeholder: placeholder,
                text: text,
                onCommit: onCommit
            )
            .frame(height: 28)
        }
        .padding(12)
        .glassCard(cornerRadius: 16, fillOpacity: 0.05)
    }

    @ViewBuilder
    private var mainCanvas: some View {
        Group {
            if hasFiles {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        topBar
                        fileListPanel
                        previewPanel
                        footer
                    }
                    .padding(24)
                }
            } else {
                emptyStateCanvas
                    .padding(32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .scrollIndicators(.hidden)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
    }

    @ViewBuilder
    private var emptyStateCanvas: some View {
        VStack {
            Spacer(minLength: 0)
            dropCanvas
                .frame(maxWidth: 760)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("files.section.title", language: currentLanguage))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.nodooAccent)
                Text(progressLabel)
                    .font(.subheadline)
                    .foregroundStyle(.nodooText.opacity(0.76))
            }

            Spacer(minLength: 0)

            Button(L10n.text("button.clear", language: currentLanguage)) {
                viewModel.clearAll()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.items.isEmpty || viewModel.isConverting)

            convertButton
        }
    }

    @ViewBuilder
    private var dropCanvas: some View {
        VStack(spacing: 14) {
            Image(systemName: isDropTargeted ? "sparkles.rectangle.stack.fill" : "square.and.arrow.down.on.square")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.nodooAccent)

            Text(L10n.text("button.add_files", language: currentLanguage))
                .font(.title3.weight(.semibold))

            Text(LocalizedStringKey(L10n.text("app.header.tagline", language: currentLanguage)))
                .foregroundStyle(.nodooText.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            Button(L10n.text("button.add_files", language: currentLanguage)) {
                viewModel.addFilesFromPanel()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, hasFiles ? 28 : 56)
        .padding(.horizontal, hasFiles ? 20 : 28)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.nodooAccent.opacity(0.85) : Color.nodooSecondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 1.5 : 1, dash: [8, 8])
                )
                .allowsHitTesting(false)
        )
        .glassCard(cornerRadius: 28, fillOpacity: isDropTargeted ? 0.12 : 0.06)
    }

    @ViewBuilder
    private var fileListPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sortControls

            if viewModel.sortedItems.isEmpty {
                emptyFilesState
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.sortedItems) { item in
                        fileCard(item)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180)
        .padding(18)
        .glassCard(cornerRadius: 24, fillOpacity: 0.08)
    }

    @ViewBuilder
    private var sortControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                sortChip(L10n.text("table.name", language: currentLanguage), column: .name)
                sortChip(L10n.text("table.before", language: currentLanguage), column: .beforeSize)
                sortChip(L10n.text("table.after", language: currentLanguage), column: .afterSize)
                sortChip(L10n.text("table.gain", language: currentLanguage), column: .gain)
                sortChip(L10n.text("table.status", language: currentLanguage), column: .status)
            }
        }
    }

    private func sortChip(_ title: String, column: ConversionViewModel.SortColumn) -> some View {
        Button {
            viewModel.cycleSort(for: column)
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                if let symbol = viewModel.sortIndicator(for: column) {
                    Image(systemName: symbol)
                        .font(.caption2.weight(.semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: 14, fillOpacity: 0.05)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var emptyFilesState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.stack")
                .font(.system(size: 28))
                .foregroundStyle(.nodooSecondary)
            Text(L10n.text("files.section.title", language: currentLanguage))
                .font(.headline)
                .foregroundStyle(.nodooAccent)
            Text(LocalizedStringKey(L10n.text("app.header.tagline", language: currentLanguage)))
                .font(.callout)
                .foregroundStyle(.nodooText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .glassCard(cornerRadius: 24, fillOpacity: 0.05)
    }

    private func fileCard(_ item: FileConversionItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.filename)
                        .font(.headline)
                        .lineLimit(2)
                    Text(item.inputURL.path)
                        .font(.caption)
                        .foregroundStyle(.nodooText.opacity(0.64))
                        .lineLimit(2)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    viewModel.removeItem(item)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isConverting)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                statTile(title: L10n.text("table.before", language: currentLanguage), value: viewModel.formattedSize(item.inputSize))
                statTile(title: L10n.text("table.after", language: currentLanguage), value: afterSizeText(for: item))
                statTile(title: L10n.text("table.gain", language: currentLanguage), value: viewModel.formattedGain(for: item))
                statTile(
                    title: L10n.text("table.status", language: currentLanguage),
                    value: statusText(for: item.status),
                    accent: statusColor(for: item.status)
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20, fillOpacity: 0.06, strokeOpacity: 0.2)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(viewModel.selectedItemID == item.id ? Color.nodooAccent.opacity(0.55) : .clear, lineWidth: 1.2)
                .allowsHitTesting(false)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            viewModel.updateSelectedItem(id: item.id)
        }
    }

    private func statTile(title: String, value: String, accent: Color = .nodooText) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.nodooText.opacity(0.62))
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(accent)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard(cornerRadius: 16, fillOpacity: 0.04, strokeOpacity: 0.12)
    }

    @ViewBuilder
    private var previewPanel: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                previewCard(title: L10n.text("preview.original", language: currentLanguage), info: viewModel.originalPreview, gainText: nil)
                previewCard(
                    title: L10n.text("preview.converted", language: currentLanguage),
                    info: viewModel.convertedPreview,
                    gainText: viewModel.selectedItem.map { viewModel.formattedGain(for: $0) }
                )
            }

            VStack(spacing: 14) {
                previewCard(title: L10n.text("preview.original", language: currentLanguage), info: viewModel.originalPreview, gainText: nil)
                previewCard(
                    title: L10n.text("preview.converted", language: currentLanguage),
                    info: viewModel.convertedPreview,
                    gainText: viewModel.selectedItem.map { viewModel.formattedGain(for: $0) }
                )
            }
        }
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
                        .frame(maxWidth: .infinity, maxHeight: 180)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            Text(viewModel.previewMessage)
                                .foregroundStyle(.nodooText.opacity(0.7))
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(10)
                        )
                        .frame(maxWidth: .infinity, minHeight: 150)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                if let info {
                    Text(L10n.format("preview.size", language: currentLanguage, viewModel.formattedSize(info.fileSize)))
                        .foregroundStyle(.nodooText.opacity(0.76))
                    if let dimensions = info.dimensions {
                        Text(L10n.format("preview.dimensions", language: currentLanguage, Int(dimensions.width), Int(dimensions.height)))
                            .foregroundStyle(.nodooText.opacity(0.76))
                    }
                    if let gainText, gainText != "-" {
                        Text(L10n.format("preview.gain", language: currentLanguage, gainText))
                            .foregroundStyle(.nodooText.opacity(0.76))
                    }
                }
            }
            .font(.caption)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCard(cornerRadius: 24, fillOpacity: 0.05)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 10) {
            if let error = viewModel.globalError {
                Text(error)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ViewThatFits(in: .horizontal) {
                footerContent(axis: .horizontal)
                footerContent(axis: .vertical)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 24, fillOpacity: 0.05)
    }

    private func footerContent(axis: Axis) -> some View {
        Group {
            if axis == .horizontal {
                HStack(spacing: 12) {
                    footerLeadingContent
                    Spacer(minLength: 0)
                    Button(L10n.text("button.add_files", language: currentLanguage)) {
                        viewModel.addFilesFromPanel()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    footerLeadingContent
                    Button(L10n.text("button.add_files", language: currentLanguage)) {
                        viewModel.addFilesFromPanel()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var footerLeadingContent: some View {
        Group {
            if viewModel.isConverting {
                HStack(spacing: 10) {
                    ProgressView(value: viewModel.progress)
                        .tint(.nodooAccent)
                        .frame(maxWidth: 240)
                    Text(progressLabel)
                        .foregroundStyle(.nodooText.opacity(0.76))
                    Button(L10n.text("button.stop", language: currentLanguage)) {
                        viewModel.stopConversion()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text(progressLabel)
                    .foregroundStyle(.nodooText.opacity(0.76))
            }
        }
    }

    @ViewBuilder
    private var convertButton: some View {
        Button(L10n.text("button.convert", language: currentLanguage)) {
            commitAllResizeInputs()
            viewModel.convertAll()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.items.isEmpty || viewModel.isConverting)
    }

    private var progressLabel: String {
        L10n.format("progress.label", language: currentLanguage, Int(viewModel.progress * 100))
    }

    private func statusText(for status: FileConversionStatus) -> String {
        switch status {
        case .pending:
            return L10n.text("status.pending", language: currentLanguage)
        case .processing:
            return L10n.text("status.processing", language: currentLanguage)
        case .success:
            return L10n.text("status.success", language: currentLanguage)
        case .failure(let message):
            return message
        }
    }

    private func statusColor(for status: FileConversionStatus) -> Color {
        switch status {
        case .pending:
            return .nodooText
        case .processing:
            return .orange
        case .success:
            return .green
        case .failure:
            return .red
        }
    }

    private func afterSizeText(for item: FileConversionItem) -> String {
        switch item.status {
        case .success(_, let outputSize):
            return viewModel.formattedSize(outputSize)
        default:
            return "-"
        }
    }

    private func cycleAppearanceMode() {
        appearanceMode = (appearanceMode + 1) % 3
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
