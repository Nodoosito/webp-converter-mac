import Foundation

struct ConversionPresetStore {
    private let userDefaults: UserDefaults
    private let presetsKey = "conversionPresets"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadPresets() -> [ConversionPreset] {
        guard let data = userDefaults.data(forKey: presetsKey) else {
            return Self.defaultPresets
        }

        let decoder = JSONDecoder()
        guard let presets = try? decoder.decode([ConversionPreset].self, from: data), !presets.isEmpty else {
            return Self.defaultPresets
        }

        return presets
    }

    func savePresets(_ presets: [ConversionPreset]) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(presets) else {
            return
        }

        userDefaults.set(data, forKey: presetsKey)
    }

    static let defaultPresets: [ConversionPreset] = [
        ConversionPreset(
            name: "Défaut",
            quality: 0.8,
            resizeSettings: ResizeSettings(mode: .original, percentage: 100, width: 1920, height: 1080, keepAspectRatio: true)
        ),
        ConversionPreset(
            name: "WordPress Thumbnail",
            quality: 0.75,
            resizeSettings: ResizeSettings(mode: .width, percentage: 100, width: 150, height: 150, keepAspectRatio: true)
        ),
        ConversionPreset(
            name: "Bannière Web",
            quality: 0.82,
            resizeSettings: ResizeSettings(mode: .width, percentage: 100, width: 1600, height: 900, keepAspectRatio: true)
        )
    ]
}
