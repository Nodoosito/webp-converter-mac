import Foundation
import AppKit

@MainActor
final class ConversionViewModel: ObservableObject {
    @Published private(set) var items: [FileConversionItem] = []
    @Published var settings = ConversionSettings()
    @Published var globalError: String?
    @Published private(set) var isConverting = false
    @Published private(set) var progress: Double = 0

    private let fileService = FileService()
    private let conversionService = ImageConversionService()

    var canConvert: Bool {
        !items.isEmpty && settings.outputFolder != nil && !isConverting
    }

    var nativeWebPAvailable: Bool {
        conversionService.isNativeWebPEncodingAvailable
    }

    func addFilesFromPanel() {
        let urls = fileService.openImagePanel()
        addFiles(urls)
    }

    func addFiles(_ urls: [URL]) {
        let existing = Set(items.map { $0.inputURL.standardizedFileURL })
        let newItems = urls
            .filter { fileService.isSupportedImage(url: $0) }
            .filter { !existing.contains($0.standardizedFileURL) }
            .map { FileConversionItem(inputURL: $0, inputSize: fileService.fileSize(for: $0)) }

        items.append(contentsOf: newItems)
    }

    func removeItem(_ item: FileConversionItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearAll() {
        items.removeAll()
        progress = 0
        globalError = nil
    }

    func selectOutputFolder() {
        settings.outputFolder = fileService.openOutputFolderPanel()
    }

    func handleDrop(providers: [NSItemProvider]) {
        Task {
            let urls = await fileService.acceptedImageURLs(from: providers)
            addFiles(urls)
        }
    }

    func updateResizeMode(_ mode: ResizeMode) {
        var updated = settings
        updated.resizeSettings.mode = mode
        settings = updated
    }

    func updatePercentage(_ percentage: Double) {
        var updated = settings
        updated.resizeSettings.percentage = min(max(1, percentage), 100)
        settings = updated
    }

    func updateWidth(_ width: Double) {
        var updated = settings
        updated.resizeSettings.width = max(1, width)
        settings = updated
    }

    func updateHeight(_ height: Double) {
        var updated = settings
        updated.resizeSettings.height = max(1, height)
        settings = updated
    }

    func updateKeepAspectRatio(_ keep: Bool) {
        var updated = settings
        updated.resizeSettings.keepAspectRatio = keep
        settings = updated
    }

    func convertAll() {
        guard let outputFolder = settings.outputFolder else {
            globalError = "Aucun dossier de sortie sélectionné."
            return
        }

        globalError = nil
        isConverting = true
        progress = 0
        for index in items.indices {
            items[index].status = .pending
        }

        let itemsToConvert = items
        let settingsSnapshot = settings
        let conversionService = self.conversionService

        Task { @MainActor [weak self, itemsToConvert, settingsSnapshot, outputFolder, conversionService] in
            guard let self else { return }

            let total = itemsToConvert.count
            var converted = 0

            for item in itemsToConvert {
                self.updateStatus(.processing, for: item.id)

                do {
                    let result = try await Task.detached(priority: .userInitiated) {
                        try conversionService.convert(
                            inputURL: item.inputURL,
                            settings: settingsSnapshot,
                            outputFolder: outputFolder
                        )
                    }.value

                    self.updateStatus(
                        .success(outputURL: result.outputURL, outputSize: result.outputSize),
                        for: item.id
                    )
                } catch {
                    self.updateStatus(.failure(message: error.localizedDescription), for: item.id)
                }

                converted += 1
                self.progress = Double(converted) / Double(max(total, 1))
            }

            self.isConverting = false
        }
    }

    func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func formattedGain(for item: FileConversionItem) -> String {
        guard case .success(_, let outputSize) = item.status, item.inputSize > 0 else {
            return "-"
        }

        let gain = (Double(outputSize - item.inputSize) / Double(item.inputSize)) * 100
        return "\(Int(gain.rounded()))%"
    }

    private func updateStatus(_ status: FileConversionStatus, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
    }
}
