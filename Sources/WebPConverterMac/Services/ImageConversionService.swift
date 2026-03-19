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

        let targetSize = computeTargetSize(for: cgImage, settings: settings.resizeSettings)
        let resizedImage = resizeIfNeeded(image: cgImage, targetSize: targetSize)

        print("[Resize] \(inputURL.lastPathComponent) original=\(cgImage.width)x\(cgImage.height) target=\(targetSize.width)x\(targetSize.height) resized=\(resizedImage.width)x\(resizedImage.height) mode=\(settings.resizeSettings.mode.rawValue)")

        let outputURL = FileService().uniqueOutputURL(for: inputURL, in: outputFolder, pathExtension: "webp")

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
        process.arguments = [
            "-quiet",
            "-q", q,
            tempInputURL.path,
            "-o", outputURL.path
        ]

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
            options = nil
        } else {
            options = metadataProperties(from: sourceProperties) as CFDictionary
        }
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.unableToWriteTemporaryImage
        }
    }

    private func destinationProperties(
        quality: Double,
        sourceProperties: [CFString: Any]?,
        removeMetadata: Bool
    ) -> [CFString: Any] {
        var properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        guard !removeMetadata else {
            return properties
        }

        for (key, value) in metadataProperties(from: sourceProperties) {
            properties[key] = value
        }

        if let orientation = sourceProperties?[kCGImagePropertyOrientation] {
            properties[kCGImagePropertyOrientation] = orientation
        }

        return properties
    }

    private func metadataProperties(from sourceProperties: [CFString: Any]?) -> [CFString: Any] {
        guard let sourceProperties else {
            return [:]
        }

        var metadata: [CFString: Any] = [:]

        for key in Self.copiedMetadataKeys {
            if let value = sourceProperties[key] {
                metadata[key] = value
            }
        }

        return metadata
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
