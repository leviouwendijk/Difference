public extension TextDifference {
    enum PatchError: Error, Sendable, Equatable {
        case missing_ending
    }

    /// Serialize a unified text patch with authoritative hunk coordinates.
    /// Includes file headers and final-newline markers; Git metadata is separate.
    func unified(context: Int = 3) throws -> String {
        var output = ["--- \(oldName)", "+++ \(newName)"]
        let changed = lines.indices.filter { lines[$0].operation != .equal }
        guard !changed.isEmpty else { return output.joined(separator: "\n") + "\n" }
        guard lines.allSatisfy({ $0.ending != nil }) else { throw PatchError.missing_ending }
        let count = max(0, context)
        var regions: [ClosedRange<Int>] = []
        for index in changed {
            let lower = max(0, index - count)
            let upper = min(lines.count - 1, index + count)
            if let last = regions.last, lower <= last.upperBound + 1 {
                regions[regions.count - 1] = last.lowerBound...max(last.upperBound, upper)
            } else {
                regions.append(lower...upper)
            }
        }
        var oldPrefix = [Int](repeating: 0, count: lines.count + 1)
        var newPrefix = [Int](repeating: 0, count: lines.count + 1)
        for index in lines.indices {
            oldPrefix[index + 1] = oldPrefix[index] + (lines[index].operation == .insert ? 0 : 1)
            newPrefix[index + 1] = newPrefix[index] + (lines[index].operation == .delete ? 0 : 1)
        }
        for region in regions {
            let start = region.lowerBound
            let end = region.upperBound + 1
            let oldCount = oldPrefix[end] - oldPrefix[start]
            let newCount = newPrefix[end] - newPrefix[start]
            let oldStart = oldPrefix[start] + (oldCount > 0 ? 1 : 0)
            let newStart = newPrefix[start] + (newCount > 0 ? 1 : 0)
            output.append("@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@")
            for index in region {
                let line = lines[index]
                let marker: String
                switch line.operation {
                case .equal: marker = " "
                case .delete: marker = "-"
                case .insert: marker = "+"
                }
                let carriage = line.ending == .crlf || line.ending == .cr ? "\r" : ""
                output.append(marker + line.text + carriage)
                if line.ending == DifferenceLine.Ending.none {
                    output.append("\\ No newline at end of file")
                }
            }
        }
        return output.joined(separator: "\n") + "\n"
    }
}
