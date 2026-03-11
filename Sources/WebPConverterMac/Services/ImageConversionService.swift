import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ConversionError: LocalizedError {
    case unableToReadImage
    case unableToCreateDestination
    case failedToFinalize
    case missingOutputFolder

    var errorDescription: String? {
        switch self {
        case .unableToReadImage:
            return "Impossible de lire l'image source."
        case .unableToCreateDestination:
            return "Impossible de créer le fichier WEBP de destination."
        case .failedToFinalize:
            return "La conversion WEBP a échoué lors de l'écriture."
        case .missingOutputFolder:
            return "Aucun dossier de sortie sélectionné."
        }
    }
}

struct ImageConversionService {
    func convert(
        inputURL: URL,
        settings: ConversionSettings,
        outputFolder: URL
    ) throws -> (outputURL: URL, outputSize: Int64) {
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ConversionError.unableToReadImage
        }

        let resizedImage = resizeIfNeeded(image: cgImage, with: settings.resizeSettings)
        let outputURL = outputFolder
            .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("webp")

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.webP.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.unableToCreateDestination
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: settings.quality
        ]

        CGImageDestinationAddImage(destination, resizedImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.failedToFinalize
        }

        let outputSize = FileService().fileSize(for: outputURL)
        return (outputURL, outputSize)
    }

    private func resizeIfNeeded(image: CGImage, with settings: ResizeSettings) -> CGImage {
        guard settings.mode != .original else { return image }

        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)

        var targetWidth = originalWidth
        var targetHeight = originalHeight

        switch settings.mode {
        case .original:
            break
        case .percentage:
            let factor = CGFloat(max(1, settings.percentage)) / 100
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

        let width = max(1, Int(targetWidth.rounded()))
        let height = max(1, Int(targetHeight.rounded()))

        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue
              ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage() ?? image
    }
}
