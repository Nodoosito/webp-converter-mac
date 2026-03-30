import AppKit
import UniformTypeIdentifiers

enum FileServiceError: LocalizedError, Sendable {
    case securityScopedAccessDenied
    case invalidSecurityScopedBookmark

    var errorDescription: String? {
        switch self {
        case .securityScopedAccessDenied:
            return "Accès refusé au dossier de sortie sélectionné. Veuillez le sélectionner à nouveau."
        case .invalidSecurityScopedBookmark:
            return "Le signet de sécurité du dossier de sortie est invalide ou a expiré."
        }
    }
}

private actor URLAccumulator {
    private var urls: [URL] = []

    func append(contentsOf newURLs: [URL]) {
        urls.append(contentsOf: newURLs)
    }

    func all() -> [URL] {
        urls
    }
}

struct FileService: Sendable {
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

    @MainActor
    func acceptedImageURLs(
        from providers: [NSItemProvider],
        completion: @escaping @MainActor ([URL]) -> Void
    ) {
        let acceptedProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }

        guard !acceptedProviders.isEmpty else {
            completion([])
            return
        }

        let group = DispatchGroup()
        let accumulator = URLAccumulator()

        for provider in acceptedProviders {
            group.enter()
            provider.loadFileURL { result in
                guard case .success(let droppedURL) = result else {
                    group.leave()
                    return
                }

                let discoveredURLs: [URL]
                if isDirectory(url: droppedURL) {
                    discoveredURLs = supportedImagesRecursively(in: droppedURL)
                } else if isSupportedImage(url: droppedURL) {
                    discoveredURLs = [droppedURL]
                } else {
                    discoveredURLs = []
                }

                Task {
                    if !discoveredURLs.isEmpty {
                        await accumulator.append(contentsOf: discoveredURLs)
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            Task { @MainActor in
                completion(await accumulator.all())
            }
        }
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

    public func makeSecurityScopedBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public func resolveSecurityScopedBookmark(_ bookmarkData: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (resolvedURL, isStale)
    }

    public func withSecurityScopedAccess<T>(to url: URL, operation: () throws -> T) throws -> T {
        let startedAccess = url.startAccessingSecurityScopedResource()
        guard startedAccess else {
            throw FileServiceError.securityScopedAccessDenied
        }

        defer { url.stopAccessingSecurityScopedResource() }
        return try operation()
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
