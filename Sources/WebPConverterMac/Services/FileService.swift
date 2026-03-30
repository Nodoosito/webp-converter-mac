import AppKit
import UniformTypeIdentifiers

// On passe en 'final class' @MainActor pour sécuriser le Drag & Drop
@MainActor
public final class FileService: Sendable {
    
    public init() {} 

    private let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic"]

    public func openImagePanel() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Ajouter"

        return panel.runModal() == .OK ? panel.urls : []
    }

    public func openOutputFolderPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choisir"

        return panel.runModal() == .OK ? panel.url : nil
    }

    // Cette fonction peut maintenant recevoir les providers car elle est MainActor
    public func acceptedImageURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            // Utilisation de loadFileURL (méthode de ton extension)
            guard let droppedURL = try? await provider.loadFileURL() else {
                continue
            }

            if isDirectory(url: droppedURL) {
                urls.append(contentsOf: supportedImagesRecursively(in: droppedURL))
            } else if isSupportedImage(url: droppedURL) {
                urls.append(droppedURL)
            }
        }

        return urls
    }

    public func isSupportedImage(url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    public func fileSize(for url: URL) -> Int64 {
        guard
            let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
            let fileSize = values.fileSize
        else { return 0 }

        return Int64(fileSize)
    }

    public func uniqueOutputURL(for inputURL: URL, in outputFolder: URL, pathExtension: String = "webp") -> URL {
        uniqueOutputURL(
            forBaseName: inputURL.deletingPathExtension().lastPathComponent,
            in: outputFolder,
            pathExtension: pathExtension
        )
    }

    public func uniqueOutputURL(forBaseName baseName: String, in outputFolder: URL, pathExtension: String = "webp") -> URL {
        var candidate = outputFolder
            .appendingPathComponent(baseName)
            .appendingPathExtension(pathExtension)

        guard FileManager.default.fileExists(atPath: candidate.path) else {
            return candidate
        }

        var index = 1
        while true {
            candidate = outputFolder
                .appendingPathComponent("\(baseName) (\(index))")
                .appendingPathExtension(pathExtension)

            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }

            index += 1
        }
    }

    private func isDirectory(url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private func supportedImagesRecursively(in folderURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [URL] = []

        for case let fileURL as URL in enumerator {
            guard
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                values.isRegularFile == true,
                isSupportedImage(url: fileURL)
            else {
                continue
            }

            results.append(fileURL)
        }

        return results
    }
}
