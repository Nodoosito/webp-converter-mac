import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ConversionError: LocalizedError {
    case unableToReadImage
    case outputFolderUnavailable
    case nativeWebPUnsupported
    case unableToCreateDestination(details: String)
    case failedToFinalize
    case fallbackEncoderUnavailable
    case fallbackEncodingFailed(details: String)
    case unableToWriteTemporaryImage

    var errorDescription: String? {
        switch self {
        case .unableToReadImage:
            return "Impossible de lire l'image source."
        case .outputFolderUnavailable:
            return "Le dossier de sortie est indisponible ou inaccessible."
        case .nativeWebPUnsupported:
            return "Ce macOS ne prend pas en charge l'export WEBP natif via ImageIO."
        case .unableToCreateDestination(let details):
            return "Impossible de créer le fichier WEBP de destination. \(details)"
        case .failedToFinalize:
            return "La conversion WEBP a échoué lors de l'écriture finale du fichier."
        case .fallbackEncoderUnavailable:
            return "Export WEBP natif indisponible et aucun encodeur de secours trouvé (installez 'cwebp')."
        case .fallbackEncodingFailed(let details):
            return "La conversion WEBP via l'encodeur de secours a échoué. \(details)"
        case .unableToWriteTemporaryImage:
            return "Impossible d'écrire l'image temporaire pour l'encodeur de secours."
        }
    }
}

struct ImageConversionService: Sendable {
    private static let webPIdentifier = UTType.webP.identifier
    nonisolated(unsafe) private static let copiedMetadataKeys: [CFString] = [
        kCGImagePropertyTIFFDictionary,
        kCGImagePropertyExifDictionary,
        kCGImagePropertyGPSDictionary,
        kCGImagePropertyIPTCDictionary,
        kCGImagePropertyPNGDictionary,
        kCGImagePropertyJFIFDictionary,
        kCGImagePropertyExifAuxDictionary,
        kCGImagePropertyMakerAppleDictionary
    ]

    var isNativeWebPEncodingAvailable: Bool {
        guard let supported = CGImageDestinationCopyTypeIdentifiers() as? [String] else {
            return false
        }
        return supported.contains(Self.webPIdentifier)
    }

    func convert(
        inputURL: URL,
        settings: ConversionSettings,
        outputFolder: URL
    ) throws -> (outputURL: URL, outputSize: Int64) {
        guard FileManager.default.fileExists(atPath: outputFolder.path) else {
            throw ConversionError.outputFolderUnavailable
        }

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ConversionError.unableToReadImage
        }
        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let sourceOrientation = imageOrientation(from: sourceProperties)
        let normalizedImage = normalizedImage(image: cgImage, orientation: sourceOrientation)

        let targetSize = computeTargetSize(for: normalizedImage, settings: settings.resizeSettings)
        let resizedImage = resizeIfNeeded(image: normalizedImage, targetSize: targetSize)

        print("[Resize] \(inputURL.lastPathComponent) original=\(cgImage.width)x\(cgImage.height) normalized=\(normalizedImage.width)x\(normalizedImage.height) target=\(targetSize.width)x\(targetSize.height) resized=\(resizedImage.width)x\(resizedImage.height) mode=\(settings.resizeSettings.mode.rawValue)")

        let outputBaseName = outputBaseName(
            for: inputURL,
            settings: settings,
            finalImage: resizedImage
        )
        let outputURL = FileService().uniqueOutputURL(
            forBaseName: outputBaseName,
            in: outputFolder,
            pathExtension: "webp"
        )

        if isNativeWebPEncodingAvailable {
            do {
                try exportNativeWebP(
                    image: resizedImage,
                    to: outputURL,
                    quality: settings.quality,
                    sourceProperties: sourceProperties,
                    removeMetadata: settings.removeMetadata
                )
                logOutputSize(outputURL: outputURL, inputURL: inputURL, encoder: "native")
                let outputSize = FileService().fileSize(for: outputURL)
                return (outputURL, outputSize)
            } catch {
                try exportWithCWebP(
                    image: resizedImage,
                    to: outputURL,
                    quality: settings.quality,
                    sourceProperties: sourceProperties,
                    removeMetadata: settings.removeMetadata
                )
                logOutputSize(outputURL: outputURL, inputURL: inputURL, encoder: "cwebp-fallback")
                let outputSize = FileService().fileSize(for: outputURL)
                return (outputURL, outputSize)
            }
        }

