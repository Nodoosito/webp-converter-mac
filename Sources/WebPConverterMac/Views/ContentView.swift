import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ConversionViewModel
    @State private var percentageInput = "100"

    var body: some View {
        VStack(spacing: 16) {
            header
            settingsPanel
            listPanel
            footer
        }
        .padding(20)
        .onAppear {
            percentageInput = normalizedPercentageString(viewModel.settings.resizeSettings.percentage)
        }
        .onChange(of: viewModel.settings.resizeSettings.mode) { mode in
            if mode == .percentage {
                percentageInput = normalizedPercentageString(viewModel.settings.resizeSettings.percentage)
            }
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
            if !viewModel.nativeWebPAvailable {
                Text("Export WEBP natif ImageIO indisponible : utilisation d'un encodeur de secours si installé (cwebp).")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

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
                            .onChange(of: percentageInput) { newValue in
                                handlePercentageInputChange(newValue)
                            }
                            .onSubmit {
                                commitPercentageInput()
                            }
                    }
                case .width:
                    HStack {
                        Text("px")
                        TextField("1920", value: Binding(
                            get: { viewModel.settings.resizeSettings.width },
                            set: { viewModel.updateWidth($0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    }
                case .height:
                    HStack {
                        Text("px")
                        TextField("1080", value: Binding(
                            get: { viewModel.settings.resizeSettings.height },
                            set: { viewModel.updateHeight($0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    }
                case .original:
                    EmptyView()
                }

                Toggle("Conserver les proportions", isOn: Binding(
                    get: { viewModel.settings.resizeSettings.keepAspectRatio },
                    set: { viewModel.updateKeepAspectRatio($0) }
                ))
                .disabled(viewModel.settings.resizeSettings.mode == .original || viewModel.settings.resizeSettings.mode == .percentage)
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

    private func handlePercentageInputChange(_ rawValue: String) {
        let filtered = rawValue.filter { $0.isNumber }

        if filtered != rawValue {
            percentageInput = filtered
            return
        }

        guard !filtered.isEmpty, let value = Double(filtered) else {
            return
        }

        viewModel.updatePercentage(value)
    }

    private func commitPercentageInput() {
        let value = Double(percentageInput) ?? viewModel.settings.resizeSettings.percentage
        let clamped = min(max(1, value), 100)
        viewModel.updatePercentage(clamped)
        percentageInput = normalizedPercentageString(clamped)
    }

    private func normalizedPercentageString(_ value: Double) -> String {
        String(Int(min(max(1, value), 100).rounded()))
    }
}
