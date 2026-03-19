import Foundation
import UniformTypeIdentifiers

enum NSItemProviderAsyncError: LocalizedError {
    case invalidFileURLData
    case unsupportedDroppedItem

    var errorDescription: String? {
        switch self {
        case .invalidFileURLData:
            return "Impossible d'extraire une URL valide depuis l'élément déposé."
        case .unsupportedDroppedItem:
            return "Le contenu déposé ne contient pas d'URL de fichier exploitable."
        }
    }
}

extension NSItemProvider {
    func loadFileURL() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }

                if let nsURL = item as? NSURL, let url = nsURL as URL? {
                    continuation.resume(returning: url)
                    return
                }

                if let data = item as? Data {
                    guard let droppedURL = URL(dataRepresentation: data, relativeTo: nil) else {
                        continuation.resume(throwing: NSItemProviderAsyncError.invalidFileURLData)
                        return
                    }

                    continuation.resume(returning: droppedURL)
                    return
                }

                continuation.resume(throwing: NSItemProviderAsyncError.unsupportedDroppedItem)
            }
        }
    }
}
