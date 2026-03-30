import AppKit
import Foundation
import ImageIO

@MainActor
public final class ConversionViewModel: ObservableObject {
    public enum SortColumn { case name, beforeSize, afterSize, gain, status }
    public enum SortDirection { case none, ascending, descending }

    public struct PreviewInfo {
        public let image: NSImage?
        public let fileSize: Int64
        public let dimensions: CGSize?
    }

    private struct LoadedPreview {
        public let image: NSImage?
        public let dimensions: CGSize?
    }

    private enum PreviewMessageState {
        case selectFile
        case loading
        case availableAfterConversion
        case none

        var localizedText: String {
            switch self {
            case .selectFile:
                return L10n.text("vm.preview.select_file")
            case .loading:
                return L10n.text("vm.preview.loading")
            case .availableAfterConversion:
                return L10n.text("vm.preview.available_after_conversion")
            case .none:
                return ""
            }
        }
    }

    private enum GlobalErrorDescriptor {
        case emptyPresetName
        case protectedPresetName
        case missingOutputFolder
        case processingStopped
        case custom(String)

        var localizedText: String {
            switch self {
            case .emptyPresetName:
                return L10n.text("vm.error.preset.empty")
            case .protectedPresetName:
                return L10n.text("vm.error.preset.protected")
            case .missingOutputFolder:
                return L10n.text("vm.error.output_folder.missing")
            case .processingStopped:
                return L10n.text("vm.error.processing_stopped")
            case .custom(let value):
                return value
            }
        }
    }

    private let percentageRange: ClosedRange<Double> = 1...100
    private let dimensionRange: ClosedRange<Double> = 1...20_000
    private let outputFolderDefaultsKey = "selectedOutputFolderPath"

    @Published public private(set) var items: [FileConversionItem] = []
    @Published public var settings = ConversionSettings()
    @Published private var globalErrorDescriptor: GlobalErrorDescriptor?
    @Published public private(set) var isConverting = false
    @Published public private(set) var progress: Double = 0
    @Published public var showCompletionAlert = false
    @Published public private(set) var presets: [ConversionPreset] = []
    @Published public var selectedPresetID: UUID?

    @Published public var currentSortColumn: SortColumn?
    @Published public var currentSortDirection: SortDirection = .none
    @Published public var selectedItemID: UUID?

    @Published public private(set) var originalPreview: PreviewInfo?
    @Published public private(set) var convertedPreview: PreviewInfo?
    @Published private var previewState: PreviewMessageState = .selectFile

    private let fileService = FileService()
    private let conversionService = ImageConversionService()
    private let presetStore: ConversionPresetStore
    private let userDefaults: UserDefaults
    private var conversionTask: Task<Void, Never>?

    public var globalError: String? {
        globalErrorDescriptor?.localizedText
    }

    public var previewMessage: String {
        previewState.localizedText
    }

    public var canConvert: Bool { !items.isEmpty && settings.outputFolder != nil && !isConverting }
    public var nativeWebPAvailable: Bool { conversionService.isNativeWebPEncodingAvailable }
    public var totalGainInMegabytes: Double {
        let successfulItems = items.compactMap { item -> (inputSize: Int64, outputSize: Int64)? in
            guard case .success(_, let outputSize) = item.status else { return nil }
            return (item.inputSize, outputSize)
        }

        let totalInputSize = successfulItems.reduce(Int64(0)) { $0 + $1.inputSize }
        let totalOutputSize = successfulItems.reduce(Int64(0)) { $0 + $1.outputSize }
        return Double(totalInputSize - totalOutputSize) / 1_048_576
    }

    public var formattedTotalGain: String {
        let formatter = NumberFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formattedValue = formatter.string(from: NSNumber(value: totalGainInMegabytes)) ?? "0.00"
        return L10n.format("vm.total_gain.megabytes", formattedValue)
    }

    public var selectedPreset: ConversionPreset? {
        guard let selectedPresetID else { return nil }
        return presets.first(where: { $0.id == selectedPresetID })
    }

    public var canDeleteSelectedPreset: Bool { selectedPreset?.isSystemPreset == false }

    public func isCustomPreset(_ preset: ConversionPreset) -> Bool { !preset.isSystemPreset }

    public init() {
        self.presetStore = ConversionPresetStore()
        self.userDefaults = .standard
        presets = presetStore.loadPresets()
        settings.outputFolder = restoredOutputFolder()
        selectedPresetID = matchingPresetID(for: settings)
    }

