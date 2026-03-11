import AppKit
import UniformTypeIdentifiers

struct FileService {
    private let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic"]

    func openImagePanel() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Ajouter"

        return panel.runModal() == .OK ? panel.urls : []
    }

    func openOutputFolderPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choisir"

        return panel.runModal() == .OK ? panel.url : nil
    }

    func acceptedImageURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
               let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil),
               isSupportedImage(url: url) {
                urls.append(url)
            }
        }

        return urls
    }

    func isSupportedImage(url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    func fileSize(for url: URL) -> Int64 {
        guard
            let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
            let fileSize = values.fileSize
        else { return 0 }

        return Int64(fileSize)
    }
}
