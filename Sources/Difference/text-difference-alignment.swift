import Foundation

extension TextDifference.Analysis {
    /// Computes a minimum-cost, monotone alignment across one changed block.
    /// Scores line replacements against explicit deletion/insertion gaps.
    /// Work is bounded by maxCells; oversized blocks use the legacy matcher.
    static func align(
        _ removed: [DifferenceLine],
        _ added: [DifferenceLine],
        minimum: Double,
        maxCells: Int
    ) -> [Match] {
        guard !removed.isEmpty, !added.isEmpty else {
            return matches(removed, added, pairing: .none)
        }

        let n = removed.count
        let m = added.count
        let (cells, overflow) = (n + 1).multipliedReportingOverflow(by: m + 1)
        guard !overflow, cells <= max(1, maxCells) else {
            return matches(removed, added, pairing: .similarity(minimum: minimum))
        }

        let threshold = minimum.isFinite ? max(0, min(1, minimum)) : 1
        let before = removed.map { Features($0.text) }
        let after = added.map { Features($0.text) }
        let rowWidth = m + 1
        let gapCost = 0.8
        let epsilon = 1e-9

        // 0: pair, 1: remove, 2: add. Equal scores prefer a pair,
        // then deletion, then insertion for deterministic output.
        var costs = [Double](repeating: 0, count: cells)
        var decisions = [UInt8](repeating: 0, count: cells)
        for i in stride(from: n - 1, through: 0, by: -1) {
            let position = i * rowWidth + m
            costs[position] = gapCost + costs[position + rowWidth]
            decisions[position] = 1
        }
        for j in stride(from: m - 1, through: 0, by: -1) {
            let position = n * rowWidth + j
            costs[position] = gapCost + costs[position + 1]
            decisions[position] = 2
        }
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                let position = i * rowWidth + j
                var best = gapCost + costs[position + rowWidth]
                var decision: UInt8 = 1
                let insertCost = gapCost + costs[position + 1]
                if insertCost + epsilon < best {
                    best = insertCost
                    decision = 2
                }

                let likeness = similarity(before[i], after[j])
                if likeness >= threshold {
                    let oldProgress = Double(i + 1) / Double(n + 1)
                    let newProgress = Double(j + 1) / Double(m + 1)
                    let displacement = abs(oldProgress - newProgress) * 0.12
                    let replaceCost = 1.3 - likeness + displacement
                        + costs[position + rowWidth + 1]
                    if replaceCost <= best + epsilon {
                        best = replaceCost
                        decision = 0
                    }
                }
                costs[position] = best
                decisions[position] = decision
            }
        }

        var result: [Match] = []
        result.reserveCapacity(n + m)
        var i = 0
        var j = 0
        while i < n || j < m {
            if i == n {
                result.append(.init(old: nil, new: j))
                j += 1
            } else if j == m {
                result.append(.init(old: i, new: nil))
                i += 1
            } else {
                switch decisions[i * rowWidth + j] {
                case 0:
                    result.append(.init(old: i, new: j))
                    i += 1
                    j += 1
                case 1:
                    result.append(.init(old: i, new: nil))
                    i += 1
                default:
                    result.append(.init(old: nil, new: j))
                    j += 1
                }
            }
        }
        return result
    }

    private struct Features {
        let characters: [Character]
        let words: Set<String>

        init(_ text: String) {
            // Prefix/suffix features are bounded for extremely long source lines.
            characters = Array(text.prefix(512))
            words = Set(text.split(whereSeparator: {
                !$0.isLetter && !$0.isNumber && $0 != "_"
            }).prefix(64).map(String.init))
        }
    }

    private static func similarity(_ lhs: Features, _ rhs: Features) -> Double {
        let old = lhs.characters
        let new = rhs.characters
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
        let anchored = Double(prefix + suffix) / Double(count)
        let totalWords = lhs.words.count + rhs.words.count
        guard totalWords > 0 else { return anchored }
        let commonWords = lhs.words.intersection(rhs.words).count
        let lexical = Double(2 * commonWords) / Double(totalWords)
        return anchored * 0.65 + lexical * 0.35
    }
}
