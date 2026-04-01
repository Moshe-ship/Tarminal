import Foundation

/// Analyzes terminal lines for RTL content.
/// Fast path: pure LTR lines skip BiDi processing entirely.
enum BiDiDirection {
    case ltr
    case rtl
    case neutral
}

struct BiDiLineAnalyzer {

    /// Unicode ranges that contain RTL characters
    private static let rtlRanges: [ClosedRange<UInt32>] = [
        0x0590...0x05FF,   // Hebrew
        0x0600...0x06FF,   // Arabic
        0x0700...0x074F,   // Syriac
        0x0750...0x077F,   // Arabic Supplement
        0x0780...0x07BF,   // Thaana
        0x07C0...0x07FF,   // NKo
        0x0800...0x083F,   // Samaritan
        0x0840...0x085F,   // Mandaic
        0x0860...0x086F,   // Syriac Supplement
        0x0870...0x089F,   // Arabic Extended-B
        0x08A0...0x08FF,   // Arabic Extended-A
        0xFB1D...0xFB4F,   // Hebrew Presentation Forms
        0xFB50...0xFDFF,   // Arabic Presentation Forms-A
        0xFE70...0xFEFF,   // Arabic Presentation Forms-B
        0x10800...0x1083F, // Cypriot Syllabary (RTL)
        0x10900...0x1091F, // Phoenician
        0x10920...0x1093F, // Lydian
        0x1EE00...0x1EEFF, // Arabic Mathematical Alphabetic Symbols
    ]

    /// Quick check if a scalar is RTL
    static func isRTL(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        for range in rtlRanges {
            if range.contains(value) { return true }
            if value < range.lowerBound { break } // Ranges are sorted
        }
        return false
    }

    /// Check if a string contains any RTL characters
    static func containsRTL(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if isRTL(scalar) { return true }
        }
        return false
    }

    /// Determine paragraph direction based on first strong character (UBA P2/P3)
    static func paragraphDirection(_ text: String) -> BiDiDirection {
        for scalar in text.unicodeScalars {
            if isRTL(scalar) { return .rtl }
            // Latin, digits, etc. are strong LTR
            if scalar.properties.generalCategory == .uppercaseLetter ||
               scalar.properties.generalCategory == .lowercaseLetter {
                return .ltr
            }
        }
        return .neutral
    }
}
