import Foundation
import UniformTypeIdentifiers

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

                if let data = item as? Data,
                   let droppedURL = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: droppedURL)
                    return
                }

                continuation.resume(throwing: CocoaError(.fileReadUnknown))
            }
        }
    }
}
