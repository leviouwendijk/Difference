import Foundation

public extension DifferenceLayout {
    enum Mode: String, Sendable, Codable, Hashable {
        case unified
        case split
    }

    enum Pairing: Sendable, Hashable {
        case none
        case similarity(minimum: Double)
    }

    struct Cell: Sendable, Codable, Hashable {
        public let line: Int
        public let text: String
        public let role: Role
    }

    struct Row: Sendable, Codable, Hashable {
        public enum Kind: Sendable, Codable, Hashable {
            case headerOld
            case headerNew
            case hunk(TextDifference.Hunk)
            case collapsed(old: Range<Int>, new: Range<Int>)
            case content
            case endOfFile
        }

        public let kind: Kind
        public let old: Cell?
        public let new: Cell?
        public let text: String
    }

    struct Projection: Sendable, Codable, Hashable {
        public let mode: Mode
        public let rows: [Row]
    }

    static func project(
        _ difference: TextDifference,
        mode: Mode = .unified,
        options: DifferenceRenderOptions = .unified,
        pairing: Pairing = .similarity(minimum: 0.45)
    ) -> Projection {
        var rows: [Row] = []
        if options.showHeader {
            rows.append(.init(kind: .headerOld, old: nil, new: nil, text: difference.oldName))
            rows.append(.init(kind: .headerNew, old: nil, new: nil, text: difference.newName))
        }
        let all = options.showUnchangedLines || options.contextLineCount == .max
        let hunks = difference.hunks(context: all ? .max : options.contextLineCount)
        if hunks.isEmpty, all {
            append(difference.lines[...], mode: mode, pairing: pairing, to: &rows)
        } else {
            var previous = 0
            for hunk in hunks {
                if hunk.indices.lowerBound > previous {
                    appendCollapsed(
                        difference.lines[previous..<hunk.indices.lowerBound],
                        label: options.collapseSeparator,
                        to: &rows
                    )
                }
                if options.showHunkHeaders {
                    rows.append(.init(kind: .hunk(hunk), old: nil, new: nil, text: hunk.header))
                }
                append(difference.lines[hunk.indices], mode: mode, pairing: pairing, to: &rows)
                previous = hunk.indices.upperBound
            }
            if previous < difference.lines.count, !hunks.isEmpty {
                appendCollapsed(
                    difference.lines[previous...],
                    label: options.collapseSeparator,
                    to: &rows
                )
            }
        }
        if options.showEndOfFile {
            rows.append(.init(kind: .endOfFile, old: nil, new: nil, text: "EOF"))
        }
        return .init(mode: mode, rows: rows)
    }

    private static func appendCollapsed(
        _ omitted: ArraySlice<DifferenceLine>,
        label: String,
        to rows: inout [Row]
    ) {
        guard !omitted.isEmpty else { return }
        let oldLines = omitted.compactMap(\.oldLine)
        let newLines = omitted.compactMap(\.newLine)
        guard let firstOld = oldLines.first, let firstNew = newLines.first else { return }
        rows.append(.init(
            kind: .collapsed(
                old: firstOld..<(firstOld + oldLines.count),
                new: firstNew..<(firstNew + newLines.count)
            ),
            old: nil,
            new: nil,
            text: label.replacingOccurrences(of: "{count}", with: String(omitted.count))
        ))
    }

    private static func append(
        _ source: ArraySlice<DifferenceLine>,
        mode: Mode,
        pairing: Pairing,
        to rows: inout [Row]
    ) {
        let lines = Array(source)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.operation == .equal {
                rows.append(content(old: cell(line, old: true), new: cell(line, old: false)))
                index += 1
                continue
            }
            if mode == .unified {
                rows.append(content(
                    old: line.operation == .delete ? cell(line, old: true) : nil,
                    new: line.operation == .insert ? cell(line, old: false) : nil
                ))
                index += 1
                continue
            }
            let start = index
            while index < lines.count, lines[index].operation != .equal {
                index += 1
            }
            let group = lines[start..<index]
            let removed = group.filter { $0.operation == .delete }
            let added = group.filter { $0.operation == .insert }
            switch pairing {
            case .none:
                for line in removed {
                    rows.append(content(old: cell(line, old: true), new: nil))
                }
                for line in added {
                    rows.append(content(old: nil, new: cell(line, old: false)))
                }
            case .similarity(let minimum):
                let threshold = max(0, min(1, minimum))
                var i = 0
                var j = 0
                while i < removed.count || j < added.count {
                    if i < removed.count, j < added.count,
                       similarity(removed[i].text, added[j].text) >= threshold {
                        rows.append(content(
                            old: cell(removed[i], old: true),
                            new: cell(added[j], old: false)
                        ))
                        i += 1
                        j += 1
                    } else if i < removed.count {
                        rows.append(content(old: cell(removed[i], old: true), new: nil))
                        i += 1
                    } else {
                        rows.append(content(old: nil, new: cell(added[j], old: false)))
                        j += 1
                    }
                }
            }
        }
    }

    private static func content(old: Cell?, new: Cell?) -> Row {
        .init(kind: .content, old: old, new: new, text: "")
    }

    private static func cell(_ line: DifferenceLine, old: Bool) -> Cell? {
        guard let number = old ? line.oldLine : line.newLine else { return nil }
        let role: Role = line.operation == .equal ? .equal : (old ? .delete : .insert)
        return .init(line: number, text: line.text, role: role)
    }

    private static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let left = Array(lhs)
        let right = Array(rhs)
        let longest = max(left.count, right.count)
        guard longest > 0 else { return 1 }
        var prefix = 0
        while prefix < min(left.count, right.count), left[prefix] == right[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < min(left.count, right.count) - prefix,
              left[left.count - suffix - 1] == right[right.count - suffix - 1] {
            suffix += 1
        }
        return Double(prefix + suffix) / Double(longest)
    }
}
