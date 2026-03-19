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

        let userPresets = presets.filter { !isProtectedPreset($0) }
        return Self.defaultPresets + userPresets
    }

    func savePresets(_ presets: [ConversionPreset]) {
        let encoder = JSONEncoder()
        let userPresets = presets.filter { !$0.isSystemPreset && !Self.protectedPresetNames.contains($0.name) }
        guard let data = try? encoder.encode(userPresets) else {
            return
        }

        userDefaults.set(data, forKey: presetsKey)
    }

    func deletePreset(id: UUID, from presets: [ConversionPreset]) -> [ConversionPreset] {
        guard let preset = presets.first(where: { $0.id == id }), !isProtectedPreset(preset) else {
            return presets
        }

        let updatedPresets = presets.filter { $0.id != id }
        savePresets(updatedPresets)
        return updatedPresets
    }

    func isProtectedPresetName(_ name: String) -> Bool {
        Self.protectedPresetNames.contains(name)
    }

    private func isProtectedPreset(_ preset: ConversionPreset) -> Bool {
        preset.isSystemPreset || Self.protectedPresetNames.contains(preset.name)
    }

    static let defaultPresetName = "Défaut"
    static let protectedPresetNames: Set<String> = [
        defaultPresetName,
        "WordPress Thumbnail",
        "Bannière Web"
    ]

    static let defaultPresets: [ConversionPreset] = [
        ConversionPreset(
            name: "Défaut",
            quality: 0.8,
            resizeSettings: ResizeSettings(mode: .original, percentage: 100, width: 1920, height: 1080, keepAspectRatio: true),
            isSystemPreset: true
        ),
        ConversionPreset(
            name: "WordPress Thumbnail",
            quality: 0.75,
            resizeSettings: ResizeSettings(mode: .width, percentage: 100, width: 150, height: 150, keepAspectRatio: true),
            isSystemPreset: true
        ),
        ConversionPreset(
            name: "Bannière Web",
            quality: 0.82,
            resizeSettings: ResizeSettings(mode: .width, percentage: 100, width: 1600, height: 900, keepAspectRatio: true),
            isSystemPreset: true
        )
    ]
}
