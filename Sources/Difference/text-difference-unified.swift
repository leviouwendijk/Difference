public extension TextDifference {
    enum PatchError: Error, Sendable, Equatable {
        case missing_ending
    }

    /// True unified patch serialization, independent of terminal presentation.
    func unified(context: Int = 3) throws -> String {
        var output = ["--- \(oldName)", "+++ \(newName)"]
        let hunks = hunks(context: context)
        guard !hunks.isEmpty else { return output.joined(separator: "\n") + "\n" }
        guard lines.allSatisfy({ $0.ending != nil }) else { throw PatchError.missing_ending }
        for hunk in hunks {
            output.append(hunk.header)
            for index in hunk.indices {
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
