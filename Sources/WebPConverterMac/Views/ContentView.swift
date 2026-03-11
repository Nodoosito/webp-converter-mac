import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ConversionViewModel

    var body: some View {
        VStack(spacing: 16) {
            header
            settingsPanel
            listPanel
            footer
        }
        .padding(20)
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
                Picker("Redimensionnement", selection: $viewModel.settings.resizeSettings.mode) {
                    ForEach(ResizeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(maxWidth: 260)

                switch viewModel.settings.resizeSettings.mode {
                case .percentage:
                    HStack {
                        Text("%")
                        TextField("100", value: $viewModel.settings.resizeSettings.percentage, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                case .width:
                    HStack {
                        Text("px")
                        TextField("1920", value: $viewModel.settings.resizeSettings.width, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                case .height:
                    HStack {
                        Text("px")
                        TextField("1080", value: $viewModel.settings.resizeSettings.height, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                case .original:
                    EmptyView()
                }

                Toggle("Conserver les proportions", isOn: $viewModel.settings.resizeSettings.keepAspectRatio)
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
}
