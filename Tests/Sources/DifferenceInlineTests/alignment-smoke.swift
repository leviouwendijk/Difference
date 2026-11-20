import Foundation
import Difference

enum DifferenceAlignmentSmoke {
    static func run() {
        let ambiguous = TextDifference(
            oldName: "old.swift", newName: "new.swift",
            lines: [
                .init(operation: .delete, text: "configure(timeout: 30)", oldLine: 1),
                .init(operation: .delete, text: "configure(retries: 2)", oldLine: 2),
                .init(operation: .insert, text: "configure(retries: 4)", newLine: 1)
            ]
        )
        let aligned = ambiguous.analyze()
        let greedy = ambiguous.analyze(options: .init(pairing: .similarity(minimum: 0.45)))
        let limited = ambiguous.analyze(options: .init(pairing: .aligned(minimum: 0.45, maxCells: 1)))
        precondition(aligned.pairs.count == 1 && aligned.pairs[0].oldLine == 2
                     && aligned.pairs[0].newLine == 1, "aligned: should skip the weaker old line")
        precondition(greedy.pairs.count == 1 && greedy.pairs[0].oldLine == 1
                     && greedy.pairs[0].newLine == 1, "legacy greedy fixture changed")
        precondition(limited.pairs == greedy.pairs, "bounded fallback differs from greedy")

        let projected = DifferenceLayout.project(ambiguous, mode: .split, options: .full)
        let projectedAnalysis = DifferenceLayout.project(aligned, mode: .split, options: .full)
        let rows = projected.rows.compactMap { row -> (Int?, Int?)? in
            guard case .content = row.kind else { return nil }
            return (row.old?.line, row.new?.line)
        }
        let analyzedRows = projectedAnalysis.rows.compactMap { row -> (Int?, Int?)? in
            guard case .content = row.kind else { return nil }
            return (row.old?.line, row.new?.line)
        }
        precondition(rows.count == 2 && rows[0].0 == 1 && rows[0].1 == nil
                     && rows[1].0 == 2 && rows[1].1 == 1, "split projection pairing mismatch")
        precondition(analyzedRows.count == rows.count && zip(rows, analyzedRows).allSatisfy {
            $0.0.0 == $0.1.0 && $0.0.1 == $0.1.1
        }, "analysis and projection disagree on pairing")

        let crossed = TextDifference(
            oldName: "old.swift", newName: "new.swift",
            lines: [
                .init(operation: .delete, text: "configure(timeout: 30)", oldLine: 1),
                .init(operation: .delete, text: "configure(retries: 2)", oldLine: 2),
                .init(operation: .insert, text: "configure(retries: 4)", newLine: 1),
                .init(operation: .insert, text: "configure(timeout: 45)", newLine: 2)
            ]
        )
        let crossings = crossed.analyze().pairs
        precondition(crossings.count == 1 && crossings[0].oldLine == 2
                     && crossings[0].newLine == 1, "alignment must not make misleading crossed pairs")

        let unicode = TextDifference(
            oldName: "old.swift", newName: "new.swift",
            lines: [
                .init(operation: .delete, text: "let 東京 = 30", oldLine: 1),
                .init(operation: .insert, text: "let 東京 = 45", newLine: 1)
            ]
        )
        let spans = unicode.analyze().pairs
        precondition(spans.count == 1 && spans[0].old.count == 1 && spans[0].new.count == 1,
                     "unicode changed span missing")
        precondition(spans[0].old[0].range.start.column == 14
                     && spans[0].new[0].range.start.column == 14,
                     "UTF-8 spans shifted after alignment")

        let many = TextDifference(
            oldName: "old.swift", newName: "new.swift",
            lines: (1...80).map { (i: Int) -> DifferenceLine in
                .init(operation: .delete, text: "let value_\(i) = 0", oldLine: i)
            } + (1...80).map { (i: Int) -> DifferenceLine in
                .init(operation: .insert, text: "let value_\(i) = 1", newLine: i)
            }
        )
        let none = ambiguous.analyze(options: .init(pairing: .none))
        precondition(none.pairs.isEmpty, "none pairing must remain opt-out")
        let bounded = many.analyze(options: .init(
            pairing: .aligned(minimum: 0.45, maxCells: 32), inline: .none
        ))
        precondition(bounded.pairs.count == 80, "oversized blocks must fall back without omissions")
        do {
            try DifferenceQualitySmoke.run()
        } catch {
            preconditionFailure("difference quality smoke failed: \(error)")
        }
        DifferenceAlignmentReuseSmoke.run()
        DifferencePerformanceSmoke.run()
        print("difference alignment smoke passed")
    }
}
