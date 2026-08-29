import Foundation

public enum TextDiffer {
    public static func diff(
        old: String,
        new: String,
        oldName: String = "old",
        newName: String = "new"
    ) -> TextDifference {
        let oldLines = normalizedLines(old)
        let newLines = normalizedLines(new)

        let table = lcsTable(
            oldLines: oldLines,
            newLines: newLines
        )

        var i = oldLines.count
        var j = newLines.count
        var reversed: [DifferenceLine] = []
        reversed.reserveCapacity(max(oldLines.count, newLines.count))

        while i > 0 || j > 0 {
            if i > 0,
               j > 0,
               oldLines[i - 1] == newLines[j - 1] {
                reversed.append(
                    .init(
                        operation: .equal,
                        text: oldLines[i - 1],
                        oldLine: i,
                        newLine: j
                    )
                )
                i -= 1
                j -= 1
                continue
            }

            if j > 0,
               (i == 0 || table[i][j - 1] >= table[i - 1][j]) {
                reversed.append(
                    .init(
                        operation: .insert,
                        text: newLines[j - 1],
                        newLine: j
                    )
                )
                j -= 1
                continue
            }

            if i > 0 {
                reversed.append(
                    .init(
                        operation: .delete,
                        text: oldLines[i - 1],
                        oldLine: i
                    )
                )
                i -= 1
                continue
            }
        }

        return .init(
            oldName: oldName,
            newName: newName,
            lines: reversed.reversed()
        )
    }

    private static func normalizedLines(
        _ string: String
    ) -> [String] {
        let normalized = string
            .replacingOccurrences(
                of: "\r\n",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\r",
                with: "\n"
            )

        guard !normalized.isEmpty else {
            return []
        }

        var lines = normalized
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(String.init)

        if normalized.hasSuffix("\n") {
            lines.removeLast()
        }

        return lines
    }

    private static func lcsTable(
        oldLines: [String],
        newLines: [String]
    ) -> [[Int]] {
        let rows = oldLines.count + 1
        let cols = newLines.count + 1

        var table = Array(
            repeating: Array(repeating: 0, count: cols),
            count: rows
        )

        guard !oldLines.isEmpty, !newLines.isEmpty else {
            return table
        }

        for i in 1..<rows {
            for j in 1..<cols {
                if oldLines[i - 1] == newLines[j - 1] {
                    table[i][j] = table[i - 1][j - 1] + 1
                } else {
                    table[i][j] = max(
                        table[i - 1][j],
                        table[i][j - 1]
                    )
                }
            }
        }

        return table
    }
}