    init(
        presetStore: ConversionPresetStore = ConversionPresetStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.presetStore = presetStore
        self.userDefaults = userDefaults
        presets = presetStore.loadPresets()
        settings.outputFolder = restoredOutputFolder()
        selectedPresetID = matchingPresetID(for: settings)
    }

    public var sortedItems: [FileConversionItem] {
        guard let column = currentSortColumn, currentSortDirection != .none else { return items }

        if column == .afterSize {
            return sortAfterColumnKeepingMissingAtBottom()
        }

        let directionMultiplier = currentSortDirection == .ascending ? 1 : -1
        return items.sorted { lhs, rhs in
            let result: Int
            switch column {
            case .name:
                result = lhs.filename.localizedCaseInsensitiveCompare(rhs.filename).comparisonValue
            case .beforeSize:
                result = compareNumbers(lhs.inputSize, rhs.inputSize)
            case .gain:
                result = compareOptionalNumbers(gainPercentage(for: lhs), gainPercentage(for: rhs))
            case .status:
                result = compareNumbers(statusRank(lhs.status), statusRank(rhs.status))
            case .afterSize:
                result = 0
            }

            if result == 0 {
                return insertionIndex(for: lhs.id) < insertionIndex(for: rhs.id)
            }

            return result * directionMultiplier < 0
        }
    }

    public var selectedItem: FileConversionItem? {
        guard let selectedItemID else { return nil }
        return items.first(where: { $0.id == selectedItemID })
    }

    public func displayName(for preset: ConversionPreset) -> String {
        preset.localizedDisplayName
    }

    public func cycleSort(for column: SortColumn) {
        if currentSortColumn != column {
            currentSortColumn = column
            currentSortDirection = .descending
            return
        }

        switch currentSortDirection {
        case .none: currentSortDirection = .descending
        case .descending: currentSortDirection = .ascending
        case .ascending:
            currentSortDirection = .none
            currentSortColumn = nil
        }
    }

    public func addFilesFromPanel() {
        addFiles(fileService.openImagePanel())
    }

    public func addFiles(_ urls: [URL]) {
        let existing = Set(items.map { $0.inputURL.standardizedFileURL })
        let newItems = urls
            .filter { fileService.isSupportedImage(url: $0) }
            .filter { !existing.contains($0.standardizedFileURL) }
            .map { FileConversionItem(inputURL: $0, inputSize: fileService.fileSize(for: $0)) }

        items.append(contentsOf: newItems)
        refreshPreviewIfNeeded()
    }

    public func removeItem(_ item: FileConversionItem) {
        items.removeAll { $0.id == item.id }
        if selectedItemID == item.id {
            selectedItemID = nil
            clearPreviewState(.selectFile)
        }
    }

    public func clearAll() {
        stopConversion()
        items.removeAll()
        progress = 0
        globalErrorDescriptor = nil
        showCompletionAlert = false
        selectedItemID = nil
        clearPreviewState(.selectFile)
    }

    public func selectOutputFolder() {
        guard let outputFolder = fileService.openOutputFolderPanel() else { return }
        settings.outputFolder = outputFolder
        persistOutputFolder(outputFolder)
    }

    public func stopConversion() {
        conversionTask?.cancel()
    }

    public func handleDrop(providers: [NSItemProvider]) {
        Task { @MainActor in 
            let urls = await fileService.acceptedImageURLs(from: providers)
            addFiles(urls)
        }
    }

    public func updateResizeMode(_ mode: ResizeMode) {
        var updated = settings
        updated.resizeSettings.mode = mode
        if mode == .percentage { updated.resizeSettings.keepAspectRatio = true }
        settings = updated
        refreshSelectedPreset()
    }

    public func updateQuality(_ quality: Double) {
        var updated = settings
        updated.quality = quality
        settings = updated
        refreshSelectedPreset()
    }

    func updatePercentage(_ percentage: Double) {
        var updated = settings
        updated.resizeSettings.percentage = min(max(percentageRange.lowerBound, percentage), percentageRange.upperBound)
        settings = updated
        refreshSelectedPreset()
    }

    public func updateWidth(_ width: Double) {
        var updated = settings
        updated.resizeSettings.width = min(max(dimensionRange.lowerBound, width), dimensionRange.upperBound)
        settings = updated
        refreshSelectedPreset()
    }

    public func updateHeight(_ height: Double) {
        var updated = settings
        updated.resizeSettings.height = min(max(dimensionRange.lowerBound, height), dimensionRange.upperBound)
        settings = updated
        refreshSelectedPreset()
    }

    func updateKeepAspectRatio(_ keep: Bool) {
        var updated = settings
        updated.resizeSettings.keepAspectRatio = keep
        settings = updated
        refreshSelectedPreset()
    }

