import SwiftUI

extension Color {
    init?(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6,
              let value = UInt64(sanitized, radix: 16) else {
            return nil
        }

        let red = Double((value & 0xFF0000) >> 16) / 255.0
        let green = Double((value & 0x00FF00) >> 8) / 255.0
        let blue = Double(value & 0x0000FF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}

enum OrloColors {
    static let primary = Color(hex: "#4B708C")!
    static let lightBlue = Color(hex: "#8DB3CE")!
    static let lightBackground = Color(hex: "#E6E8E9")!
    static let darkBackground = Color(hex: "#050A12")!
}
