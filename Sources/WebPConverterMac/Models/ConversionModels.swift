import Foundation

public enum ResizeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case original = "Taille originale"
    case percentage = "Pourcentage"
    case width = "Largeur"
    case height = "Hauteur"

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .original:
            return L10n.text("resize.original")
        case .percentage:
            return L10n.text("resize.percentage")
        case .width:
            return L10n.text("resize.width")
        case .height:
            return L10n.text("resize.height")
        }
    }
}

public enum SuffixMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "Aucun"
    case presetName = "Nom du préréglage"
    case dimensions = "Dimensions"

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .none:
            return L10n.text("suffix.none")
        case .presetName:
            return L10n.text("suffix.preset_name")
        case .dimensions:
            return L10n.text("suffix.dimensions")
        }
    }
}

public struct ResizeSettings: Codable, Equatable, Sendable {
    public var mode: ResizeMode = .original
    public var percentage: Double = 100
    public var width: Double = 1920
    public var height: Double = 1080
    public var keepAspectRatio: Bool = true

    public init(
        mode: ResizeMode = .original,
        percentage: Double = 100,
        width: Double = 1920,
        height: Double = 1080,
        keepAspectRatio: Bool = true
    ) {
        self.mode = mode
        self.percentage = percentage
        self.width = width
        self.height = height
        self.keepAspectRatio = keepAspectRatio
    }
}

// 1. AJOUT DE 'Sendable' ICI
public enum FileConversionStatus: Equatable, Sendable {
    case pending
    case processing
    case success(outputURL: URL, outputSize: Int64)
    case failure(message: String)
}

// 2. AJOUT DE 'Sendable' ICI
public struct FileConversionItem: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let inputURL: URL
    public let inputSize: Int64
    public var status: FileConversionStatus = .pending

    public var filename: String { inputURL.lastPathComponent }

    public init(inputURL: URL, inputSize: Int64, status: FileConversionStatus = .pending) {
        self.inputURL = inputURL
        self.inputSize = inputSize
        self.status = status
    }
}

public struct ConversionSettings: Sendable {
    public var quality: Double = 0.8
    public var resizeSettings = ResizeSettings()
    public var outputFolder: URL?
    public var removeMetadata: Bool = true
    public var suffixMode: SuffixMode = .none
    public var selectedPresetName: String?

    public init(
        quality: Double = 0.8,
        resizeSettings: ResizeSettings = ResizeSettings(),
        outputFolder: URL? = nil,
        removeMetadata: Bool = true,
        suffixMode: SuffixMode = .none,
        selectedPresetName: String? = nil
    ) {
        self.quality = quality
        self.resizeSettings = resizeSettings
        self.outputFolder = outputFolder
        self.removeMetadata = removeMetadata
        self.suffixMode = suffixMode
        self.selectedPresetName = selectedPresetName
    }
}

public struct ConversionPreset: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var quality: Double
    public var resizeSettings: ResizeSettings
    public var removeMetadata: Bool
    public var suffixMode: SuffixMode
    public var isSystemPreset: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        quality: Double,
        resizeSettings: ResizeSettings,
        removeMetadata: Bool = true,
        suffixMode: SuffixMode = .none,
        isSystemPreset: Bool = false
    ) {
        self.id = id
        self.name = name
        self.quality = quality
        self.resizeSettings = resizeSettings
        self.removeMetadata = removeMetadata
        self.suffixMode = suffixMode
        self.isSystemPreset = isSystemPreset
    }

    public var localizedDisplayName: String {
        guard isSystemPreset else { return name }

        switch name {
        case ConversionPresetStore.defaultPresetName:
            return L10n.text("preset.default")
        case ConversionPresetStore.wordpressThumbnailPresetName:
            return L10n.text("preset.wordpress_thumbnail")
        case ConversionPresetStore.webBannerPresetName:
            return L10n.text("preset.web_banner")
        default:
            return name
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case quality
        case resizeSettings
        case removeMetadata
        case suffixMode
        case isSystemPreset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        quality = try container.decode(Double.self, forKey: .quality)
        resizeSettings = try container.decode(ResizeSettings.self, forKey: .resizeSettings)
        removeMetadata = try container.decodeIfPresent(Bool.self, forKey: .removeMetadata) ?? true
        suffixMode = try container.decodeIfPresent(SuffixMode.self, forKey: .suffixMode) ?? .none
        isSystemPreset = try container.decodeIfPresent(Bool.self, forKey: .isSystemPreset) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(quality, forKey: .quality)
        try container.encode(resizeSettings, forKey: .resizeSettings)
        try container.encode(removeMetadata, forKey: .removeMetadata)
        try container.encode(suffixMode, forKey: .suffixMode)
        try container.encode(isSystemPreset, forKey: .isSystemPreset)
    }
}