    func updateRemoveMetadata(_ removeMetadata: Bool) {
        var updated = settings
        updated.removeMetadata = removeMetadata
        settings = updated
        refreshSelectedPreset()
    }

    func updateSuffixMode(_ suffixMode: SuffixMode) {
        var updated = settings
        updated.suffixMode = suffixMode
        settings = updated
        refreshSelectedPreset()
    }

    public func applyPreset(id: UUID?) {
        guard let id, let preset = presets.first(where: { $0.id == id }) else {
            selectedPresetID = nil
            return
        }

        let outputFolder = settings.outputFolder
        settings = ConversionSettings(
            quality: preset.quality,
            resizeSettings: preset.resizeSettings,
            outputFolder: outputFolder,
            removeMetadata: preset.removeMetadata,
            suffixMode: preset.suffixMode,
            selectedPresetName: preset.name
        )
        selectedPresetID = preset.id
    }

    public func saveCurrentPreset(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            globalErrorDescriptor = .emptyPresetName
            return
        }
        guard !presetStore.isProtectedPresetName(trimmedName) else {
            globalErrorDescriptor = .protectedPresetName
            return
        }

        globalErrorDescriptor = nil

        let preset = ConversionPreset(
            name: trimmedName,
            quality: settings.quality,
            resizeSettings: settings.resizeSettings,
            removeMetadata: settings.removeMetadata,
            suffixMode: settings.suffixMode
        )

