import Foundation
import CoreText

/// Maps between logical buffer positions and visual screen positions.
/// Essential for BiDi text where the visual order differs from the logical order.
class CursorMapper {

    struct VisualMapping {
        let logicalToVisualX: [Int: CGFloat]
        let ctLine: CTLine
    }

    private var rowMappings: [Int: VisualMapping] = [:]

    /// Update the mapping for a row after BiDi rendering
    func updateMapping(row: Int, text: String, font: CTFont) {
        guard !text.isEmpty else {
            rowMappings.removeValue(forKey: row)
            return
        }

        let attrString = NSAttributedString(
            string: text,
            attributes: [.font: font as Any]
        )
        let ctLine = CTLineCreateWithAttributedString(attrString)

        var mapping: [Int: CGFloat] = [:]
        for i in 0...text.count {
            let offset = CTLineGetOffsetForStringIndex(ctLine, i, nil)
            mapping[i] = CGFloat(offset)
        }

        rowMappings[row] = VisualMapping(
            logicalToVisualX: mapping,
            ctLine: ctLine
        )
    }

    /// Get the visual X position for a logical column
    func visualX(logicalCol: Int, row: Int) -> CGFloat? {
        rowMappings[row]?.logicalToVisualX[logicalCol]
    }

    /// Get the logical column for a visual X click position
    func logicalCol(visualX: CGFloat, row: Int) -> Int? {
        guard let mapping = rowMappings[row] else { return nil }
        return CTLineGetStringIndexForPosition(
            mapping.ctLine,
            CGPoint(x: visualX, y: 0)
        )
    }

    /// Clear mappings (e.g., on scroll or resize)
    func clearAll() {
        rowMappings.removeAll()
    }

    /// Clear mapping for a specific row
    func clearRow(_ row: Int) {
        rowMappings.removeValue(forKey: row)
    }
}
