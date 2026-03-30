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
    @MainActor
    func loadFileURL(completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let error {
                completion(.failure(error))
                return
            }

            if let url = item as? URL {
                completion(.success(url))
                return
            }

            if let nsURL = item as? NSURL, let url = nsURL as URL? {
                completion(.success(url))
                return
            }

            if let data = item as? Data {
                guard let droppedURL = URL(dataRepresentation: data, relativeTo: nil) else {
                    completion(.failure(NSItemProviderAsyncError.invalidFileURLData))
                    return
                }

                completion(.success(droppedURL))
                return
            }

            completion(.failure(NSItemProviderAsyncError.unsupportedDroppedItem))
        }
    }
}