        presets.append(preset)
        presetStore.savePresets(presets)
        selectedPresetID = preset.id
    }

    public func deletePreset(id: UUID) {
        guard
            let preset = presets.first(where: { $0.id == id }),
            !preset.isSystemPreset,
            !presetStore.isProtectedPresetName(preset.name)
        else {
            return
        }

        presets = presetStore.deletePreset(id: id, from: presets)

        if selectedPresetID == id {
            applyDefaultPreset()
            return
        }

        refreshSelectedPreset()
    }

    func updateSelectedItem(id: UUID?) {
        selectedItemID = id
        refreshPreviewIfNeeded()
    }

    public func convertAll() {
        guard let outputFolder = settings.outputFolder else {
            globalErrorDescriptor = .missingOutputFolder
            return
        }

        globalErrorDescriptor = nil
        showCompletionAlert = false
        isConverting = true
        progress = 0
        for index in items.indices { items[index].status = .pending }

        let itemsToConvert = items
        var settingsSnapshot = settings
        settingsSnapshot.selectedPresetName = selectedPreset?.name
        let conversionService = self.conversionService

        conversionTask?.cancel()
        conversionTask = Task { @MainActor [weak self, itemsToConvert, settingsSnapshot, outputFolder, conversionService] in
            guard let self else { return }
            defer { self.conversionTask = nil }

            let total = itemsToConvert.count
            var converted = 0

            for item in itemsToConvert {
                if Task.isCancelled {
                    self.finishStoppedConversion()
                    return
                }

                self.updateStatus(.processing, for: item.id)
                do {
                    let result = try await Task.detached(priority: .userInitiated) {
                        try conversionService.convert(inputURL: item.inputURL, settings: settingsSnapshot, outputFolder: outputFolder)
                    }.value

                    if Task.isCancelled {
                        self.finishStoppedConversion()
                        return
                    }

                    self.updateStatus(.success(outputURL: result.outputURL, outputSize: result.outputSize), for: item.id)
                } catch is CancellationError {
                    self.finishStoppedConversion()
                    return
                } catch {
                    self.updateStatus(.failure(message: error.localizedDescription), for: item.id)
                }

                converted += 1
                self.progress = Double(converted) / Double(max(total, 1))
            }

            self.isConverting = false
            self.showCompletionAlert = true
        }
    }

    func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    func formattedGain(for item: FileConversionItem) -> String {
        guard let gain = gainPercentage(for: item) else { return "-" }
        return L10n.format("vm.gain.percent", Int(gain.rounded()))
    }

    func sortIndicator(for column: SortColumn) -> String? {
        guard currentSortColumn == column else { return nil }
        switch currentSortDirection {
        case .ascending: return "chevron.up"
        case .descending: return "chevron.down"
        case .none: return nil
        }
    }

    private func updateStatus(_ status: FileConversionStatus, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
        if id == selectedItemID { refreshPreviewIfNeeded() }
    }

    private func refreshPreviewIfNeeded() {
        guard let item = selectedItem else {
            clearPreviewState(.selectFile)
            return
        }

        let requestedID = item.id
        previewState = .loading

        Task {
            let originalLoaded = await loadPreview(for: item.inputURL)
            let converted = await loadConvertedPreview(for: item)
            guard selectedItemID == requestedID else { return }

            originalPreview = PreviewInfo(image: originalLoaded.image, fileSize: item.inputSize, dimensions: originalLoaded.dimensions)
            convertedPreview = converted
            previewState = converted == nil ? .availableAfterConversion : .none
        }
    }

    private func loadConvertedPreview(for item: FileConversionItem) async -> PreviewInfo? {
        guard case .success(let outputURL, let outputSize) = item.status else { return nil }
        let loaded = await loadPreview(for: outputURL)
        return PreviewInfo(image: loaded.image, fileSize: outputSize, dimensions: loaded.dimensions)
    }

    private func loadPreview(for url: URL) async -> LoadedPreview {
        let dimensions = await Task.detached(priority: .utility) {
            Self.imageDimensions(for: url)
        }.value

        return LoadedPreview(image: NSImage(contentsOf: url), dimensions: dimensions)
    }

    nonisolated private static func imageDimensions(for url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        return CGSize(width: width, height: height)
    }

    private func clearPreviewState(_ state: PreviewMessageState) {
        previewState = state
        originalPreview = nil
        convertedPreview = nil
    }

    private func persistOutputFolder(_ url: URL) {
        userDefaults.set(url.path, forKey: outputFolderDefaultsKey)
    }

    private func restoredOutputFolder() -> URL? {
        guard let savedPath = userDefaults.string(forKey: outputFolderDefaultsKey) else {
            return nil
        }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: savedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            userDefaults.removeObject(forKey: outputFolderDefaultsKey)
            return nil
        }

        return URL(fileURLWithPath: savedPath, isDirectory: true)
    }

    private func finishStoppedConversion() {
        isConverting = false
        showCompletionAlert = false
        globalErrorDescriptor = .processingStopped
    }

    private var defaultPresetID: UUID? {
        presets.first(where: { $0.name == ConversionPresetStore.defaultPresetName })?.id
    }

    private func applyDefaultPreset() {
        applyPreset(id: defaultPresetID)
    }

    private func refreshSelectedPreset() {
        selectedPresetID = matchingPresetID(for: settings)
    }

    private func matchingPresetID(for settings: ConversionSettings) -> UUID? {
        presets.first {
            $0.quality == settings.quality &&
            $0.resizeSettings == settings.resizeSettings &&
            $0.removeMetadata == settings.removeMetadata
        }?.id
    }

    private func sortAfterColumnKeepingMissingAtBottom() -> [FileConversionItem] {
        let complete = items.filter { $0.status.outputSizeForSorting != nil }
        let missing = items.filter { $0.status.outputSizeForSorting == nil }
        let directionMultiplier = currentSortDirection == .ascending ? 1 : -1

        let sortedComplete = complete.sorted { lhs, rhs in
            let result = compareNumbers(lhs.status.outputSizeForSorting ?? 0, rhs.status.outputSizeForSorting ?? 0)
            if result == 0 {
                return insertionIndex(for: lhs.id) < insertionIndex(for: rhs.id)
            }
            return result * directionMultiplier < 0
        }

        return sortedComplete + missing
    }

    private func insertionIndex(for id: UUID) -> Int {
        items.firstIndex(where: { $0.id == id }) ?? Int.max
    }

    private func compareNumbers<T: Comparable>(_ lhs: T, _ rhs: T) -> Int {
        if lhs < rhs { return -1 }
        if lhs > rhs { return 1 }
        return 0
    }

    private func compareOptionalNumbers<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Int {
        switch (lhs, rhs) {
        case let (l?, r?): return compareNumbers(l, r)
        case (nil, nil): return 0
        case (nil, _): return 1
        case (_, nil): return -1
        }
    }

    private func gainPercentage(for item: FileConversionItem) -> Double? {
        guard case .success(_, let outputSize) = item.status, item.inputSize > 0 else { return nil }
        return (Double(outputSize - item.inputSize) / Double(item.inputSize)) * 100
    }

    private func statusRank(_ status: FileConversionStatus) -> Int {
        switch status {
        case .processing: return 0
        case .success: return 1
        case .failure: return 2
        case .pending: return 3
        }
    }
}

private extension ComparisonResult {
    var comparisonValue: Int {
        switch self {
        case .orderedAscending: return -1
        case .orderedDescending: return 1
        case .orderedSame: return 0
        }
    }
}

private extension FileConversionStatus {
    var outputSizeForSorting: Int64? {
        guard case .success(_, let outputSize) = self else { return nil }
        return outputSize
    }
}
