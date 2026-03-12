import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ConversionViewModel

    @State private var percentageInput = "100"
    @State private var widthInput = "1920"
    @State private var heightInput = "1080"

    @FocusState private var focusedField: ResizeField?
    @State private var previousFocusedField: ResizeField?

    private enum ResizeField: Hashable {
        case percentage
        case width
        case height
    }

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
        .onChange(of: focusedField) { newFocus in
            if let previousFocusedField, previousFocusedField != newFocus {
                commit(field: previousFocusedField)
            }
            previousFocusedField = newFocus
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
                        TextField("100", text: $percentageInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .focused($focusedField, equals: .percentage)
                            .onSubmit {
                                commitPercentageInput()
                            }
                    }
                case .width:
                    HStack {
                        Text("px")
                        TextField("1920", text: $widthInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .focused($focusedField, equals: .width)
                            .onSubmit {
                                commitWidthInput()
                            }
                    }
                case .height:
                    HStack {
                        Text("px")
                        TextField("1080", text: $heightInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .focused($focusedField, equals: .height)
                            .onSubmit {
                                commitHeightInput()
                            }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Fichiers")
                    .font(.headline)
                Spacer()
                Button("Vider") {
                    viewModel.clearAll()
                }
                .disabled(viewModel.items.isEmpty || viewModel.isConverting)
            }

            Table(viewModel.items) {
                TableColumn("Nom") { item in
                    Text(item.filename)
                }
                TableColumn("Avant") { item in
                    Text(viewModel.formattedSize(item.inputSize))
                }
                TableColumn("Après") { item in
                    switch item.status {
                    case .success(_, let outputSize):
                        Text(viewModel.formattedSize(outputSize))
                    default:
                        Text("-")
                    }
                }
                TableColumn("Gain") { item in
                    Text(viewModel.formattedGain(for: item))
                        .foregroundStyle(.secondary)
                }
                TableColumn("Statut") { item in
                    statusView(for: item.status)
                }
                TableColumn("Action") { item in
                    Button(role: .destructive) {
                        viewModel.removeItem(item)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isConverting)
                }
                .width(60)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let error = viewModel.globalError {
                Text(error)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ProgressView(value: viewModel.progress)
                .opacity(viewModel.isConverting ? 1 : 0)

            HStack {
                Text("Progression : \(Int(viewModel.progress * 100))%")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Convertir") {
                    commitAllResizeInputs()
                    viewModel.convertAll()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canConvert)
            }
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

    private func commit(field: ResizeField) {
        switch field {
        case .percentage:
            commitPercentageInput()
        case .width:
            commitWidthInput()
        case .height:
            commitHeightInput()
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
