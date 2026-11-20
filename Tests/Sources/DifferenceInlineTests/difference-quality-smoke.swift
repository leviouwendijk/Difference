import Foundation
import Difference

enum DifferenceQualitySmoke {
    private struct Generator {
        var state: UInt64 = 0x5EED_D1FF_2026

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }

        mutating func index(_ count: Int) -> Int {
            Int(next() % UInt64(count))
        }

        mutating func line() -> String {
            let values = [
                "let timeout = 30", "let timeout = 45", "", " ", "    ",
                "let 日本語 = 2", "let 東京 = 30", "e\u{301} cafe", "🇯🇵 漢字",
                "HTTPServerConfiguration", "let value = 123", "a\tb\tc", "{}"
            ]
            let endings = ["\n", "\r\n", "\r", ""]
            return values[index(values.count)] + endings[index(endings.count)]
        }
    }

    private static func reconstruct(_ difference: TextDifference, old: Bool) -> String {
        var source = ""
        for line in difference.lines {
            if old && line.operation == .insert { continue }
            if !old && line.operation == .delete { continue }
            source += line.text
            switch line.ending {
            case .lf: source += "\n"
            case .crlf: source += "\r\n"
            case .cr: source += "\r"
            case .some(.none), nil: break
            }
        }
        return source
    }

    @discardableResult
    private static func verify(_ old: String, _ new: String, options: TextDiffer.Options = .init()) throws -> TextDifference {
        let difference = try TextDiffer.diff(old: old, new: new, options: options)
        precondition(reconstruct(difference, old: true).utf8.elementsEqual(old.utf8))
        precondition(reconstruct(difference, old: false).utf8.elementsEqual(new.utf8))
        let again = try TextDiffer.diff(old: old, new: new, options: options)
        precondition(difference == again, "text differ must be deterministic")

        var expectedOld = 1
        var expectedNew = 1
        for line in difference.lines {
            precondition(line.ending != nil, "text differ must record physical newline endings")
            if line.operation != .insert {
                precondition(line.oldLine == expectedOld)
                expectedOld += 1
            } else {
                precondition(line.oldLine == nil)
            }
            if line.operation != .delete {
                precondition(line.newLine == expectedNew)
                expectedNew += 1
            } else {
                precondition(line.newLine == nil)
            }
        }

        let analysis = difference.analyze()
        let second = difference.analyze()
        precondition(analysis.pairs == second.pairs, "alignment must be deterministic")
        var lastOld = 0
        var lastNew = 0
        let oldLines = Dictionary(uniqueKeysWithValues: difference.lines.compactMap { line in
            line.oldLine.map { ($0, line) }
        })
        let newLines = Dictionary(uniqueKeysWithValues: difference.lines.compactMap { line in
            line.newLine.map { ($0, line) }
        })
        for pair in analysis.pairs {
            precondition(pair.oldLine > lastOld && pair.newLine > lastNew,
                         "aligned replacement pairs must be strictly monotone")
            guard let before = oldLines[pair.oldLine], let after = newLines[pair.newLine] else {
                preconditionFailure("pair references a nonexistent source line")
            }
            precondition(before.operation == .delete && after.operation == .insert,
                         "a replacement must pair deleted and inserted lines")
            for span in pair.old {
                precondition(span.range.start.line == pair.oldLine &&
                             span.range.end.line == pair.oldLine &&
                             span.range.start.column >= 1 &&
                             span.range.end.column <= before.text.utf8.count + 1 &&
                             span.range.start.column < span.range.end.column)
            }
            for span in pair.new {
                precondition(span.range.start.line == pair.newLine &&
                             span.range.end.line == pair.newLine &&
                             span.range.start.column >= 1 &&
                             span.range.end.column <= after.text.utf8.count + 1 &&
                             span.range.start.column < span.range.end.column)
            }
            lastOld = pair.oldLine
            lastNew = pair.newLine
        }

        let projection = DifferenceLayout.project(analysis, mode: .split, options: .full)
        let projectedOld = projection.rows.compactMap { $0.old?.text }
        let projectedNew = projection.rows.compactMap { $0.new?.text }
        let oldText = difference.lines.filter { $0.operation != .insert }.map(\.text)
        let newText = difference.lines.filter { $0.operation != .delete }.map(\.text)
        precondition(projectedOld == oldText && projectedNew == newText,
                     "semantic split projection lost or duplicated source lines")
        return difference
    }

    private static func referenceLCS(_ old: [String], _ new: [String]) -> Int {
        let width = new.count + 1
        var table = [Int](repeating: 0, count: (old.count + 1) * width)
        if !old.isEmpty && !new.isEmpty {
            for i in stride(from: old.count - 1, through: 0, by: -1) {
                for j in stride(from: new.count - 1, through: 0, by: -1) {
                    table[i * width + j] = old[i] == new[j]
                        ? 1 + table[(i + 1) * width + j + 1]
                        : max(table[(i + 1) * width + j], table[i * width + j + 1])
                }
            }
        }
        return table[0]
    }

    static func run() throws {
        let special: [(String, String)] = [
            ("", ""), ("", "x"), ("x", ""), ("a\n", "a"), ("a", "a\n"),
            ("a\r\nb\rc\n", "a\r\nb\nc\r"),
            ("\n\n", "\r\n\r"), ("🇯🇵 日本語\ne\u{301}\n", "🇯🇵 漢字\né\r\n"),
            ("\tlet timeout = 30\n", "\tlet timeout = 45\n"),
            ("same\nsame\nsame\n", "same\nsame\n"),
            ("hello\rworld\n", "hello\nworld\r")
        ]
        for (old, new) in special {
            _ = try verify(old, new)
        }

        let lcsCases: [([String], [String])] = [
            (["a", "b", "c"], ["b", "a", "c"]),
            (["repeat", "repeat", "a"], ["repeat", "a", "repeat"]),
            (["a", "b", "a", "b"], ["b", "a", "b", "a"]),
            ([], ["one", "two"]),
            (["one", "two"], []),
            (["x", "x", "x"], ["x", "x"])
        ]
        for (old, new) in lcsCases {
            let before = old.map { $0 + "\n" }.joined()
            let after = new.map { $0 + "\n" }.joined()
            let result = try verify(before, after)
            precondition(result.quality == .shortest)
            precondition(result.changeCount == old.count + new.count - 2 * referenceLCS(old, new),
                         "Myers did not produce the minimum number of line changes")
        }

        var generator = Generator()
        for _ in 0..<200 {
            let source = (0..<generator.index(32)).map { _ in generator.line() }
            var target = source
            for _ in 0..<(1 + generator.index(9)) {
                switch generator.index(3) {
                case 0 where !target.isEmpty:
                    target.remove(at: generator.index(target.count))
                case 1 where !target.isEmpty:
                    target[generator.index(target.count)] = generator.line()
                default:
                    target.insert(generator.line(), at: generator.index(target.count + 1))
                }
            }
            _ = try verify(source.joined(), target.joined())
        }

        let old = (0..<96).map { "old_\($0)\n" }.joined()
        let new = (0..<96).map { "new_\($0)\r\n" }.joined()
        let coarse = try verify(old, new, options: .init(maxTraceCells: 32, onLimit: .coarse))
        precondition(coarse.quality == .coarse, "trace budget must force coarse, exact reconstruction")
        do {
            _ = try TextDiffer.diff(old: old, new: new,
                                    options: .init(maxTraceCells: 32, onLimit: .fail))
            preconditionFailure("trace budget failure was ignored")
        } catch TextDiffer.Failure.limit_exceeded {
            // Expected.
        }

        let oldBlock = (0..<128).map { i in
            DifferenceLine(operation: .delete, text: "let timeout_\(i) = 30", oldLine: i + 1)
        }
        let newBlock = (0..<128).map { i in
            DifferenceLine(operation: .insert, text: "let timeout_\(i) = 45", newLine: i + 1)
        }
        let large = TextDifference(oldName: "old", newName: "new", lines: oldBlock + newBlock)
        let expected = large.analyze(options: .init(pairing: .similarity(minimum: 0.45), inline: .none))
        let capped = large.analyze(options: .init(
            pairing: .aligned(minimum: 0.45, maxCells: 16_384), inline: .none
        ))
        precondition(expected.pairs == capped.pairs, "over-budget pairing did not take greedy fallback")
        let withoutPairing = large.analyze(options: .init(pairing: .none, inline: .none))
        precondition(withoutPairing.pairs.isEmpty)
        print("difference quality: 200 seeded cases, exact reconstruction, shortest scripts, spans, pairing limits passed")
    }
}
