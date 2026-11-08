import Foundation

public enum TextDiffer {
    public struct Options: Sendable, Hashable {
        public enum OnLimit: Sendable, Hashable {
            case coarse
            case fail
        }

        public var maxTraceCells: Int
        public var onLimit: OnLimit

        public init(maxTraceCells: Int = 4_000_000, onLimit: OnLimit = .coarse) {
            self.maxTraceCells = max(1, maxTraceCells)
            self.onLimit = onLimit
        }
    }

    public enum Failure: Error, Sendable, Equatable {
        case limit_exceeded
    }

    public static func diff(
        old: String,
        new: String,
        oldName: String = "old",
        newName: String = "new"
    ) -> TextDifference {
        // The default operation always completes with an exact, possibly coarse script.
        do {
            return try diff(old: old, new: new, oldName: oldName, newName: newName, options: .init())
        } catch {
            let before = tokenize(old)
            let after = tokenize(new)
            let deleted = before.enumerated().map { index, token in
                DifferenceLine(operation: .delete, text: token.text, oldLine: index + 1, ending: token.ending)
            }
            let inserted = after.enumerated().map { index, token in
                DifferenceLine(operation: .insert, text: token.text, newLine: index + 1, ending: token.ending)
            }
            return .init(oldName: oldName, newName: newName, lines: deleted + inserted,
                         quality: .coarse)
        }
    }

    public static func diff(
        old: String,
        new: String,
        oldName: String = "old",
        newName: String = "new",
        options: Options
    ) throws -> TextDifference {
        let before = tokenize(old)
        let after = tokenize(new)
        var prefix = 0
        while prefix < min(before.count, after.count), before[prefix] == after[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < min(before.count, after.count) - prefix,
              before[before.count - suffix - 1] == after[after.count - suffix - 1] {
            suffix += 1
        }
        let oldMiddle = Array(before[prefix..<(before.count - suffix)])
        let newMiddle = Array(after[prefix..<(after.count - suffix)])
        let computed = try steps(oldMiddle, newMiddle, options: options)
        var operations: [Step] = []
        operations.reserveCapacity(before.count + after.count)
        for index in 0..<prefix { operations.append(.equal(index, index)) }
        for step in computed.steps {
            switch step {
            case .equal(let i, let j): operations.append(.equal(i + prefix, j + prefix))
            case .delete(let i): operations.append(.delete(i + prefix))
            case .insert(let j): operations.append(.insert(j + prefix))
            }
        }
        for index in 0..<suffix {
            operations.append(.equal(before.count - suffix + index, after.count - suffix + index))
        }
        let lines = operations.map { step -> DifferenceLine in
            switch step {
            case .equal(let i, let j):
                return .init(operation: .equal, text: before[i].text, oldLine: i + 1,
                             newLine: j + 1, ending: before[i].ending)
            case .delete(let i):
                return .init(operation: .delete, text: before[i].text, oldLine: i + 1,
                             ending: before[i].ending)
            case .insert(let j):
                return .init(operation: .insert, text: after[j].text, newLine: j + 1,
                             ending: after[j].ending)
            }
        }
        return .init(oldName: oldName, newName: newName, lines: lines,
                     quality: computed.coarse ? .coarse : .shortest)
    }

    private struct Token: Equatable {
        let text: String
        let ending: DifferenceLine.Ending
    }

    private enum Step {
        case equal(Int, Int)
        case delete(Int)
        case insert(Int)
    }

    private static func tokenize(_ source: String) -> [Token] {
        let bytes = Array(source.utf8)
        var result: [Token] = []
        var start = 0
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            guard byte == 10 || byte == 13 else {
                index += 1
                continue
            }
            let ending: DifferenceLine.Ending
            let length: Int
            if byte == 13, index + 1 < bytes.count, bytes[index + 1] == 10 {
                ending = .crlf
                length = 2
            } else if byte == 13 {
                ending = .cr
                length = 1
            } else {
                ending = .lf
                length = 1
            }
            result.append(.init(text: String(decoding: bytes[start..<index], as: UTF8.self), ending: ending))
            index += length
            start = index
        }
        if start < bytes.count {
            result.append(.init(text: String(decoding: bytes[start..<bytes.count], as: UTF8.self), ending: .none))
        }
        return result
    }

    private static func steps(
        _ old: [Token],
        _ new: [Token],
        options: Options
    ) throws -> (steps: [Step], coarse: Bool) {
        if old.isEmpty { return (new.indices.map { .insert($0) }, false) }
        if new.isEmpty { return (old.indices.map { .delete($0) }, false) }
        let (maximum, countOverflow) = old.count.addingReportingOverflow(new.count)
        guard !countOverflow, maximum <= (Int.max - 3) / 2 else {
            throw Failure.limit_exceeded
        }
        let length = maximum * 2 + 3
        if length > options.maxTraceCells {
            if options.onLimit == .fail { throw Failure.limit_exceeded }
            return (old.indices.map { .delete($0) } + new.indices.map { .insert($0) }, true)
        }
        let offset = maximum + 1
        var previous = Array(repeating: -1, count: length)
        previous[offset + 1] = 0
        var trace: [[Int]] = []
        for depth in 0...maximum {
            if length > options.maxTraceCells / (depth + 1) {
                if options.onLimit == .fail { throw Failure.limit_exceeded }
                return (old.indices.map { .delete($0) } + new.indices.map { .insert($0) }, true)
            }
            trace.append(previous)
            for diagonal in stride(from: -depth, through: depth, by: 2) {
                let position = offset + diagonal
                var x: Int
                if diagonal == -depth || (diagonal != depth && previous[position - 1] < previous[position + 1]) {
                    x = previous[position + 1]
                } else {
                    x = previous[position - 1] + 1
                }
                var y = x - diagonal
                while x < old.count, y < new.count, x >= 0, y >= 0, old[x] == new[y] {
                    x += 1
                    y += 1
                }
                previous[position] = x
                if x >= old.count, y >= new.count {
                    return (backtrack(trace: trace, depth: depth, oldCount: old.count,
                                      newCount: new.count, offset: offset), false)
                }
            }
        }
        // The search should always terminate. Treat any violation as an error.
        throw Failure.limit_exceeded
    }

    private static func backtrack(
        trace: [[Int]], depth: Int, oldCount: Int, newCount: Int, offset: Int
    ) -> [Step] {
        var x = oldCount
        var y = newCount
        var reversed: [Step] = []
        if depth > 0 {
            for d in stride(from: depth, through: 1, by: -1) {
                let v = trace[d]
                let k = x - y
                let previousK: Int
                if k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) {
                    previousK = k + 1
                } else {
                    previousK = k - 1
                }
                let previousX = v[offset + previousK]
                let previousY = previousX - previousK
                while x > previousX, y > previousY {
                    reversed.append(.equal(x - 1, y - 1))
                    x -= 1
                    y -= 1
                }
                if x == previousX {
                    reversed.append(.insert(y - 1))
                    y -= 1
                } else {
                    reversed.append(.delete(x - 1))
                    x -= 1
                }
            }
        }
        while x > 0, y > 0 {
            reversed.append(.equal(x - 1, y - 1))
            x -= 1
            y -= 1
        }
        while x > 0 { reversed.append(.delete(x - 1)); x -= 1 }
        while y > 0 { reversed.append(.insert(y - 1)); y -= 1 }
        return reversed.reversed()
    }
}
