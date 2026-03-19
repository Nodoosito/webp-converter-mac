import Foundation

enum ResizeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case original = "Taille originale"
    case percentage = "Pourcentage"
    case width = "Largeur"
    case height = "Hauteur"

    var id: String { rawValue }
}

struct ResizeSettings: Codable, Equatable, Sendable {
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

struct ConversionSettings: Sendable {
    var quality: Double = 0.8
    var resizeSettings = ResizeSettings()
    var outputFolder: URL?
    var removeMetadata: Bool = true
}

struct ConversionPreset: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var quality: Double
    var resizeSettings: ResizeSettings
    var removeMetadata: Bool
    var isSystemPreset: Bool

    init(
        id: UUID = UUID(),
        name: String,
        quality: Double,
        resizeSettings: ResizeSettings,
        removeMetadata: Bool = true,
        isSystemPreset: Bool = false
    ) {
        self.id = id
        self.name = name
        self.quality = quality
        self.resizeSettings = resizeSettings
        self.removeMetadata = removeMetadata
        self.isSystemPreset = isSystemPreset
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case quality
        case resizeSettings
        case removeMetadata
        case isSystemPreset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        quality = try container.decode(Double.self, forKey: .quality)
        resizeSettings = try container.decode(ResizeSettings.self, forKey: .resizeSettings)
        removeMetadata = try container.decodeIfPresent(Bool.self, forKey: .removeMetadata) ?? true
        isSystemPreset = try container.decodeIfPresent(Bool.self, forKey: .isSystemPreset) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(quality, forKey: .quality)
        try container.encode(resizeSettings, forKey: .resizeSettings)
        try container.encode(removeMetadata, forKey: .removeMetadata)
        try container.encode(isSystemPreset, forKey: .isSystemPreset)
    }
}
