import Foundation
import Position

public extension TextDifference {
    struct Analysis: Sendable, Hashable {
        public enum Inline: Sendable, Hashable {
            case none
            case characters
        }

        public struct Options: Sendable, Hashable {
            public var pairing: DifferenceLayout.Pairing
            public var inline: Inline
            public var maxCells: Int

            public init(
                pairing: DifferenceLayout.Pairing = .aligned(minimum: 0.45),
                inline: Inline = .characters,
                maxCells: Int = 65_536
            ) {
                self.pairing = pairing
                self.inline = inline
                self.maxCells = max(1, maxCells)
            }
        }

        public struct Span: Sendable, Codable, Hashable {
            public let range: Position.CoordinateRange<Position.Unit.UTF8>
        }

        public struct Pair: Sendable, Codable, Hashable {
            public let oldLine: Int
            public let newLine: Int
            public let old: [Span]
            public let new: [Span]
        }

        public let difference: TextDifference
        public let pairing: DifferenceLayout.Pairing
        public let pairs: [Pair]

        struct Match {
            let old: Int?
            let new: Int?
        }

        static func matches(
            _ removed: [DifferenceLine],
            _ added: [DifferenceLine],
            pairing: DifferenceLayout.Pairing
        ) -> [Match] {
            switch pairing {
            case .none:
                return removed.indices.map { Match(old: $0, new: nil) }
                    + added.indices.map { Match(old: nil, new: $0) }
            case .aligned(let minimum, let maxCells):
                return align(removed, added, minimum: minimum, maxCells: maxCells)
            case .similarity(let minimum):
                let threshold = minimum.isFinite ? max(0, min(1, minimum)) : 1
                var result: [Match] = []
                var old = 0
                var new = 0
                while old < removed.count || new < added.count {
                    if old < removed.count, new < added.count,
                       similarity(removed[old].text, added[new].text) >= threshold {
                        result.append(.init(old: old, new: new))
                        old += 1
                        new += 1
                    } else if old < removed.count {
                        result.append(.init(old: old, new: nil))
                        old += 1
                    } else {
                        result.append(.init(old: nil, new: new))
                        new += 1
                    }
                }
                return result
            }
        }

        private static func similarity(_ lhs: String, _ rhs: String) -> Double {
            let old = Array(lhs)
            let new = Array(rhs)
            let count = max(old.count, new.count)
            guard count > 0 else { return 1 }
            var prefix = 0
            while prefix < min(old.count, new.count), old[prefix] == new[prefix] {
                prefix += 1
            }
            var suffix = 0
            while suffix < min(old.count, new.count) - prefix,
                  old[old.count - suffix - 1] == new[new.count - suffix - 1] {
                suffix += 1
            }
            return Double(prefix + suffix) / Double(count)
        }

        static func changes(
            old oldText: String,
            new newText: String,
            oldLine: Int,
            newLine: Int,
            maxCells: Int
        ) -> (old: [Span], new: [Span]) {
            let old = Array(oldText)
            let new = Array(newText)
            var prefix = 0
            while prefix < min(old.count, new.count), old[prefix] == new[prefix] {
                prefix += 1
            }
            var suffix = 0
            while suffix < min(old.count, new.count) - prefix,
                  old[old.count - suffix - 1] == new[new.count - suffix - 1] {
                suffix += 1
            }
            let n = old.count - prefix - suffix
            let m = new.count - prefix - suffix
            guard n > 0 || m > 0 else { return ([], []) }

            var runs: [(Range<Int>, Range<Int>)] = []
            let (cells, overflow) = (n + 1).multipliedReportingOverflow(by: m + 1)
            if overflow || cells > maxCells {
                runs = [(prefix..<(prefix + n), prefix..<(prefix + m))]
            } else {
                let tableWidth = m + 1
                var table = [Int](repeating: 0, count: cells)
                if n > 0, m > 0 {
                    for i in stride(from: n - 1, through: 0, by: -1) {
                        for j in stride(from: m - 1, through: 0, by: -1) {
                            table[i * tableWidth + j] = old[prefix + i] == new[prefix + j]
                                ? table[(i + 1) * tableWidth + j + 1] + 1
                                : max(table[(i + 1) * tableWidth + j], table[i * tableWidth + j + 1])
                        }
                    }
                }
                var i = 0
                var j = 0
                var runOld = 0
                var runNew = 0
                while i < n || j < m {
                    if i < n, j < m, old[prefix + i] == new[prefix + j] {
                        if i > runOld || j > runNew {
                            runs.append(((prefix + runOld)..<(prefix + i),
                                         (prefix + runNew)..<(prefix + j)))
                        }
                        i += 1
                        j += 1
                        runOld = i
                        runNew = j
                    } else if j < m, (i == n || table[i * tableWidth + j + 1] >= table[(i + 1) * tableWidth + j]) {
                        j += 1
                    } else {
                        i += 1
                    }
                }
                if i > runOld || j > runNew {
                    runs.append(((prefix + runOld)..<(prefix + i),
                                 (prefix + runNew)..<(prefix + j)))
                }
            }

            func offsets(_ characters: [Character]) -> [Int] {
                var positions = [0]
                positions.reserveCapacity(characters.count + 1)
                for character in characters {
                    positions.append(positions[positions.count - 1] + String(character).utf8.count)
                }
                return positions
            }
            let oldOffsets = offsets(old)
            let newOffsets = offsets(new)
            func span(_ indices: Range<Int>, offsets: [Int], line: Int) -> Span? {
                guard !indices.isEmpty,
                      let start = try? Position.Coordinate<Position.Unit.UTF8>(
                        line: line, column: offsets[indices.lowerBound] + 1
                      ),
                      let end = try? Position.Coordinate<Position.Unit.UTF8>(
                        line: line, column: offsets[indices.upperBound] + 1
                      ),
                      let range = try? Position.CoordinateRange(start: start, end: end) else {
                    return nil
                }
                return .init(range: range)
            }
            return (
                runs.compactMap { span($0.0, offsets: oldOffsets, line: oldLine) },
                runs.compactMap { span($0.1, offsets: newOffsets, line: newLine) }
            )
        }
    }

    func analyze(options: Analysis.Options = .init()) -> Analysis {
        var pairs: [Analysis.Pair] = []
        var index = 0
        while index < lines.count {
            if lines[index].operation == .equal {
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
            for match in Analysis.matches(removed, added, pairing: options.pairing) {
                guard let oldIndex = match.old, let newIndex = match.new,
                      let oldLine = removed[oldIndex].oldLine,
                      let newLine = added[newIndex].newLine else { continue }
                let ranges: (old: [Analysis.Span], new: [Analysis.Span])
                switch options.inline {
                case .none:
                    ranges = ([], [])
                case .characters:
                    ranges = Analysis.changes(
                        old: removed[oldIndex].text,
                        new: added[newIndex].text,
                        oldLine: oldLine,
                        newLine: newLine,
                        maxCells: options.maxCells
                    )
                }
                pairs.append(.init(oldLine: oldLine, newLine: newLine,
                                   old: ranges.old, new: ranges.new))
            }
        }
        return .init(difference: self, pairing: options.pairing, pairs: pairs)
    }
}
