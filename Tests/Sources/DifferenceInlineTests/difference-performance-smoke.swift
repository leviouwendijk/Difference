import Dispatch
import Foundation
import Difference

enum DifferencePerformanceSmoke {
    private static func changedBlock(_ count: Int, length: Int = 48) -> TextDifference {
        let padding = String(repeating: "x", count: max(0, length - 28))
        let removed = (0..<count).map { i in
            DifferenceLine(operation: .delete,
                           text: "let request_\(i) = timeout(30)" + padding, oldLine: i + 1)
        }
        let added = (0..<count).map { i in
            DifferenceLine(operation: .insert,
                           text: "let request_\(i) = timeout(45)" + padding, newLine: i + 1)
        }
        return TextDifference(oldName: "before", newName: "after", lines: removed + added)
    }

    private static func measure(_ label: String, repetitions: Int, body: () -> Int) {
        _ = body()
        let start = DispatchTime.now().uptimeNanoseconds
        var count = 0
        for _ in 0..<repetitions {
            count &+= body()
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        let milliseconds = Double(elapsed) / 1_000_000 / Double(repetitions)
        print("difference benchmark \(label): \(String(format: "%.3f", milliseconds)) ms/run (n=\(repetitions), result=\(count))")
    }

    static func run() {
        for count in [48, 96, 128, 256] {
            let difference = changedBlock(count)
            let cells = (count + 1) * (count + 1)
            let repeats = count <= 96 ? 5 : 3
            measure("aligned-\(count) / \(cells) cells", repetitions: repeats) {
                difference.analyze(options: .init(inline: .none)).pairs.count
            }
            measure("greedy-\(count)", repetitions: repeats) {
                difference.analyze(options: .init(
                    pairing: .similarity(minimum: 0.45), inline: .none
                )).pairs.count
            }
        }
        let longLines = changedBlock(20, length: 12_000)
        measure("aligned-20 / long lines", repetitions: 3) {
            longLines.analyze(options: .init(inline: .none)).pairs.count
        }
        let unchanged = (0..<2_000).map { "let value_\($0) = \($0)" }
        var updated = unchanged
        updated[100] = "let value_100 = -1"
        updated[1_900] = "let value_1900 = -1"
        measure("Myers-2000-lines / 2 changes", repetitions: 3) {
            TextDiffer.diff(old: unchanged.joined(separator: "\n") + "\n",
                            new: updated.joined(separator: "\n") + "\n").changeCount
        }
        let complete = changedBlock(96)
        let prepared = complete.analyze(options: .init(inline: .none))
        measure("projection-precomputed-96", repetitions: 5) {
            DifferenceLayout.project(prepared, mode: .split, options: .full).rows.count
        }
        measure("direct projection-96", repetitions: 3) {
            DifferenceLayout.project(complete, mode: .split, options: .full).rows.count
        }
        measure("analysis + projection-96", repetitions: 3) {
            let analysis = complete.analyze(options: .init(inline: .none))
            return DifferenceLayout.project(analysis, mode: .split, options: .full).rows.count
        }
        print("difference benchmark completed (observational; no machine-specific latency threshold)")
    }
}
