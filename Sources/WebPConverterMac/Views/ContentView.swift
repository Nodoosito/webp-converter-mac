import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ConversionViewModel

    @State private var percentageInput = "100"
    @State private var widthInput = "1920"
    @State private var heightInput = "1080"

    private let columnWidths: [CGFloat] = [280, 100, 100, 90, 220, 60]

    var body: some View {
        VStack(spacing: 16) {
            header
            settingsPanel
            listPanel
            footer
        }
        .padding(20)
        .onAppear {
            syncInputsFromSettings()
        }
        .onChange(of: viewModel.settings.resizeSettings.mode) { _ in
            syncInputsFromSettings()
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("WEBP Converter")
                    .font(.title.bold())
                Text("Conversion par lot PNG / JPG / HEIC vers WEBP")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Ajouter des fichiers") {
                viewModel.addFilesFromPanel()
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Qualité WEBP")
                Slider(value: $viewModel.settings.quality, in: 0.1...1.0, step: 0.05)
                Text("\(Int(viewModel.settings.quality * 100))%")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 50)
            }

            HStack {
                Picker("Redimensionnement", selection: Binding(
                    get: { viewModel.settings.resizeSettings.mode },
                    set: { viewModel.updateResizeMode($0) }
                )) {
                    ForEach(ResizeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
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

                if viewModel.settings.resizeSettings.mode == .width || viewModel.settings.resizeSettings.mode == .height {
                    Toggle("Conserver les proportions", isOn: Binding(
                        get: { viewModel.settings.resizeSettings.keepAspectRatio },
                        set: { viewModel.updateKeepAspectRatio($0) }
                    ))
                }
            }

            HStack {
                Text("Sortie :")
                Text(viewModel.settings.outputFolder?.path ?? "Aucun dossier sélectionné")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Choisir") {
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
                Text("Fichiers")
                    .font(.headline)
                Spacer()
                Button("Vider") {
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
            sortHeader("Nom", column: .name, width: columnWidths[0], alignment: .leading)
            sortHeader("Avant", column: .beforeSize, width: columnWidths[1], alignment: .trailing)
            sortHeader("Après", column: .afterSize, width: columnWidths[2], alignment: .trailing)
            sortHeader("Gain", column: .gain, width: columnWidths[3], alignment: .trailing)
            sortHeader("Statut", column: .status, width: columnWidths[4], alignment: .leading)
            Text("Action")
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
            previewCard(title: "Original", info: viewModel.originalPreview, gainText: nil)
            previewCard(
                title: "WebP converti",
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
                    Text("Taille: \(viewModel.formattedSize(info.fileSize))")
                        .foregroundStyle(.secondary)
                    if let dimensions = info.dimensions {
                        Text("Dimensions: \(Int(dimensions.width)) × \(Int(dimensions.height))")
                            .foregroundStyle(.secondary)
                    }
                    if let gainText, gainText != "-" {
                        Text("Gain: \(gainText)")
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
private var footer: some View {
    VStack(spacing: 8) {

        if let error = viewModel.globalError {
            Text(error)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        HStack {
            Text("Progression : \(Int(viewModel.progress * 100))%")
                .foregroundStyle(.secondary)

            Spacer()

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
            Text("En attente").foregroundStyle(.secondary)
        case .processing:
            Text("Conversion...").foregroundStyle(.orange)
        case .success:
            Text("OK").foregroundStyle(.green)
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
            .disabled(viewModel.items.isEmpty || viewModel.isConverting)
        }
    }
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
                    Text("Taille: \(viewModel.formattedSize(info.fileSize))")
                        .foregroundStyle(.secondary)
                    if let dimensions = info.dimensions {
                        Text("Dimensions: \(Int(dimensions.width)) × \(Int(dimensions.height))")
                            .foregroundStyle(.secondary)
                    }
                    if let gainText, gainText != "-" {
                        Text("Gain: \(gainText)")
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
