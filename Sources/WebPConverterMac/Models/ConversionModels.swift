import Foundation

enum ResizeMode: String, CaseIterable, Identifiable {
    case original = "Taille originale"
    case percentage = "Pourcentage"
    case width = "Largeur"
    case height = "Hauteur"

    var id: String { rawValue }
}

struct ResizeSettings {
    var mode: ResizeMode = .original
    var percentage: Double = 100
    var width: Double = 1920
    var height: Double = 1080
    var keepAspectRatio: Bool = true
}

enum FileConversionStatus: Equatable {
    case pending
    case processing
    case success(outputURL: URL, outputSize: Int64)
    case failure(message: String)
}

struct FileConversionItem: Identifiable, Equatable {
    let id = UUID()
    let inputURL: URL
    let inputSize: Int64
    var status: FileConversionStatus = .pending

    var filename: String { inputURL.lastPathComponent }
}

struct ConversionSettings {
    var quality: Double = 0.8
    var resizeSettings = ResizeSettings()
    var outputFolder: URL?
}