        try exportWithCWebP(
            image: resizedImage,
            to: outputURL,
            quality: settings.quality,
            sourceProperties: sourceProperties,
            removeMetadata: settings.removeMetadata
        )
        logOutputSize(outputURL: outputURL, inputURL: inputURL, encoder: "cwebp")
        let outputSize = FileService().fileSize(for: outputURL)
        return (outputURL, outputSize)
    }

    private func exportNativeWebP(
        image: CGImage,
        to outputURL: URL,
        quality: Double,
        sourceProperties: [CFString: Any]?,
        removeMetadata: Bool
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            Self.webPIdentifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.unableToCreateDestination(details: "Format '\(Self.webPIdentifier)' non accepté par ImageIO sur cette machine.")
        }

        let options = destinationProperties(
            image: image,
            quality: quality,
            sourceProperties: sourceProperties,
            removeMetadata: removeMetadata
        )

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.failedToFinalize
        }
    }

    private func exportWithCWebP(
        image: CGImage,
        to outputURL: URL,
        quality: Double,
        sourceProperties: [CFString: Any]?,
        removeMetadata: Bool
    ) throws {
        guard let cwebpPath = findCWebPPath() else {
            if isNativeWebPEncodingAvailable {
                throw ConversionError.fallbackEncoderUnavailable
            }
            throw ConversionError.nativeWebPUnsupported
        }

        let tempInputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        try writeTemporaryPNG(
            image: image,
            to: tempInputURL,
            sourceProperties: sourceProperties,
            removeMetadata: removeMetadata
        )
        defer { try? FileManager.default.removeItem(at: tempInputURL) }

        let q = String(Int((quality * 100).rounded()))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cwebpPath)
        var arguments = [
            "-quiet",
            "-q", q
        ]
        if !removeMetadata {
            arguments.append(contentsOf: ["-metadata", "all"])
        }
        arguments.append(contentsOf: [
            tempInputURL.path,
            "-o", outputURL.path
        ])
        process.arguments = arguments

        let stderr = Pipe()
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw ConversionError.fallbackEncodingFailed(details: stderrText.isEmpty ? "Code \(process.terminationStatus)." : stderrText)
        }
    }

    private func findCWebPPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/cwebp",
            "/usr/local/bin/cwebp",
            "/usr/bin/cwebp"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return nil
    }

    private func writeTemporaryPNG(
        image: CGImage,
        to url: URL,
        sourceProperties: [CFString: Any]?,
        removeMetadata: Bool
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ConversionError.unableToWriteTemporaryImage
        }
        let options: CFDictionary?
        if removeMetadata {
            options = [kCGImagePropertyOrientation: CGImagePropertyOrientation.up.rawValue] as CFDictionary
        } else {
            options = preservedSourceProperties(
                for: image,
                sourceProperties: sourceProperties
            ) as CFDictionary
        }
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.unableToWriteTemporaryImage
        }
    }

    private func destinationProperties(
        image: CGImage,
        quality: Double,
        sourceProperties: [CFString: Any]?,
        removeMetadata: Bool
    ) -> [CFString: Any] {
        guard !removeMetadata else {
            return [
                kCGImageDestinationLossyCompressionQuality: quality,
                kCGImagePropertyOrientation: CGImagePropertyOrientation.up.rawValue
            ]
        }

        var properties = preservedSourceProperties(
            for: image,
            sourceProperties: sourceProperties
        )
        properties[kCGImageDestinationLossyCompressionQuality] = quality

        return properties
    }

    private func preservedSourceProperties(
        for image: CGImage,
        sourceProperties: [CFString: Any]?
    ) -> [CFString: Any] {
        var properties = sourceProperties ?? [:]

        properties[kCGImagePropertyPixelWidth] = image.width
        properties[kCGImagePropertyPixelHeight] = image.height
        properties[kCGImagePropertyOrientation] = CGImagePropertyOrientation.up.rawValue

        return properties
    }

    private func imageOrientation(from sourceProperties: [CFString: Any]?) -> CGImagePropertyOrientation {
        if let orientation = sourceProperties?[kCGImagePropertyOrientation] as? UInt32,
           let imageOrientation = CGImagePropertyOrientation(rawValue: orientation) {
            return imageOrientation
        }

        if let orientation = sourceProperties?[kCGImagePropertyOrientation] as? Int,
           let imageOrientation = CGImagePropertyOrientation(rawValue: UInt32(orientation)) {
            return imageOrientation
        }

        return .up
    }

    private func normalizedImage(image: CGImage, orientation: CGImagePropertyOrientation) -> CGImage {
        guard orientation != .up else {
            return image
        }

        let originalWidth = image.width
        let originalHeight = image.height
        let requiresDimensionSwap = orientation == .left ||
            orientation == .leftMirrored ||
            orientation == .right ||
            orientation == .rightMirrored

        let contextWidth = requiresDimensionSwap ? originalHeight : originalWidth
        let contextHeight = requiresDimensionSwap ? originalWidth : originalHeight

        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: contextWidth,
            height: contextHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return image
        }

        switch orientation {
        case .up:
            break
        case .upMirrored:
            context.translateBy(x: CGFloat(contextWidth), y: 0)
            context.scaleBy(x: -1, y: 1)
        case .down:
            context.translateBy(x: CGFloat(contextWidth), y: CGFloat(contextHeight))
            context.rotate(by: .pi)
        case .downMirrored:
            context.translateBy(x: 0, y: CGFloat(contextHeight))
            context.scaleBy(x: 1, y: -1)
        case .left:
            context.translateBy(x: 0, y: CGFloat(contextHeight))
            context.rotate(by: -.pi / 2)
        case .leftMirrored:
            context.translateBy(x: CGFloat(contextWidth), y: CGFloat(contextHeight))
            context.scaleBy(x: -1, y: 1)
            context.rotate(by: -.pi / 2)
        case .right:
            context.translateBy(x: CGFloat(contextWidth), y: 0)
            context.rotate(by: .pi / 2)
        case .rightMirrored:
            context.scaleBy(x: -1, y: 1)
            context.rotate(by: .pi / 2)
            context.translateBy(x: -CGFloat(originalWidth), y: 0)
        @unknown default:
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight))

        return context.makeImage() ?? image
    }

    private func outputBaseName(
        for inputURL: URL,
        settings: ConversionSettings,
        finalImage: CGImage
    ) -> String {
        let originalBaseName = inputURL.deletingPathExtension().lastPathComponent

        guard let suffix = outputSuffix(settings: settings, finalImage: finalImage) else {
            return originalBaseName
        }

        return "\(originalBaseName)-\(suffix)"
    }

    private func outputSuffix(settings: ConversionSettings, finalImage: CGImage) -> String? {
        switch settings.suffixMode {
        case .none:
            return nil
        case .presetName:
            guard
                let presetName = settings.selectedPresetName?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !presetName.isEmpty
            else {
                return nil
            }

            return sanitizedSuffixComponent(presetName)
        case .dimensions:
            return "\(finalImage.width)x\(finalImage.height)"
        }
    }

    private func sanitizedSuffixComponent(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let components = folded
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }

        let sanitized = components.joined(separator: "-")
        return sanitized.isEmpty ? value.replacingOccurrences(of: " ", with: "-") : sanitized
    }

    private func computeTargetSize(for image: CGImage, settings: ResizeSettings) -> CGSize {
        guard settings.mode != .original else {
            return CGSize(width: image.width, height: image.height)
        }

        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)

        var targetWidth = originalWidth
        var targetHeight = originalHeight

        switch settings.mode {
        case .original:
            break
        case .percentage:
            let clampedPercent = max(1, settings.percentage)
            let factor = CGFloat(clampedPercent) / 100
            targetWidth = originalWidth * factor
            targetHeight = originalHeight * factor
        case .width:
            targetWidth = CGFloat(max(1, settings.width))
            if settings.keepAspectRatio {
                targetHeight = originalHeight * (targetWidth / originalWidth)
            }
        case .height:
            targetHeight = CGFloat(max(1, settings.height))
            if settings.keepAspectRatio {
                targetWidth = originalWidth * (targetHeight / originalHeight)
            }
        }

        return CGSize(
            width: max(1, Int(targetWidth.rounded())),
            height: max(1, Int(targetHeight.rounded()))
        )
    }

    private func resizeIfNeeded(image: CGImage, targetSize: CGSize) -> CGImage {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)

        guard width != image.width || height != image.height else {
            return image
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage() ?? image
    }

    private func logOutputSize(outputURL: URL, inputURL: URL, encoder: String) {
        guard let source = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return
        }

        print("[Resize] \(inputURL.lastPathComponent) output=\(image.width)x\(image.height) encoder=\(encoder)")
    }
}
