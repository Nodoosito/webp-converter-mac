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

    func convertAll() {
        guard let outputFolder = settings.outputFolder else {
            globalError = ConversionError.missingOutputFolder.localizedDescription
            return
        }

        globalError = nil
        isConverting = true
        progress = 0
        for index in items.indices {
            items[index].status = .pending
        }

        Task {
            let total = items.count
            var converted = 0

            for item in items {
                updateStatus(.processing, for: item.id)

                do {
                    let result = try await Task.detached(priority: .userInitiated) {
                        try conversionService.convert(inputURL: item.inputURL, settings: settings, outputFolder: outputFolder)
                    }.value

                    updateStatus(.success(outputURL: result.outputURL, outputSize: result.outputSize), for: item.id)
                } catch {
                    updateStatus(.failure(message: error.localizedDescription), for: item.id)
                }

                converted += 1
                progress = Double(converted) / Double(max(total, 1))
            }

            isConverting = false
        }
    }

    func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func updateStatus(_ status: FileConversionStatus, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
    }
}
