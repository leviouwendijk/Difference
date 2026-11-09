import Foundation

public extension DifferenceLayout {
    enum Mode: String, Sendable, Codable, Hashable {
        case unified
        case split
    }

    enum Pairing: Sendable, Hashable {
        case none
        /// Bounded, order-preserving line alignment with greedy fallback.
        case aligned(minimum: Double, maxCells: Int = 16_384)
        /// Original lookahead-free matcher retained for compatibility.
        case similarity(minimum: Double)
    }

    struct Cell: Sendable, Codable, Hashable {
        public let line: Int
        public let text: String
        public let role: Role
        public let spans: [TextDifference.Analysis.Span]

        public init(
            line: Int,
            text: String,
            role: Role,
            spans: [TextDifference.Analysis.Span] = []
        ) {
            self.line = line
            self.text = text
            self.role = role
            self.spans = spans
        }
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
        pairing: Pairing = .aligned(minimum: 0.45)
    ) -> Projection {
        if mode == .split {
            // The raw convenience path computes alignment once, with no inline spans.
            return project(
                difference.analyze(options: .init(pairing: pairing, inline: .none)),
                mode: mode,
                options: options
            )
        }
        return projectRows(difference, mode: mode, options: options,
                           alignments: [], pairs: [])
    }

    /// Reuse the alignment and optional UTF-8 spans already held by analysis.
    static func project(
        _ analysis: TextDifference.Analysis,
        mode: Mode = .split,
        options: DifferenceRenderOptions = .unified
    ) -> Projection {
        projectRows(analysis.difference, mode: mode, options: options,
                    alignments: analysis.alignments, pairs: analysis.pairs)
    }

    private static func projectRows(
        _ difference: TextDifference,
        mode: Mode,
        options: DifferenceRenderOptions,
        alignments: [TextDifference.Analysis.Alignment],
        pairs: [TextDifference.Analysis.Pair]
    ) -> Projection {
        let byStart = Dictionary(uniqueKeysWithValues: alignments.map {
            ($0.range.lowerBound, $0)
        })
        let oldSpans = Dictionary(uniqueKeysWithValues: pairs.map { ($0.oldLine, $0.old) })
        let newSpans = Dictionary(uniqueKeysWithValues: pairs.map { ($0.newLine, $0.new) })
        var rows: [Row] = []
        if options.showHeader {
            rows.append(.init(kind: .headerOld, old: nil, new: nil, text: difference.oldName))
            rows.append(.init(kind: .headerNew, old: nil, new: nil, text: difference.newName))
        }
        let all = options.showUnchangedLines || options.contextLineCount == .max
        let hunks = difference.hunks(context: all ? .max : options.contextLineCount)
        if hunks.isEmpty, all {
            append(difference.lines[...], mode: mode, alignments: byStart,
                   oldSpans: oldSpans, newSpans: newSpans, to: &rows)
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
                append(difference.lines[hunk.indices], mode: mode, alignments: byStart,
                       oldSpans: oldSpans, newSpans: newSpans, to: &rows)
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
        alignments: [Int: TextDifference.Analysis.Alignment],
        oldSpans: [Int: [TextDifference.Analysis.Span]],
        newSpans: [Int: [TextDifference.Analysis.Span]],
        to rows: inout [Row]
    ) {
        var index = source.startIndex
        while index < source.endIndex {
            let line = source[index]
            if line.operation == .equal {
                rows.append(content(
                    old: cell(line, old: true, spans: oldSpans),
                    new: cell(line, old: false, spans: newSpans)
                ))
                index += 1
                continue
            }
            if mode == .unified {
                rows.append(content(
                    old: line.operation == .delete ? cell(line, old: true, spans: oldSpans) : nil,
                    new: line.operation == .insert ? cell(line, old: false, spans: newSpans) : nil
                ))
                index += 1
                continue
            }

            let start = index
            while index < source.endIndex, source[index].operation != .equal {
                index += 1
            }
            guard let alignment = alignments[start],
                  alignment.range == (start..<index) else {
                // Defensive lossless fallback for an incomplete or mismatched analysis.
                for line in source[start..<index] {
                    rows.append(content(
                        old: line.operation == .delete ? cell(line, old: true, spans: oldSpans) : nil,
                        new: line.operation == .insert ? cell(line, old: false, spans: newSpans) : nil
                    ))
                }
                continue
            }
            for step in alignment.steps {
                let old = step.oldIndex.flatMap { cell(source[$0], old: true, spans: oldSpans) }
                let new = step.newIndex.flatMap { cell(source[$0], old: false, spans: newSpans) }
                rows.append(content(old: old, new: new))
            }
        }
    }

    private static func content(old: Cell?, new: Cell?) -> Row {
        .init(kind: .content, old: old, new: new, text: "")
    }

    private static func cell(
        _ line: DifferenceLine,
        old: Bool,
        spans: [Int: [TextDifference.Analysis.Span]]
    ) -> Cell? {
        guard let number = old ? line.oldLine : line.newLine else { return nil }
        let role: Role = line.operation == .equal ? .equal : (old ? .delete : .insert)
        return .init(line: number, text: line.text, role: role, spans: spans[number] ?? [])
    }

}
